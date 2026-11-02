pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: win

    // Hyprland Wayland Layer Shell configuration
    WlrLayershell.layer: (configData.layer === "overlay") ? WlrLayer.Overlay :
                         ((configData.layer === "top") ? WlrLayer.Top : WlrLayer.Bottom)
    WlrLayershell.namespace: "prayer-widget"

    anchors {
        top: true
        left: true
    }

    margins {
        top: win.posY
        left: win.posX
    }

    implicitWidth: 494
    implicitHeight: 196
    color: "transparent"

    property real posX: 40
    property real posY: 80
    property bool showExtended: false

    property var configData: ({
        city: "Гудермес",
        position: { top: 80, left: 40 },
        layer: "bottom",
        theme: "auto"
    })

    readonly property bool isDark: {
        if (configData.theme === "light") return false;
        if (configData.theme === "dark") return true;
        return true; // default Material You dark on Hyprland
    }

    // Material 3 Color Tokens
    readonly property var c: ({
        surface: isDark ? "#121318" : "#fdf8fd",
        surfaceContainer: isDark ? "#191c24" : "#f4f1f7",
        surfaceContainerHigh: isDark ? "#232632" : "#eae6ed",
        surfaceContainerHighest: isDark ? "#2d313e" : "#e0dce3",
        primary: isDark ? "#a8c7fa" : "#0b57d0",
        onPrimary: isDark ? "#042f65" : "#ffffff",
        primaryContainer: isDark ? "#0b4674" : "#d3e3fd",
        onPrimaryContainer: isDark ? "#c2e7ff" : "#041e49",
        secondaryContainer: isDark ? "#2a303c" : "#e0e3ed",
        onSecondaryContainer: isDark ? "#dbe1ed" : "#171c22",
        tertiaryContainer: isDark ? "#482b4a" : "#ffd7f3",
        onTertiaryContainer: isDark ? "#fed6f8" : "#370c3e",
        onSurface: isDark ? "#e3e2e8" : "#1a1b1f",
        onSurfaceVariant: isDark ? "#c4c6cf" : "#44474e",
        outlineVariant: isDark ? "rgba(255, 255, 255, 0.10)" : "rgba(0, 0, 0, 0.08)",
        shadowColor: isDark ? "#45000000" : "#18000000"
    })

    property var prayerData: ({
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
        tahajjud: "01:56",
        progress: 0.15,
        time_type: "night"
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

    function updateLiveCountdown() {
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

    // Process to fetch backend prayer data
    Process {
        id: fetchProc
        command: ["python3", Quickshell.shellPath("fetch_prayer.py")]
        stdout: StdioCollector {
            id: stdoutCol
            onStreamFinished: {
                if (stdoutCol.text.length > 0) {
                    try {
                        var parsed = JSON.parse(stdoutCol.text);
                        win.prayerData = parsed;
                        if (parsed.config) {
                            win.configData = parsed.config;
                            if (parsed.config.position) {
                                win.posX = parsed.config.position.left ?? win.posX;
                                win.posY = parsed.config.position.top ?? win.posY;
                            }
                        }
                        win.updateLiveCountdown();
                    } catch (e) {
                        console.log("Prayer JSON parse error: " + e);
                    }
                }
            }
        }
    }

    // Process to persist window position on drag release
    Process {
        id: savePosProc
    }

    function savePosition(x, y) {
        var pyCode = "import json, os; p = os.path.expanduser('~/.config/quickshell/prayer-widget/config.json'); " +
                     "cfg = json.load(open(p, 'r')) if os.path.exists(p) else {}; " +
                     "cfg.setdefault('position', {})['left'] = " + Math.round(x) + "; " +
                     "cfg['position']['top'] = " + Math.round(y) + "; " +
                     "json.dump(cfg, open(p, 'w'), ensure_ascii=False, indent=2)";
        savePosProc.command = ["python3", "-c", pyCode];
        savePosProc.running = true;
    }

    // Timers: live countdown every second, data refresh every 15 minutes
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: win.updateLiveCountdown()
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: fetchProc.running = true
    }

    Component.onCompleted: {
        fetchProc.running = true;
        win.updateLiveCountdown();
    }

    // Main Card Surface
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: 28
        color: win.c.surfaceContainer
        border.color: win.c.outlineVariant
        border.width: 1

        // Soft elevation shadow
        RectangularGlow {
            z: -1
            anchors.fill: parent
            glowRadius: 18
            spread: 0.12
            color: win.c.shadowColor
            cornerRadius: 28
        }

        // MouseArea for Drag & Drop and subtle gestures (zero button slop)
        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            property real startMouseX: 0
            property real startMouseY: 0
            property bool dragging: false

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    startMouseX = mouse.x;
                    startMouseY = mouse.y;
                    dragging = false;
                } else if (mouse.button === Qt.RightButton) {
                    win.showExtended = !win.showExtended;
                }
            }

            onPositionChanged: (mouse) => {
                if (mouse.buttons & Qt.LeftButton) {
                    var dx = mouse.x - startMouseX;
                    var dy = mouse.y - startMouseY;
                    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                        dragging = true;
                        win.posX = Math.max(0, win.posX + dx);
                        win.posY = Math.max(0, win.posY + dy);
                    }
                }
            }

            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    if (dragging) {
                        dragging = false;
                        win.savePosition(win.posX, win.posY);
                    }
                }
            }
        }

        // Header Section
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

                Text {
                    text: "🕌"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: win.prayerData.city || "Гудермес"
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "sans-serif"
                    color: win.c.onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Current Prayer Status Chip (M3 Tonal Pill)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: win.c.secondaryContainer
                    implicitWidth: currentStatusText.implicitWidth + 14

                    Text {
                        id: currentStatusText
                        anchors.centerIn: parent
                        text: "● " + win.currentPrayerName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: win.c.onSecondaryContainer
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
                    visible: (win.prayerData.special_day ?? "").length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: win.c.tertiaryContainer
                    implicitWidth: specialDayText.implicitWidth + 14

                    Text {
                        id: specialDayText
                        anchors.centerIn: parent
                        text: win.prayerData.special_day ?? ""
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: win.c.onTertiaryContainer
                    }
                }

                // Hijri date chip
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: win.c.surfaceContainerHigh
                    border.color: win.c.outlineVariant
                    border.width: 1
                    implicitWidth: hijriDateText.implicitWidth + 14

                    Text {
                        id: hijriDateText
                        anchors.centerIn: parent
                        text: win.prayerData.hijri_date || ""
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: win.c.onSurfaceVariant
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

                // Dynamic Material You atmospheric gradient
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: win.nextPrayerType === "night" ? "#1e1b4b" :
                               win.nextPrayerType === "dawn" ? "#2e1065" :
                               win.nextPrayerType === "sunrise" ? "#431407" :
                               win.nextPrayerType === "sunset" ? "#4c0519" : "#0284c7"
                    }
                    GradientStop {
                        position: 1.0
                        color: win.nextPrayerType === "night" ? "#0f172a" :
                               win.nextPrayerType === "dawn" ? "#170f2f" :
                               win.nextPrayerType === "sunrise" ? "#ea580c" :
                               win.nextPrayerType === "sunset" ? "#9f1239" : "#0369a1"
                    }
                }

                // Celestial Glow
                Rectangle {
                    width: 78
                    height: 78
                    radius: 39
                    anchors.centerIn: parent
                    color: win.nextPrayerType === "night" || win.nextPrayerType === "dawn" ? "#c084fc" :
                           win.nextPrayerType === "sunrise" ? "#fdba74" :
                           win.nextPrayerType === "sunset" ? "#fda4af" : "#fef08a"
                    opacity: win.nextPrayerType === "night" ? 0.22 : 0.35
                }

                // Moon / Sun Core
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    anchors.centerIn: parent
                    color: win.nextPrayerType === "night" || win.nextPrayerType === "dawn" ? "#e9d5ff" :
                           win.nextPrayerType === "sunrise" ? "#ffedd5" :
                           win.nextPrayerType === "sunset" ? "#ffe4e6" : "#fef9c3"
                    opacity: win.nextPrayerType === "night" ? 0.85 : 0.92
                }

                // Night Stars
                Item {
                    anchors.fill: parent
                    visible: win.nextPrayerType === "night" || win.nextPrayerType === "dawn"
                    Rectangle { x: 16; y: 18; width: 3; height: 3; radius: 1.5; color: "#ffffff"; opacity: 0.85 }
                    Rectangle { x: 94; y: 22; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.75 }
                    Rectangle { x: 22; y: 90; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.70 }
                    Rectangle { x: 90; y: 86; width: 3; height: 3; radius: 1.5; color: "#ffffff"; opacity: 0.85 }
                }

                // Day Radiance Rays
                Item {
                    anchors.fill: parent
                    visible: win.nextPrayerType === "day"
                    Rectangle { x: 14; y: 16; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                    Rectangle { x: 96; y: 18; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                    Rectangle { x: 92; y: 92; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                    Rectangle { x: 18; y: 90; width: 4; height: 4; radius: 2; color: "#fef08a"; opacity: 0.75 }
                }

                // Large Numerals in Material Clock style
                Column {
                    anchors.centerIn: parent
                    spacing: -6

                    Text {
                        text: win.nextPrayerHours
                        font.pixelSize: 42
                        font.bold: true
                        font.family: "sans-serif"
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: win.nextPrayerMins
                        font.pixelSize: 42
                        font.bold: true
                        font.family: "sans-serif"
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // Subtle click to refresh
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
                Text {
                    text: win.nextPrayerName
                    font.pixelSize: 22
                    font.bold: true
                    font.family: "sans-serif"
                    color: win.c.onSurface
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // "через" subtitle
                Text {
                    text: "через"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: win.c.onSurfaceVariant
                    opacity: 0.75
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Large countdown time
                Text {
                    text: win.remainingTimeStr
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    font.family: "monospace"
                    color: win.c.primary
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
                        color: win.c.surfaceContainerHighest

                        Rectangle {
                            height: parent.height
                            radius: 3.5
                            width: Math.max(7, parent.width * win.progressVal)
                            color: win.c.primary

                            Behavior on width {
                                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                // Optional extended details (Midnight / Tahajjud)
                Row {
                    visible: win.showExtended
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        text: "🌙 " + (win.prayerData.midnight || "23:39")
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: win.c.onSurfaceVariant
                    }
                    Text {
                        text: "✨ " + (win.prayerData.tahajjud || "01:56")
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: win.c.onSurfaceVariant
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
                        { name: "Фаджр", key: "fajr", time: win.prayerData.fajr || "05:17" },
                        { name: "Восход", key: "sunrise", time: win.prayerData.sunrise || "06:30" },
                        { name: "Зухр", key: "dhuhr", time: win.prayerData.dhuhr || "12:30" },
                        { name: "Аср", key: "asr", time: win.prayerData.asr || "14:45" },
                        { name: "Магриб", key: "maghrib", time: win.prayerData.maghrib || "16:51" },
                        { name: "Иша", key: "isha", time: win.prayerData.isha || "18:20" }
                    ]

                    delegate: Item {
                        id: timingRow
                        required property var modelData
                        width: parent.width
                        height: 19

                        readonly property bool isCurrent: win.nextPrayerKey === timingRow.modelData.key
                        readonly property bool isSunrise: timingRow.modelData.key === "sunrise"

                        // Active prayer M3 Tonal Pill background
                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: timingRow.isCurrent ? win.c.primaryContainer :
                                   (hoverArea.containsMouse ? win.c.surfaceContainerHigh : "transparent")
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
                            Text {
                                text: timingRow.modelData.name
                                width: 82
                                font.pixelSize: 12
                                font.weight: timingRow.isCurrent ? Font.Bold : Font.Normal
                                font.italic: timingRow.isSunrise && !timingRow.isCurrent
                                color: timingRow.isCurrent ? win.c.onPrimaryContainer :
                                       (timingRow.isSunrise ? win.c.onSurfaceVariant : win.c.onSurface)
                                opacity: timingRow.isSunrise && !timingRow.isCurrent ? 0.65 : 0.90
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Prayer time
                            Text {
                                text: timingRow.modelData.time
                                width: 62
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 12
                                font.weight: timingRow.isCurrent ? Font.Bold : Font.Normal
                                font.family: "monospace"
                                color: timingRow.isCurrent ? win.c.onPrimaryContainer :
                                       (timingRow.isSunrise ? win.c.onSurfaceVariant : win.c.onSurface)
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
