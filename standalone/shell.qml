pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: win

    // Sits on wallpaper (bottom layer) or on top
    WlrLayershell.layer: configData.layer === "top" ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "prayer-widget"

    anchors {
        top: (configData.position?.bottom === undefined)
        bottom: (configData.position?.bottom !== undefined)
        left: (configData.position?.right === undefined)
        right: (configData.position?.right !== undefined)
    }
    margins {
        top: configData.position?.top ?? 80
        bottom: configData.position?.bottom ?? 0
        left: configData.position?.left ?? 40
        right: configData.position?.right ?? 0
    }

    implicitWidth: 460
    implicitHeight: 185
    color: "transparent"

    property var configData: ({
        position: { top: 80, left: 40 },
        theme: "light"
    })

    readonly property bool isDark: configData.theme === "dark"

    property var prayerData: ({
        city: "Гудермес",
        hijri_date: "23 Джумада аль-уля",
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
            next = schedule[0]; // Fajr tomorrow
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

    // Process to fetch data via python
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
                        }
                        win.updateTimes();
                    } catch (e) {
                        console.log("JSON parse error: " + e);
                    }
                }
            }
        }
    }

    // Refresh data hourly and countdown every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: win.updateTimes()
    }

    Timer {
        interval: 3600000 // 1 hour
        running: true
        repeat: true
        onTriggered: fetchProc.running = true
    }

    Component.onCompleted: {
        fetchProc.running = true;
        win.updateTimes();
    }

    // Background Card
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: 24
        // Light frosted blue glass or dark glass
        color: win.isDark ? "#1e2230" : "#d8e7f7"
        opacity: win.isDark ? 0.88 : 0.92
        border.color: win.isDark ? "#333b52" : "#e8f2fc"
        border.width: 1

        // Header
        Item {
            id: headerRow
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 16
                rightMargin: 16
            }
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: "🕋"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: win.prayerData.city || "Гудермес"
                    font.pixelSize: 15
                    font.bold: true
                    color: win.isDark ? "#f1f5f9" : "#1e293b"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: win.prayerData.hijri_date || ""
                font.pixelSize: 14
                color: win.isDark ? "#94a3b8" : "#334155"
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
                topMargin: 10
                bottomMargin: 14
                leftMargin: 16
                rightMargin: 16
            }

            // 1. Left Square Illustration Card
            Rectangle {
                id: leftArtCard
                width: 110
                height: 110
                radius: 18
                clip: true
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                // Gradient background depending on prayer type
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: win.nextPrayerType === "night" ? "#2f2852" :
                               win.nextPrayerType === "sunset" ? "#843d63" :
                               win.nextPrayerType === "sunrise" ? "#e07a5f" : "#3b82f6"
                    }
                    GradientStop {
                        position: 1.0
                        color: win.nextPrayerType === "night" ? "#181329" :
                               win.nextPrayerType === "sunset" ? "#311847" :
                               win.nextPrayerType === "sunrise" ? "#4a2840" : "#1d4ed8"
                    }
                }

                // Moon / Sun
                Rectangle {
                    width: 76
                    height: 76
                    radius: 38
                    anchors.centerIn: parent
                    color: win.nextPrayerType === "night" ? "#a89ecf" : "#fed7aa"
                    opacity: win.nextPrayerType === "night" ? 0.35 : 0.45
                }

                Rectangle {
                    width: 58
                    height: 58
                    radius: 29
                    anchors.centerIn: parent
                    color: win.nextPrayerType === "night" ? "#bfb5e5" : "#ffedd5"
                    opacity: win.nextPrayerType === "night" ? 0.85 : 0.90
                }

                // Night Stars
                Item {
                    anchors.fill: parent
                    visible: win.nextPrayerType === "night"
                    Rectangle { x: 16; y: 18; width: 3; height: 3; radius: 1.5; color: "#ffffff"; opacity: 0.8 }
                    Rectangle { x: 92; y: 22; width: 2.5; height: 2.5; radius: 1.25; color: "#ffffff"; opacity: 0.7 }
                    Rectangle { x: 22; y: 88; width: 2; height: 2; radius: 1; color: "#ffffff"; opacity: 0.7 }
                    Rectangle { x: 88; y: 84; width: 3; height: 3; radius: 1.5; color: "#ffffff"; opacity: 0.85 }
                }

                // Large numbers (18 / 20)
                Column {
                    anchors.centerIn: parent
                    spacing: -4

                    Text {
                        text: win.nextPrayerHours
                        font.pixelSize: 42
                        font.bold: true
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: win.nextPrayerMins
                        font.pixelSize: 42
                        font.bold: true
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // 2. Middle Block (Prayer Name & Countdown)
            Column {
                id: middleBlock
                anchors {
                    left: leftArtCard.right
                    right: divider.left
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

                Text {
                    text: win.nextPrayerName
                    font.pixelSize: 22
                    font.bold: true
                    color: win.isDark ? "#ffffff" : "#0f172a"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "через"
                    font.pixelSize: 13
                    color: win.isDark ? "#94a3b8" : "#64748b"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: win.remainingTimeStr
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: win.isDark ? "#f1f5f9" : "#1e293b"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // 3. Divider Line
            Rectangle {
                id: divider
                width: 1
                height: 110
                anchors.right: rightTable.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: win.isDark ? "#475569" : "#94a3b8"
                opacity: 0.35
            }

            // 4. Right Table with 6 Timings
            Column {
                id: rightTable
                width: 145
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

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
                        required property var modelData
                        width: parent.width
                        height: 16

                        readonly property bool isCurrent: win.nextPrayerKey === modelData.key
                        readonly property bool isDimmed: modelData.key === "sunrise" && !isCurrent

                        Row {
                            anchors.fill: parent

                            Text {
                                text: parent.parent.modelData.name
                                width: 85
                                font.pixelSize: 13
                                font.bold: parent.parent.isCurrent
                                color: parent.parent.isCurrent ? (win.isDark ? "#38bdf8" : "#0f172a") :
                                       (parent.parent.isDimmed ? (win.isDark ? "#64748b" : "#94a3b8") :
                                       (win.isDark ? "#cbd5e1" : "#334155"))
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: parent.parent.modelData.time
                                width: 60
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 13
                                font.bold: parent.parent.isCurrent
                                font.family: "monospace"
                                color: parent.parent.isCurrent ? (win.isDark ? "#38bdf8" : "#0f172a") :
                                       (parent.parent.isDimmed ? (win.isDark ? "#64748b" : "#94a3b8") :
                                       (win.isDark ? "#cbd5e1" : "#334155"))
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
