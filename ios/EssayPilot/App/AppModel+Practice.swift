import Foundation

@MainActor extension AppModel {
    var continuingDrafts: [DraftDocument] {
        drafts.filter { draft in !draft.isEmpty && !submissions.contains(where: { draft.matches($0) }) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    private var hiddenPracticeTaskKey: String { "practice.hiddenTasks.\(profileOwner)" }
    var reusablePracticeTasks: [WritingTaskDocument] {
        let hidden = Set(UserDefaults.standard.stringArray(forKey: hiddenPracticeTaskKey) ?? [])
        var seen = Set<UUID>()
        return gradingReports.sorted { $0.createdAt > $1.createdAt }.compactMap { report in
            guard let task = submissions.first(where: { $0.id == report.submissionID })?.task,
                  !hidden.contains(task.id.uuidString), seen.insert(task.id).inserted else { return nil }
            return task
        }
    }
    /// This removes a shortcut, not the submitted evidence or the report used by history.
    func hideReusableTask(_ task: WritingTaskDocument) {
        var hidden = Set(UserDefaults.standard.stringArray(forKey: hiddenPracticeTaskKey) ?? [])
        hidden.insert(task.id.uuidString)
        UserDefaults.standard.set(Array(hidden).sorted(), forKey: hiddenPracticeTaskKey)
        objectWillChange.send()
    }
}
