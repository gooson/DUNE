import SwiftUI

/// Simplified vector illustrations for each equipment type.
struct EquipmentIllustrationView: View {
    let equipment: Equipment
    let size: CGFloat

    init(equipment: Equipment, size: CGFloat = 60) {
        self.equipment = equipment
        self.size = size
    }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            guard w > 0, h > 0 else { return }
            draw(equipment, in: context, width: w, height: h)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Drawing

    private func draw(_ equipment: Equipment, in context: GraphicsContext, width w: CGFloat, height h: CGFloat) {
        let stroke = DS.Color.activity
        let fill = DS.Color.activity.opacity(0.15)
        let lineWidth: CGFloat = 2

        switch equipment {
        case .barbell:
            drawBarbell(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .dumbbell:
            drawDumbbell(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .kettlebell:
            drawKettlebell(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .ezBar:
            drawEZBar(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .trapBar:
            drawTrapBar(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .smithMachine:
            drawSmithMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .legPressMachine:
            drawLegPressMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .hackSquatMachine:
            drawHackSquatMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .chestPressMachine, .shoulderPressMachine:
            drawSeatedPressMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .latPulldownMachine:
            drawLatPulldownMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .legExtensionMachine, .legCurlMachine:
            drawLegMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .pecDeckMachine:
            drawPecDeckMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .cableMachine:
            drawCable(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .machine:
            drawMachine(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .cable:
            drawCable(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .bodyweight:
            drawBodyweight(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .pullUpBar:
            drawPullUpBar(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .dipStation:
            drawDipStation(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .band:
            drawBand(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .trx:
            drawTRX(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .medicineBall:
            drawMedicineBall(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .stabilityBall:
            drawStabilityBall(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        case .other:
            drawOther(context, w: w, h: h, stroke: stroke, fill: fill, lineWidth: lineWidth)
        }
    }

    // MARK: - Barbell

    private func drawBarbell(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cy = h * 0.5
        // Bar
        var bar = Path()
        bar.addRoundedRect(in: CGRect(x: w * 0.1, y: cy - 2, width: w * 0.8, height: 4), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(bar, with: .color(stroke))

        // Left plates
        let plateRects = [
            CGRect(x: w * 0.12, y: cy - h * 0.3, width: w * 0.08, height: h * 0.6),
            CGRect(x: w * 0.22, y: cy - h * 0.25, width: w * 0.06, height: h * 0.5),
        ]
        // Right plates (mirrored)
        let rightPlateRects = [
            CGRect(x: w * 0.8, y: cy - h * 0.3, width: w * 0.08, height: h * 0.6),
            CGRect(x: w * 0.72, y: cy - h * 0.25, width: w * 0.06, height: h * 0.5),
        ]

        for rect in plateRects + rightPlateRects {
            var plate = Path()
            plate.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
            ctx.fill(plate, with: .color(fill))
            ctx.stroke(plate, with: .color(stroke), lineWidth: lineWidth)
        }
    }

    // MARK: - Dumbbell

    private func drawDumbbell(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cy = h * 0.5
        // Handle
        var handle = Path()
        handle.addRoundedRect(in: CGRect(x: w * 0.3, y: cy - 3, width: w * 0.4, height: 6), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(handle, with: .color(stroke))

        // Left weight
        var left = Path()
        left.addRoundedRect(in: CGRect(x: w * 0.15, y: cy - h * 0.28, width: w * 0.18, height: h * 0.56), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(left, with: .color(fill))
        ctx.stroke(left, with: .color(stroke), lineWidth: lineWidth)

        // Right weight
        var right = Path()
        right.addRoundedRect(in: CGRect(x: w * 0.67, y: cy - h * 0.28, width: w * 0.18, height: h * 0.56), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(right, with: .color(fill))
        ctx.stroke(right, with: .color(stroke), lineWidth: lineWidth)
    }

    // MARK: - Kettlebell

    private func drawKettlebell(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cx = w * 0.5

        // Handle (arc)
        var handle = Path()
        handle.addArc(center: CGPoint(x: cx, y: h * 0.28), radius: w * 0.18, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        ctx.stroke(handle, with: .color(stroke), lineWidth: lineWidth + 1)

        // Body (bell shape — large circle)
        var body = Path()
        body.addEllipse(in: CGRect(x: cx - w * 0.25, y: h * 0.35, width: w * 0.5, height: h * 0.5))
        ctx.fill(body, with: .color(fill))
        ctx.stroke(body, with: .color(stroke), lineWidth: lineWidth)

        // Base flat
        var base = Path()
        base.addRoundedRect(in: CGRect(x: cx - w * 0.15, y: h * 0.8, width: w * 0.3, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(base, with: .color(stroke.opacity(0.3)))
    }

    // MARK: - EZ Bar

    private func drawEZBar(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cy = h * 0.5
        // W-shaped bar
        var bar = Path()
        bar.move(to: CGPoint(x: w * 0.08, y: cy))
        bar.addLine(to: CGPoint(x: w * 0.25, y: cy))
        bar.addLine(to: CGPoint(x: w * 0.35, y: cy - h * 0.08))
        bar.addLine(to: CGPoint(x: w * 0.45, y: cy + h * 0.08))
        bar.addLine(to: CGPoint(x: w * 0.55, y: cy - h * 0.08))
        bar.addLine(to: CGPoint(x: w * 0.65, y: cy + h * 0.08))
        bar.addLine(to: CGPoint(x: w * 0.75, y: cy))
        bar.addLine(to: CGPoint(x: w * 0.92, y: cy))
        ctx.stroke(bar, with: .color(stroke), lineWidth: lineWidth + 1)

        // Plates
        let plates = [
            CGRect(x: w * 0.06, y: cy - h * 0.22, width: w * 0.06, height: h * 0.44),
            CGRect(x: w * 0.88, y: cy - h * 0.22, width: w * 0.06, height: h * 0.44),
        ]
        for rect in plates {
            var plate = Path()
            plate.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
            ctx.fill(plate, with: .color(fill))
            ctx.stroke(plate, with: .color(stroke), lineWidth: lineWidth)
        }
    }

    // MARK: - Trap Bar

    private func drawTrapBar(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cx = w * 0.5
        let cy = h * 0.5
        // Hexagonal frame
        var hex = Path()
        hex.move(to: CGPoint(x: cx, y: cy - h * 0.3))
        hex.addLine(to: CGPoint(x: cx + w * 0.25, y: cy - h * 0.15))
        hex.addLine(to: CGPoint(x: cx + w * 0.25, y: cy + h * 0.15))
        hex.addLine(to: CGPoint(x: cx, y: cy + h * 0.3))
        hex.addLine(to: CGPoint(x: cx - w * 0.25, y: cy + h * 0.15))
        hex.addLine(to: CGPoint(x: cx - w * 0.25, y: cy - h * 0.15))
        hex.closeSubpath()
        ctx.fill(hex, with: .color(fill))
        ctx.stroke(hex, with: .color(stroke), lineWidth: lineWidth)

        // Side handles
        var leftHandle = Path()
        leftHandle.addRoundedRect(in: CGRect(x: w * 0.12, y: cy - h * 0.04, width: w * 0.12, height: h * 0.08), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(leftHandle, with: .color(stroke))

        var rightHandle = Path()
        rightHandle.addRoundedRect(in: CGRect(x: w * 0.76, y: cy - h * 0.04, width: w * 0.12, height: h * 0.08), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(rightHandle, with: .color(stroke))

        // Extending bars
        var leftBar = Path()
        leftBar.move(to: CGPoint(x: cx - w * 0.25, y: cy))
        leftBar.addLine(to: CGPoint(x: w * 0.12, y: cy))
        ctx.stroke(leftBar, with: .color(stroke), lineWidth: lineWidth)

        var rightBar = Path()
        rightBar.move(to: CGPoint(x: cx + w * 0.25, y: cy))
        rightBar.addLine(to: CGPoint(x: w * 0.88, y: cy))
        ctx.stroke(rightBar, with: .color(stroke), lineWidth: lineWidth)
    }

    // MARK: - Smith Machine

    private func drawSmithMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Two vertical rails
        let rails = [
            CGRect(x: w * 0.15, y: h * 0.05, width: w * 0.06, height: h * 0.9),
            CGRect(x: w * 0.79, y: h * 0.05, width: w * 0.06, height: h * 0.9),
        ]
        for rect in rails {
            var rail = Path()
            rail.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
            ctx.fill(rail, with: .color(fill))
            ctx.stroke(rail, with: .color(stroke), lineWidth: lineWidth)
        }

        // Barbell on rails
        let barY = h * 0.45
        var bar = Path()
        bar.addRoundedRect(in: CGRect(x: w * 0.1, y: barY - 2, width: w * 0.8, height: 4), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(bar, with: .color(stroke))

        // Plates on bar
        let plates = [
            CGRect(x: w * 0.08, y: barY - h * 0.12, width: w * 0.06, height: h * 0.24),
            CGRect(x: w * 0.86, y: barY - h * 0.12, width: w * 0.06, height: h * 0.24),
        ]
        for rect in plates {
            var plate = Path()
            plate.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
            ctx.fill(plate, with: .color(fill))
            ctx.stroke(plate, with: .color(stroke), lineWidth: lineWidth)
        }

        // Guide notches on rails
        for i in 0..<6 {
            let y = h * 0.1 + CGFloat(i) * h * 0.13
            var notch = Path()
            notch.move(to: CGPoint(x: w * 0.21, y: y))
            notch.addLine(to: CGPoint(x: w * 0.25, y: y))
            ctx.stroke(notch, with: .color(stroke.opacity(0.4)), lineWidth: 1)

            var notchR = Path()
            notchR.move(to: CGPoint(x: w * 0.75, y: y))
            notchR.addLine(to: CGPoint(x: w * 0.79, y: y))
            ctx.stroke(notchR, with: .color(stroke.opacity(0.4)), lineWidth: 1)
        }
    }

    // MARK: - Leg Press Machine

    private func drawLegPressMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Angled rail
        var rail = Path()
        rail.move(to: CGPoint(x: w * 0.15, y: h * 0.85))
        rail.addLine(to: CGPoint(x: w * 0.75, y: h * 0.15))
        ctx.stroke(rail, with: .color(stroke), lineWidth: lineWidth)

        // Foot plate
        var plate = Path()
        plate.addRoundedRect(in: CGRect(x: w * 0.55, y: h * 0.2, width: w * 0.25, height: h * 0.15), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(plate, with: .color(fill))
        ctx.stroke(plate, with: .color(stroke), lineWidth: lineWidth)

        // Seat
        var seat = Path()
        seat.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.7, width: w * 0.3, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(seat, with: .color(fill))
        ctx.stroke(seat, with: .color(stroke), lineWidth: lineWidth)

        // Back rest
        var back = Path()
        back.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.4, width: w * 0.1, height: h * 0.32), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(back, with: .color(fill))
        ctx.stroke(back, with: .color(stroke), lineWidth: lineWidth)

        // Weight plates stacked
        for i in 0..<3 {
            let x = w * 0.7 + CGFloat(i) * w * 0.06
            var wp = Path()
            wp.addRoundedRect(in: CGRect(x: x, y: h * 0.38, width: w * 0.04, height: h * 0.15), cornerSize: CGSize(width: 1, height: 1))
            ctx.fill(wp, with: .color(fill))
            ctx.stroke(wp, with: .color(stroke.opacity(0.6)), lineWidth: 1)
        }
    }

    // MARK: - Hack Squat Machine

    private func drawHackSquatMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Angled rail (steeper than leg press)
        var rail = Path()
        rail.move(to: CGPoint(x: w * 0.3, y: h * 0.9))
        rail.addLine(to: CGPoint(x: w * 0.6, y: h * 0.1))
        ctx.stroke(rail, with: .color(stroke), lineWidth: lineWidth)

        // Shoulder pads
        var pads = Path()
        pads.addRoundedRect(in: CGRect(x: w * 0.35, y: h * 0.35, width: w * 0.3, height: h * 0.1), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(pads, with: .color(fill))
        ctx.stroke(pads, with: .color(stroke), lineWidth: lineWidth)

        // Back pad
        var backPad = Path()
        backPad.addRoundedRect(in: CGRect(x: w * 0.38, y: h * 0.45, width: w * 0.12, height: h * 0.3), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(backPad, with: .color(fill))
        ctx.stroke(backPad, with: .color(stroke), lineWidth: lineWidth)

        // Foot platform
        var platform = Path()
        platform.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.85, width: w * 0.5, height: h * 0.08), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(platform, with: .color(stroke.opacity(0.3)))
        ctx.stroke(platform, with: .color(stroke), lineWidth: lineWidth)
    }

    // MARK: - Seated Press Machine (Chest / Shoulder)

    private func drawSeatedPressMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Vertical frame
        var frame = Path()
        frame.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.05, width: w * 0.08, height: h * 0.9), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(frame, with: .color(fill))
        ctx.stroke(frame, with: .color(stroke), lineWidth: lineWidth)

        // Seat
        var seat = Path()
        seat.addRoundedRect(in: CGRect(x: w * 0.25, y: h * 0.68, width: w * 0.35, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(seat, with: .color(fill))
        ctx.stroke(seat, with: .color(stroke), lineWidth: lineWidth)

        // Back pad
        var pad = Path()
        pad.addRoundedRect(in: CGRect(x: w * 0.22, y: h * 0.3, width: w * 0.08, height: h * 0.4), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(pad, with: .color(fill))
        ctx.stroke(pad, with: .color(stroke), lineWidth: lineWidth)

        // Press arms (two horizontal bars extending forward)
        var armTop = Path()
        armTop.move(to: CGPoint(x: w * 0.2, y: h * 0.35))
        armTop.addLine(to: CGPoint(x: w * 0.82, y: h * 0.35))
        ctx.stroke(armTop, with: .color(stroke), lineWidth: lineWidth)

        var armBot = Path()
        armBot.move(to: CGPoint(x: w * 0.2, y: h * 0.5))
        armBot.addLine(to: CGPoint(x: w * 0.82, y: h * 0.5))
        ctx.stroke(armBot, with: .color(stroke), lineWidth: lineWidth)

        // Handles
        var handleT = Path()
        handleT.addRoundedRect(in: CGRect(x: w * 0.78, y: h * 0.3, width: w * 0.08, height: h * 0.1), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(handleT, with: .color(stroke.opacity(0.4)))

        var handleB = Path()
        handleB.addRoundedRect(in: CGRect(x: w * 0.78, y: h * 0.45, width: w * 0.08, height: h * 0.1), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(handleB, with: .color(stroke.opacity(0.4)))
    }

    // MARK: - Lat Pulldown Machine

    private func drawLatPulldownMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Vertical frame
        var frame = Path()
        frame.addRoundedRect(in: CGRect(x: w * 0.45, y: h * 0.05, width: w * 0.1, height: h * 0.9), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(frame, with: .color(fill))
        ctx.stroke(frame, with: .color(stroke), lineWidth: lineWidth)

        // Top bar (wide lat bar)
        var topBar = Path()
        topBar.move(to: CGPoint(x: w * 0.1, y: h * 0.12))
        topBar.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.12), control: CGPoint(x: w * 0.5, y: h * 0.2))
        ctx.stroke(topBar, with: .color(stroke), lineWidth: lineWidth + 1)

        // Cable
        var cable = Path()
        cable.move(to: CGPoint(x: w * 0.5, y: h * 0.12))
        cable.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05))
        ctx.stroke(cable, with: .color(stroke), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))

        // Seat
        var seat = Path()
        seat.addRoundedRect(in: CGRect(x: w * 0.25, y: h * 0.75, width: w * 0.5, height: h * 0.07), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(seat, with: .color(fill))
        ctx.stroke(seat, with: .color(stroke), lineWidth: lineWidth)

        // Thigh pad
        var pad = Path()
        pad.addRoundedRect(in: CGRect(x: w * 0.3, y: h * 0.65, width: w * 0.4, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(pad, with: .color(fill))
        ctx.stroke(pad, with: .color(stroke), lineWidth: lineWidth)
    }

    // MARK: - Leg Extension / Leg Curl Machine

    private func drawLegMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Frame pillar
        var frame = Path()
        frame.addRoundedRect(in: CGRect(x: w * 0.1, y: h * 0.1, width: w * 0.08, height: h * 0.8), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(frame, with: .color(fill))
        ctx.stroke(frame, with: .color(stroke), lineWidth: lineWidth)

        // Seat
        var seat = Path()
        seat.addRoundedRect(in: CGRect(x: w * 0.2, y: h * 0.55, width: w * 0.4, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(seat, with: .color(fill))
        ctx.stroke(seat, with: .color(stroke), lineWidth: lineWidth)

        // Back pad
        var pad = Path()
        pad.addRoundedRect(in: CGRect(x: w * 0.2, y: h * 0.25, width: w * 0.08, height: h * 0.32), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(pad, with: .color(fill))
        ctx.stroke(pad, with: .color(stroke), lineWidth: lineWidth)

        // Leg lever arm
        var lever = Path()
        lever.move(to: CGPoint(x: w * 0.58, y: h * 0.58))
        lever.addLine(to: CGPoint(x: w * 0.85, y: h * 0.75))
        ctx.stroke(lever, with: .color(stroke), lineWidth: lineWidth + 1)

        // Ankle pad
        var ankle = Path()
        ankle.addRoundedRect(in: CGRect(x: w * 0.78, y: h * 0.72, width: w * 0.12, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(ankle, with: .color(fill))
        ctx.stroke(ankle, with: .color(stroke), lineWidth: lineWidth)

        // Weight stack (small)
        for i in 0..<3 {
            let y = h * 0.15 + CGFloat(i) * h * 0.08
            var plate = Path()
            plate.addRoundedRect(in: CGRect(x: w * 0.02, y: y, width: w * 0.08, height: h * 0.06), cornerSize: CGSize(width: 1, height: 1))
            ctx.fill(plate, with: .color(fill))
            ctx.stroke(plate, with: .color(stroke.opacity(0.5)), lineWidth: 1)
        }
    }

    // MARK: - Pec Deck Machine

    private func drawPecDeckMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Central pillar
        var pillar = Path()
        pillar.addRoundedRect(in: CGRect(x: w * 0.44, y: h * 0.05, width: w * 0.12, height: h * 0.85), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(pillar, with: .color(fill))
        ctx.stroke(pillar, with: .color(stroke), lineWidth: lineWidth)

        // Left arm
        var leftArm = Path()
        leftArm.addArc(center: CGPoint(x: w * 0.5, y: h * 0.25), radius: w * 0.35, startAngle: .degrees(150), endAngle: .degrees(190), clockwise: false)
        ctx.stroke(leftArm, with: .color(stroke), lineWidth: lineWidth + 1)

        // Right arm
        var rightArm = Path()
        rightArm.addArc(center: CGPoint(x: w * 0.5, y: h * 0.25), radius: w * 0.35, startAngle: .degrees(350), endAngle: .degrees(30), clockwise: false)
        ctx.stroke(rightArm, with: .color(stroke), lineWidth: lineWidth + 1)

        // Arm pads
        var leftPad = Path()
        leftPad.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.3, width: w * 0.08, height: h * 0.2), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(leftPad, with: .color(fill))
        ctx.stroke(leftPad, with: .color(stroke), lineWidth: lineWidth)

        var rightPad = Path()
        rightPad.addRoundedRect(in: CGRect(x: w * 0.84, y: h * 0.3, width: w * 0.08, height: h * 0.2), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(rightPad, with: .color(fill))
        ctx.stroke(rightPad, with: .color(stroke), lineWidth: lineWidth)

        // Seat
        var seat = Path()
        seat.addRoundedRect(in: CGRect(x: w * 0.3, y: h * 0.78, width: w * 0.4, height: h * 0.07), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(seat, with: .color(fill))
        ctx.stroke(seat, with: .color(stroke), lineWidth: lineWidth)
    }

    // MARK: - Machine (generic)

    private func drawMachine(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Frame (vertical pillar)
        var frame = Path()
        frame.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.08, width: w * 0.12, height: h * 0.84), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(frame, with: .color(fill))
        ctx.stroke(frame, with: .color(stroke), lineWidth: lineWidth)

        // Weight stack
        for i in 0..<5 {
            let y = h * 0.12 + CGFloat(i) * h * 0.1
            var plate = Path()
            plate.addRoundedRect(in: CGRect(x: w * 0.32, y: y, width: w * 0.28, height: h * 0.07), cornerSize: CGSize(width: 2, height: 2))
            ctx.fill(plate, with: .color(i < 3 ? fill : fill.opacity(0.5)))
            ctx.stroke(plate, with: .color(stroke.opacity(i < 3 ? 1 : 0.4)), lineWidth: 1)
        }

        // Seat
        var seat = Path()
        seat.addRoundedRect(in: CGRect(x: w * 0.4, y: h * 0.72, width: w * 0.45, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(seat, with: .color(fill))
        ctx.stroke(seat, with: .color(stroke), lineWidth: lineWidth)

        // Back pad
        var pad = Path()
        pad.addRoundedRect(in: CGRect(x: w * 0.72, y: h * 0.35, width: w * 0.1, height: h * 0.38), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(pad, with: .color(fill))
        ctx.stroke(pad, with: .color(stroke), lineWidth: lineWidth)

        // Guide rail (connecting cable)
        var cable = Path()
        cable.move(to: CGPoint(x: w * 0.46, y: h * 0.12))
        cable.addLine(to: CGPoint(x: w * 0.46, y: h * 0.72))
        ctx.stroke(cable, with: .color(stroke.opacity(0.5)), lineWidth: 1)
    }

    // MARK: - Cable

    private func drawCable(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Top pulley housing
        var housing = Path()
        housing.addRoundedRect(in: CGRect(x: w * 0.3, y: h * 0.05, width: w * 0.4, height: h * 0.12), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(housing, with: .color(fill))
        ctx.stroke(housing, with: .color(stroke), lineWidth: lineWidth)

        // Pulley circle
        var pulley = Path()
        pulley.addEllipse(in: CGRect(x: w * 0.43, y: h * 0.07, width: w * 0.14, height: h * 0.08))
        ctx.stroke(pulley, with: .color(stroke), lineWidth: lineWidth)

        // Cable line
        var cable = Path()
        cable.move(to: CGPoint(x: w * 0.5, y: h * 0.17))
        cable.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
        ctx.stroke(cable, with: .color(stroke), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

        // Handle
        var handle = Path()
        handle.addRoundedRect(in: CGRect(x: w * 0.3, y: h * 0.7, width: w * 0.4, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(handle, with: .color(fill))
        ctx.stroke(handle, with: .color(stroke), lineWidth: lineWidth)

        // Grip ends
        var leftGrip = Path()
        leftGrip.addRoundedRect(in: CGRect(x: w * 0.25, y: h * 0.68, width: w * 0.06, height: h * 0.1), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(leftGrip, with: .color(stroke))

        var rightGrip = Path()
        rightGrip.addRoundedRect(in: CGRect(x: w * 0.69, y: h * 0.68, width: w * 0.06, height: h * 0.1), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(rightGrip, with: .color(stroke))
    }

    // MARK: - Bodyweight

    private func drawBodyweight(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cx = w * 0.5
        // Head
        var head = Path()
        head.addEllipse(in: CGRect(x: cx - w * 0.08, y: h * 0.06, width: w * 0.16, height: h * 0.16))
        ctx.fill(head, with: .color(fill))
        ctx.stroke(head, with: .color(stroke), lineWidth: lineWidth)

        // Torso
        var torso = Path()
        torso.move(to: CGPoint(x: cx, y: h * 0.22))
        torso.addLine(to: CGPoint(x: cx, y: h * 0.55))
        ctx.stroke(torso, with: .color(stroke), lineWidth: lineWidth)

        // Arms (push-up pose, slightly out)
        var arms = Path()
        arms.move(to: CGPoint(x: cx - w * 0.25, y: h * 0.4))
        arms.addLine(to: CGPoint(x: cx, y: h * 0.3))
        arms.addLine(to: CGPoint(x: cx + w * 0.25, y: h * 0.4))
        ctx.stroke(arms, with: .color(stroke), lineWidth: lineWidth)

        // Legs
        var legs = Path()
        legs.move(to: CGPoint(x: cx - w * 0.15, y: h * 0.85))
        legs.addLine(to: CGPoint(x: cx, y: h * 0.55))
        legs.addLine(to: CGPoint(x: cx + w * 0.15, y: h * 0.85))
        ctx.stroke(legs, with: .color(stroke), lineWidth: lineWidth)

        // Feet
        var leftFoot = Path()
        leftFoot.addEllipse(in: CGRect(x: cx - w * 0.18, y: h * 0.83, width: w * 0.06, height: h * 0.06))
        ctx.fill(leftFoot, with: .color(stroke))
        var rightFoot = Path()
        rightFoot.addEllipse(in: CGRect(x: cx + w * 0.12, y: h * 0.83, width: w * 0.06, height: h * 0.06))
        ctx.fill(rightFoot, with: .color(stroke))
    }

    // MARK: - Pull-Up Bar

    private func drawPullUpBar(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Horizontal bar
        var bar = Path()
        bar.addRoundedRect(in: CGRect(x: w * 0.1, y: h * 0.2, width: w * 0.8, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(bar, with: .color(fill))
        ctx.stroke(bar, with: .color(stroke), lineWidth: lineWidth)

        // Mounting brackets
        var leftMount = Path()
        leftMount.addRoundedRect(in: CGRect(x: w * 0.1, y: h * 0.08, width: w * 0.06, height: h * 0.18), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(leftMount, with: .color(stroke.opacity(0.4)))

        var rightMount = Path()
        rightMount.addRoundedRect(in: CGRect(x: w * 0.84, y: h * 0.08, width: w * 0.06, height: h * 0.18), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(rightMount, with: .color(stroke.opacity(0.4)))

        // Hanging figure (simplified)
        let cx = w * 0.5
        var hands = Path()
        hands.move(to: CGPoint(x: cx - w * 0.15, y: h * 0.26))
        hands.addLine(to: CGPoint(x: cx, y: h * 0.35))
        hands.addLine(to: CGPoint(x: cx + w * 0.15, y: h * 0.26))
        ctx.stroke(hands, with: .color(stroke.opacity(0.5)), lineWidth: lineWidth)

        var body = Path()
        body.move(to: CGPoint(x: cx, y: h * 0.35))
        body.addLine(to: CGPoint(x: cx, y: h * 0.65))
        ctx.stroke(body, with: .color(stroke.opacity(0.5)), lineWidth: lineWidth)

        var figLegs = Path()
        figLegs.move(to: CGPoint(x: cx - w * 0.1, y: h * 0.85))
        figLegs.addLine(to: CGPoint(x: cx, y: h * 0.65))
        figLegs.addLine(to: CGPoint(x: cx + w * 0.1, y: h * 0.85))
        ctx.stroke(figLegs, with: .color(stroke.opacity(0.5)), lineWidth: lineWidth)
    }

    // MARK: - Dip Station

    private func drawDipStation(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Two parallel bars
        var leftBar = Path()
        leftBar.addRoundedRect(in: CGRect(x: w * 0.2, y: h * 0.3, width: w * 0.06, height: h * 0.5), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(leftBar, with: .color(fill))
        ctx.stroke(leftBar, with: .color(stroke), lineWidth: lineWidth)

        var rightBar = Path()
        rightBar.addRoundedRect(in: CGRect(x: w * 0.74, y: h * 0.3, width: w * 0.06, height: h * 0.5), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(rightBar, with: .color(fill))
        ctx.stroke(rightBar, with: .color(stroke), lineWidth: lineWidth)

        // Horizontal handles
        var leftHandle = Path()
        leftHandle.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.28, width: w * 0.16, height: h * 0.05), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(leftHandle, with: .color(stroke))

        var rightHandle = Path()
        rightHandle.addRoundedRect(in: CGRect(x: w * 0.69, y: h * 0.28, width: w * 0.16, height: h * 0.05), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(rightHandle, with: .color(stroke))

        // Base
        var base = Path()
        base.addRoundedRect(in: CGRect(x: w * 0.15, y: h * 0.82, width: w * 0.7, height: h * 0.05), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(base, with: .color(stroke.opacity(0.3)))
    }

    // MARK: - Band

    private func drawBand(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Elastic band loop shape
        var band = Path()
        band.move(to: CGPoint(x: w * 0.2, y: h * 0.3))
        band.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.3), control: CGPoint(x: w * 0.5, y: h * 0.05))
        band.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.7), control: CGPoint(x: w * 0.85, y: h * 0.5))
        band.addQuadCurve(to: CGPoint(x: w * 0.2, y: h * 0.3), control: CGPoint(x: w * 0.3, y: h * 0.55))
        ctx.fill(band, with: .color(fill))
        ctx.stroke(band, with: .color(stroke), lineWidth: lineWidth)

        // Stretch lines (indicating elasticity)
        for i in 0..<3 {
            let x = w * 0.35 + CGFloat(i) * w * 0.12
            var line = Path()
            line.move(to: CGPoint(x: x, y: h * 0.2))
            line.addLine(to: CGPoint(x: x + w * 0.04, y: h * 0.15))
            ctx.stroke(line, with: .color(stroke.opacity(0.4)), lineWidth: 1)
        }
    }

    // MARK: - TRX

    private func drawTRX(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        // Anchor point
        var anchor = Path()
        anchor.addRoundedRect(in: CGRect(x: w * 0.35, y: h * 0.05, width: w * 0.3, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(anchor, with: .color(stroke.opacity(0.4)))

        // Left strap
        var leftStrap = Path()
        leftStrap.move(to: CGPoint(x: w * 0.42, y: h * 0.11))
        leftStrap.addLine(to: CGPoint(x: w * 0.35, y: h * 0.65))
        ctx.stroke(leftStrap, with: .color(stroke), lineWidth: lineWidth)

        // Right strap
        var rightStrap = Path()
        rightStrap.move(to: CGPoint(x: w * 0.58, y: h * 0.11))
        rightStrap.addLine(to: CGPoint(x: w * 0.65, y: h * 0.65))
        ctx.stroke(rightStrap, with: .color(stroke), lineWidth: lineWidth)

        // Left handle
        var leftHandle = Path()
        leftHandle.addRoundedRect(in: CGRect(x: w * 0.28, y: h * 0.65, width: w * 0.14, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(leftHandle, with: .color(fill))
        ctx.stroke(leftHandle, with: .color(stroke), lineWidth: lineWidth)

        // Right handle
        var rightHandle = Path()
        rightHandle.addRoundedRect(in: CGRect(x: w * 0.58, y: h * 0.65, width: w * 0.14, height: h * 0.08), cornerSize: CGSize(width: 4, height: 4))
        ctx.fill(rightHandle, with: .color(fill))
        ctx.stroke(rightHandle, with: .color(stroke), lineWidth: lineWidth)

        // Foot cradles
        var leftCradle = Path()
        leftCradle.addRoundedRect(in: CGRect(x: w * 0.3, y: h * 0.8, width: w * 0.1, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(leftCradle, with: .color(fill))
        ctx.stroke(leftCradle, with: .color(stroke), lineWidth: 1)

        var rightCradle = Path()
        rightCradle.addRoundedRect(in: CGRect(x: w * 0.6, y: h * 0.8, width: w * 0.1, height: h * 0.06), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(rightCradle, with: .color(fill))
        ctx.stroke(rightCradle, with: .color(stroke), lineWidth: 1)
    }

    // MARK: - Medicine Ball

    private func drawMedicineBall(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cx = w * 0.5
        let cy = h * 0.48
        let r = Swift.min(w, h) * 0.35

        // Ball body
        var ball = Path()
        ball.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.fill(ball, with: .color(fill))
        ctx.stroke(ball, with: .color(stroke), lineWidth: lineWidth)

        // Cross seam lines
        var hLine = Path()
        hLine.move(to: CGPoint(x: cx - r * 0.7, y: cy))
        hLine.addQuadCurve(to: CGPoint(x: cx + r * 0.7, y: cy), control: CGPoint(x: cx, y: cy - r * 0.15))
        ctx.stroke(hLine, with: .color(stroke.opacity(0.4)), lineWidth: 1)

        var vLine = Path()
        vLine.move(to: CGPoint(x: cx, y: cy - r * 0.7))
        vLine.addQuadCurve(to: CGPoint(x: cx, y: cy + r * 0.7), control: CGPoint(x: cx + r * 0.15, y: cy))
        ctx.stroke(vLine, with: .color(stroke.opacity(0.4)), lineWidth: 1)

        // Shadow/ground
        var shadow = Path()
        shadow.addEllipse(in: CGRect(x: cx - r * 0.6, y: h * 0.88, width: r * 1.2, height: h * 0.04))
        ctx.fill(shadow, with: .color(stroke.opacity(0.15)))
    }

    // MARK: - Stability Ball

    private func drawStabilityBall(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cx = w * 0.5
        let cy = h * 0.45
        let rx = w * 0.38
        let ry = h * 0.35

        // Large ball
        var ball = Path()
        ball.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        ctx.fill(ball, with: .color(fill))
        ctx.stroke(ball, with: .color(stroke), lineWidth: lineWidth)

        // Equator line
        var equator = Path()
        equator.move(to: CGPoint(x: cx - rx * 0.85, y: cy))
        equator.addQuadCurve(to: CGPoint(x: cx + rx * 0.85, y: cy), control: CGPoint(x: cx, y: cy + ry * 0.15))
        ctx.stroke(equator, with: .color(stroke.opacity(0.3)), lineWidth: 1)

        // Highlight
        var highlight = Path()
        highlight.addEllipse(in: CGRect(x: cx - rx * 0.3, y: cy - ry * 0.6, width: rx * 0.35, height: ry * 0.3))
        ctx.fill(highlight, with: .color(.white.opacity(0.2)))

        // Shadow/ground
        var shadow = Path()
        shadow.addEllipse(in: CGRect(x: cx - rx * 0.5, y: h * 0.88, width: rx, height: h * 0.04))
        ctx.fill(shadow, with: .color(stroke.opacity(0.15)))
    }

    // MARK: - Other

    private func drawOther(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, stroke: Color, fill: Color, lineWidth: CGFloat) {
        let cx = w * 0.5
        let cy = h * 0.5

        // Question-mark style circle
        var circle = Path()
        circle.addEllipse(in: CGRect(x: cx - w * 0.25, y: cy - h * 0.25, width: w * 0.5, height: h * 0.5))
        ctx.fill(circle, with: .color(fill))
        ctx.stroke(circle, with: .color(stroke), lineWidth: lineWidth)

        // Ellipsis dots
        for i in 0..<3 {
            let dotX = cx - w * 0.1 + CGFloat(i) * w * 0.1
            var dot = Path()
            dot.addEllipse(in: CGRect(x: dotX - 3, y: cy - 3, width: 6, height: 6))
            ctx.fill(dot, with: .color(stroke))
        }
    }
}

// MARK: - Previews

#Preview("All Equipment") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
            ForEach(Equipment.allCases, id: \.self) { equipment in
                VStack(spacing: 8) {
                    EquipmentIllustrationView(equipment: equipment, size: 70)
                    Text(equipment.localizedDisplayName)
                        .font(.caption2)
                }
            }
        }
        .padding()
    }
}
