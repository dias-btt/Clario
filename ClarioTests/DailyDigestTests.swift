import Foundation
import SwiftData
import Testing
@testable import Clario

// MARK: - Test doubles

/// Deterministic digest AI. Either answers immediately or suspends each request until the test resumes it.
/// Suspended requests deliberately ignore task cancellation, like a network response that arrives late.
@MainActor
final class DigestAIServiceStub: AIService {
    enum Mode {
        case immediate(Result<String, Error>)
        case suspended
    }

    var mode: Mode
    private(set) var receivedLanguageCodes: [String] = []
    private(set) var receivedContexts: [String] = []
    private var pending: [CheckedContinuation<String, Error>] = []

    var callCount: Int { receivedContexts.count }

    init(mode: Mode) {
        self.mode = mode
    }

    func process(input: String) async throws -> AIResult { .empty }

    func summarizeDailyDigest(structuredContext: String, languageCode: String) async throws -> String {
        receivedContexts.append(structuredContext)
        receivedLanguageCodes.append(languageCode)
        switch mode {
        case let .immediate(result):
            return try result.get()
        case .suspended:
            return try await withCheckedThrowingContinuation { pending.append($0) }
        }
    }

    func resumeOldest(with result: Result<String, Error>) {
        pending.removeFirst().resume(with: result)
    }

    func resumeNewest(with result: Result<String, Error>) {
        pending.removeLast().resume(with: result)
    }

    func waitForPending(_ count: Int) async throws {
        for _ in 0 ..< 1_000 where pending.count < count {
            await Task.yield()
        }
        try #require(pending.count >= count, "Expected \(count) suspended digest request(s)")
    }
}

// MARK: - Fixtures

private func makeIsolatedCache() -> DailyDigestCache {
    let suiteName = "ClarioTests.DailyDigest.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return DailyDigestCache(defaults: defaults)
}

private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: TaskItem.self, IdeaItem.self, NoteItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

private func calendar(_ timeZoneID: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneID)!
    return calendar
}

private func date(_ iso8601: String) -> Date {
    ISO8601DateFormatter().date(from: iso8601)!
}

private let utc = calendar("UTC")
/// Fixed reference time: 2026-11-13 12:00 UTC.
private let noon = date("2026-11-13T12:00:00Z")

private struct SimulatedAIFailure: Error {}

/// Holds model objects in an in-memory store and exposes a summarize helper with fixed calendar/now.
@MainActor
private final class DigestFixture {
    let container: ModelContainer
    let cache = makeIsolatedCache()
    let service: DailyDigestSummaryService
    var tasks: [TaskItem] = []
    var ideas: [IdeaItem] = []
    var notes: [NoteItem] = []

    init() throws {
        container = try makeContainer()
        service = DailyDigestSummaryService(cache: cache)
    }

    @discardableResult
    func addTask(
        _ title: String,
        tag: TaskPriorityTag = .important,
        isToday: Bool = true,
        createdAt: Date = noon
    ) -> TaskItem {
        let task = TaskItem(title: title, isToday: isToday, priorityTag: tag, createdAt: createdAt)
        container.mainContext.insert(task)
        tasks.append(task)
        return task
    }

    @discardableResult
    func addIdea(_ content: String, createdAt: Date = noon) -> IdeaItem {
        let idea = IdeaItem(content: content, createdAt: createdAt)
        container.mainContext.insert(idea)
        ideas.append(idea)
        return idea
    }

    func fingerprint(language: String = "en", calendar: Calendar = utc, now: Date = noon) -> String {
        DailyDigestFingerprint.identifier(
            tasks: tasks, ideas: ideas, notes: notes, languageCode: language, calendar: calendar, now: now
        )
    }

    func summarize(
        _ ai: AIService,
        language: String = "en",
        calendar: Calendar = utc,
        now: Date = noon
    ) async -> String? {
        await service.summarize(
            tasks: tasks,
            ideas: ideas,
            notes: notes,
            languageCode: language,
            aiService: ai,
            calendar: calendar,
            now: now
        )
    }
}

// MARK: - Summary service

@MainActor
@Suite("Daily digest summary")
struct DailyDigestSummaryTests {
    @Test("Successful AI summary is returned and cached")
    func successfulSummary() async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent", tag: .urgent)
        let ai = DigestAIServiceStub(mode: .immediate(.success("You have one urgent task.")))

        let summary = await fixture.summarize(ai)

        #expect(summary == "You have one urgent task.")
        #expect(ai.callCount == 1)
        #expect(ai.receivedLanguageCodes == ["en"])
        #expect(ai.receivedContexts.first?.contains("- [urgent] Pay rent") == true)
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint()) == "You have one urgent task.")
    }

    @Test("Genuine AI failure falls back to the localized local summary")
    func genuineFailureFallsBack() async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent")
        fixture.addTask("Call bank")
        let ai = DigestAIServiceStub(mode: .immediate(.failure(AIServiceError.requestFailed(statusCode: 500, message: nil))))

        let summary = await fixture.summarize(ai)

        let data = DailyDigestBuilder.make(
            tasks: fixture.tasks, ideas: [], notes: [], calendar: utc, now: noon
        )
        let expected = DailyDigestSummaryService.localSummary(data: data, languageCode: "en")
        #expect(summary == expected)
        #expect(expected.contains("2"))
        // Fallback is cached so a failing service is not hammered for unchanged content.
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint()) == expected)
    }

    @Test("Network errors that wrap a genuine failure still fall back")
    func wrappedNetworkFailureFallsBack() async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent")
        let ai = DigestAIServiceStub(mode: .immediate(.failure(AIServiceError.network(URLError(.notConnectedToInternet)))))

        let summary = await fixture.summarize(ai)

        #expect(summary != nil)
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint()) == summary)
    }

    @Test("Cancellation errors are not treated as failures and are never cached",
          arguments: [
              CancellationError() as Error,
              URLError(.cancelled) as Error,
              AIServiceError.network(URLError(.cancelled)) as Error,
          ])
    func cancellationErrorIsNotCached(error: Error) async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent")
        let ai = DigestAIServiceStub(mode: .immediate(.failure(error)))

        let summary = await fixture.summarize(ai)

        #expect(summary == nil)
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint()) == nil)
    }

    @Test("Cancelling the task during generation discards the result and leaves the cache empty")
    func cancellationDuringGeneration() async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent")
        let ai = DigestAIServiceStub(mode: .suspended)

        let request = Task { await fixture.summarize(ai) }
        try await ai.waitForPending(1)
        request.cancel()
        // The service ignores cancellation and answers anyway (late network response).
        ai.resumeOldest(with: .success("Late summary"))

        #expect(await request.value == nil)
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint()) == nil)

        // The next request is not blocked by the cancelled one and calls the AI again.
        ai.mode = .immediate(.success("Fresh summary"))
        #expect(await fixture.summarize(ai) == "Fresh summary")
        #expect(ai.callCount == 2)
    }

    @Test("A late response from an obsolete request cannot overwrite the newer result or cache entry")
    func lateResponseFromObsoleteRequest() async throws {
        let fixture = try DigestFixture()
        let task = fixture.addTask("Draft report")
        let ai = DigestAIServiceStub(mode: .suspended)

        let oldFingerprint = fixture.fingerprint()
        let oldRequest = Task { await fixture.summarize(ai) }
        try await ai.waitForPending(1)

        task.priorityTag = .urgent
        let newFingerprint = fixture.fingerprint()
        #expect(newFingerprint != oldFingerprint)
        let newRequest = Task { await fixture.summarize(ai) }
        try await ai.waitForPending(2)

        // The newer request finishes first; then the obsolete one arrives late.
        ai.resumeNewest(with: .success("New summary"))
        #expect(await newRequest.value == "New summary")
        #expect(fixture.cache.summary(forFingerprint: newFingerprint) == "New summary")

        ai.resumeOldest(with: .success("Old summary"))
        #expect(await oldRequest.value == nil)
        #expect(fixture.cache.summary(forFingerprint: newFingerprint) == "New summary")
        #expect(fixture.cache.summary(forFingerprint: oldFingerprint) == nil)
    }

    @Test("Overlapping requests: an older request finishing first does not write the cache")
    func overlappingRequestsCacheOrdering() async throws {
        let fixture = try DigestFixture()
        let task = fixture.addTask("Draft report")
        let ai = DigestAIServiceStub(mode: .suspended)

        let oldFingerprint = fixture.fingerprint()
        let oldRequest = Task { await fixture.summarize(ai) }
        try await ai.waitForPending(1)

        task.title = "Draft final report"
        let newFingerprint = fixture.fingerprint()
        let newRequest = Task { await fixture.summarize(ai) }
        try await ai.waitForPending(2)

        // The older request completes while the newer one is still in flight.
        ai.resumeOldest(with: .success("Old summary"))
        #expect(await oldRequest.value == nil)
        #expect(fixture.cache.summary(forFingerprint: oldFingerprint) == nil)

        ai.resumeOldest(with: .success("New summary"))
        #expect(await newRequest.value == "New summary")
        #expect(fixture.cache.summary(forFingerprint: newFingerprint) == "New summary")
        #expect(fixture.cache.summary(forFingerprint: oldFingerprint) == nil)
        #expect(ai.callCount == 2)
    }

    @Test("Cache hit avoids a repeated AI request; content changes invalidate it")
    func cacheHitAndInvalidation() async throws {
        let fixture = try DigestFixture()
        let task = fixture.addTask("Pay rent")
        let ai = DigestAIServiceStub(mode: .immediate(.success("First")))

        #expect(await fixture.summarize(ai) == "First")
        ai.mode = .immediate(.success("Second"))
        #expect(await fixture.summarize(ai) == "First")
        #expect(ai.callCount == 1)

        task.isCompleted = true
        fixture.addIdea("Try a standing desk")
        #expect(await fixture.summarize(ai) == "Second")
        #expect(ai.callCount == 2)

        // A different service instance sharing the same storage reuses the persisted entry (relaunch).
        let relaunched = DailyDigestSummaryService(cache: fixture.cache)
        let afterRelaunch = await relaunched.summarize(
            tasks: fixture.tasks, ideas: fixture.ideas, notes: fixture.notes,
            languageCode: "en", aiService: ai, calendar: utc, now: noon
        )
        #expect(afterRelaunch == "Second")
        #expect(ai.callCount == 2)
    }

    @Test("Nothing to summarize: no AI request, localized quiet summary")
    func emptyDayDoesNotCallAI() async throws {
        let fixture = try DigestFixture()
        let ai = DigestAIServiceStub(mode: .immediate(.success("unused")))

        let summary = await fixture.summarize(ai)

        #expect(ai.callCount == 0)
        #expect(summary == AppLanguageStore.localized("digest.summary.quiet", languageCode: "en"))
    }

    @Test("Language change invalidates the cache and requests the new language")
    func languageChange() async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent")
        let ai = DigestAIServiceStub(mode: .immediate(.success("English summary")))

        #expect(await fixture.summarize(ai, language: "en") == "English summary")
        ai.mode = .immediate(.success("Русская сводка"))
        #expect(await fixture.summarize(ai, language: "ru") == "Русская сводка")
        #expect(ai.receivedLanguageCodes == ["en", "ru"])

        // The single-slot cache now holds the Russian entry only.
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint(language: "ru")) == "Русская сводка")
        #expect(fixture.cache.summary(forFingerprint: fixture.fingerprint(language: "en")) == nil)
    }

    @Test("Local fallback is localized for the requested language")
    func localFallbackIsLocalized() async throws {
        let fixture = try DigestFixture()
        fixture.addTask("Pay rent")
        let ai = DigestAIServiceStub(mode: .immediate(.failure(SimulatedAIFailure())))

        let english = await fixture.summarize(ai, language: "en")
        let russian = await fixture.summarize(ai, language: "ru")
        let kazakh = await fixture.summarize(ai, language: "kk")

        #expect(english == AppLanguageStore.localizedFormat("digest.summary.tasks_only", languageCode: "en", arguments: [Int64(1)]))
        #expect(russian == AppLanguageStore.localizedFormat("digest.summary.tasks_only", languageCode: "ru", arguments: [Int64(1)]))
        #expect(english != russian)
        #expect(russian != kazakh)
        #expect(russian?.contains("задач") == true)
    }

    @Test("Crossing midnight changes the fingerprint and triggers a fresh summary for the new day")
    func midnightBoundary() async throws {
        let fixture = try DigestFixture()
        let beforeMidnight = date("2026-11-13T23:59:00Z")
        let afterMidnight = date("2026-11-14T00:01:00Z")
        fixture.addIdea("Late-night idea", createdAt: date("2026-11-13T23:30:00Z"))
        let ai = DigestAIServiceStub(mode: .immediate(.success("Evening digest")))

        #expect(await fixture.summarize(ai, now: beforeMidnight) == "Evening digest")
        #expect(fixture.fingerprint(now: beforeMidnight) != fixture.fingerprint(now: afterMidnight))

        // After midnight yesterday's idea no longer counts: quiet day, no AI request, no stale evening digest.
        let nextDay = await fixture.summarize(ai, now: afterMidnight)
        #expect(nextDay == AppLanguageStore.localized("digest.summary.quiet", languageCode: "en"))
        #expect(ai.callCount == 1)
    }
}

// MARK: - Builder

@MainActor
@Suite("Daily digest builder")
struct DailyDigestBuilderTests {
    @Test("Tasks are ordered urgent → important → low, newest first within a priority")
    func priorityOrdering() throws {
        let container = try makeContainer()
        let tasks = [
            TaskItem(title: "low", isToday: true, priorityTag: .lowPriority, createdAt: noon),
            TaskItem(title: "important-old", isToday: true, priorityTag: .important, createdAt: noon.addingTimeInterval(-60)),
            TaskItem(title: "urgent", isToday: true, priorityTag: .urgent, createdAt: noon.addingTimeInterval(-120)),
            TaskItem(title: "important-new", isToday: true, priorityTag: .important, createdAt: noon),
            TaskItem(title: "done-urgent", isCompleted: true, isToday: true, priorityTag: .urgent, createdAt: noon),
        ]
        tasks.forEach { container.mainContext.insert($0) }

        let data = DailyDigestBuilder.make(tasks: tasks, ideas: [], notes: [], calendar: utc, now: noon)

        #expect(data.prioritizedTasks.map(\.title) == ["urgent", "important-new", "important-old", "low"])
        #expect(data.totalOpenTasksToday == 4)
    }

    @Test("Only the top five tasks are shown; the rest are counted as hidden")
    func taskLimit() throws {
        let tasks = (0 ..< 7).map { TaskItem(title: "t\($0)", isToday: true, createdAt: noon) }
        let data = DailyDigestBuilder.make(tasks: tasks, ideas: [], notes: [], calendar: utc, now: noon)
        #expect(data.prioritizedTasks.count == 5)
        #expect(data.hiddenTasksCount == 2)
    }

    @Test("'Today' uses the injected calendar and now, not the device clock")
    func usesInjectedNow() throws {
        let fixedPast = date("2020-02-29T10:00:00Z")
        let ideas = [IdeaItem(content: "leap-day idea", createdAt: fixedPast.addingTimeInterval(-3_600))]
        let notes = [NoteItem(content: "leap-day note", createdAt: fixedPast)]
        let tasks = [TaskItem(title: "created that day", isToday: false, createdAt: fixedPast)]

        let data = DailyDigestBuilder.make(tasks: tasks, ideas: ideas, notes: notes, calendar: utc, now: fixedPast)

        #expect(data.totalIdeasToday == 1)
        #expect(data.totalNotesToday == 1)
        #expect(data.totalOpenTasksToday == 1)
    }

    @Test("Midnight boundary: items from the previous day drop out after midnight")
    func midnightBoundary() {
        let idea = IdeaItem(content: "evening", createdAt: date("2026-11-13T23:30:00Z"))
        let task = TaskItem(title: "created yesterday", isToday: false, createdAt: date("2026-11-13T23:30:00Z"))
        let pinned = TaskItem(title: "pinned to today", isToday: true, createdAt: date("2026-11-10T09:00:00Z"))

        let before = DailyDigestBuilder.make(
            tasks: [task, pinned], ideas: [idea], notes: [], calendar: utc, now: date("2026-11-13T23:59:59Z")
        )
        let after = DailyDigestBuilder.make(
            tasks: [task, pinned], ideas: [idea], notes: [], calendar: utc, now: date("2026-11-14T00:00:00Z")
        )

        #expect(before.totalIdeasToday == 1)
        #expect(before.totalOpenTasksToday == 2)
        #expect(after.totalIdeasToday == 0)
        #expect(after.prioritizedTasks.map(\.title) == ["pinned to today"])
    }

    @Test("Time-zone boundary: the same instant belongs to different days in different zones")
    func timeZoneBoundary() {
        // 18:30 UTC = 23:30 in Almaty (UTC+5); now 19:30 UTC = 00:30 the next day in Almaty.
        let idea = IdeaItem(content: "boundary", createdAt: date("2026-11-13T18:30:00Z"))
        let now = date("2026-11-13T19:30:00Z")
        let almaty = calendar("Asia/Almaty")

        let inUTC = DailyDigestBuilder.make(tasks: [], ideas: [idea], notes: [], calendar: utc, now: now)
        let inAlmaty = DailyDigestBuilder.make(tasks: [], ideas: [idea], notes: [], calendar: almaty, now: now)

        #expect(inUTC.totalIdeasToday == 1)
        #expect(inAlmaty.totalIdeasToday == 0)

        let utcFingerprint = DailyDigestFingerprint.identifier(
            tasks: [], ideas: [idea], notes: [], languageCode: "en", calendar: utc, now: now
        )
        let almatyFingerprint = DailyDigestFingerprint.identifier(
            tasks: [], ideas: [idea], notes: [], languageCode: "en", calendar: almaty, now: now
        )
        #expect(utcFingerprint != almatyFingerprint)
    }

    @Test("Fingerprint is stable within a day and independent of input order")
    func fingerprintStability() {
        let a = TaskItem(title: "a", createdAt: noon)
        let b = TaskItem(title: "b", createdAt: noon)
        let morning = date("2026-11-13T00:00:00Z")
        let evening = date("2026-11-13T23:59:59Z")

        let first = DailyDigestFingerprint.identifier(
            tasks: [a, b], ideas: [], notes: [], languageCode: "en", calendar: utc, now: morning
        )
        let second = DailyDigestFingerprint.identifier(
            tasks: [b, a], ideas: [], notes: [], languageCode: "en", calendar: utc, now: evening
        )
        let otherLanguage = DailyDigestFingerprint.identifier(
            tasks: [a, b], ideas: [], notes: [], languageCode: "kk", calendar: utc, now: morning
        )

        #expect(first == second)
        #expect(first != otherLanguage)
    }
}
