import SwiftUI

/// The desk cat, drawn in points around its own feet so it can sit on the desk scene or stand alone.
struct CompanionPetCanvas: View, Animatable {
    var pose: CompanionPose
    var stage: CompanionStage
    var night: Bool
    var bounce: Double
    /// Where the cat's feet sit, in the 360×156 desk coordinate space.
    var anchor = CGPoint(x: 238, y: 137)
    var canvasSize = CGSize(width: 360, height: 156)
    var animatableData: Double {
        get { bounce }
        set { bounce = newValue }
    }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / canvasSize.width, y: size.height / canvasSize.height)
            let hop = abs(sin(bounce * .pi))
            let scale = 0.8 + 0.045 * Double(stage.rawValue)
            context.translateBy(x: anchor.x, y: anchor.y - hop * 7)
            context.scaleBy(x: scale, y: scale)
            draw(in: &context, hop: hop)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func draw(in context: inout GraphicsContext, hop: Double) {
        let dark = colorScheme == .dark
        let fur = dark ? Color(red: 0.86, green: 0.58, blue: 0.36) : Color(red: 0.93, green: 0.64, blue: 0.38)
        let belly = dark ? Color(red: 0.96, green: 0.86, blue: 0.72) : Color(red: 1, green: 0.95, blue: 0.86)
        let line = WriteRightTheme.secondary.opacity(0.85)
        let stripe = Color(red: 0.72, green: 0.38, blue: 0.2).opacity(0.7)
        let ink = WriteRightTheme.ink.opacity(0.85)
        func fill(_ path: Path, _ color: Color) { context.fill(path, with: .color(color)); context.stroke(path, with: .color(line), lineWidth: 0.9) }
        func stroke(_ path: Path, _ color: Color, _ width: CGFloat = 1) {
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func ear(_ x: Double, _ y: Double, _ flip: Double, _ size: Double) -> Path {
            var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 2 * flip, y: y - size))
            p.addLine(to: CGPoint(x: x + 7 * flip, y: y - 3)); p.closeSubpath(); return p
        }
        // A lantern for evenings once the cat has grown into it; drawn first so it sits beside the body.
        if stage >= .lantern && night && pose != .sleeping {
            var handle = Path(); handle.move(to: CGPoint(x: -24, y: -26)); handle.addQuadCurve(to: CGPoint(x: -16, y: -26), control: CGPoint(x: -20, y: -32))
            stroke(handle, line, 0.8)
            context.fill(Path(ellipseIn: CGRect(x: -31, y: -38, width: 22, height: 22)), with: .color(WriteRightTheme.accent.opacity(0.18)))
            fill(Path(roundedRect: CGRect(x: -25, y: -26, width: 10, height: 12), cornerRadius: 3), Color(red: 1, green: 0.8, blue: 0.45))
        }
        if stage >= .together && pose != .sleeping {
            fill(Path(roundedRect: CGRect(x: 7, y: -24, width: 11, height: 14), cornerRadius: 3.5), WriteRightTheme.sage.opacity(0.85))
            stroke(Path { $0.move(to: CGPoint(x: 9, y: -20)); $0.addLine(to: CGPoint(x: 16, y: -20)) }, line, 0.7)
        }
        switch pose {
        case .sleeping:
            var tail = Path(); tail.move(to: CGPoint(x: 15, y: -5)); tail.addCurve(to: CGPoint(x: -10, y: -1), control1: CGPoint(x: 24, y: 2), control2: CGPoint(x: 6, y: 3))
            stroke(tail, line, 4.2); stroke(tail, fur, 3)
            fill(Path(ellipseIn: CGRect(x: -16, y: -15, width: 33, height: 15)), fur)
            for x in [0.0, 5, 10] { stroke(Path { $0.move(to: CGPoint(x: x, y: -14)); $0.addLine(to: CGPoint(x: x + 1.5, y: -10)) }, stripe, 1) }
            fill(ear(-19, -14, 1, 6), fur); fill(ear(-7, -14, -1, 6), fur)
            fill(Path(ellipseIn: CGRect(x: -22, y: -16, width: 17, height: 14)), fur)
            for x in [-17.0, -10] { stroke(Path { $0.addArc(center: CGPoint(x: x, y: -10), radius: 2, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false) }, ink, 0.8) }
            if stage >= .guardian { stroke(Path { $0.move(to: CGPoint(x: -8, y: -6)); $0.addLine(to: CGPoint(x: -3, y: -11)) }, WriteRightTheme.accent, 2.4) }
            context.draw(Text("z").font(.system(size: 7, design: .serif)).foregroundColor(WriteRightTheme.secondary), at: CGPoint(x: -4, y: -24))
            context.draw(Text("z").font(.system(size: 5, design: .serif)).foregroundColor(WriteRightTheme.secondary), at: CGPoint(x: 1, y: -30))
        case .sitting, .focusing:
            let swish = sin(bounce * .pi) * 6
            var tail = Path(); tail.move(to: CGPoint(x: 12, y: -4))
            tail.addCurve(to: CGPoint(x: 21 + swish * 0.4, y: -24 - swish), control1: CGPoint(x: 26, y: -2), control2: CGPoint(x: 25, y: -14))
            stroke(tail, line, 4.2); stroke(tail, fur, 3)
            fill(Path(ellipseIn: CGRect(x: -14, y: -24, width: 28, height: 24)), fur)
            context.fill(Path(ellipseIn: CGRect(x: -7, y: -19, width: 14, height: 17)), with: .color(belly))
            for x in [-5.0, 5] { fill(Path(ellipseIn: CGRect(x: x - 3.5, y: -4, width: 7, height: 4.5)), belly) }
            let tilt: Double = pose == .focusing ? -2.5 : 0
            let headY: Double = -32
            fill(ear(-9 + tilt, headY - 4, 1, 9), fur); fill(ear(9 + tilt, headY - 4, -1, 9), fur)
            fill(Path(ellipseIn: CGRect(x: -10.5 + tilt, y: headY - 9, width: 21, height: 18)), fur)
            for x in [-3.0, 0, 3] { stroke(Path { $0.move(to: CGPoint(x: x + tilt, y: headY - 8)); $0.addLine(to: CGPoint(x: x + tilt, y: headY - 5)) }, stripe, 0.9) }
            let look: Double = pose == .focusing ? -1.4 : 0
            if hop > 0.25 {
                for x in [-4.0, 4] { stroke(Path { $0.addArc(center: CGPoint(x: x + tilt, y: headY + 0.5), radius: 2, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) }, ink, 0.9) }
            } else {
                for x in [-4.0, 4] { context.fill(Path(ellipseIn: CGRect(x: x + tilt + look - 1.4, y: headY - 1, width: 2.8, height: 3.2)), with: .color(ink)) }
            }
            context.fill(Path(ellipseIn: CGRect(x: -1.2 + tilt, y: headY + 2.4, width: 2.4, height: 1.6)), with: .color(WriteRightTheme.accent.opacity(0.8)))
            for side in [-1.0, 1] {
                context.fill(Path(ellipseIn: CGRect(x: side * 6.5 + tilt - 2, y: headY + 2.5, width: 4, height: 2.4)), with: .color(WriteRightTheme.accent.opacity(0.18)))
                stroke(Path { $0.move(to: CGPoint(x: side * 7 + tilt, y: headY + 3)); $0.addLine(to: CGPoint(x: side * 14 + tilt, y: headY + 2)) }, line.opacity(0.5), 0.5)
            }
            if stage >= .guardian {
                var scarf = Path(); scarf.move(to: CGPoint(x: -8, y: -23)); scarf.addQuadCurve(to: CGPoint(x: 8, y: -23), control: CGPoint(x: 0, y: -19))
                stroke(scarf, WriteRightTheme.accent, 3)
                stroke(Path { $0.move(to: CGPoint(x: 4, y: -22)); $0.addLine(to: CGPoint(x: 6.5, y: -15)) }, WriteRightTheme.accent, 2.4)
                if stage >= .lantern && !night { context.fill(star(CGPoint(x: -4, y: -20), 2.2), with: .color(Color(red: 1, green: 0.82, blue: 0.4))) }
            }
            if stage >= .partner {
                stroke(Path { $0.move(to: CGPoint(x: -12, y: -6)); $0.addLine(to: CGPoint(x: -19, y: -19)) }, WriteRightTheme.accent, 2.2)
                stroke(Path { $0.move(to: CGPoint(x: -19, y: -19)); $0.addLine(to: CGPoint(x: -20, y: -21)) }, ink, 1.6)
            }
            if hop > 0.05 { context.fill(heart(CGPoint(x: 12, y: headY - 14 - hop * 4)), with: .color(WriteRightTheme.accent.opacity(hop))) }
        }
    }
    private func heart(_ c: CGPoint) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + 3.5))
        p.addCurve(to: CGPoint(x: c.x - 3.5, y: c.y - 1), control1: CGPoint(x: c.x - 2, y: c.y + 2), control2: CGPoint(x: c.x - 3.5, y: c.y + 1))
        p.addArc(center: CGPoint(x: c.x - 1.75, y: c.y - 1), radius: 1.75, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: c.x + 1.75, y: c.y - 1), radius: 1.75, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: c.x, y: c.y + 3.5), control1: CGPoint(x: c.x + 3.5, y: c.y + 1), control2: CGPoint(x: c.x + 2, y: c.y + 2))
        return p
    }
    private func star(_ c: CGPoint, _ r: Double) -> Path {
        var p = Path()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? r : r * 0.45
            let angle = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath(); return p
    }
}
