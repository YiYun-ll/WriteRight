import XCTest
@testable import EssayPilot

@MainActor final class NotebookPresentationTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12))! }
    func testBoardSeparatesPinnedTodayLaterMomentsAndCompletedWithDeterministicOrder() {
        var pinned = NotebookEntry(title: "最想先做的一件"); pinned.pinned = true
        var today = NotebookEntry(title: "今天的小事"); today.dueDate = now
        var earlier = NotebookEntry(title: "接着做也可以"); earlier.dueDate = now.addingTimeInterval(-86400)
        let later = NotebookEntry(title: "不着急")
        let note = NotebookEntry(kind: .note, title: "留住一句话")
        var done = NotebookEntry(title: "走过了"); done.completed = true
        let entries = [later, done, today, pinned, note, earlier]
        let sections = NotebookPresentation.sections(entries, filter: "all", search: "", now: now, calendar: calendar)
        XCTAssertEqual(sections.map(\.id), ["pinned", "today", "later", "moments", "done"])
        XCTAssertEqual(sections[1].entries.map(\.id), [earlier.id, today.id])
        XCTAssertEqual(NotebookPresentation.sections(entries, filter: "pending", search: "", now: now, calendar: calendar).flatMap(\.entries).count, 5)
        XCTAssertTrue(NotebookPresentation.dateLabel(earlier.dueDate!, now: now, calendar: calendar).contains("还可以接着做"))
    }
    func testLinkFilterIncludesAttachedTaskLinksAndSearchDoesNotResurrectDeletedRecords() {
        var task = NotebookEntry(title: "今天看看"); task.link = "https://xhslink.com/o/test"
        var deleted = NotebookEntry(title: "已收起"); deleted.deletedAt = now
        let linked = NotebookPresentation.sections([task, deleted], filter: "links", search: "  今天  ", now: now, calendar: calendar)
        XCTAssertEqual(linked.flatMap(\.entries).map(\.id), [task.id])
        XCTAssertTrue(NotebookPresentation.sections([deleted], filter: "all", search: "已收起").isEmpty)
    }
    func testEditorCreatesBodyOnlyNotesAndPreservesShareTextWithoutFetching() throws {
        let note = NotebookEditorModel(entry: NotebookEntry(kind: .note, title: ""))
        note.entry.note = "今天看见一束光。\n想把它写下来。"
        XCTAssertEqual(try XCTUnwrap(note.prepare()).title, "今天看见一束光。")
        let link = NotebookEditorModel(entry: NotebookEntry(kind: .link, title: ""))
        link.linkInput = "值得留下 https://v.douyin.com/abc/ 复制打开"
        let saved = try XCTUnwrap(link.prepare())
        XCTAssertEqual(saved.link, "https://v.douyin.com/abc/")
        XCTAssertEqual(saved.note, link.linkInput)
        XCTAssertEqual(saved.title, "抖音里的一点灵感")
        link.linkInput = "javascript:alert(1)"
        XCTAssertNil(link.prepare()); XCTAssertNotNil(link.error)
        XCTAssertEqual(link.linkInput, "javascript:alert(1)")
    }
    func testRowPreviewDoesNotRepeatAutoTitleOrLongShareURL() {
        var entry = NotebookEntry(kind: .note, title: "第一行")
        entry.note = "第一行\n第二行的想法"
        XCTAssertEqual(NotebookPresentation.preview(entry), "第二行的想法")
        entry.title = "小红书里的一点灵感"; entry.note = "想再看 https://xhslink.com/o/test  这段话"; entry.link = "https://xhslink.com/o/test"
        XCTAssertEqual(NotebookPresentation.preview(entry), "想再看 这段话")
        XCTAssertTrue(entry.note.contains("https://"))
    }

    func testEditorKeepsTaskIdentityWithOptionalLinkAndCanRemoveLinkWithoutLosingNote() throws {
        let editor = NotebookEditorModel(entry: NotebookEntry(title: "读一篇文章"))
        editor.entry.note = "找一句喜欢的表达。"; editor.includeLink = true; editor.linkInput = "https://example.com/a"
        var saved = try XCTUnwrap(editor.prepare())
        XCTAssertEqual(saved.kind, .task); XCTAssertNotNil(saved.link)
        editor.includeLink = false; editor.linkInput = ""
        saved = try XCTUnwrap(editor.prepare())
        XCTAssertNil(saved.link); XCTAssertEqual(saved.note, editor.entry.note)
    }
    func testUndoWhileDeletionIsInFlightSurvivesLateDeleteAcknowledgement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(storeRoot: root)
        let entry = NotebookEntry(title: "稍后再看")
        XCTAssertTrue(model.saveNotebook(entry))
        var deleted = entry; deleted.deletedAt = now
        XCTAssertTrue(model.saveNotebook(deleted)); XCTAssertTrue(model.restoreNotebook(entry))
        let restored = try XCTUnwrap(model.notebook.first)
        XCTAssertNotEqual(restored.id, entry.id)
        try model.repository?.acknowledgeNotebook(deleted, revision: 2, deleted: true)
        model.refresh()
        XCTAssertEqual(model.notebook.map(\.id), [restored.id])
    }
}
