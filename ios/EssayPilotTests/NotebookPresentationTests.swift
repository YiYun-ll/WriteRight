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
        XCTAssertEqual(saved.title, "值得留下")
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
        entry.title = "Another clip"; entry.note = "Another clip https://b23.tv/x"; entry.link = "https://b23.tv/x"
        XCTAssertEqual(NotebookPresentation.preview(entry), "")
        entry.title = "五分钟读懂议论文结构"; entry.note = "【五分钟读懂议论文结构-哔哩哔哩】 https://b23.tv/x\n周末再看一遍"
        XCTAssertEqual(NotebookPresentation.preview(entry), "周末再看一遍")
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
    func testBilibiliAndWeChatShareTextAreRecognisedWithoutSwallowingChineseText() throws {
        let bilibili = try XCTUnwrap(NotebookLink.url("【五分钟读懂议论文结构-哔哩哔哩】 https://b23.tv/AbC123x"))
        XCTAssertEqual(bilibili.absoluteString, "https://b23.tv/AbC123x")
        XCTAssertEqual(NotebookLink.platform(bilibili), .bilibili)
        XCTAssertEqual(NotebookLink.source(try XCTUnwrap(NotebookLink.url("https://www.bilibili.com/video/BV1xx411c7mD?p=2"))), "哔哩哔哩")
        XCTAssertEqual(NotebookLink.source(try XCTUnwrap(NotebookLink.url("https://m.bilibili.com/video/BV1xx411c7mD"))), "哔哩哔哩")
        let wechat = try XCTUnwrap(NotebookLink.url("好文章：https://mp.weixin.qq.com/s/Xy_z-12AbC，有空看看"))
        XCTAssertEqual(wechat.absoluteString, "https://mp.weixin.qq.com/s/Xy_z-12AbC")
        XCTAssertEqual(NotebookLink.source(wechat), "微信公众号")
        XCTAssertEqual(NotebookLink.source(try XCTUnwrap(NotebookLink.url("https://mp.weixin.qq.com/s?__biz=MzA&mid=1&idx=1&sn=ab#rd"))), "微信公众号")
        XCTAssertNotEqual(NotebookLink.source(try XCTUnwrap(NotebookLink.url("https://weixin.qq.com/download"))), "微信公众号")
        // Xiaohongshu share text glues Chinese to an http short link.
        let xhs = try XCTUnwrap(NotebookLink.url("考研英语作文模板 http://xhslink.com/a/Ab12Cd，复制本条信息，打开【小红书】App查看精彩内容！"))
        XCTAssertEqual(xhs.absoluteString, "https://xhslink.com/a/Ab12Cd")
        XCTAssertNil(NotebookLink.url("http://example.com/plain-http"))
        XCTAssertEqual(NotebookLink.url("先 http://example.com/x 再 https://example.com/ok")?.absoluteString, "https://example.com/ok")
    }
    func testShareTitlesComeFromTheSharedTextNeverFromTheNetwork() throws {
        XCTAssertEqual(NotebookLink.suggestedTitle("【五分钟读懂议论文结构_哔哩哔哩_bilibili】 https://b23.tv/AbC123x"), "五分钟读懂议论文结构")
        XCTAssertEqual(NotebookLink.suggestedTitle("考研英语作文模板 http://xhslink.com/a/Ab12Cd，复制本条信息，打开【小红书】App查看精彩内容！"), "考研英语作文模板")
        XCTAssertNil(NotebookLink.suggestedTitle("https://mp.weixin.qq.com/s/Xy_z-12AbC"))
        let editor = NotebookEditorModel(entry: NotebookEntry(kind: .link, title: ""))
        editor.linkInput = "https://mp.weixin.qq.com/s/Xy_z-12AbC"
        let saved = try XCTUnwrap(editor.prepare())
        XCTAssertEqual(saved.title, "微信公众号里的一点灵感"); XCTAssertEqual(saved.note, "")
        let xhs = NotebookEditorModel(entry: NotebookEntry(kind: .link, title: ""))
        xhs.linkInput = "http://xhslink.com/a/Ab12Cd"
        let bare = try XCTUnwrap(xhs.prepare())
        XCTAssertEqual(bare.link, "https://xhslink.com/a/Ab12Cd"); XCTAssertEqual(bare.note, "")
    }
    func testLinkShelfGroupsBySourceUnreadFirstAndCanNarrowToOneSource() {
        func link(_ title: String, _ url: String, seen: Bool = false, age: TimeInterval = 0) -> NotebookEntry {
            var entry = NotebookEntry(kind: .link, title: title); entry.link = url; entry.completed = seen
            entry.createdAt = now.addingTimeInterval(-age); return entry
        }
        let oldVideo = link("旧视频", "https://b23.tv/old", age: 300)
        let newVideo = link("新视频", "https://www.bilibili.com/video/BV1", age: 10)
        let seenVideo = link("看过的视频", "https://b23.tv/seen", seen: true)
        let article = link("公众号文章", "https://mp.weixin.qq.com/s/a")
        let blog = link("博客", "https://example.com/post")
        var removed = link("已收起", "https://b23.tv/gone"); removed.deletedAt = now
        let plain = NotebookEntry(title: "没有链接")
        let entries = [blog, seenVideo, article, oldVideo, plain, removed, newVideo]
        let shelves = NotebookPresentation.sections(entries, filter: "links", search: "", now: now, calendar: calendar)
        XCTAssertEqual(shelves.map(\.id), ["source-哔哩哔哩", "source-微信公众号", "source-其他网站"])
        XCTAssertEqual(shelves[0].title, "哔哩哔哩 · 3")
        XCTAssertEqual(shelves[0].entries.map(\.id), [newVideo.id, oldVideo.id, seenVideo.id])
        XCTAssertEqual(NotebookPresentation.linkSources(entries), [.init(title: "哔哩哔哩", count: 3), .init(title: "微信公众号", count: 1), .init(title: "其他网站", count: 1)])
        XCTAssertEqual(NotebookPresentation.sections(entries, filter: "links", search: "", source: "微信公众号", now: now, calendar: calendar).flatMap(\.entries).map(\.id), [article.id])
        XCTAssertEqual(NotebookPresentation.sections(entries, filter: "links", search: "B站", now: now, calendar: calendar).flatMap(\.entries).count, 3)
        XCTAssertEqual(NotebookPresentation.sections(entries, filter: "all", search: "公众号", now: now, calendar: calendar).flatMap(\.entries).map(\.id), [article.id])
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
