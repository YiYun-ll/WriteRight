import SwiftUI

/// The desk cat, drawn in points around its own feet so it can sit on the desk scene or stand alone.
struct CompanionPetCanvas: View, Animatable {
    var pose: CompanionPose
    var stage: CompanionStage
    var night: Bool
    var bounce: Double
    /// Where the cat's feet sit, in the 360×156 desk coordinate space.
    var anchor = CompanionPetCanvas.deskAnchor
    var canvasSize = DeskSpace.design
    static let deskAnchor = CGPoint(x: 238, y: 135)
    var animatableData: Double {
        get { bounce }
        set { bounce = newValue }
    }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            DeskSpace(size, design: canvasSize).enter(&context)
            let hop = abs(sin(bounce * .pi))
            let scale = 0.94 + 0.04 * Double(stage.rawValue)
            context.translateBy(x: anchor.x, y: anchor.y - hop * 7)
            context.scaleBy(x: scale, y: scale)
            draw(in: context, hop: hop)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private struct Palette {
        let fur, furLight, belly, stripe, innerEar, nose, eye, blush: PaintColor
        let outline: Color
        init(dark: Bool) {
            fur = PaintColor(dark ? 0xD99257 : 0xF2A35C); furLight = PaintColor(dark ? 0xE8AE77 : 0xFCC78F)
            belly = PaintColor(dark ? 0xEBDDCB : 0xFFF6E8); stripe = PaintColor(dark ? 0xB4652F : 0xDA7B3C)
            innerEar = PaintColor(dark ? 0xD99A90 : 0xF7B4A6); nose = PaintColor(0xEF8A8A)
            eye = PaintColor(dark ? 0x24180F : 0x3A2A22); blush = PaintColor(0xF59A8B)
            outline = dark ? PaintColor(0x1C110A).color(0.75) : PaintColor(0x8A4E2B).color(0.7)
        }
    }

    private func draw(in context: GraphicsContext, hop: Double) {
        let dark = colorScheme == .dark
        let p = Palette(dark: dark)
        func fill(_ path: Path, _ shading: GraphicsContext.Shading, line: Bool = true) {
            context.fill(path, with: shading)
            if line { context.stroke(path, with: .color(p.outline), style: StrokeStyle(lineWidth: 1, lineJoin: .round)) }
        }
        func stroke(_ path: Path, _ color: Color, _ width: CGFloat) {
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func fur(_ rect: CGRect) -> GraphicsContext.Shading { DeskArt.vertical(p.furLight, p.fur, from: rect.minY, to: rect.maxY) }
        func ears(_ head: CGPoint, size s: CGFloat, tilt: CGFloat = 0) {
            for side in [-1.0, 1] as [CGFloat] {
                var ear = Path()
                ear.move(to: CGPoint(x: head.x + side * 15 * s, y: head.y - 2 * s))
                ear.addQuadCurve(to: CGPoint(x: head.x + side * 12.5 * s + tilt, y: head.y - 20 * s), control: CGPoint(x: head.x + side * 17 * s, y: head.y - 13 * s))
                ear.addQuadCurve(to: CGPoint(x: head.x + side * 3 * s, y: head.y - 11 * s), control: CGPoint(x: head.x + side * 7 * s, y: head.y - 18 * s))
                ear.closeSubpath()
                fill(ear, .color(p.fur.color))
                var inner = Path()
                inner.move(to: CGPoint(x: head.x + side * 12.5 * s, y: head.y - 6 * s))
                inner.addQuadCurve(to: CGPoint(x: head.x + side * 12 * s + tilt * 0.8, y: head.y - 16.5 * s), control: CGPoint(x: head.x + side * 14 * s, y: head.y - 12 * s))
                inner.addQuadCurve(to: CGPoint(x: head.x + side * 6 * s, y: head.y - 11 * s), control: CGPoint(x: head.x + side * 8 * s, y: head.y - 15 * s))
                inner.closeSubpath()
                context.fill(inner, with: .color(p.innerEar.color))
            }
        }
        func cheeks(_ head: CGPoint, spread: CGFloat, y: CGFloat) {
            for side in [-1.0, 1] as [CGFloat] {
                context.fill(Path(ellipseIn: CGRect(x: head.x + side * spread - 3, y: head.y + y, width: 6, height: 3.4)), with: .color(p.blush.color(0.5)))
            }
        }
        func nose(_ head: CGPoint, y: CGFloat) {
            var n = Path()
            n.move(to: CGPoint(x: head.x - 1.9, y: head.y + y)); n.addLine(to: CGPoint(x: head.x + 1.9, y: head.y + y))
            n.addQuadCurve(to: CGPoint(x: head.x - 1.9, y: head.y + y), control: CGPoint(x: head.x, y: head.y + y + 3.6))
            context.fill(n, with: .color(p.nose.color))
        }

        context.fill(Path(ellipseIn: CGRect(x: -20, y: -2.6, width: 40, height: 5.2)), with: .color(Color.black.opacity(dark ? 0.3 : 0.12)))
        // A lantern for evenings once the cat has grown into it; drawn first so it sits beside the body.
        if stage >= .lantern && night && pose != .sleeping {
            let light = CGPoint(x: -33, y: -11)
            context.fill(Path(ellipseIn: CGRect(x: light.x - 18, y: light.y - 18, width: 36, height: 36)), with: DeskArt.glow(PaintColor(0xFFD98A), opacity: 0.55, at: light, radius: 18))
            stroke(Path { $0.move(to: CGPoint(x: -37, y: -19)); $0.addQuadCurve(to: CGPoint(x: -29, y: -19), control: CGPoint(x: -33, y: -26)) }, p.outline, 0.9)
            fill(Path(roundedRect: CGRect(x: -38.5, y: -19, width: 11, height: 15), cornerRadius: 4.5), DeskArt.vertical(PaintColor(0xFFE6A0), PaintColor(0xF7B85A), from: -19, to: -4))
            context.fill(Path(roundedRect: CGRect(x: -37, y: -20.5, width: 8, height: 2.4), cornerRadius: 1), with: .color(PaintColor(0x7B6556).color))
            context.fill(Path(roundedRect: CGRect(x: -37, y: -5, width: 8, height: 2.4), cornerRadius: 1), with: .color(PaintColor(0x7B6556).color))
        }
        if stage >= .together && pose != .sleeping {
            let pack = CGRect(x: 7, y: -25, width: 14, height: 16)
            fill(Path(roundedRect: pack, cornerRadius: 4), .color(PaintColor(dark ? 0x7E9A78 : 0x9CC59A).color))
            fill(Path(roundedRect: CGRect(x: 7, y: -25, width: 14, height: 7), cornerRadius: 3.5), .color(PaintColor(dark ? 0x6A8564 : 0x86B484).color))
            context.fill(Path(ellipseIn: CGRect(x: 15.5, y: -20, width: 3, height: 3)), with: .color(PaintColor(0xFFD36E).color))
        }

        switch pose {
        case .sleeping:
            var tail = Path(); tail.move(to: CGPoint(x: 17, y: -6))
            tail.addCurve(to: CGPoint(x: -10, y: -1.6), control1: CGPoint(x: 28, y: 1.5), control2: CGPoint(x: 8, y: 2.6))
            stroke(tail, p.outline, 7.2); stroke(tail, p.fur.color, 5.4)
            let body = CGRect(x: -19, y: -20, width: 40, height: 20)
            fill(Path(ellipseIn: body), fur(body))
            for x in [3.0, 9, 15] as [CGFloat] {
                stroke(Path { $0.move(to: CGPoint(x: x, y: -19.4)); $0.addLine(to: CGPoint(x: x + 1, y: -15)) }, p.stripe.color, 1.6)
            }
            let head = CGPoint(x: -13, y: -13)
            ears(head, size: 0.78, tilt: -1.5)
            let face = CGRect(x: head.x - 13.5, y: head.y - 11, width: 27, height: 21)
            fill(Path(ellipseIn: face), fur(face))
            context.fill(Path(ellipseIn: CGRect(x: head.x - 5.5, y: head.y + 1.5, width: 11, height: 7)), with: .color(p.belly.color))
            for side in [-1.0, 1] as [CGFloat] {
                stroke(Path { $0.addArc(center: CGPoint(x: head.x + side * 5.5, y: head.y - 1.5), radius: 2.6, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false) }, p.eye.color, 1.3)
            }
            nose(head, y: 2)
            cheeks(head, spread: 9.5, y: 1.5)
            fill(Path(ellipseIn: CGRect(x: head.x - 1, y: head.y + 7, width: 10, height: 5.4)), .color(p.belly.color))
            if stage >= .guardian {
                stroke(Path { $0.move(to: CGPoint(x: head.x + 10, y: head.y + 3)); $0.addQuadCurve(to: CGPoint(x: head.x + 13, y: head.y + 11), control: CGPoint(x: head.x + 14, y: head.y + 6)) }, WriteRightTheme.accent, 3.4)
            }
            let z = WriteRightTheme.secondary
            context.draw(Text("z").font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundColor(z), at: CGPoint(x: head.x + 13, y: head.y - 17))
            context.draw(Text("z").font(.system(size: 6, weight: .semibold, design: .rounded)).foregroundColor(z.opacity(0.7)), at: CGPoint(x: head.x + 19, y: head.y - 24))
        case .sitting, .focusing:
            let swish = sin(bounce * .pi) * 6
            var tail = Path(); tail.move(to: CGPoint(x: 9, y: -5))
            tail.addCurve(to: CGPoint(x: 22 + swish * 0.4, y: -27 - swish * 0.5), control1: CGPoint(x: 28, y: -3), control2: CGPoint(x: 29, y: -18))
            stroke(tail, p.outline, 7.4); stroke(tail, p.fur.color, 5.6)
            stroke(Path { $0.move(to: CGPoint(x: 26.5 + swish * 0.2, y: -18 - swish * 0.3)); $0.addLine(to: CGPoint(x: 22.5 + swish * 0.2, y: -17.5 - swish * 0.3)) }, p.stripe.color, 1.5)
            let body = CGRect(x: -14, y: -28, width: 28, height: 28)
            fill(Path(ellipseIn: body), fur(body))
            context.fill(Path(ellipseIn: CGRect(x: -8, y: -22, width: 16, height: 19)), with: .color(p.belly.color))
            for side in [-1.0, 1] as [CGFloat] {
                for k in 0..<2 {
                    let y = -19.0 + CGFloat(k) * 5
                    stroke(Path { $0.move(to: CGPoint(x: side * 13.6, y: y)); $0.addLine(to: CGPoint(x: side * 10, y: y + 1.2)) }, p.stripe.color, 1.4)
                }
            }
            for x in [-5.5, 5.5] as [CGFloat] {
                fill(Path(ellipseIn: CGRect(x: x - 4.6, y: -6, width: 9.2, height: 6.6)), .color(p.belly.color))
                for toe in [-1.5, 1.5] as [CGFloat] {
                    stroke(Path { $0.move(to: CGPoint(x: x + toe, y: -1.9)); $0.addLine(to: CGPoint(x: x + toe, y: -0.4)) }, p.outline, 0.6)
                }
            }
            let tilt: CGFloat = pose == .focusing ? -2 : 0
            let head = CGPoint(x: tilt, y: -39)
            ears(head, size: 1, tilt: tilt * 0.5)
            let face = CGRect(x: head.x - 17.5, y: head.y - 13.5, width: 35, height: 28)
            fill(Path(ellipseIn: face), fur(face))
            for dx in [-4.0, 0, 4] as [CGFloat] {
                stroke(Path { $0.move(to: CGPoint(x: head.x + dx, y: head.y - 13)); $0.addLine(to: CGPoint(x: head.x + dx * 0.85, y: head.y - 8.5)) }, p.stripe.color, 1.6)
            }
            context.fill(Path(ellipseIn: CGRect(x: head.x - 7.5, y: head.y + 1.5, width: 15, height: 9.5)), with: .color(p.belly.color))
            if hop > 0.25 {
                for side in [-1.0, 1] as [CGFloat] {
                    stroke(Path { $0.addArc(center: CGPoint(x: head.x + side * 7, y: head.y + 0.5), radius: 3, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) }, p.eye.color, 1.4)
                }
            } else {
                let look = pose == .focusing ? CGPoint(x: -1.2, y: 1.6) : .zero
                let eye = pose == .focusing ? CGSize(width: 5.2, height: 5) : CGSize(width: 5.8, height: 6.8)
                for side in [-1.0, 1] as [CGFloat] {
                    let center = CGPoint(x: head.x + side * 7 + look.x, y: head.y - 1.5 + look.y)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - eye.width / 2, y: center.y - eye.height / 2, width: eye.width, height: eye.height)), with: .color(p.eye.color))
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 0.4, y: center.y - eye.height / 2 + 0.6, width: 2.4, height: 2.4)), with: .color(.white))
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y + 0.9, width: 1.1, height: 1.1)), with: .color(Color.white.opacity(0.8)))
                }
            }
            nose(head, y: 2.6)
            for side in [-1.0, 1] as [CGFloat] {
                stroke(Path { $0.addArc(center: CGPoint(x: head.x + side * 1.7, y: head.y + 4.7), radius: 1.7, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false) }, p.eye.color.opacity(0.8), 0.8)
                for k in 0..<2 {
                    let y = head.y + 4 + CGFloat(k) * 2.6
                    stroke(Path { $0.move(to: CGPoint(x: head.x + side * 12.5, y: y)); $0.addLine(to: CGPoint(x: head.x + side * 20, y: y - 1.5 + CGFloat(k) * 2.5)) }, p.outline.opacity(0.55), 0.6)
                }
            }
            cheeks(head, spread: 11.5, y: 2.5)
            if stage >= .guardian {
                var scarf = Path(); scarf.move(to: CGPoint(x: -11.5, y: -26.5)); scarf.addQuadCurve(to: CGPoint(x: 11.5, y: -26.5), control: CGPoint(x: 0, y: -20.5))
                stroke(scarf, p.outline, 5.4); stroke(scarf, WriteRightTheme.accent, 4)
                var end = Path(); end.move(to: CGPoint(x: 5.5, y: -24)); end.addLine(to: CGPoint(x: 8.5, y: -15))
                stroke(end, p.outline, 4.6); stroke(end, WriteRightTheme.accent, 3.2)
                if stage >= .lantern && !night { context.fill(DeskArt.star(CGPoint(x: -4.5, y: -23.5), 2.6), with: .color(PaintColor(0xFFD36E).color)) }
            }
            if stage >= .partner {
                DeskArt.pencil(context, from: CGPoint(x: -21, y: -25), angle: .degrees(62), length: 22, outline: p.outline)
                fill(Path(ellipseIn: CGRect(x: -12.5, y: -9.5, width: 7, height: 6)), .color(p.belly.color))
            }
            if hop > 0.05 {
                context.fill(DeskArt.heart(CGPoint(x: 15, y: head.y - 19 - hop * 4), size: 1.3), with: .color(PaintColor(0xF27C7C).color(hop)))
            }
        }
    }
}
