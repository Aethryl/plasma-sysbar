import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    readonly property int capacity: 60
    readonly property string psCommand: "top -b -n 2 -d 0.5 -o %CPU -e k -w 512 | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ {print $9, $6, $12}' | head -n 5"

    property real compactWidth: Kirigami.Units.gridUnit * 18
    property Item compactItem: null
    property bool drooped: false

    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []
    property var downHistory: []
    property var upHistory: []
    property var processes: []

    readonly property color notchColor: "#262634"
    readonly property real ear: Kirigami.Units.gridUnit * 0.7
    readonly property real bottomRadius: Kirigami.Units.gridUnit * 1.1

    readonly property color mauve: "#cba6f7"
    readonly property color blue: "#89b4fa"
    readonly property color green: "#a6e3a1"
    readonly property color sky: "#89dceb"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color red: "#f38ba8"
    readonly property color dim: Qt.alpha(Kirigami.Theme.textColor, 0.45)
    readonly property color faint: Qt.alpha(Kirigami.Theme.textColor, 0.06)

    readonly property real cpuUsage: cpu.value || 0
    readonly property real memUsage: memPercent.value || 0
    readonly property real gpuUsage: gpu.value || 0

    preferredRepresentation: compactRepresentation
    fullRepresentation: Item {}
    Plasmoid.backgroundHints: "NoBackground"
    toolTipMainText: ""
    toolTipSubText: ""

    function tempColor(t) {
        return t >= 85 ? red : t >= 70 ? yellow : dim
    }

    function bytes(value) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let v = value || 0, i = 0
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024
            i++
        }
        return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
    }

    function rate(value) {
        return bytes(value) + "/s"
    }

    function shortRate(value) {
        const units = ["", "K", "M", "G"]
        let v = value || 0, i = 0
        while (v >= 1000 && i < units.length - 1) {
            v /= 1000
            i++
        }
        return (v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)) + units[i]
    }

    function push(series, value) {
        const next = series.concat([value || 0])
        return next.length > capacity ? next.slice(next.length - capacity) : next
    }

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: cpuTemp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: cpuFreq; sensorId: "cpu/all/averageFrequency"; updateRateLimit: 2000 }
    Sensors.Sensor { id: coreCount; sensorId: "cpu/all/coreCount" }
    Sensors.Sensor { id: memPercent; sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Sensors.Sensor { id: memUsed; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: memTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: swapPercent; sensorId: "memory/swap/usedPercent"; updateRateLimit: 5000 }
    Sensors.Sensor { id: gpu; sensorId: "gpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: vramUsed; sensorId: "gpu/all/usedVram"; updateRateLimit: 2000 }
    Sensors.Sensor { id: vramTotal; sensorId: "gpu/all/totalVram" }
    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: 1000 }
    Sensors.Sensor { id: up; sensorId: "network/all/upload"; updateRateLimit: 1000 }
    Sensors.Sensor { id: diskRead; sensorId: "disk/all/read"; enabled: root.drooped; updateRateLimit: 1000 }
    Sensors.Sensor { id: diskWrite; sensorId: "disk/all/write"; enabled: root.drooped; updateRateLimit: 1000 }

    Repeater {
        id: cores
        model: coreCount.value || 0
        delegate: Item {
            readonly property real usage: coreSensor.value || 0
            Sensors.Sensor {
                id: coreSensor
                sensorId: "cpu/cpu" + index + "/usage"
                enabled: root.drooped
                updateRateLimit: 1000
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.cpuHistory = root.push(root.cpuHistory, root.cpuUsage)
            root.memHistory = root.push(root.memHistory, root.memUsage)
            root.gpuHistory = root.push(root.gpuHistory, root.gpuUsage)
            root.downHistory = root.push(root.downHistory, down.value)
            root.upHistory = root.push(root.upHistory, up.value)
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source !== root.psCommand)
                return
            root.processes = data["stdout"].trim().split("\n").map(line => {
                const m = line.trim().match(/^(\S+)\s+(\S+)\s+(.+)$/)
                return m ? { cpu: parseFloat(m[1]), rss: parseInt(m[2]) * 1024, name: m[3] } : null
            }).filter(p => p)
        }
    }

    Timer {
        interval: 2000
        running: root.drooped
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.connectSource(root.psCommand)
    }

    component Bar: Rectangle {
        property real pct
        property color fill
        implicitHeight: Kirigami.Units.smallSpacing * 1.5
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, pct)) / 100
            height: parent.height
            radius: parent.radius
            color: fill
            Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }
    }

    component Meter: RowLayout {
        id: meter
        property string label
        property real pct
        property color accent
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents.Label {
            text: meter.label
            color: root.dim
        }
        Bar {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            pct: meter.pct
            fill: meter.accent
        }
        PlasmaComponents.Label {
            text: Math.round(meter.pct) + "%"
            font.features: { "tnum": 1 }
            Layout.minimumWidth: Kirigami.Units.gridUnit * 1.6
        }
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: Kirigami.Units.gridUnit * 0.8
        color: root.dim
    }

    component Card: Rectangle {
        id: card
        property string title
        property string value
        property color accent
        property string detail
        property alias graph: graphSlot.data
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: cardColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius * 2
        color: root.faint

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.title
                    color: root.dim
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1
                }
                PlasmaComponents.Label {
                    text: card.value
                    color: card.accent
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
            Item {
                id: graphSlot
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.4
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: card.detail
                color: root.dim
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        onWidthChanged: root.compactWidth = width
        Component.onCompleted: root.compactItem = this
        onClicked: root.drooped = !root.drooped

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Meter { label: "cpu"; pct: root.cpuUsage; accent: root.mauve }
            PlasmaComponents.Label {
                visible: cpuTemp.value > 0
                text: Math.round(cpuTemp.value) + "°"
                color: root.tempColor(cpuTemp.value)
                Layout.leftMargin: -Kirigami.Units.smallSpacing
            }
            Divider {}
            Meter { label: "ram"; pct: root.memUsage; accent: root.blue }
            Divider {}
            Meter { label: "gpu"; pct: root.gpuUsage; accent: root.green }
            Divider {}
            PlasmaComponents.Label {
                text: "↓ " + root.shortRate(down.value) + "  ↑ " + root.shortRate(up.value)
                color: root.dim
                font.features: { "tnum": 1 }
            }
        }
    }

    onDroopedChanged: {
        if (drooped) {
            droop.visible = true
            droop.requestActivate()
            reveal.to = 1
            reveal.easing.type = Easing.OutBack
            reveal.duration = 320
        } else {
            reveal.to = 0
            reveal.easing.type = Easing.InCubic
            reveal.duration = 160
        }
        reveal.restart()
    }

    NumberAnimation {
        id: reveal
        target: notch
        property: "progress"
        onFinished: if (!root.drooped) droop.visible = false
    }

    PlasmaCore.Dialog {
        id: droop
        visualParent: root.compactItem
        location: PlasmaCore.Types.TopEdge
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: if (!visible) { root.drooped = false; notch.progress = 0 }
        onXChanged: notch.inset = Math.max(0, root.compactItem.mapToGlobal(0, 0).x - x - 2)

        mainItem: Item {
            id: notch
            property real progress: 0
            property real inset: 0
            readonly property real bodyWidth: Math.max(root.compactWidth, Kirigami.Units.gridUnit * 26) + Kirigami.Units.gridUnit
            readonly property real fullHeight: content.implicitHeight + Kirigami.Units.gridUnit * 1.6
            readonly property real shownHeight: Math.max(0, fullHeight * progress)
            width: inset + bodyWidth + root.ear
            height: fullHeight * 1.1
            focus: true
            Keys.onEscapePressed: root.drooped = false

            Shape {
                x: notch.inset
                width: parent.width - notch.inset
                height: parent.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    id: sp
                    readonly property real e: root.ear
                    readonly property real w: notch.bodyWidth
                    readonly property real h: Math.max(notch.shownHeight, e + 1)
                    readonly property real r: Math.min(root.bottomRadius, h - e)
                    strokeWidth: -1
                    fillColor: root.notchColor
                    startX: 0; startY: 0
                    PathLine { x: 0; y: sp.h - sp.r }
                    PathQuad { controlX: 0; controlY: sp.h; x: sp.r; y: sp.h }
                    PathLine { x: sp.w - sp.r; y: sp.h }
                    PathQuad { controlX: sp.w; controlY: sp.h; x: sp.w; y: sp.h - sp.r }
                    PathLine { x: sp.w; y: sp.e }
                    PathQuad { controlX: sp.w; controlY: 0; x: sp.w + sp.e; y: 0 }
                    PathLine { x: 0; y: 0 }
                }
            }

            Item {
                x: notch.inset
                width: notch.bodyWidth
                height: notch.shownHeight
                clip: true

                ColumnLayout {
                    id: content
                    x: Kirigami.Units.gridUnit * 0.8
                    y: Kirigami.Units.gridUnit * 0.6
                    width: parent.width - Kirigami.Units.gridUnit * 1.6
                    spacing: Kirigami.Units.largeSpacing
                    opacity: Math.min(1, Math.max(0, notch.progress * 1.6 - 0.4))

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        Card {
                            title: "CPU"
                            value: Math.round(root.cpuUsage) + "%"
                            accent: root.mauve
                            detail: [
                                cpuTemp.value > 0 ? Math.round(cpuTemp.value) + "°C" : "",
                                cpuFreq.value > 0 ? (cpuFreq.value / 1000).toFixed(1) + " GHz" : "",
                                (coreCount.value || 0) + " threads",
                            ].filter(s => s).join(" · ")
                            graph: [
                                Sparkline {
                                    anchors.fill: parent
                                    anchors.bottomMargin: Kirigami.Units.smallSpacing * 2.5
                                    values: root.cpuHistory
                                    color: root.mauve
                                    capacity: root.capacity
                                },
                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Kirigami.Units.smallSpacing * 1.5
                                    spacing: 2
                                    Repeater {
                                        model: cores.count
                                        Rectangle {
                                            readonly property real usage: cores.itemAt(index) ? cores.itemAt(index).usage : 0
                                            width: (parent.width - (cores.count - 1) * 2) / Math.max(1, cores.count)
                                            height: parent.height
                                            radius: 1
                                            color: Qt.alpha(root.mauve, 0.15 + 0.85 * Math.min(1, usage / 100))
                                        }
                                    }
                                }
                            ]
                        }

                        Card {
                            title: "Memory"
                            value: Math.round(root.memUsage) + "%"
                            accent: root.blue
                            detail: root.bytes(memUsed.value) + " / " + root.bytes(memTotal.value)
                                + " · swap " + Math.round(swapPercent.value || 0) + "%"
                            graph: Sparkline {
                                anchors.fill: parent
                                values: root.memHistory
                                color: root.blue
                                capacity: root.capacity
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        Card {
                            title: "GPU"
                            value: Math.round(root.gpuUsage) + "%"
                            accent: root.green
                            detail: [
                                gpuTemp.value > 0 ? Math.round(gpuTemp.value) + "°C" : "",
                                vramTotal.value > 0 ? "VRAM " + root.bytes(vramUsed.value) + " / " + root.bytes(vramTotal.value) : "",
                            ].filter(s => s).join(" · ")
                            graph: Sparkline {
                                anchors.fill: parent
                                values: root.gpuHistory
                                color: root.green
                                capacity: root.capacity
                            }
                        }

                        Card {
                            title: "Network"
                            value: "↓ " + root.rate(down.value)
                            accent: root.sky
                            detail: "↑ " + root.rate(up.value) + " · disk " + root.shortRate(diskRead.value) + "B/" + root.shortRate(diskWrite.value) + "B"
                            graph: Sparkline {
                                anchors.fill: parent
                                values: root.downHistory
                                secondary: root.upHistory
                                maximum: 1024
                                color: root.sky
                                secondaryColor: root.peach
                                capacity: root.capacity
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: "Top processes"
                                color: root.dim
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1
                            }
                            PlasmaComponents.Label {
                                text: "System Monitor ↗"
                                color: monitorHover.containsMouse ? Kirigami.Theme.textColor : root.dim
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                MouseArea {
                                    id: monitorHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        executable.connectSource("plasma-systemmonitor")
                                        root.drooped = false
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.processes
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing * 2
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: modelData.name
                                }
                                PlasmaComponents.Label {
                                    text: root.bytes(modelData.rss)
                                    color: root.dim
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    font.features: { "tnum": 1 }
                                }
                                Bar {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                    pct: modelData.cpu
                                    fill: root.mauve
                                }
                                PlasmaComponents.Label {
                                    Layout.minimumWidth: Kirigami.Units.gridUnit * 2.2
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.cpu.toFixed(0) + "%"
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
