import XCTest
@testable import EssayPilot

@MainActor final class HomeDeskTests: XCTestCase {
    func testSceneInteractionsChangeRealTemporaryStatesAndCanReturnToQuiet() {
        let desk = HomeDeskModel()
        desk.changeWindow(); XCTAssertEqual(desk.window, .breeze)
        desk.changeWindow(); XCTAssertEqual(desk.window, .rain)
        XCTAssertTrue(desk.caption(mood: .ready).contains("小画"))
        desk.changeWindow(); XCTAssertEqual(desk.window, .quiet)
        XCTAssertEqual(desk.windowMotion, 3)
        desk.pourTea(); XCTAssertEqual(desk.teaLift, 1)
        desk.tendPlant(); XCTAssertEqual(desk.plantPulse, 1)
        XCTAssertTrue(desk.caption(mood: .tired).contains("叶子"))
        let reopened = HomeDeskModel()
        XCTAssertEqual(reopened.window, .quiet); XCTAssertEqual(reopened.teaLift, 0); XCTAssertNil(reopened.response)
    }
    func testRestAndLampRemainIndependentOfWindowAndReestablishReadableCaptions() {
        let desk = HomeDeskModel(); desk.changeWindow(); desk.toggleRest()
        XCTAssertTrue(desk.resting); XCTAssertFalse(desk.lampOn); XCTAssertEqual(desk.lampGlow, 0)
        XCTAssertEqual(desk.sunsetProgress, 1); XCTAssertEqual(desk.window, .breeze)
        desk.toggleLamp(); XCTAssertEqual(desk.lampGlow, 1); XCTAssertTrue(desk.caption(mood: .tired).contains("夜色"))
        desk.toggleRest(); XCTAssertTrue(desk.lampOn); XCTAssertFalse(desk.resting); XCTAssertEqual(desk.sunsetProgress, 0)
        XCTAssertEqual(desk.caption(mood: .ready), DeskMood.ready.sceneCaption)
    }
}
