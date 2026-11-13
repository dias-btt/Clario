import Foundation

/// Raw content for the daily digest (SwiftData models → structured data).
struct DailyDigestData: Equatable {
    /// Open tasks tied to today (scheduled for today or created today), urgent → important → low.
    let prioritizedTasks: [TaskItem]
    /// Ideas captured today (newest first).
    let ideasToday: [IdeaItem]
    /// Notes captured today (newest first).
    let notesToday: [NoteItem]

    let totalOpenTasksToday: Int
    let totalIdeasToday: Int
    let totalNotesToday: Int

    var hasAnything: Bool {
        !prioritizedTasks.isEmpty || !ideasToday.isEmpty || !notesToday.isEmpty
    }

    var hiddenTasksCount: Int { max(0, totalOpenTasksToday - prioritizedTasks.count) }
    var hiddenIdeasCount: Int { max(0, totalIdeasToday - ideasToday.count) }
    var hiddenNotesCount: Int { max(0, totalNotesToday - notesToday.count) }
}

enum DailyDigestBuilder {
    private static let maxTasks = 5
    private static let maxIdeas = 3
    private static let maxNotes = 3

    static func make(
        tasks: [TaskItem],
        ideas: [IdeaItem],
        notes: [NoteItem],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> DailyDigestData {
        let openToday = tasks.filter { task in
            guard !task.isCompleted else { return false }
            return task.isToday || calendar.isDate(task.createdAt, inSameDayAs: now)
        }
        .sorted { lhs, rhs in
            let lhsRank = priorityRank(lhs.priorityTag)
            let rhsRank = priorityRank(rhs.priorityTag)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            // Within a priority, newest first (matches the screen's query order) for a deterministic result.
            return lhs.createdAt > rhs.createdAt
        }

        // Use the injected calendar and `now` (not `isDateInToday`) so "today" is consistent everywhere.
        let allIdeasToday = ideas.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
        let allNotesToday = notes.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }

        return DailyDigestData(
            prioritizedTasks: Array(openToday.prefix(maxTasks)),
            ideasToday: Array(allIdeasToday.prefix(maxIdeas)),
            notesToday: Array(allNotesToday.prefix(maxNotes)),
            totalOpenTasksToday: openToday.count,
            totalIdeasToday: allIdeasToday.count,
            totalNotesToday: allNotesToday.count
        )
    }

    private static func priorityRank(_ tag: TaskPriorityTag) -> Int {
        switch tag {
        case .urgent: return 0
        case .important: return 1
        case .lowPriority: return 2
        }
    }

    /// Plain-text snapshot for the digest model (English labels; user content stays as stored).
    static func structuredContext(for data: DailyDigestData) -> String {
        var lines: [String] = []

        lines.append("Open tasks (relevant to today; urgent first):")
        if data.totalOpenTasksToday == 0 {
            lines.append("(none)")
        } else {
            for task in data.prioritizedTasks {
                lines.append("- [\(task.priorityTag.rawValue)] \(task.title)")
            }
            if data.hiddenTasksCount > 0 {
                lines.append("… and \(data.hiddenTasksCount) more open task(s) not shown in this list.")
            }
        }

        lines.append("")
        lines.append("Ideas captured today:")
        if data.totalIdeasToday == 0 {
            lines.append("(none)")
        } else {
            for idea in data.ideasToday {
                lines.append("- \(idea.content.replacingOccurrences(of: "\n", with: " "))")
            }
            if data.hiddenIdeasCount > 0 {
                lines.append("… and \(data.hiddenIdeasCount) more idea(s).")
            }
        }

        lines.append("")
        lines.append("Notes captured today:")
        if data.totalNotesToday == 0 {
            lines.append("(none)")
        } else {
            for note in data.notesToday {
                lines.append("- \(note.content.replacingOccurrences(of: "\n", with: " "))")
            }
            if data.hiddenNotesCount > 0 {
                lines.append("… and \(data.hiddenNotesCount) more note(s).")
            }
        }

        lines.append("")
        lines.append(
            "Totals: \(data.totalOpenTasksToday) open task(s), \(data.totalIdeasToday) idea(s), \(data.totalNotesToday) note(s) for today."
        )

        return lines.joined(separator: "\n")
    }
}

// MARK: - Daily digest summary (cache + AI + local fallback)

/// Produces the digest summary text. Only the most recently started request may publish a result or write
/// the cache, so cancelled or superseded requests can never overwrite newer UI state or newer cache entries.
final class DailyDigestSummaryService {
    private let cache: DailyDigestCache
    private var latestRequestID = 0

    init(cache: DailyDigestCache = .standard) {
        self.cache = cache
    }

    func cachedSummary(forFingerprint fingerprint: String) -> String? {
        cache.summary(forFingerprint: fingerprint)
    }

    /// Returns the summary to display, or `nil` when the request was cancelled or superseded by a newer one
    /// (the caller must then leave its current state untouched). Genuine AI failures yield the local summary.
    func summarize(
        tasks: [TaskItem],
        ideas: [IdeaItem],
        notes: [NoteItem],
        languageCode: String,
        aiService: AIService,
        calendar: Calendar = .current,
        now: Date = .now
    ) async -> String? {
        latestRequestID += 1
        let requestID = latestRequestID

        let fingerprint = DailyDigestFingerprint.identifier(
            tasks: tasks,
            ideas: ideas,
            notes: notes,
            languageCode: languageCode,
            calendar: calendar,
            now: now
        )

        if let cached = cache.summary(forFingerprint: fingerprint) {
            return cached
        }

        let data = DailyDigestBuilder.make(tasks: tasks, ideas: ideas, notes: notes, calendar: calendar, now: now)

        let summary: String
        if !data.hasAnything {
            summary = Self.localSummary(data: data, languageCode: languageCode)
        } else {
            let context = DailyDigestBuilder.structuredContext(for: data)
            do {
                summary = try await aiService.summarizeDailyDigest(
                    structuredContext: context,
                    languageCode: languageCode
                )
            } catch {
                if Task.isCancelled || AIServiceError.isCancellation(error) { return nil }
                summary = Self.localSummary(data: data, languageCode: languageCode)
            }
        }

        // A late answer for a cancelled or superseded request must not reach the cache or the UI.
        guard !Task.isCancelled, requestID == latestRequestID else { return nil }

        cache.store(summary, fingerprint: fingerprint)
        return summary
    }

    static func localSummary(data: DailyDigestData, languageCode: String) -> String {
        if !data.hasAnything {
            return AppLanguageStore.localized("digest.summary.quiet", languageCode: languageCode)
        }

        let t = data.totalOpenTasksToday
        let i = data.totalIdeasToday
        let n = data.totalNotesToday

        if i == 0, n == 0 {
            return AppLanguageStore.localizedFormat(
                "digest.summary.tasks_only", languageCode: languageCode, arguments: [Int64(t)]
            )
        }
        if t == 0 {
            return AppLanguageStore.localizedFormat(
                "digest.summary.ideas_notes_only", languageCode: languageCode, arguments: [Int64(i + n)]
            )
        }
        return AppLanguageStore.localizedFormat(
            "digest.summary.mixed", languageCode: languageCode, arguments: [Int64(t), Int64(i), Int64(n)]
        )
    }
}
