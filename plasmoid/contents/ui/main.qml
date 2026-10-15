import QtQuick
import QtQuick.Window
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

    readonly property real ear: Kirigami.Units.gridUnit * 0.7
    readonly property real bottomRadius: Kirigami.Units.gridUnit * 1.1

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color link: Kirigami.Theme.linkColor
    readonly property color ok: Kirigami.Theme.positiveTextColor
    readonly property color info: Kirigami.Theme.activeTextColor
    readonly property color extra: Kirigami.Theme.visitedLinkColor
    readonly property color warning: Kirigami.Theme.neutralTextColor
    readonly property color critical: Kirigami.Theme.negativeTextColor
    readonly property color dim: Kirigami.Theme.disabledTextColor
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
        return t >= 85 ? critical : t >= 70 ? warning : dim
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
            width: pct > 0 ? Math.max(parent.height, parent.width * Math.min(100, pct) / 100) : 0
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
            id: meterLabel
            readonly property real dpr: Screen.devicePixelRatio || 1
            text: meter.label
            color: root.dim
            transform: Translate {
                y: -Math.round((meterMetrics.ascent - meterMetrics.xHeight / 2 - meterMetrics.height / 2) * meterLabel.dpr) / meterLabel.dpr
            }
        }
        Bar {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
            Layout.alignment: Qt.AlignVCenter
            pct: meter.pct
            fill: meter.accent
        }
        FontMetrics {
            id: meterMetrics
            font: meterLabel.font
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

            Meter { label: "cpu"; pct: root.cpuUsage; accent: root.accent; Layout.leftMargin: Kirigami.Units.smallSpacing }
            PlasmaComponents.Label {
                visible: cpuTemp.value > 0
                text: Math.round(cpuTemp.value) + "°"
                color: root.tempColor(cpuTemp.value)
                Layout.leftMargin: -Kirigami.Units.smallSpacing
            }
            Divider {}
            Meter { label: "ram"; pct: root.memUsage; accent: root.link }
            Divider {}
            Meter { label: "gpu"; pct: root.gpuUsage; accent: root.ok }
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
            let bar = compactItem
            while (bar.parent && bar.parent.parent && bar.parent.parent.parent)
                bar = bar.parent
            const corner = bar.mapToGlobal(0, bar.height)
            droop.x = Math.floor(corner.x)
            droop.y = Math.floor(corner.y) - Kirigami.Units.cornerRadius
            notch.edgeX = corner.x - droop.x
            notch.edgeY = corner.y - droop.y
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
        location: PlasmaCore.Types.TopEdge
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: if (!visible) { root.drooped = false; notch.progress = 0 }

        mainItem: Item {
            id: notch
            property real progress: 0
            property real edgeX: 0
            property real edgeY: Kirigami.Units.cornerRadius
            readonly property real bodyWidth: Math.max(root.compactWidth, Kirigami.Units.gridUnit * 26) + Kirigami.Units.gridUnit
            readonly property real fullHeight: content.implicitHeight + Kirigami.Units.gridUnit * 1.6
            readonly property real shownHeight: Math.max(0, fullHeight * progress)
            width: edgeX + bodyWidth + root.ear
            height: edgeY + fullHeight * 1.1
            focus: true
            Keys.onEscapePressed: root.drooped = false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false

            Shape {
                x: notch.edgeX
                width: parent.width - notch.edgeX
                height: parent.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    id: sp
                    readonly property real c: notch.edgeY
                    readonly property real e: root.ear
                    readonly property real w: notch.bodyWidth
                    readonly property real h: c + Math.max(notch.shownHeight, e + 1)
                    readonly property real r: Math.min(root.bottomRadius, h - c - e)
                    readonly property real o: 0.5
                    strokeWidth: -1
                    fillColor: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.textColor, 0.08))
                    startX: 0; startY: 0
                    PathLine { x: 0; y: sp.h - sp.r }
                    PathArc { x: sp.r; y: sp.h; radiusX: sp.r; radiusY: sp.r; direction: PathArc.Counterclockwise }
                    PathLine { x: sp.w - sp.r; y: sp.h }
                    PathArc { x: sp.w; y: sp.h - sp.r; radiusX: sp.r; radiusY: sp.r; direction: PathArc.Counterclockwise }
                    PathLine { x: sp.w; y: sp.c + sp.e }
                    PathArc { x: sp.w + sp.e; y: sp.c; radiusX: sp.e; radiusY: sp.e }
                    PathLine { x: sp.w + sp.e; y: 0 }
                    PathLine { x: 0; y: 0 }
                }
                ShapePath {
                    strokeWidth: 1
                    strokeColor: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.textColor, 0.14))
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: sp.o; startY: 0
                    PathLine { x: sp.o; y: sp.h - sp.r }
                    PathArc { x: sp.r; y: sp.h - sp.o; radiusX: sp.r - sp.o; radiusY: sp.r - sp.o; direction: PathArc.Counterclockwise }
                    PathLine { x: sp.w - sp.r; y: sp.h - sp.o }
                    PathArc { x: sp.w - sp.o; y: sp.h - sp.r; radiusX: sp.r - sp.o; radiusY: sp.r - sp.o; direction: PathArc.Counterclockwise }
                    PathLine { x: sp.w - sp.o; y: sp.c + sp.e }
                    PathArc { x: sp.w + sp.e; y: sp.c - sp.o; radiusX: sp.e + sp.o; radiusY: sp.e + sp.o }
                }
            }

            Item {
                x: notch.edgeX
                y: notch.edgeY
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
                            accent: root.accent
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
                                    color: root.accent
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
                                            color: Qt.alpha(root.accent, 0.15 + 0.85 * Math.min(1, usage / 100))
                                        }
                                    }
                                }
                            ]
                        }

                        Card {
                            title: "Memory"
                            value: Math.round(root.memUsage) + "%"
                            accent: root.link
                            detail: root.bytes(memUsed.value) + " / " + root.bytes(memTotal.value)
                                + " · swap " + Math.round(swapPercent.value || 0) + "%"
                            graph: Sparkline {
                                anchors.fill: parent
                                values: root.memHistory
                                color: root.link
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
                            accent: root.ok
                            detail: [
                                gpuTemp.value > 0 ? Math.round(gpuTemp.value) + "°C" : "",
                                vramTotal.value > 0 ? "VRAM " + root.bytes(vramUsed.value) + " / " + root.bytes(vramTotal.value) : "",
                            ].filter(s => s).join(" · ")
                            graph: Sparkline {
                                anchors.fill: parent
                                values: root.gpuHistory
                                color: root.ok
                                capacity: root.capacity
                            }
                        }

                        Card {
                            title: "Network"
                            value: "↓ " + root.rate(down.value)
                            accent: root.info
                            detail: "↑ " + root.rate(up.value) + " · disk " + root.shortRate(diskRead.value) + "B/" + root.shortRate(diskWrite.value) + "B"
                            graph: Sparkline {
                                anchors.fill: parent
                                values: root.downHistory
                                secondary: root.upHistory
                                maximum: 1024
                                color: root.info
                                secondaryColor: root.extra
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
                                    fill: root.accent
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
