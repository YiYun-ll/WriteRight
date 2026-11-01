import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = 72
    @State private var favoriteID: UUID?
    @State private var showFavoriteMeaning = false
    @State private var mood: DeskMood = .ready
    @State private var now = ExamDesk.referenceNow()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var owner: String { model.account?.userID.uuidString ?? "guest" }
    private var snapshot: ExamDesk.Snapshot {
        ExamDesk(calendar: .current).snapshot(on: now)
    }

    private var favoritePages: [FavoriteDocument] {
        model.favorites.filter { $0.deletedAt == nil && !$0.expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.sorted { $0.createdAt > $1.createdAt }
    }
    private var featuredFavorite: FavoriteDocument? { favoritePages.first { $0.id == favoriteID } ?? favoritePages.first }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                BrandWordmark()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                InteractiveDeskView(mood: mood, owner: owner, reportCount: model.gradingReports.count,
                                    now: now, daysToExam: snapshot.daysRemaining)
                    .id("home-scene-" + owner)
                countdown
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("给今天的你").font(.system(.title3, design: .serif).weight(.medium))
                        Spacer()
                        Image(systemName: "text.quote").foregroundStyle(WriteRightTheme.accent).accessibilityHidden(true)
                    }
                    Text(snapshot.note)
                        .font(.system(.body, design: .serif)).lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("exam-note")
                    HStack {
                        Rectangle().fill(WriteRightTheme.accent).frame(width: 24, height: 1)
                        Text("WriteRight · 陪你一页一页写下去")
                            .font(.caption).foregroundStyle(WriteRightTheme.secondary)
                    }
                }
                .padding(24)
                .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                if let favorite = featuredFavorite { favoriteCorner(favorite) }
                pausePage
            }
            .padding(.horizontal, 24)
            .padding(.top, 15)
            .padding(.bottom, 32)
        }
        .background(WriteRightTheme.background)
        .foregroundStyle(WriteRightTheme.ink)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in now = ExamDesk.referenceNow() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = ExamDesk.referenceNow() } }
        .onChange(of: model.account?.userID) { _, _ in favoriteID = nil; showFavoriteMeaning = false; mood = .ready }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WriteRightTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            calendarDateRow("今天", value: todayDate)
            .foregroundStyle(WriteRightTheme.onAccent)
            .padding(20)
            .background(WriteRightTheme.accent)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        calendarNumber
                        calendarCaption
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 20) {
                        calendarNumber
                        calendarCaption
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            calendarDateRow("考试日期", value: examDate)
                .foregroundStyle(WriteRightTheme.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            Rectangle().fill(WriteRightTheme.soft).frame(height: 1)
                .padding(.horizontal, 16).padding(.bottom, 10).accessibilityHidden(true)
        }
        .background(WriteRightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topLeading) { bindingRing.padding(.leading, 32).offset(y: -7) }
        .overlay(alignment: .topTrailing) { bindingRing.padding(.trailing, 32).offset(y: -7) }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exam-countdown")
        .accessibilityLabel("今天，\(todayDate)，考试日期，\(examDate)，\(snapshot.accessibilityLabel)")
    }

    private var todayDate: String {
        now.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).year().month().day().weekday(.wide))
    }

    private var examDate: String {
        "\(String(ExamDesk.examYear))年\(ExamDesk.examMonth)月\(ExamDesk.examDay)日"
    }

    private func calendarDateRow(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title).fontWeight(.medium).fixedSize()
                Spacer(minLength: 0)
                Text(value).monospacedDigit().fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).fontWeight(.medium)
                Text(value).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }

    private var bindingRing: some View {
        Capsule().fill(WriteRightTheme.secondary).frame(width: 5, height: 17)
    }

    @ViewBuilder private var calendarNumber: some View {
        if snapshot.showsNumber {
            Text(snapshot.daysRemaining, format: .number)
                .font(.system(size: countdownSize, weight: .regular, design: .serif))
                .monospacedDigit().accessibilityIdentifier("exam-days")
        } else {
            Image(systemName: snapshot.daysRemaining == 0 ? "sun.max" : "leaf")
                .font(.largeTitle).foregroundStyle(WriteRightTheme.accent)
        }
    }

    private var calendarCaption: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.showsNumber ? "天，慢慢写向初试" : snapshot.daysRemaining == 0 ? "初试这一天" : "翻过这一页")
                .font(.system(.headline, design: .serif))
            Text(snapshot.daysRemaining < 0 ? "这一程，辛苦了" : "把今天这一页，慢慢写好")
                .font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
        }
    }

    private var pausePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今天，心里是什么天气？")
                .font(.system(.title3, design: .serif))
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                ForEach(DeskMood.allCases) { choice in
                    Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { mood = choice } } label: {
                        Text(choice.title).font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 4)
                            .foregroundStyle(mood == choice ? WriteRightTheme.accent : WriteRightTheme.secondary)
                            .background(mood == choice ? WriteRightTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(mood == choice ? WriteRightTheme.accent.opacity(0.3) : WriteRightTheme.secondary.opacity(0.15)) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home-mood-" + choice.rawValue)
                    .accessibilityAddTraits(mood == choice ? [.isSelected] : [])
                }
            }
            Text(mood.message)
                .font(.system(.body, design: .serif)).lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home-mood-response")
            HStack(spacing: 8) {
                Image(systemName: "leaf").accessibilityHidden(true)
                Text("每一种状态，都可以在这里落脚。")
            }.font(.caption).foregroundStyle(WriteRightTheme.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WriteRightTheme.soft.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
    }

    private func favoriteCorner(_ favorite: FavoriteDocument) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("书页一角", systemImage: "bookmark").font(.system(.title3, design: .serif))
                Spacer()
                if favoritePages.count > 1 {
                    Button("换一句") {
                        let index = favoritePages.firstIndex(where: { $0.id == favorite.id }) ?? 0
                        favoriteID = favoritePages[(index + 1) % favoritePages.count].id
                        showFavoriteMeaning = false
                    }.font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("home-favorite-next")
                }
            }.foregroundStyle(WriteRightTheme.accent)
            Text("上次收藏的话，今天再遇见。").font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
            Text(favorite.expression).font(.system(.title2, design: .serif)).lineSpacing(6).accessibilityIdentifier("home-favorite")
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            DisclosureGroup(isExpanded: $showFavoriteMeaning) {
                VStack(alignment: .leading, spacing: 12) {
                    if !favorite.meaning.isEmpty { Text(favorite.meaning).font(.subheadline) }
                    if !favorite.usage.isEmpty { Text(favorite.usage).font(.system(.body, design: .serif)).lineSpacing(5) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
            } label: { Text("看看这句话怎么用").font(.subheadline) }
            Divider()
            NavigationLink { FavoritesView() } label: {
                HStack { Text("翻开收藏夹"); Spacer(); Image(systemName: "arrow.up.right") }.font(.subheadline).frame(minHeight: 44)
            }.accessibilityIdentifier("home-open-favorites")
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18).fill(WriteRightTheme.accent.opacity(0.25)).frame(width: 3).padding(.vertical, 20) }
    }

}

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let onPhotos: () -> Void
    let onCreate: (WritingPart, WritingTaskDocument?) -> Void
    let onOpen: (DraftDocument) -> Void
    let onOpenReport: (GradingReportDocument) -> Void

    private var tasks: [WritingTaskDocument] {
        var seen = Set<UUID>()
        return model.drafts.filter { !$0.isEmpty }.compactMap { seen.insert($0.task.id).inserted ? $0.task : nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("每一页，都有往前走的痕迹。")
                        .font(.system(.title2, design: .serif))
                    Text("把题目和写好的作文放在一起，慢慢看清下一步。")
                        .font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                }
                photoInvitation
                Text("也可以，从空白页开始").font(.system(.headline, design: .serif))
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(WritingPart.allCases) { part in
                        PartEntry(part: part) { onCreate(part, nil) }
                    }
                }
                let activeJobs = model.gradingJobs.filter { $0.status != .completed }
                if !activeJobs.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("批改任务").font(.title2.weight(.semibold))
                        ForEach(activeJobs) { job in
                            ReadingProgressView(status: job.status, stage: job.stage,
                                connectionIssue: model.gradingConnectionIssues[job.id],
                                retry: job.status == .failed || model.gradingConnectionIssues[job.id] != nil ? {
                                    Task { if job.status == .failed { await model.retryGrading(job) } else { await model.refreshGrading(job) } }
                                } : nil)
                        }
                    }
                }
                let drafts = model.drafts.filter { !$0.isEmpty }
                if !drafts.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("继续写").font(.title2.weight(.semibold))
                        VStack(spacing: 0) {
                            ForEach(Array(drafts.prefix(3).enumerated()), id: \.element.id) { index, draft in
                                if index > 0 { Divider().padding(.leading, 20) }
                                Button { onOpen(draft) } label: {
                                    HStack(spacing: 16) {
                                        DraftRow(draft: draft, combinesAccessibility: false)
                                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                                            .foregroundStyle(WriteRightTheme.secondary)
                                    }
                                    .padding(.horizontal, 20).padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("continue-draft")
                            }
                        }.background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                    }
                }
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("再写一稿").font(.title2.weight(.semibold))
                        ForEach(tasks) { task in
                            Button { onCreate(task.part, task) } label: {
                                HStack(spacing: 16) {
                                    Text(task.part.rawValue).font(.system(.title, design: .serif))
                                        .frame(width: 34).foregroundStyle(WriteRightTheme.accent)
                                    Text(task.displayTitle).font(.headline).foregroundStyle(WriteRightTheme.ink)
                                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "arrow.up.right").foregroundStyle(WriteRightTheme.secondary)
                                }.padding(20).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain).accessibilityIdentifier("reuse-task")
                        }
                    }
                }
                if !model.gradingReports.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("最近报告").font(.title2.weight(.semibold))
                        ForEach(model.gradingReports) { report in
                            Button { onOpenReport(report) } label: {
                                HStack(spacing: 16) {
                                    if let score = report.report.score.value {
                                        Text(score, format: .number.precision(.fractionLength(0...1)))
                                            .font(.system(.title, design: .serif)).frame(width: 42)
                                    } else {
                                        Image(systemName: "text.quote").frame(width: 42)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(report.part.title).font(.headline)
                                        Text(report.createdAt, format: .dateTime.month().day().hour().minute())
                                            .font(.caption).foregroundStyle(WriteRightTheme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(WriteRightTheme.secondary)
                                }
                                .padding(20).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain).accessibilityIdentifier("recent-report")
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 32)
        }
        .background(WriteRightTheme.background)
        .foregroundStyle(WriteRightTheme.ink)
        .navigationTitle("练习")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { HistoryView(onOpen: onOpen, onCreate: {}) } label: {
                    Image(systemName: "clock.arrow.circlepath").frame(width: 44, height: 44)
                }.accessibilityLabel("练习历史").accessibilityIdentifier("practice-history")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(WritingPart.allCases) { part in
                        Button(part.title) { onCreate(part, nil) }
                    }
                } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }
                    .accessibilityLabel("新建练习")
            }
        }
    }

    private var photoInvitation: some View {
        Button(action: onPhotos) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("题目与作文，\n一起读懂。")
                            .font(.system(.title, design: .serif)).fixedSize(horizontal: false, vertical: true)
                        Text("拍照或选图 · 直接看图批改")
                            .font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if !typeSize.isAccessibilitySize { PhotoPracticeArtwork().frame(width: 104, height: 134).accessibilityHidden(true) }
                }
                HStack {
                    Label("上传照片，开始这一篇", systemImage: "camera")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                }.foregroundStyle(WriteRightTheme.accent)
            }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(WriteRightTheme.soft, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityIdentifier("start-photo-practice")
    }

    private func stageTitle(_ stage: GradingStage) -> String {
        switch stage {
        case .evaluate: return "评分"
        case .correct: return "逐句纠错"
        case .rewrite: return "生成修改稿"
        case .validate: return "核验报告"
        case .done: return "完成"
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2)
    }
}

private struct PhotoPracticeArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(WriteRightTheme.accent.opacity(0.14))
                .frame(width: 82, height: 112).rotationEffect(.degrees(-12)).offset(x: -9, y: -4)
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "text.quote").font(.title2).foregroundStyle(WriteRightTheme.accent)
                ForEach(0..<4) { index in
                    Rectangle().fill(WriteRightTheme.secondary.opacity(0.25))
                        .frame(width: index == 3 ? 30 : 52, height: 1)
                }
            }
            .padding(16).frame(width: 84, height: 112)
            .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .rotationEffect(.degrees(6)).offset(x: 6, y: 5)
            Image(systemName: "camera.aperture").font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(WriteRightTheme.accent).offset(x: 30, y: 52)
        }
    }
}
