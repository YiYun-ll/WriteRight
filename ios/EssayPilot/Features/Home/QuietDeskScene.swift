import SwiftUI

/// A small illustration drawn in points, so it stays crisp at every screen size.
struct QuietDeskScene: View, Animatable {
    let mood: DeskMood
    var sunsetProgress: Double = 0
    var window: DeskWindow = .quiet
    var windowMotion: Double = 0
    var teaLift: Double = 0
    var plantPulse: Double = 0
    var lampGlow: Double = 1
    typealias Motion = AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, Double>>>>
    var animatableData: Motion {
        get { .init(sunsetProgress, .init(windowMotion, .init(teaLift, .init(plantPulse, lampGlow)))) }
        set {
            sunsetProgress = newValue.first; windowMotion = newValue.second.first
            teaLift = newValue.second.second.first; plantPulse = newValue.second.second.second.first
            lampGlow = newValue.second.second.second.second
        }
    }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let space = DeskSpace(size)
            context.clip(to: space.room)
            space.enter(&context)
            draw(in: context, area: space.visible)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func draw(in context: GraphicsContext, area: CGRect) {
        let dark = colorScheme == .dark
        func paint(_ light: Int, _ night: Int) -> PaintColor { PaintColor(dark ? night : light) }
        let progress = min(1, max(0, sunsetProgress))
        let glow = min(1, max(0, lampGlow))
        let outline = dark ? PaintColor(0x140D09).color(0.6) : PaintColor(0x8A5A3A).color(0.42)
        func fill(_ path: Path, _ shading: GraphicsContext.Shading, line: Bool = true, width: CGFloat = 0.8) {
            context.fill(path, with: shading)
            if line { context.stroke(path, with: .color(outline), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)) }
        }
        func stroke(_ path: Path, _ color: Color, _ width: CGFloat) {
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        let deskTop: CGFloat = 126, deskFront: CGFloat = 140, deskBottom: CGFloat = 150

        // Wall with a soft dotted paper; it cools toward dusk when the desk rests.
        let wallTop = paint(0xFBEAD6, 0x3A302B).mix(paint(0x4A4462, 0x221E2B), progress * 0.85)
        let wallLow = paint(0xF3D7BB, 0x30271F).mix(paint(0x3F3650, 0x1C1822), progress * 0.85)
        context.fill(Path(CGRect(x: area.minX, y: area.minY, width: area.width, height: deskTop - area.minY)),
                     with: DeskArt.vertical(wallTop, wallLow, from: area.minY, to: deskTop))
        var dots = Path()
        for row in 0..<8 {
            let y = 14 + CGFloat(row) * 15
            var x = area.minX + (row.isMultiple(of: 2) ? 6 : 15)
            while x < area.maxX { dots.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)); x += 18 }
        }
        context.fill(dots, with: .color(dark ? Color.white.opacity(0.035) : Color.white.opacity(0.6 - progress * 0.45)))

        // String lights, a little framed picture, and the lamp's warm cone on the wall.
        var cord = Path(); cord.move(to: DeskGarland.start); cord.addQuadCurve(to: DeskGarland.end, control: DeskGarland.control)
        stroke(cord, outline, 0.8)
        for bulb in DeskGarland.bulbs {
            let lit = bulb.color.mix(PaintColor(0xFFFFFF), 0.35 * (1 - progress))
            context.fill(Path(CGRect(x: bulb.center.x - 1.2, y: bulb.center.y - 4.6, width: 2.4, height: 2)), with: .color(outline))
            context.fill(Path(ellipseIn: CGRect(x: bulb.center.x - 2.2, y: bulb.center.y - 3, width: 4.4, height: 6)), with: .color(lit.color))
        }
        stroke(Path { $0.move(to: CGPoint(x: 133, y: 40)); $0.addLine(to: CGPoint(x: 141, y: 32)); $0.addLine(to: CGPoint(x: 149, y: 40)) }, outline, 0.7)
        let frame = CGRect(x: 124, y: 40, width: 34, height: 28)
        fill(Path(roundedRect: frame, cornerRadius: 3), .color(paint(0xD69A6A, 0x7D553A).color))
        let mat = frame.insetBy(dx: 3, dy: 3)
        var art = context; art.clip(to: Path(roundedRect: mat, cornerRadius: 1.5))
        art.fill(Path(mat), with: DeskArt.vertical(paint(0xCFE7F2, 0x50687A), paint(0xFFF1DE, 0x8A7A68), from: mat.minY, to: mat.maxY))
        art.fill(Path(ellipseIn: CGRect(x: 143, y: 47, width: 6, height: 6)), with: .color(PaintColor(0xF4A26E).color))
        var hill = Path(); hill.move(to: CGPoint(x: mat.minX, y: mat.maxY)); hill.addQuadCurve(to: CGPoint(x: mat.maxX, y: mat.maxY - 2), control: CGPoint(x: 136, y: 46))
        art.fill(hill, with: .color(paint(0x8CC47A, 0x5E7F52).color))

        // An arched window with wooden frame, curtains, and the sky outside.
        let center = CGPoint(x: 260, y: 66)
        func arch(_ radius: CGFloat, bottom: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: center.x - radius, y: bottom)); p.addLine(to: CGPoint(x: center.x - radius, y: center.y))
            p.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: CGPoint(x: center.x + radius, y: bottom)); p.closeSubpath(); return p
        }
        let wood = paint(0xD39467, 0x80583C), woodDeep = paint(0xB97A50, 0x6A4630)
        fill(arch(57, bottom: 118), DeskArt.vertical(wood, woodDeep, from: 9, to: 118))
        let glass = arch(51, bottom: 116)
        drawSky(in: context, clip: glass, dark: dark, progress: progress)
        context.fill(Path(CGRect(x: 258.8, y: 16, width: 2.4, height: 100)), with: .color(wood.color))
        context.fill(Path(CGRect(x: 209, y: 70, width: 102, height: 2.4)), with: .color(wood.color))
        var glare = context; glare.clip(to: glass)
        var streak = Path(); streak.move(to: CGPoint(x: 222, y: 60)); streak.addLine(to: CGPoint(x: 240, y: 30))
        streak.addLine(to: CGPoint(x: 246, y: 30)); streak.addLine(to: CGPoint(x: 228, y: 60)); streak.closeSubpath()
        glare.fill(streak, with: .color(Color.white.opacity(0.12 * (1 - progress))))
        context.stroke(glass, with: .color(outline), lineWidth: 0.7)
        fill(Path(roundedRect: CGRect(x: 194, y: 114, width: 132, height: 7), cornerRadius: 2.5), DeskArt.vertical(wood.mix(PaintColor(0xFFFFFF), 0.15), wood, from: 114, to: 121))

        let sway = sin(windowMotion * .pi * 2) * (window == .breeze ? 5 : 2)
        let cloth = paint(0xF4B7A2, 0x9C5E54).mix(paint(0x9A7E9E, 0x5A3E48), progress * 0.6)
        let clothDeep = paint(0xE69A84, 0x834A42).mix(paint(0x7F6585, 0x48303A), progress * 0.6)
        for mirrored in [false, true] {
            let drift = mirrored ? -sway : sway
            var curtain = Path()
            curtain.move(to: CGPoint(x: 185, y: 9)); curtain.addLine(to: CGPoint(x: 215, y: 9))
            curtain.addCurve(to: CGPoint(x: 205, y: 70), control1: CGPoint(x: 215, y: 38), control2: CGPoint(x: 204, y: 56))
            curtain.addCurve(to: CGPoint(x: 212 + drift, y: 122), control1: CGPoint(x: 206, y: 86), control2: CGPoint(x: 212 + drift, y: 106))
            curtain.addLine(to: CGPoint(x: 185 + drift * 0.4, y: 122)); curtain.closeSubpath()
            var fold = Path()
            fold.move(to: CGPoint(x: 194, y: 12)); fold.addQuadCurve(to: CGPoint(x: 195, y: 68), control: CGPoint(x: 197, y: 40))
            fold.move(to: CGPoint(x: 196, y: 74)); fold.addQuadCurve(to: CGPoint(x: 197 + drift * 0.7, y: 120), control: CGPoint(x: 193, y: 98))
            let tie = Path(roundedRect: CGRect(x: 196, y: 66, width: 13, height: 6), cornerRadius: 3)
            let flip = mirrored ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 520, ty: 0) : .identity
            fill(curtain.applying(flip), DeskArt.vertical(cloth, clothDeep, from: 9, to: 122))
            stroke(fold.applying(flip), clothDeep.color(0.9), 1.1)
            fill(tie.applying(flip), .color(clothDeep.mix(PaintColor(0x8A4A3A), 0.3).color))
        }
        fill(Path(roundedRect: CGRect(x: 181, y: 5.5, width: 158, height: 3.2), cornerRadius: 1.6), .color(woodDeep.color))
        for x in [181.0, 339.0] { fill(Path(ellipseIn: CGRect(x: x - 3.2, y: 3.9, width: 6.4, height: 6.4)), .color(wood.color)) }

        // The lamp's light falls across the desk before anything sits on it.
        let warm = PaintColor(0xFFD98A)
        if glow > 0 {
            var cone = Path(); cone.move(to: CGPoint(x: 46, y: 90)); cone.addLine(to: CGPoint(x: 80, y: 90))
            cone.addLine(to: CGPoint(x: 134, y: 134)); cone.addLine(to: CGPoint(x: 10, y: 134)); cone.closeSubpath()
            context.fill(cone, with: .linearGradient(Gradient(colors: [warm.color(0.22 * glow), warm.color(0.04 * glow)]),
                                                     startPoint: CGPoint(x: 0, y: 90), endPoint: CGPoint(x: 0, y: 134)))
        }

        // A wooden desk that runs edge to edge, with a little grain.
        let top = paint(0xE7B487, 0x8E6446).mix(paint(0x8C6E78, 0x4A3A36), progress * 0.5)
        let face = paint(0xC98A5C, 0x6F4B33).mix(paint(0x6C5260, 0x392A27), progress * 0.5)
        context.fill(Path(CGRect(x: area.minX, y: deskTop, width: area.width, height: deskFront - deskTop)),
                     with: DeskArt.vertical(top.mix(PaintColor(0xFFFFFF), 0.12), top, from: deskTop, to: deskFront))
        context.fill(Path(CGRect(x: area.minX, y: deskFront, width: area.width, height: deskBottom - deskFront)), with: .color(face.color))
        context.fill(Path(CGRect(x: area.minX, y: deskBottom, width: area.width, height: area.maxY - deskBottom)),
                     with: .color(wallLow.mix(PaintColor(0x000000), dark ? 0.25 : 0.12).color))
        stroke(Path { $0.move(to: CGPoint(x: area.minX, y: deskTop + 0.6)); $0.addLine(to: CGPoint(x: area.maxX, y: deskTop + 0.6)) }, Color.white.opacity(dark ? 0.08 : 0.4), 1)
        stroke(Path { $0.move(to: CGPoint(x: area.minX, y: deskFront)); $0.addLine(to: CGPoint(x: area.maxX, y: deskFront)) }, outline, 0.8)
        let grain = face.mix(PaintColor(0x000000), 0.15).color(0.5)
        for (x, y, length) in [(12.0, 132.0, 46.0), (150, 129.5, 38), (232, 134, 44), (320, 130, 30)] {
            var line = Path(); line.move(to: CGPoint(x: x, y: y))
            line.addQuadCurve(to: CGPoint(x: x + length, y: y), control: CGPoint(x: x + length / 2, y: y - 1.6))
            stroke(line, top.mix(PaintColor(0x000000), 0.12).color(0.6), 0.6)
        }
        for (x, length) in [(30.0, 60.0), (170, 50), (290, 44)] {
            var line = Path(); line.move(to: CGPoint(x: x, y: 145))
            line.addQuadCurve(to: CGPoint(x: x + length, y: 145), control: CGPoint(x: x + length / 2, y: 143))
            stroke(line, grain, 0.6)
        }
        if glow > 0 {
            context.fill(Path(ellipseIn: CGRect(x: 14, y: 124, width: 122, height: 16)), with: .color(warm.color(0.22 * glow)))
        }
        func shadow(_ rect: CGRect) { context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(dark ? 0.28 : 0.1))) }

        // Two stacked books, the lamp, and a mug of tea.
        shadow(CGRect(x: 6, y: 131, width: 36, height: 5))
        let pages = paint(0xFFF8EC, 0xD9CDBB)
        fill(Path(roundedRect: CGRect(x: 7, y: 124, width: 32, height: 9.5), cornerRadius: 2), .color(paint(0x8DB596, 0x56775D).color))
        context.fill(Path(CGRect(x: 10, y: 126, width: 28, height: 2)), with: .color(pages.color))
        fill(Path(roundedRect: CGRect(x: 10, y: 116, width: 27, height: 8.5), cornerRadius: 2), .color(paint(0xEE8C76, 0x9C5546).color))
        context.fill(Path(CGRect(x: 13, y: 118, width: 23, height: 1.8)), with: .color(pages.color))

        let metal = paint(0x7B6556, 0x5A4A40)
        shadow(CGRect(x: 36, y: 131, width: 34, height: 5))
        fill(Path(ellipseIn: CGRect(x: 39, y: 127.5, width: 27, height: 7.5)), DeskArt.vertical(metal.mix(PaintColor(0xFFFFFF), 0.25), metal, from: 127, to: 135))
        var arm = Path(); arm.move(to: CGPoint(x: 52.5, y: 130)); arm.addLine(to: CGPoint(x: 46, y: 104)); arm.addLine(to: CGPoint(x: 61, y: 70))
        stroke(arm, outline, 3.6); stroke(arm, metal.color, 2.4)
        fill(Path(ellipseIn: CGRect(x: 43.5, y: 101.5, width: 5, height: 5)), .color(metal.color))
        var shade = Path()
        shade.move(to: CGPoint(x: 40, y: 89)); shade.addCurve(to: CGPoint(x: 62, y: 62), control1: CGPoint(x: 40, y: 73), control2: CGPoint(x: 49, y: 62))
        shade.addCurve(to: CGPoint(x: 84, y: 89), control1: CGPoint(x: 75, y: 62), control2: CGPoint(x: 84, y: 73))
        shade.addQuadCurve(to: CGPoint(x: 40, y: 89), control: CGPoint(x: 62, y: 94)); shade.closeSubpath()
        let bulb = paint(0xD9CFC0, 0x6E665C).mix(PaintColor(0xFFF4C9), glow)
        fill(Path(ellipseIn: CGRect(x: 53, y: 85.5, width: 18, height: 8)), .color(bulb.color))
        fill(shade, DeskArt.vertical(paint(0xF8D37E, 0xC9A055), paint(0xE8A64C, 0xA2763A), from: 62, to: 92))
        stroke(Path { $0.move(to: CGPoint(x: 50, y: 70)); $0.addQuadCurve(to: CGPoint(x: 45, y: 82), control: CGPoint(x: 45.5, y: 74)) }, Color.white.opacity(0.45), 1.6)
        fill(Path(ellipseIn: CGRect(x: 59.5, y: 57.5, width: 5, height: 5)), .color(metal.color))

        let mug = paint(0xFFF7EC, 0xE3D6C4)
        shadow(CGRect(x: 82, y: 131, width: 26, height: 5))
        var handle = Path(); handle.addArc(center: CGPoint(x: 104, y: 124), radius: 4.8, startAngle: .degrees(-70), endAngle: .degrees(70), clockwise: false)
        stroke(handle, outline, 4.4); stroke(handle, mug.color, 2.8)
        fill(Path(roundedRect: CGRect(x: 84, y: 114, width: 20, height: 20), cornerRadius: 6), DeskArt.vertical(mug, mug.mix(PaintColor(0xE9D8C2), 0.6), from: 114, to: 134))
        context.fill(Path(ellipseIn: CGRect(x: 85.6, y: 113.2, width: 16.8, height: 4)), with: .color(paint(0xB97A4A, 0x8A5A38).color))
        context.fill(DeskArt.heart(CGPoint(x: 94, y: 124), size: 1.15), with: .color(PaintColor(0xEE8C76).color))
        for index in 0..<3 {
            let phase = sin(teaLift * .pi + Double(index) * 0.45)
            let x = 89.0 + Double(index) * 5 + phase * 2
            let y = 108.0 - abs(phase) * 6
            var steam = Path(); steam.move(to: CGPoint(x: x, y: y))
            steam.addCurve(to: CGPoint(x: x + 1, y: y - 18), control1: CGPoint(x: x + 7, y: y - 6), control2: CGPoint(x: x - 6, y: y - 11))
            stroke(steam, (dark ? Color.white : PaintColor(0xB9967A).color).opacity(index == 1 ? 0.5 : 0.28), 1.1)
        }

        // An open notebook with a ribbon and a pencil.
        shadow(CGRect(x: 108, y: 131.5, width: 90, height: 7))
        let paper = paint(0xFFFDF7, 0xE8DDCB)
        for side in [-1.0, 1] {
            var page = Path()
            page.move(to: CGPoint(x: 152, y: 121)); page.addQuadCurve(to: CGPoint(x: 152 + side * 40, y: 118), control: CGPoint(x: 152 + side * 20, y: 113))
            page.addLine(to: CGPoint(x: 152 + side * 42, y: 135)); page.addQuadCurve(to: CGPoint(x: 152, y: 137.5), control: CGPoint(x: 152 + side * 20, y: 131))
            page.closeSubpath()
            fill(page, DeskArt.vertical(paper, paper.mix(PaintColor(0xEADCC8), 0.5), from: 114, to: 137))
            for row in 0..<3 {
                let y = 121.5 + Double(row) * 4.2
                stroke(Path { $0.move(to: CGPoint(x: 152 + side * 8, y: y + 1)); $0.addQuadCurve(to: CGPoint(x: 152 + side * 33, y: y - 0.5), control: CGPoint(x: 152 + side * 20, y: y - 2.2)) },
                       paint(0xE3CDB4, 0xA8977F).color, 0.7)
            }
        }
        stroke(Path { $0.move(to: CGPoint(x: 152, y: 121)); $0.addLine(to: CGPoint(x: 152, y: 137.5)) }, outline, 0.7)
        var ribbon = Path(); ribbon.move(to: CGPoint(x: 150.5, y: 136)); ribbon.addLine(to: CGPoint(x: 150, y: 143.5))
        ribbon.addLine(to: CGPoint(x: 152, y: 141.8)); ribbon.addLine(to: CGPoint(x: 154, y: 143.5)); ribbon.addLine(to: CGPoint(x: 153.5, y: 136)); ribbon.closeSubpath()
        context.fill(ribbon, with: .color(PaintColor(0xEE8C76).color))
        context.fill(DeskArt.heart(CGPoint(x: 176, y: 129.5), size: 0.8), with: .color(PaintColor(0xF4A0A6).color(0.8)))
        DeskArt.pencil(context, from: CGPoint(x: 158, y: 134), angle: .degrees(-24), length: 30, outline: outline)

        // A terracotta pot with a small face and leaves that stretch when tended.
        let leafSway = sin(plantPulse * .pi) * 0.28
        let stemBase = CGPoint(x: 301, y: 112)
        let leaves: [(CGPoint, Double)] = [(CGPoint(x: 289, y: 105), -1.15), (CGPoint(x: 313, y: 104), 1.15), (CGPoint(x: 291, y: 92), -0.7),
                                            (CGPoint(x: 311, y: 90), 0.7), (CGPoint(x: 297, y: 80), -0.3), (CGPoint(x: 305, y: 79), 0.3)]
        let leafLight = paint(0x93CB80, 0x6E9A5E).mix(paint(0x4F6C67, 0x3B5048), progress * 0.5)
        let leafDeep = paint(0x6FAE62, 0x557F4C).mix(paint(0x3F5A57, 0x2E4239), progress * 0.5)
        for (index, leaf) in leaves.enumerated() {
            let tip = CGPoint(x: leaf.0.x + CGFloat(leafSway * 6 * (index.isMultiple(of: 2) ? -1 : 1)), y: leaf.0.y)
            stroke(Path { $0.move(to: stemBase); $0.addQuadCurve(to: tip, control: CGPoint(x: stemBase.x, y: (stemBase.y + tip.y) / 2)) }, leafDeep.color, 1.2)
            var leafContext = context
            leafContext.translateBy(x: tip.x, y: tip.y)
            leafContext.rotate(by: .radians(leaf.1 - .pi / 2 + leafSway * (index.isMultiple(of: 2) ? -1 : 1)))
            let blade = Path(ellipseIn: CGRect(x: -2, y: -4.5, width: 15, height: 9))
            leafContext.fill(blade, with: .color((index.isMultiple(of: 2) ? leafLight : leafDeep).color))
            leafContext.stroke(blade, with: .color(outline), lineWidth: 0.6)
            leafContext.stroke(Path { $0.move(to: CGPoint(x: 0, y: 0)); $0.addLine(to: CGPoint(x: 11, y: 0)) }, with: .color(Color.white.opacity(0.35)), lineWidth: 0.6)
        }
        if mood == .ready {
            let bloom = CGPoint(x: 301.5, y: 70)
            stroke(Path { $0.move(to: stemBase); $0.addQuadCurve(to: bloom, control: CGPoint(x: 302, y: 92)) }, leafDeep.color, 1.2)
            for i in 0..<5 {
                let angle = Double(i) * 2 * .pi / 5
                context.fill(Path(ellipseIn: CGRect(x: bloom.x + cos(angle) * 3 - 2.4, y: bloom.y + sin(angle) * 3 - 2.4, width: 4.8, height: 4.8)), with: .color(PaintColor(0xF6A6B2).color))
            }
            context.fill(Path(ellipseIn: CGRect(x: bloom.x - 1.8, y: bloom.y - 1.8, width: 3.6, height: 3.6)), with: .color(PaintColor(0xFFD36E).color))
        }
        shadow(CGRect(x: 285, y: 132, width: 32, height: 5))
        let clay = paint(0xE58A66, 0xA35C43), clayDeep = paint(0xCF7050, 0x8A4B37)
        var pot = Path(); pot.move(to: CGPoint(x: 288, y: 116)); pot.addLine(to: CGPoint(x: 314, y: 116))
        pot.addLine(to: CGPoint(x: 310, y: 135)); pot.addQuadCurve(to: CGPoint(x: 292, y: 135), control: CGPoint(x: 301, y: 136.5)); pot.closeSubpath()
        fill(pot, DeskArt.vertical(clay, clayDeep, from: 116, to: 136))
        fill(Path(roundedRect: CGRect(x: 285.5, y: 111, width: 31, height: 6.5), cornerRadius: 2.5), .color(clay.mix(PaintColor(0xFFFFFF), 0.15).color))
        let potFace = PaintColor(0x5A3524).color(0.75)
        for x in [297.0, 305] { context.fill(Path(ellipseIn: CGRect(x: x - 1, y: 123, width: 2, height: 2.2)), with: .color(potFace)) }
        stroke(Path { $0.addArc(center: CGPoint(x: 301, y: 126.2), radius: 1.6, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false) }, potFace, 0.8)
        for x in [294.0, 308] { context.fill(Path(ellipseIn: CGRect(x: x - 2, y: 126, width: 4, height: 2.2)), with: .color(PaintColor(0xF59A8B).color(0.6))) }
        let leafGlow = abs(sin(plantPulse * .pi))
        if leafGlow > 0.01 {
            context.fill(Path(ellipseIn: CGRect(x: 276, y: 66, width: 50, height: 48)), with: DeskArt.glow(PaintColor(0xC8F0A8), opacity: 0.35 * leafGlow, at: CGPoint(x: 301, y: 90), radius: 26))
            for point in [CGPoint(x: 282, y: 74), CGPoint(x: 322, y: 84), CGPoint(x: 300, y: 64)] {
                context.fill(DeskArt.star(point, 3), with: .color(PaintColor(0xFFD36E).color(leafGlow)))
            }
        }
    }

    private func drawSky(in parent: GraphicsContext, clip: Path, dark: Bool, progress: Double) {
        var sky = parent; sky.clip(to: clip)
        let duskWeight = min(1, progress * 2), nightWeight = max(0, progress * 2 - 1)
        var high = PaintColor(dark ? 0x4E6A86 : 0x9FD0EE).mix(PaintColor(0x8E6FA6), duskWeight).mix(PaintColor(0x141B38), nightWeight)
        var low = PaintColor(dark ? 0x8C7A6E : 0xFDE6C8).mix(PaintColor(0xF6A26E), duskWeight).mix(PaintColor(0x2C2F57), nightWeight)
        if window == .rain {
            high = high.mix(PaintColor(0x9AA6B6), 0.55 * (1 - progress)); low = low.mix(PaintColor(0xC9CFD6), 0.5 * (1 - progress))
        }
        let bounds = clip.boundingRect
        sky.fill(Path(bounds), with: DeskArt.vertical(high, low, from: bounds.minY, to: bounds.maxY))
        // The sun sets behind the hills; the moon and stars come out after.
        if progress < 0.98 {
            let sun = CGPoint(x: 286 - 16 * progress, y: 38 + 62 * progress)
            let strength = (window == .rain ? 0.3 : 1) * (1 - progress * 0.3)
            sky.fill(Path(ellipseIn: CGRect(x: sun.x - 22, y: sun.y - 22, width: 44, height: 44)), with: DeskArt.glow(PaintColor(0xFFE2A0), opacity: 0.6 * strength, at: sun, radius: 22))
            sky.fill(Path(ellipseIn: CGRect(x: sun.x - 9, y: sun.y - 9, width: 18, height: 18)), with: .color(PaintColor(0xFFD27A).mix(PaintColor(0xFF9A5C), progress).color(strength)))
        }
        let moonlight = max(0, (progress - 0.6) / 0.4)
        if moonlight > 0 {
            var night = sky; night.opacity = moonlight
            let moon = CGPoint(x: 283, y: 33)
            night.fill(Path(ellipseIn: CGRect(x: moon.x - 16, y: moon.y - 16, width: 32, height: 32)), with: DeskArt.glow(PaintColor(0xFFF2C6), opacity: 0.4, at: moon, radius: 16))
            night.fill(Path(ellipseIn: CGRect(x: moon.x - 7.5, y: moon.y - 7.5, width: 15, height: 15)), with: .color(PaintColor(0xFFF2C6).color))
            night.fill(Path(ellipseIn: CGRect(x: moon.x - 2.5, y: moon.y - 10.5, width: 14, height: 14)), with: .color(high.color))
            for (point, size) in [(CGPoint(x: 232, y: 26), 2.6), (CGPoint(x: 252, y: 54), 1.8), (CGPoint(x: 222, y: 62), 2), (CGPoint(x: 300, y: 58), 1.6), (CGPoint(x: 264, y: 22), 1.5)] {
                night.fill(DeskArt.star(point, size), with: .color(Color.white.opacity(0.9)))
            }
        }
        let backHill = PaintColor(dark ? 0x5E7558 : 0xB9D8A8).mix(PaintColor(0x2D3550), progress)
        let frontHill = PaintColor(dark ? 0x4F6849 : 0x9CC48F).mix(PaintColor(0x252B45), progress)
        var far = Path(); far.move(to: CGPoint(x: 205, y: 102)); far.addQuadCurve(to: CGPoint(x: 290, y: 100), control: CGPoint(x: 245, y: 82))
        far.addQuadCurve(to: CGPoint(x: 316, y: 96), control: CGPoint(x: 305, y: 90)); far.addLine(to: CGPoint(x: 316, y: 118)); far.addLine(to: CGPoint(x: 205, y: 118)); far.closeSubpath()
        sky.fill(far, with: .color(backHill.color))
        var near = Path(); near.move(to: CGPoint(x: 205, y: 110)); near.addQuadCurve(to: CGPoint(x: 316, y: 106), control: CGPoint(x: 280, y: 92))
        near.addLine(to: CGPoint(x: 316, y: 118)); near.addLine(to: CGPoint(x: 205, y: 118)); near.closeSubpath()
        sky.fill(near, with: .color(frontHill.color))

        // A chosen atmosphere, never a claim about real weather. Motion ends with the tap animation.
        let drift = CGFloat(sin(windowMotion * .pi * 2) * (window == .breeze ? 8 : 3))
        let rain = window == .rain
        let puff = PaintColor(0xFFFFFF).mix(PaintColor(rain ? 0xC6CCD6 : 0xE7E2F0), rain ? 0.7 : 0).mix(PaintColor(0x5A5F80), progress * 0.8)
        let haze = rain ? 1 : 1 - progress * 0.55
        sky.fill(DeskArt.cloud(CGPoint(x: 236 + drift, y: 44), scale: rain ? 1.25 : 1), with: .color(puff.color(0.92 * haze)))
        sky.fill(DeskArt.cloud(CGPoint(x: 294 + drift * 0.6, y: 66), scale: 0.7), with: .color(puff.color(0.85 * haze)))
        if mood == .unsettled {
            sky.fill(DeskArt.cloud(CGPoint(x: 268 - drift * 0.5, y: 50), scale: 1.1), with: .color(PaintColor(0xD8D2DA).mix(PaintColor(0x4A4E6A), progress).color(0.9)))
        }
        if rain {
            let drop = (progress > 0.5 ? Color.white : PaintColor(0x7E8DA3).color).opacity(0.55)
            for index in 0..<14 {
                let x = 215.0 + Double(index % 6) * 17 + Double(index / 6) * 6
                let y = 30 + (Double(index * 19) + windowMotion * 92).truncatingRemainder(dividingBy: 80)
                sky.stroke(Path { $0.move(to: CGPoint(x: x, y: y)); $0.addLine(to: CGPoint(x: x - 2.5, y: y + 8)) }, with: .color(drop), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
            for point in [CGPoint(x: 226, y: 86), CGPoint(x: 284, y: 96), CGPoint(x: 300, y: 40)] {
                sky.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 2.6, height: 3.4)), with: .color(Color.white.opacity(0.5)))
            }
        } else if window == .breeze {
            for index in 0..<3 {
                let y = 52.0 + Double(index) * 16
                let x = 214 + drift + CGFloat(index) * 9
                var curl = Path(); curl.move(to: CGPoint(x: x, y: y))
                curl.addCurve(to: CGPoint(x: x + 38, y: y - 3), control1: CGPoint(x: x + 16, y: y + 5), control2: CGPoint(x: x + 30, y: y - 12))
                curl.addArc(center: CGPoint(x: x + 38, y: y - 6.5), radius: 3.5, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
                sky.stroke(curl, with: .color(Color.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
    }
}

/// Dusk, night and lamp light drawn over the whole desk, the cat included, so everything shares one light.
struct DeskLightLayer: View, Animatable {
    var sunsetProgress: Double
    var lampGlow: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { .init(sunsetProgress, lampGlow) }
        set { sunsetProgress = newValue.first; lampGlow = newValue.second }
    }
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double { min(1, max(0, sunsetProgress)) }
    private var glow: Double { min(1, max(0, lampGlow)) }

    var body: some View {
        ZStack {
            // Multiplying keeps colours rich as the room darkens instead of greying them out.
            Canvas { context, size in
                let space = DeskSpace(size)
                context.clip(to: space.room)
                space.enter(&context)
                guard progress > 0 else { return }
                let dusk = PaintColor(0xF7C2A0).mix(PaintColor(colorScheme == .dark ? 0x5A5A8A : 0x6D6AA6), min(1, progress * 1.6))
                let depth = progress * (1 - 0.35 * glow)
                context.fill(Path(space.visible), with: .color(PaintColor(0xFFFFFF).mix(dusk, depth).color))
            }
            .blendMode(.multiply)
            Canvas { context, size in
                let space = DeskSpace(size)
                context.clip(to: space.room)
                space.enter(&context)
                if glow > 0 {
                    let reach = 110 + 50 * progress
                    let lamp = CGPoint(x: 62, y: 92)
                    context.fill(Path(ellipseIn: CGRect(x: lamp.x - reach, y: lamp.y - reach, width: reach * 2, height: reach * 2)),
                                 with: DeskArt.glow(PaintColor(0xFFB566), opacity: glow * (0.08 + 0.32 * progress), at: lamp, radius: reach))
                }
                for bulb in DeskGarland.bulbs {
                    let c = bulb.center
                    context.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)),
                                 with: DeskArt.glow(bulb.color, opacity: 0.1 + 0.6 * progress, at: c, radius: 9))
                }
            }
            .blendMode(.screen)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

enum DeskMood: String, CaseIterable, Identifiable {
    case ready, tired, unsettled
    var id: String { rawValue }
    var title: String {
        switch self { case .ready: "想写一点"; case .tired: "有点累了"; case .unsettled: "心有点乱" }
    }
    var message: String {
        switch self {
        case .ready: "那就从最想说的一句话开始。不必先想好整篇，写着写着，路会慢慢清楚。"
        case .tired: "今天可以把目标放小，也可以暂时收笔。去喝口温水，松一松肩膀；休息不需要用完成多少来交换。"
        case .unsettled: "先不用急着把一切理顺。看看窗外，感受脚下的地面。等愿意了，再只想眼前这一句。"
        }
    }
    var sceneCaption: String {
        switch self {
        case .ready: "留一张纸，给慢慢长出的想法。"
        case .tired: "灯留着，歇一会儿也没关系。"
        case .unsettled: "云会经过，先在这里坐一会儿。"
        }
    }
}
