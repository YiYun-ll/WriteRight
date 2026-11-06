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
    static let background = adaptive(0xF6F1E8, 0x1D1A17)
    static let surface = adaptive(0xFFFCF6, 0x2A2520)
    static let ink = adaptive(0x352E27, 0xF4EBDD)
    static let secondary = adaptive(0x756759, 0xC3B4A2)
    static let accent = adaptive(0xAC4829, 0xF1A383)
    static let soft = adaptive(0xEDE3D5, 0x3C332A)
    static let emphasisRed = adaptive(0xA82830, 0xFFB4AB)
    static let sage = adaptive(0x65785D, 0xA8B59A)
    static let blue = Color(red: 0.325, green: 0.498, blue: 0.624)
    static let onAccent = adaptive(0xFFFFFF, 0x322017)

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
            .foregroundStyle(WriteRightTheme.onAccent)
            .background(WriteRightTheme.accent, in: RoundedRectangle(cornerRadius: 18))
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(part.rawValue)
                        .font(.system(size: min(letterSize, 46), weight: .regular, design: .serif))
                        .foregroundStyle(WriteRightTheme.accent)
                        .accessibilityHidden(true)
                    Spacer()
                    Image(systemName: part == .a ? "envelope.open" : "chart.xyaxis.line")
                        .font(.system(size: 27, weight: .ultraLight))
                        .padding(.top, 8).accessibilityHidden(true)
                }
                Rectangle().fill(WriteRightTheme.ink.opacity(0.14)).frame(height: 1)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(part.title).font(.system(.title3, design: .serif).weight(.semibold))
                        Text("\(part.maximumScore) 分").font(.subheadline.monospacedDigit())
                            .foregroundStyle(WriteRightTheme.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.body.weight(.medium))
                }
            }
            .padding(22).frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 195 : 180, alignment: .leading)
            .foregroundStyle(WriteRightTheme.ink)
            .background(part == .a ? WriteRightTheme.surface : WriteRightTheme.soft, in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                Rectangle().fill(WriteRightTheme.accent.opacity(0.25)).frame(width: 3).padding(.vertical, 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写\(part.title)，Part \(part.rawValue)，满分\(part.maximumScore)分")
        .accessibilityIdentifier("new-part-\(part.rawValue)")
    }
}

struct DraftRow: View {
    let draft: DraftDocument
    var combinesAccessibility = true

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            title
            if draft.conflictOf != nil {
                Text("冲突副本").font(.caption).foregroundStyle(WriteRightTheme.secondary)
            }
            HStack {
                Text(draft.practiceSummary)
                Spacer()
                Text(draft.updatedAt, format: .dateTime.month().day())
            }.font(.caption).foregroundStyle(WriteRightTheme.secondary)
        }.padding(.vertical, 9)
        .modifier(DraftRowAccessibility(combines: combinesAccessibility))
    }

    private var title: some View {
        Text(draft.task.displayTitle).font(.headline).lineLimit(2).foregroundStyle(WriteRightTheme.ink)
            .accessibilityIdentifier(combinesAccessibility ? "draft-title" : "continue-title")
    }
}

private struct DraftRowAccessibility: ViewModifier {
    var combines: Bool
    func body(content: Content) -> some View {
        if combines { content.accessibilityElement(children: .combine) }
        else { content }
    }
}
