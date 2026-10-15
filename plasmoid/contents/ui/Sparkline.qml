import QtQuick

Canvas {
    id: canvas

    property var values: []
    property var secondary: []
    property real maximum: 100
    property color color: "white"
    property color secondaryColor: "white"
    property int capacity: 60

    onValuesChanged: requestPaint()
    onSecondaryChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function trace(ctx, series, top, stroke) {
        if (series.length < 2)
            return
        const step = width / (capacity - 1)
        const x0 = width - (series.length - 1) * step
        const y = v => height - Math.min(1, v / Math.max(top, 1e-9)) * (height - 2) - 1
        ctx.beginPath()
        ctx.moveTo(x0, height)
        for (let i = 0; i < series.length; i++)
            ctx.lineTo(x0 + i * step, y(series[i]))
        ctx.lineTo(width, height)
        ctx.closePath()
        const fill = ctx.createLinearGradient(0, 0, 0, height)
        fill.addColorStop(0, Qt.alpha(stroke, 0.35))
        fill.addColorStop(1, Qt.alpha(stroke, 0.02))
        ctx.fillStyle = fill
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < series.length; i++) {
            const px = x0 + i * step
            if (i === 0)
                ctx.moveTo(px, y(series[i]))
            else
                ctx.lineTo(px, y(series[i]))
        }
        ctx.strokeStyle = stroke
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const top = secondary.length ? Math.max(maximum, ...values, ...secondary) : Math.max(maximum, ...values)
        trace(ctx, secondary, top, secondaryColor)
        trace(ctx, values, top, color)
    }
}
