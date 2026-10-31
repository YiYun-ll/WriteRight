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
            let sx = size.width / 360
            let sy = size.height / 156
            context.scaleBy(x: sx, y: sy)
            let line = WriteRightTheme.secondary.opacity(0.65)
            let warm = WriteRightTheme.accent
            let glow = min(1, max(0, lampGlow))
            func stroke(_ points: [CGPoint], color: Color = line, width: CGFloat = 1.1) {
                guard let first = points.first else { return }
                var path = Path(); path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func ellipse(_ rect: CGRect, color: Color) { context.fill(Path(ellipseIn: rect), with: .color(color)) }
            // Soft light on the wall and an arched window.
            ellipse(CGRect(x: 158, y: 2, width: 162, height: 138), color: warm.opacity(0.015 + 0.08 * glow))
            let progress = min(1, max(0, sunsetProgress))
            let windowRect = CGRect(x: 205, y: 9, width: 112, height: 112)
            let windowShape = Path(roundedRect: windowRect, cornerRadius: 49)
            let day: (Double, Double, Double) = colorScheme == .dark ? (0.31, 0.38, 0.42) : (0.93, 0.88, 0.76)
            let dusk = (0.83, 0.43, 0.34)
            let night = (0.12, 0.17, 0.29)
            func blend(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> (Double, Double, Double) {
                (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
            }
            var rgb = progress < 0.5 ? blend(day, dusk, progress * 2) : blend(dusk, night, (progress - 0.5) * 2)
            if window == .rain { rgb = blend(rgb, (0.68, 0.75, 0.77), 0.18 * (1 - progress)) }
            let skyColor = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
            let horizon = Color(red: min(1, rgb.0 + 0.08 * (1 - progress)), green: rgb.1, blue: rgb.2)
            var sky = context; sky.clip(to: windowShape)
            sky.fill(windowShape, with: .linearGradient(Gradient(colors: [skyColor, horizon]), startPoint: CGPoint(x: 261, y: 9), endPoint: CGPoint(x: 261, y: 121)))
            sky.fill(Path(ellipseIn: CGRect(x: 275 - 12 * progress, y: 28 + 110 * progress, width: 22, height: 22)), with: .color(Color(red: 0.98, green: 0.66, blue: 0.36).opacity((0.8 - progress * 0.35) * (window == .rain ? 0.2 : 1))))
            let moonlight = max(0, (progress - 0.65) / 0.35)
            if moonlight > 0 {
                var moon = sky; moon.opacity = moonlight
                moon.fill(Path(ellipseIn: CGRect(x: 277, y: 29, width: 20, height: 20)), with: .color(Color(red: 0.98, green: 0.92, blue: 0.76)))
                moon.fill(Path(ellipseIn: CGRect(x: 284, y: 25, width: 19, height: 19)), with: .color(skyColor))
                for point in [CGPoint(x: 223, y: 33), CGPoint(x: 242, y: 50), CGPoint(x: 301, y: 65), CGPoint(x: 237, y: 92)] {
                    moon.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 1.7, height: 1.7)), with: .color(Color.white.opacity(0.85)))
                }
            }
            // A chosen atmosphere, never a claim about real weather. Motion ends with the tap animation.
            if window == .rain {
                let rainColor = progress > 0.5 ? Color.white.opacity(0.35) : WriteRightTheme.secondary.opacity(0.4)
                for index in 0..<12 {
                    let x = 219.0 + Double(index % 5) * 20
                    let y = 17 + (Double(index * 19) + windowMotion * 92).truncatingRemainder(dividingBy: 96)
                    var drop = Path(); drop.move(to: CGPoint(x: x, y: y)); drop.addLine(to: CGPoint(x: x - 3, y: y + 9))
                    sky.stroke(drop, with: .color(rainColor), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
                sky.fill(Path(ellipseIn: CGRect(x: 215, y: 25, width: 58, height: 14)), with: .color(WriteRightTheme.surface.opacity(0.4)))
            } else if window == .breeze {
                let shift = sin(windowMotion * .pi * 2) * 7
                for index in 0..<3 {
                    let y = 45.0 + Double(index) * 19
                    var breeze = Path(); breeze.move(to: CGPoint(x: 214 + shift, y: y))
                    breeze.addCurve(to: CGPoint(x: 253 + shift, y: y - 3), control1: CGPoint(x: 231 + shift, y: y + 5), control2: CGPoint(x: 247 + shift, y: y - 12))
                    sky.stroke(breeze, with: .color((progress > 0.5 ? Color.white : WriteRightTheme.secondary).opacity(0.35)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                }
            }
            context.stroke(windowShape, with: .color(line), lineWidth: 1.1)
            stroke([CGPoint(x: 261, y: 10), CGPoint(x: 261, y: 120)])
            stroke([CGPoint(x: 205, y: 72), CGPoint(x: 317, y: 72)])
            if mood == .unsettled {
                var cloud = Path()
                cloud.move(to: CGPoint(x: 216, y: 51))
                cloud.addCurve(to: CGPoint(x: 253, y: 51), control1: CGPoint(x: 216, y: 26), control2: CGPoint(x: 251, y: 29))
                cloud.addQuadCurve(to: CGPoint(x: 216, y: 51), control: CGPoint(x: 272, y: 66))
                context.fill(cloud, with: .color(WriteRightTheme.surface.opacity(0.85 * (1 - progress))))
            }
            // A small reading lamp responds to the desk's light switch.
            stroke([CGPoint(x: 71, y: 111), CGPoint(x: 71, y: 83), CGPoint(x: 81, y: 69)])
            var shade = Path(); shade.move(to: CGPoint(x: 72, y: 68)); shade.addLine(to: CGPoint(x: 91, y: 68))
            shade.addLine(to: CGPoint(x: 101, y: 82)); shade.addLine(to: CGPoint(x: 62, y: 82)); shade.closeSubpath()
            context.fill(shade, with: .color(WriteRightTheme.soft))
            context.fill(shade, with: .color(warm.opacity(0.25 * glow)))
            context.stroke(shade, with: .color(line), lineWidth: 1)
            if glow > 0 {
                var pool = Path(); pool.move(to: CGPoint(x: 64, y: 84)); pool.addLine(to: CGPoint(x: 96, y: 84))
                pool.addLine(to: CGPoint(x: 123, y: 133)); pool.addLine(to: CGPoint(x: 46, y: 133)); pool.closeSubpath()
                context.fill(pool, with: .color(warm.opacity(0.06 * glow)))
            }
            // The desk, an open notebook, and a pencil.
            stroke([CGPoint(x: 26, y: 137), CGPoint(x: 335, y: 137)])
            var book = Path()
            book.move(to: CGPoint(x: 79, y: 112)); book.addQuadCurve(to: CGPoint(x: 139, y: 117), control: CGPoint(x: 112, y: 101))
            book.addQuadCurve(to: CGPoint(x: 193, y: 111), control: CGPoint(x: 166, y: 103))
            book.addLine(to: CGPoint(x: 203, y: 133)); book.addQuadCurve(to: CGPoint(x: 140, y: 138), control: CGPoint(x: 169, y: 126))
            book.addQuadCurve(to: CGPoint(x: 70, y: 133), control: CGPoint(x: 104, y: 126)); book.closeSubpath()
            context.fill(book, with: .color(WriteRightTheme.surface))
            context.stroke(book, with: .color(line), lineWidth: 1.1)
            stroke([CGPoint(x: 139, y: 117), CGPoint(x: 140, y: 136)])
            for i in 0..<3 {
                let y = CGFloat(115 + i * 5)
                stroke([CGPoint(x: 88, y: y), CGPoint(x: 119, y: y + 2)], color: line.opacity(0.4), width: 0.7)
            }
            stroke([CGPoint(x: 157, y: 130), CGPoint(x: 185, y: 119)], color: warm, width: 2.5)
            // A cup, steam, and a plant growing beside the window.
            let cup = Path(roundedRect: CGRect(x: 35, y: 111, width: 25, height: 22), cornerRadius: 5)
            context.fill(cup, with: .color(warm.opacity(0.12))); context.stroke(cup, with: .color(line), lineWidth: 1)
            context.stroke(Path(ellipseIn: CGRect(x: 57, y: 115, width: 11, height: 11)), with: .color(line), lineWidth: 1)
            for index in 0..<3 {
                let phase = sin(teaLift * .pi + Double(index) * 0.45)
                let x = 40.0 + Double(index) * 7 + phase * 2
                let y = 104.0 - abs(phase) * 6
                var steam = Path(); steam.move(to: CGPoint(x: x, y: y))
                steam.addCurve(to: CGPoint(x: x + 1, y: y - 20), control1: CGPoint(x: x + 9, y: y - 7), control2: CGPoint(x: x - 8, y: y - 12))
                context.stroke(steam, with: .color(line.opacity(index == 1 ? 0.5 : 0.24)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
            stroke([CGPoint(x: 292, y: 119), CGPoint(x: 290, y: 87), CGPoint(x: 283, y: 78)])
            for (x, y, tilt) in [(279.0, 81.0, -0.5), (287.0, 93.0, 0.5), (275.0, 100.0, -0.4)] {
                var leafContext = context
                leafContext.translateBy(x: x + 6, y: y + 3)
                leafContext.rotate(by: .radians(tilt + sin(plantPulse * .pi) * 0.28))
                leafContext.fill(Path(ellipseIn: CGRect(x: -8, y: -4, width: 16, height: 8)), with: .color(WriteRightTheme.sage.opacity(0.75)))
            }
            var pot = Path(); pot.move(to: CGPoint(x: 277, y: 116)); pot.addLine(to: CGPoint(x: 302, y: 116))
            pot.addLine(to: CGPoint(x: 298, y: 136)); pot.addLine(to: CGPoint(x: 281, y: 136)); pot.closeSubpath()
            context.fill(pot, with: .color(warm.opacity(0.22))); context.stroke(pot, with: .color(line), lineWidth: 1)
            let leafGlow = abs(sin(plantPulse * .pi))
            if leafGlow > 0.01 {
                ellipse(CGRect(x: 266, y: 68, width: 47, height: 42), color: WriteRightTheme.sage.opacity(0.12 * leafGlow))
                for point in [CGPoint(x: 275, y: 72), CGPoint(x: 302, y: 83)] {
                    var sparkle = Path(); sparkle.move(to: CGPoint(x: point.x - 3, y: point.y)); sparkle.addLine(to: CGPoint(x: point.x + 3, y: point.y))
                    sparkle.move(to: CGPoint(x: point.x, y: point.y - 3)); sparkle.addLine(to: CGPoint(x: point.x, y: point.y + 3))
                    context.stroke(sparkle, with: .color(warm.opacity(leafGlow * 0.6)), lineWidth: 0.8)
                }
            }
            if mood == .ready {
                ellipse(CGRect(x: 278, y: 73, width: 8, height: 8), color: warm.opacity(0.65))
            }
            if progress > 0 && glow < 1 {
                context.fill(Path(CGRect(x: 0, y: 0, width: 360, height: 156)), with: .color(WriteRightTheme.background.opacity(progress * (1 - glow) * 0.25)))
            }
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
