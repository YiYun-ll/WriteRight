import SwiftUI

/// Maps a fixed drawing space into any frame without stretching it, so round things stay round.
struct DeskSpace {
    static let design = CGSize(width: 360, height: 156)
    static let cornerRadius: CGFloat = 22
    let size: CGSize
    let scale: CGFloat
    let origin: CGPoint

    init(_ size: CGSize, design: CGSize = DeskSpace.design) {
        self.size = size
        scale = max(0.01, min(size.width / design.width, size.height / design.height))
        origin = CGPoint(x: (size.width - design.width * scale) / 2, y: (size.height - design.height * scale) / 2)
    }
    /// The whole frame in drawing units, so the wall and desk reach every edge on wide screens.
    var visible: CGRect { CGRect(x: -origin.x / scale, y: -origin.y / scale, width: size.width / scale, height: size.height / scale) }
    var room: Path { Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: Self.cornerRadius, style: .continuous) }
    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale) }
    func enter(_ context: inout GraphicsContext) {
        context.translateBy(x: origin.x, y: origin.y)
        context.scaleBy(x: scale, y: scale)
    }
}

struct PaintColor {
    var r: Double, g: Double, b: Double
    init(_ hex: Int) {
        r = Double((hex >> 16) & 255) / 255; g = Double((hex >> 8) & 255) / 255; b = Double(hex & 255) / 255
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    func mix(_ other: PaintColor, _ amount: Double) -> PaintColor {
        let t = min(1, max(0, amount))
        return PaintColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
    var color: Color { Color(red: r, green: g, blue: b) }
    func color(_ opacity: Double) -> Color { color.opacity(opacity) }
}

enum DeskArt {
    static func vertical(_ top: PaintColor, _ bottom: PaintColor, from y0: CGFloat, to y1: CGFloat) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [top.color, bottom.color]), startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y1))
    }
    static func glow(_ color: PaintColor, opacity: Double, at center: CGPoint, radius: CGFloat) -> GraphicsContext.Shading {
        .radialGradient(Gradient(colors: [color.color(opacity), color.color(0)]), center: center, startRadius: 0, endRadius: radius)
    }
    static func heart(_ c: CGPoint, size s: CGFloat = 1) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + 3.5 * s))
        p.addCurve(to: CGPoint(x: c.x - 3.5 * s, y: c.y - 1 * s), control1: CGPoint(x: c.x - 2 * s, y: c.y + 2 * s), control2: CGPoint(x: c.x - 3.5 * s, y: c.y + 1 * s))
        p.addArc(center: CGPoint(x: c.x - 1.75 * s, y: c.y - 1 * s), radius: 1.75 * s, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: c.x + 1.75 * s, y: c.y - 1 * s), radius: 1.75 * s, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: c.x, y: c.y + 3.5 * s), control1: CGPoint(x: c.x + 3.5 * s, y: c.y + 1 * s), control2: CGPoint(x: c.x + 2 * s, y: c.y + 2 * s))
        return p
    }
    static func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? r : r * 0.45
            let angle = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath(); return p
    }
    /// A puffy cloud made of overlapping circles, centred on its base.
    static func cloud(_ c: CGPoint, scale s: CGFloat) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: c.x - 15 * s, y: c.y - 7 * s, width: 14 * s, height: 10 * s))
        p.addEllipse(in: CGRect(x: c.x - 8 * s, y: c.y - 13 * s, width: 15 * s, height: 15 * s))
        p.addEllipse(in: CGRect(x: c.x + 2 * s, y: c.y - 9 * s, width: 13 * s, height: 11 * s))
        p.addRoundedRect(in: CGRect(x: c.x - 15 * s, y: c.y - 4 * s, width: 30 * s, height: 6 * s), cornerSize: CGSize(width: 3 * s, height: 3 * s))
        return p
    }
    /// A yellow pencil lying from `start` along `angle`, eraser first.
    static func pencil(_ context: GraphicsContext, from start: CGPoint, angle: Angle, length: CGFloat, outline: Color) {
        var c = context
        c.translateBy(x: start.x, y: start.y); c.rotate(by: angle)
        let w: CGFloat = 3.6, h = w / 2, body = length - 9
        let eraser = Path(roundedRect: CGRect(x: 0, y: -h, width: 4, height: w), cornerRadius: 1.4)
        c.fill(eraser, with: .color(PaintColor(0xF4A0A6).color))
        c.fill(Path(CGRect(x: 3.5, y: -h, width: 2.2, height: w)), with: .color(PaintColor(0xC9C2BA).color))
        c.fill(Path(CGRect(x: 5.7, y: -h, width: body - 5.7, height: w)), with: .color(PaintColor(0xF8C948).color))
        c.fill(Path(CGRect(x: 5.7, y: -h, width: body - 5.7, height: w * 0.35)), with: .color(PaintColor(0xFFE08A).color))
        var tip = Path(); tip.move(to: CGPoint(x: body, y: -h)); tip.addLine(to: CGPoint(x: length, y: 0)); tip.addLine(to: CGPoint(x: body, y: h)); tip.closeSubpath()
        c.fill(tip, with: .color(PaintColor(0xEACDA4).color))
        var lead = Path(); lead.move(to: CGPoint(x: length - 2.6, y: -0.55)); lead.addLine(to: CGPoint(x: length, y: 0)); lead.addLine(to: CGPoint(x: length - 2.6, y: 0.55)); lead.closeSubpath()
        c.fill(lead, with: .color(PaintColor(0x4A3B30).color))
        var shape = Path(roundedRect: CGRect(x: 0, y: -h, width: body, height: w), cornerRadius: 1.4)
        shape.addPath(tip)
        c.stroke(shape, with: .color(outline), lineWidth: 0.6)
    }
}

/// The string of little lights along the wall; shared so their halos line up with the bulbs.
enum DeskGarland {
    static let start = CGPoint(x: 2, y: 6), control = CGPoint(x: 94, y: 40), end = CGPoint(x: 186, y: 6)
    static let colors = [PaintColor(0xFFD36E), PaintColor(0xF59A8B), PaintColor(0x9AD1B5), PaintColor(0x9CC3EE)]
    static func point(_ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                       y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
    }
    static var bulbs: [(center: CGPoint, color: PaintColor)] {
        (1...9).map { index in
            let anchor = point(Double(index) / 10)
            return (CGPoint(x: anchor.x, y: anchor.y + 4), colors[index % colors.count])
        }
    }
}
