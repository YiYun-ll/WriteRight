import SwiftUI

struct BrandWordmark: View {
    var size: CGFloat = 34
    var relativeTo: Font.TextStyle = .largeTitle

    var body: some View {
        Text("WriteRight")
            .font(.custom("TimesNewRomanPS-BoldMT", size: size, relativeTo: relativeTo))
            .lineLimit(1).minimumScaleFactor(0.5)
            .accessibilityIdentifier("brand-wordmark")
    }
}

enum WriteRightTheme {
    static let background = adaptive(0xF8F5EF, 0x161513)
    static let surface = adaptive(0xFFFFFF, 0x24221E)
    static let ink = adaptive(0x26231F, 0xF4EFE7)
    static let secondary = adaptive(0x756F67, 0xBBB3A8)
    static let accent = adaptive(0xBF4820, 0xFFA174)
    static let soft = adaptive(0xEFE8DE, 0x302C26)
    static let orange = Color(red: 0.94, green: 0.48, blue: 0.29)
    static let orangeInk = Color(red: 0.18, green: 0.09, blue: 0.05)

    private static func adaptive(_ light: Int, _ dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

struct MainActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(Color.white)
            .background(Color(red: 0.70, green: 0.23, blue: 0.09), in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct PartEntry: View {
    let part: WritingPart
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var letterSize: Double = 68

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                Text(part.rawValue).font(.system(size: min(letterSize, 110), weight: .regular, design: .serif))
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(part.title).font(.title3.weight(.semibold))
                        Text("\(part.maximumScore) 分").font(.subheadline.monospacedDigit())
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.body.weight(.semibold))
                }
            }
            .padding(22).frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 210 : 220, alignment: .leading)
            .foregroundStyle(part == .b ? WriteRightTheme.orangeInk : WriteRightTheme.ink)
            .background(part == .b ? WriteRightTheme.orange : WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写\(part.title)，Part \(part.rawValue)，满分\(part.maximumScore)分")
        .accessibilityIdentifier("new-part-\(part.rawValue)")
    }
}

struct DraftRow: View {
    let draft: DraftDocument
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(draft.task.displayTitle).font(.headline).lineLimit(2).foregroundStyle(WriteRightTheme.ink)
            HStack {
                Text("\(draft.task.part.title) · \(draft.wordCount) 词")
                Spacer()
                Text(draft.updatedAt, format: .dateTime.month().day())
            }.font(.caption).foregroundStyle(WriteRightTheme.secondary)
        }.padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}
