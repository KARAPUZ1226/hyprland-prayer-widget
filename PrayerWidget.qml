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

    readonly property real cardWidth: 420
    readonly property real cardHeight: 134

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    property var prayerData: ({
        title: "Время намаза",
        hijri_date: "23 Джумада аль-уля",
        special_day: "",
        fajr: "05:17",
        sunrise: "06:30",
        dhuhr: "12:30",
        asr: "14:45",
        maghrib: "16:51",
        isha: "18:20"
    })

    property string nextPrayerName: "Иша"
    property string nextPrayerKey: "isha"
    property string nextPrayerType: "night"
    property string nextPrayerHours: "18"
    property string nextPrayerMins: "20"
    property string remainingTimeStr: "01:05"

    function updateTimes() {
        if (!prayerData || !prayerData.fajr) return;
        var now = new Date();
        var curMinutes = now.getHours() * 60 + now.getMinutes();

        function parseMin(s) {
            if (!s) return 0;
            var parts = s.split(":");
            return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
        }

        var schedule = [
            { key: "fajr", name: "Фаджр", timeStr: prayerData.fajr, minutes: parseMin(prayerData.fajr), type: "dawn" },
            { key: "sunrise", name: "Восход", timeStr: prayerData.sunrise, minutes: parseMin(prayerData.sunrise), type: "sunrise" },
            { key: "dhuhr", name: "Зухр", timeStr: prayerData.dhuhr, minutes: parseMin(prayerData.dhuhr), type: "day" },
            { key: "asr", name: "Аср", timeStr: prayerData.asr, minutes: parseMin(prayerData.asr), type: "day" },
            { key: "maghrib", name: "Магриб", timeStr: prayerData.maghrib, minutes: parseMin(prayerData.maghrib), type: "sunset" },
            { key: "isha", name: "Иша", timeStr: prayerData.isha, minutes: parseMin(prayerData.isha), type: "night" }
        ];

        var next = null;
        var diffMin = 0;

        for (var i = 0; i < schedule.length; i++) {
            if (schedule[i].minutes > curMinutes) {
                next = schedule[i];
                diffMin = schedule[i].minutes - curMinutes;
                break;
            }
        }

        if (!next) {
            next = schedule[0]; // Tomorrow's Fajr
            diffMin = (24 * 60 - curMinutes) + schedule[0].minutes;
        }

        nextPrayerName = next.name;
        nextPrayerKey = next.key;
        nextPrayerType = next.type;

        var parts = next.timeStr.split(":");
        nextPrayerHours = parts[0] || "00";
        nextPrayerMins = parts[1] || "00";

        var remH = Math.floor(diffMin / 60);
        var remM = diffMin % 60;
        remainingTimeStr = (remH < 10 ? "0" + remH : "" + remH) + ":" + (remM < 10 ? "0" + remM : "" + remM);
    }

    Process {
        id: fetchProc
        command: ["python3", Quickshell.shellPath("modules/ii/background/widgets/prayer/fetch_prayer.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    try {
                        root.prayerData = JSON.parse(text);
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
        interval: 3600000 // 1 hour
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
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

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
            tintOpacity: 0.55
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
                topMargin: 10
                leftMargin: 14
                rightMargin: 14
            }
            height: 20

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                StyledText {
                    text: "🕋"
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Время намаза"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    visible: (root.prayerData.special_day ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    radius: 9
                    color: Appearance.colors.colPrimary
                    opacity: 0.9
                    implicitWidth: holidayText.implicitWidth + 10

                    StyledText {
                        id: holidayText
                        anchors.centerIn: parent
                        text: root.prayerData.special_day ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimary
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.prayerData.hijri_date || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.75
                }
            }
        }

        // Main content
        Item {
            id: contentArea
            anchors {
                top: headerRow.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 6
                bottomMargin: 10
                leftMargin: 14
                rightMargin: 14
            }

            // Left Visual Art Card with Next Prayer Time
            Rectangle {
                id: leftArt
                width: 82
                height: 82
                radius: 18
                clip: true
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.nextPrayerType === "night" ? "#2f2852" :
                               root.nextPrayerType === "sunset" ? "#b91c1c" :
                               root.nextPrayerType === "sunrise" ? "#ea580c" : "#38bdf8"
                    }
                    GradientStop {
                        position: 1.0
                        color: root.nextPrayerType === "night" ? "#181329" :
                               root.nextPrayerType === "sunset" ? "#311042" :
                               root.nextPrayerType === "sunrise" ? "#431407" : "#1d4ed8"
                    }
                }

                // Halo
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    anchors.centerIn: parent
                    color: root.nextPrayerType === "night" ? "#a89ecf" :
                           root.nextPrayerType === "sunset" ? "#f97316" :
                           root.nextPrayerType === "sunrise" ? "#fb923c" : "#fef08a"
                    opacity: root.nextPrayerType === "night" ? 0.35 : 0.45
                }

                // Moon / Sun Core
                Rectangle {
                    width: 42
                    height: 42
                    radius: 21
                    anchors.centerIn: parent
                    color: root.nextPrayerType === "night" ? "#bfb5e5" :
                           root.nextPrayerType === "sunset" ? "#ea580c" :
                           root.nextPrayerType === "sunrise" ? "#f97316" : "#facc15"
                    opacity: root.nextPrayerType === "night" ? 0.85 : 0.95
                }

                // Stars (Night only)
                Item {
                    anchors.fill: parent
                    visible: root.nextPrayerType === "night"
                    Rectangle { x: 10; y: 12; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.8 }
                    Rectangle { x: 66; y: 14; width: 2; height: 2; radius: 1; color: "#ffffff"; opacity: 0.7 }
                    Rectangle { x: 12; y: 64; width: 2; height: 2; radius: 1; color: "#ffffff"; opacity: 0.7 }
                    Rectangle { x: 64; y: 62; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.85 }
                }

                // Sun rays (Day only)
                Item {
                    anchors.fill: parent
                    visible: root.nextPrayerType === "day"
                    Rectangle { x: 8; y: 10; width: 3; height: 3; radius: 1.5; color: "#fef08a"; opacity: 0.7 }
                    Rectangle { x: 68; y: 12; width: 3; height: 3; radius: 1.5; color: "#fef08a"; opacity: 0.7 }
                    Rectangle { x: 66; y: 66; width: 3; height: 3; radius: 1.5; color: "#fef08a"; opacity: 0.7 }
                }

                // Two line time: 18 / 20
                Column {
                    anchors.centerIn: parent
                    spacing: -6

                    StyledText {
                        text: root.nextPrayerHours
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: root.nextPrayerMins
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Middle Countdown Block
            Column {
                id: middleBlock
                anchors {
                    left: leftArt.right
                    right: dividerLine.left
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                StyledText {
                    text: root.nextPrayerName
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "через"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.remainingTimeStr
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Divider Line
            Rectangle {
                id: dividerLine
                width: 1
                height: 80
                anchors.right: timingsTable.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.15
            }

            // Right Timings Table
            Column {
                id: timingsTable
                width: 130
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
                        required property var modelData
                        width: parent.width
                        height: 14

                        readonly property bool isCurrent: root.nextPrayerKey === modelData.key
                        readonly property bool isDimmed: modelData.key === "sunrise" && !isCurrent

                        Row {
                            anchors.fill: parent

                            StyledText {
                                text: parent.parent.modelData.name
                                width: 72
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: parent.parent.isCurrent ? Font.Bold : Font.Normal
                                color: parent.parent.isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                                opacity: parent.parent.isCurrent ? 1.0 : (parent.parent.isDimmed ? 0.45 : 0.85)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: parent.parent.modelData.time
                                width: 58
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: parent.parent.isCurrent ? Font.Bold : Font.Normal
                                color: parent.parent.isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                                opacity: parent.parent.isCurrent ? 1.0 : (parent.parent.isDimmed ? 0.45 : 0.85)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
