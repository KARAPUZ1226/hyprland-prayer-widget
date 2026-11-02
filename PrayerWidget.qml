pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "prayer"
    hoverEnabled: true

    readonly property real cardWidth: 486
    readonly property real cardHeight: 184

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    property var prayerData: ({
        title: "Время намаза",
        city: "Гудермес",
        hijri_date: "23 Джумада аль-уля 1448",
        special_day: "",
        fajr: "05:17",
        sunrise: "06:30",
        dhuhr: "12:30",
        asr: "14:45",
        maghrib: "16:51",
        isha: "18:20",
        midnight: "23:39",
        tahajjud: "01:56"
    })

    property string currentPrayerName: "Иша"
    property string nextPrayerName: "Фаджр"
    property string nextPrayerKey: "fajr"
    property string nextPrayerType: "night"
    property string nextPrayerHours: "05"
    property string nextPrayerMins: "17"
    property string remainingTimeStr: "09:15"
    property real progressVal: 0.15

    function parseMin(s) {
        if (!s) return 0;
        var parts = s.split(":");
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
    }

    function updateTimes() {
        if (!prayerData || !prayerData.fajr) return;
        var now = new Date();
        var curM = now.getHours() * 60 + now.getMinutes();

        var schedule = [
            { key: "fajr", name: "Фаджр", time: prayerData.fajr, type: "dawn", m: parseMin(prayerData.fajr) },
            { key: "sunrise", name: "Восход", time: prayerData.sunrise, type: "sunrise", m: parseMin(prayerData.sunrise) },
            { key: "dhuhr", name: "Зухр", time: prayerData.dhuhr, type: "day", m: parseMin(prayerData.dhuhr) },
            { key: "asr", name: "Аср", time: prayerData.asr, type: "day", m: parseMin(prayerData.asr) },
            { key: "maghrib", name: "Магриб", time: prayerData.maghrib, type: "sunset", m: parseMin(prayerData.maghrib) },
            { key: "isha", name: "Иша", time: prayerData.isha, type: "night", m: parseMin(prayerData.isha) }
        ];

        var nextIdx = -1;
        for (var i = 0; i < schedule.length; i++) {
            if (schedule[i].m > curM) {
                nextIdx = i;
                break;
            }
        }

        var nextItem;
        var prevItem;
        var diffM = 0;
        var intervalLen = 0;
        var elapsed = 0;

        if (nextIdx !== -1) {
            nextItem = schedule[nextIdx];
            prevItem = (nextIdx > 0) ? schedule[nextIdx - 1] : schedule[schedule.length - 1];
            diffM = nextItem.m - curM;

            if (nextIdx === 0) {
                intervalLen = (nextItem.m + 1440 - prevItem.m) % 1440;
                elapsed = (curM + 1440 - prevItem.m) % 1440;
            } else {
                intervalLen = nextItem.m - prevItem.m;
                elapsed = curM - prevItem.m;
            }
        } else {
            nextItem = schedule[0];
            prevItem = schedule[schedule.length - 1];
            diffM = (1440 - curM) + nextItem.m;
            intervalLen = (nextItem.m + 1440 - prevItem.m) % 1440;
            elapsed = curM - prevItem.m;
        }

        currentPrayerName = prevItem.name;
        nextPrayerName = nextItem.name;
        nextPrayerKey = nextItem.key;
        nextPrayerType = nextItem.type;

        var parts = nextItem.time.split(":");
        nextPrayerHours = parts[0] || "00";
        nextPrayerMins = parts[1] || "00";

        var remH = Math.floor(diffM / 60);
        var remM = diffM % 60;
        remainingTimeStr = (remH < 10 ? "0" + remH : "" + remH) + ":" + (remM < 10 ? "0" + remM : "" + remM);

        if (intervalLen > 0) {
            progressVal = Math.max(0.0, Math.min(1.0, elapsed / intervalLen));
        }
    }

    Process {
        id: fetchProc
        command: ["python3", Quickshell.shellPath("modules/ii/background/widgets/prayer/fetch_prayer.py")]
        stdout: StdioCollector {
            id: stdioCollector
            onStreamFinished: {
                if (stdioCollector.text.length > 0) {
                    try {
                        root.prayerData = JSON.parse(stdioCollector.text);
                        root.updateTimes();
                    } catch (e) {
                        console.log("Prayer JSON parse error: " + e);
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateTimes()
    }

    Timer {
        interval: 900000 // 15 mins
        running: true
        repeat: true
        onTriggered: fetchProc.running = true
    }

    Component.onCompleted: {
        fetchProc.running = true;
        root.updateTimes();
    }

    Rectangle {
        id: card
        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        radius: Appearance.rounding?.large ?? 28
        color: Appearance.colors.colLayer1Base
        border.color: Appearance.colors.colLayer0Border
        border.width: 1

        StyledRectangularShadow {
            target: card
            z: -2
            visible: Config.options.background.widgets.shadow
        }

        FastBlurred {
            anchors.fill: parent
            blurSource: root.wallpaperItem
            cardRadius: card.radius
            tint: Appearance.colors.colLayer1
            tintOpacity: 0.70
            trackX: root.x
            trackY: root.y
            visible: Config.options.background.widgets.blurWidgets
        }

        // Top Header
        Item {
            id: headerRow
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 18
                rightMargin: 18
            }
            height: 26

            // Left Header: Mosque Icon + City + Current Prayer Status
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                StyledText {
                    text: "🕌"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.prayerData.city || "Гудермес"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer2
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Current Prayer Status Pill (M3 Tonal Pill)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: Appearance.colors.colLayer2
                    implicitWidth: currentStatusText.implicitWidth + 14

                    StyledText {
                        id: currentStatusText
                        anchors.centerIn: parent
                        text: "● " + root.currentPrayerName
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }
                }
            }

            // Right Header: Special Day Chip + Hijri Date Chip
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Special day badge (e.g. "Джума", "Рамадан", "Ураза-Байрам")
                Rectangle {
                    visible: (root.prayerData.special_day ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: Appearance.colors.colPrimary
                    implicitWidth: specialDayText.implicitWidth + 14

                    StyledText {
                        id: specialDayText
                        anchors.centerIn: parent
                        text: root.prayerData.special_day ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimary
                    }
                }

                // Hijri date chip
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: Appearance.colors.colLayer2
                    border.color: Appearance.colors.colLayer0Border
                    border.width: 1
                    implicitWidth: hijriDateText.implicitWidth + 14

                    StyledText {
                        id: hijriDateText
                        anchors.centerIn: parent
                        text: root.prayerData.hijri_date || ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        // Main Content Area
        Item {
            id: contentArea
            anchors {
                top: headerRow.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 8
                bottomMargin: 12
                leftMargin: 18
                rightMargin: 18
            }

            // 1. Left Dynamic Hero Art Card
            Rectangle {
                id: heroArtCard
                width: 114
                height: 114
                radius: 22
                clip: true
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.nextPrayerType === "night" ? "#1e1b4b" :
                               root.nextPrayerType === "dawn" ? "#2e1065" :
                               root.nextPrayerType === "sunrise" ? "#431407" :
                               root.nextPrayerType === "sunset" ? "#4c0519" : "#0284c7"
                    }
                    GradientStop {
                        position: 1.0
                        color: root.nextPrayerType === "night" ? "#0f172a" :
                               root.nextPrayerType === "dawn" ? "#170f2f" :
                               root.nextPrayerType === "sunrise" ? "#ea580c" :
                               root.nextPrayerType === "sunset" ? "#9f1239" : "#0369a1"
                    }
                }

                // Celestial Glow
                Rectangle {
                    width: 78
                    height: 78
                    radius: 39
                    anchors.centerIn: parent
                    color: root.nextPrayerType === "night" || root.nextPrayerType === "dawn" ? "#c084fc" :
                           root.nextPrayerType === "sunrise" ? "#fdba74" :
                           root.nextPrayerType === "sunset" ? "#fda4af" : "#fef08a"
                    opacity: root.nextPrayerType === "night" ? 0.22 : 0.35
                }

                // Moon / Sun Core
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    anchors.centerIn: parent
                    color: root.nextPrayerType === "night" || root.nextPrayerType === "dawn" ? "#e9d5ff" :
                           root.nextPrayerType === "sunrise" ? "#ffedd5" :
                           root.nextPrayerType === "sunset" ? "#ffe4e6" : "#fef9c3"
                    opacity: root.nextPrayerType === "night" ? 0.85 : 0.92
                }

                // Night Stars
                Item {
                    anchors.fill: parent
                    visible: root.nextPrayerType === "night" || root.nextPrayerType === "dawn"
                    Rectangle { x: 16; y: 18; width: 3; height: 3; radius: 1.5; color: "#ffffff"; opacity: 0.85 }
                    Rectangle { x: 94; y: 22; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.75 }
                    Rectangle { x: 22; y: 90; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.70 }
                    Rectangle { x: 90; y: 86; width: 3; height: 3; radius: 1.5; color: "#ffffff"; opacity: 0.85 }
                }

                // Day Radiance Rays
                Item {
                    anchors.fill: parent
                    visible: root.nextPrayerType === "day"
                    Rectangle { x: 14; y: 16; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                    Rectangle { x: 96; y: 18; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                    Rectangle { x: 92; y: 92; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                    Rectangle { x: 18; y: 90; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                }

                // Large Numerals in Material Clock style
                Column {
                    anchors.centerIn: parent
                    spacing: -6

                    StyledText {
                        text: root.nextPrayerHours
                        font.pixelSize: 42
                        font.weight: Font.Bold
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: root.nextPrayerMins
                        font.pixelSize: 42
                        font.weight: Font.Bold
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fetchProc.running = true;
                    }
                }
            }

            // 2. Middle Section: Next Prayer, Countdown & Progress Bar
            Column {
                id: middleSection
                anchors {
                    left: heroArtCard.right
                    right: rightTimingsList.left
                    leftMargin: 12
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

                // Next prayer title
                StyledText {
                    text: root.nextPrayerName
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer2
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // "через" subtitle
                StyledText {
                    text: "через"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.75
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Large countdown time
                StyledText {
                    text: root.remainingTimeStr
                    font.pixelSize: Appearance.font.pixelSize.huge ?? 24
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Material You Linear Progress Bar
                Item {
                    width: 136
                    height: 7
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 3.5
                        color: Appearance.colors.colLayer3

                        Rectangle {
                            height: parent.height
                            radius: 3.5
                            width: Math.max(7, parent.width * root.progressVal)
                            color: Appearance.colors.colPrimary

                            Behavior on width {
                                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            // 3. Right Timings List
            Column {
                id: rightTimingsList
                width: 156
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Repeater {
                    model: [
                        { name: "Фаджр", key: "fajr", time: root.prayerData.fajr || "05:17" },
                        { name: "Восход", key: "sunrise", time: root.prayerData.sunrise || "06:30" },
                        { name: "Зухр", key: "dhuhr", time: root.prayerData.dhuhr || "12:30" },
                        { name: "Аср", key: "asr", time: root.prayerData.asr || "14:45" },
                        { name: "Магриб", key: "maghrib", time: root.prayerData.maghrib || "16:51" },
                        { name: "Иша", key: "isha", time: root.prayerData.isha || "18:20" }
                    ]

                    delegate: Item {
                        id: timingRow
                        required property var modelData
                        width: parent.width
                        height: 19

                        readonly property bool isCurrent: root.nextPrayerKey === timingRow.modelData.key
                        readonly property bool isSunrise: timingRow.modelData.key === "sunrise"

                        // Active prayer M3 Tonal Pill background
                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: timingRow.isCurrent ? Appearance.colors.colPrimaryContainer :
                                   (hoverArea.containsMouse ? Appearance.colors.colLayer2 : "transparent")
                            opacity: timingRow.isCurrent ? 1.0 : (hoverArea.containsMouse ? 0.6 : 0)

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            anchors {
                                fill: parent
                                leftMargin: timingRow.isCurrent ? 8 : 4
                                rightMargin: timingRow.isCurrent ? 8 : 4
                            }

                            // Prayer name
                            StyledText {
                                text: timingRow.modelData.name
                                width: 82
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: timingRow.isCurrent ? Font.Bold : Font.Normal
                                font.italic: timingRow.isSunrise && !timingRow.isCurrent
                                color: timingRow.isCurrent ? Appearance.colors.colOnPrimaryContainer :
                                       (timingRow.isSunrise ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnLayer2)
                                opacity: timingRow.isSunrise && !timingRow.isCurrent ? 0.65 : 0.90
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Prayer time
                            StyledText {
                                text: timingRow.modelData.time
                                width: 62
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: timingRow.isCurrent ? Font.Bold : Font.Normal
                                color: timingRow.isCurrent ? Appearance.colors.colOnPrimaryContainer :
                                       (timingRow.isSunrise ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnLayer2)
                                opacity: timingRow.isSunrise && !timingRow.isCurrent ? 0.65 : 0.90
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
