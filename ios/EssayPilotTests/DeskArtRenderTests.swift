import SwiftUI
import XCTest
@testable import EssayPilot

/// Renders every desk and cat state so the artwork can be reviewed from the test attachments.
@MainActor final class DeskArtRenderTests: XCTestCase {
    private struct Scene: View {
        var mood: DeskMood = .ready
        var progress = 0.0, glow = 1.0
        var window: DeskWindow = .quiet
        var pose: CompanionPose = .sitting
        var stage: CompanionStage = .visitor
        var night = false
        var body: some View {
            ZStack {
                QuietDeskScene(mood: mood, sunsetProgress: progress, window: window, lampGlow: glow)
                CompanionPetCanvas(pose: pose, stage: stage, night: night, bounce: 0)
                DeskLightLayer(sunsetProgress: progress, lampGlow: glow)
            }.frame(width: 390, height: 170)
        }
    }

    private func attach(_ name: String, _ view: some View, dark: Bool = false) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, dark ? .dark : .light))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, name)
        XCTAssertGreaterThan(image.size.width, 0)
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDeskStatesRenderInBothAppearances() throws {
        for dark in [false, true] {
            let look = dark ? "dark" : "light"
            try attach("desk-day-\(look)", Scene(), dark: dark)
            try attach("desk-rest-night-\(look)", Scene(progress: 1, glow: 0, pose: .sleeping, night: true), dark: dark)
            try attach("desk-night-lamp-\(look)", Scene(progress: 1, glow: 1, stage: .lantern, night: true), dark: dark)
            try attach("desk-rain-\(look)", Scene(mood: .unsettled, window: .rain, pose: .focusing, stage: .together), dark: dark)
            try attach("desk-breeze-\(look)", Scene(mood: .tired, glow: 0, window: .breeze, stage: .partner), dark: dark)
        }
    }

    func testEveryGrowthStageRenders() throws {
        let row = HStack(spacing: 0) {
            ForEach(CompanionStage.allCases) { stage in
                CompanionPetCanvas(pose: .sitting, stage: stage, night: stage >= .lantern, bounce: 0,
                                   anchor: CGPoint(x: 60, y: 74), canvasSize: CGSize(width: 120, height: 80))
                    .frame(width: 150, height: 100)
            }
        }.background(WriteRightTheme.background)
        try attach("cat-stages-light", row)
        try attach("cat-stages-dark", row, dark: true)
    }
}
