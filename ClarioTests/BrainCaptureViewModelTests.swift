import Foundation
import SwiftData
import Testing
@testable import Clario

// MARK: - Test doubles

/// Deterministic AI service. Either answers immediately or suspends until the test resumes it.
@MainActor
final class ControllableAIService: AIService {
    enum Mode {
        case immediate(Result<AIResult, Error>)
        case suspended
    }

    var mode: Mode
    private(set) var processCallCount = 0
    private(set) var receivedInputs: [String] = []
    /// Number of suspended requests whose calling task was cancelled by the time they were resumed.
    private(set) var observedCancellations = 0
    private var pending: [CheckedContinuation<AIResult, Error>] = []

    init(mode: Mode) {
        self.mode = mode
    }

    var pendingCount: Int { pending.count }

    func process(input: String) async throws -> AIResult {
        processCallCount += 1
        receivedInputs.append(input)
        switch mode {
        case let .immediate(result):
            return try result.get()
        case .suspended:
            let result: Result<AIResult, Error>
            do {
                result = .success(try await withCheckedThrowingContinuation { pending.append($0) })
            } catch {
                result = .failure(error)
            }
            if Task.isCancelled { observedCancellations += 1 }
            return try result.get()
        }
    }

    func summarizeDailyDigest(structuredContext: String, languageCode: String) async throws -> String {
        ""
    }

    /// Resumes the oldest suspended request.
    func resumeOldest(with result: Result<AIResult, Error>) {
        pending.removeFirst().resume(with: result)
    }

    /// Waits until `count` requests are suspended inside the service.
    func waitForPending(_ count: Int) async throws {
        for _ in 0 ..< 1_000 where pending.count < count {
            await Task.yield()
        }
        try #require(pending.count >= count, "Expected \(count) suspended AI request(s)")
    }
}

@MainActor
final class ContextSaveSwitch {
    struct SimulatedSaveError: LocalizedError {
        var errorDescription: String? { "Simulated disk full" }
    }

    var shouldFail = false

    func save(_ context: ModelContext) throws {
        if shouldFail { throw SimulatedSaveError() }
        try context.save()
    }
}

// MARK: - Fixtures

private let sampleResult = AIResult(
    tasks: [
        AITask(title: "Call the bank", tag: .urgent),
        AITask(title: "Read chapter 3", tag: .lowPriority),
    ],
    ideas: ["Weekly reflection card"],
    notes: ["Rent is due on the 5th"]
)

private let originalInput = "  Call the bank today, read chapter 3 sometime. Rent is due on the 5th.  "

/// The container must outlive its context, so tests hold on to it for their whole duration.
@MainActor
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: TaskItem.self, IdeaItem.self, NoteItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
private func counts(in context: ModelContext) throws -> (tasks: Int, ideas: Int, notes: Int) {
    (
        try context.fetchCount(FetchDescriptor<TaskItem>()),
        try context.fetchCount(FetchDescriptor<IdeaItem>()),
        try context.fetchCount(FetchDescriptor<NoteItem>())
    )
}

// MARK: - Tests

@MainActor
@Suite("Capture workflow")
struct BrainCaptureViewModelTests {
    @Test("Successful capture and save stores items with priorities and clears input only after saving")
    func successfulCaptureAndSave() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ControllableAIService(mode: .immediate(.success(sampleResult)))
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let draft = try #require(await viewModel.submit())

        #expect(service.receivedInputs == [originalInput.trimmingCharacters(in: .whitespacesAndNewlines)])
        #expect(viewModel.inputText == originalInput, "Input must survive until the save is confirmed")
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.errorMessage == nil)

        #expect(viewModel.persist(draft, in: context))

        let tasks = try context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.title)]))
        #expect(tasks.map(\.title) == ["Call the bank", "Read chapter 3"])
        #expect(tasks.map(\.priorityTag) == [.urgent, .lowPriority])
        #expect(try counts(in: context) == (2, 1, 1))
        #expect(context.hasChanges == false)
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test("Only kept draft items are saved")
    func onlyKeptItemsAreSaved() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = BrainCaptureViewModel(aiService: ControllableAIService(mode: .immediate(.success(sampleResult))))
        viewModel.inputText = originalInput

        var draft = try #require(await viewModel.submit())
        draft.tasks[1].isKept = false
        draft.notes[0].isKept = false

        #expect(viewModel.persist(draft, in: context))
        #expect(try counts(in: context) == (1, 1, 0))
    }

    @Test("Discarding the preview keeps the original input and saves nothing")
    func discardPreservesInput() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let viewModel = BrainCaptureViewModel(aiService: ControllableAIService(mode: .immediate(.success(sampleResult))))
        viewModel.inputText = originalInput

        let draft = await viewModel.submit()
        #expect(draft != nil)
        // Discard == the preview drops the draft without calling persist.

        #expect(viewModel.inputText == originalInput)
        #expect(viewModel.canSubmit, "User can resubmit the same text after discarding")
        #expect(try counts(in: context) == (0, 0, 0))
    }

    @Test("AI failure keeps input and shows an error")
    func aiFailure() async throws {
        let service = ControllableAIService(
            mode: .immediate(.failure(AIServiceError.requestFailed(statusCode: 500, message: "Server error")))
        )
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let draft = await viewModel.submit()

        #expect(draft == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.inputText == originalInput)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.canSubmit)
    }

    @Test("Persistence failure keeps input, leaves no pending draft inserts, and preserves unrelated changes")
    func persistenceFailure() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let saveSwitch = ContextSaveSwitch()
        let viewModel = BrainCaptureViewModel(
            aiService: ControllableAIService(mode: .immediate(.success(sampleResult))),
            saveContext: { try saveSwitch.save($0) }
        )

        // Unrelated state: one saved task, then an unsaved edit to it and an unsaved unrelated note.
        let existing = TaskItem(title: "Existing", priorityTag: .important)
        context.insert(existing)
        try context.save()
        existing.title = "Existing (edited)"
        let unrelatedNote = NoteItem(content: "Unrelated pending note")
        context.insert(unrelatedNote)

        viewModel.inputText = originalInput
        let draft = try #require(await viewModel.submit())

        saveSwitch.shouldFail = true
        #expect(viewModel.persist(draft, in: context) == false)

        // Error surfaced, input kept.
        #expect(viewModel.saveErrorMessage == "Simulated disk full")
        #expect(viewModel.inputText == originalInput)

        // No draft items left as net pending inserts. SwiftData keeps an inserted-then-deleted model in both
        // the inserted and deleted sets until the next save, so assert on the net effect.
        let deletedIDs = Set(context.deletedModelsArray.map(\.persistentModelID))
        let netPendingInserts = context.insertedModelsArray.filter { !deletedIDs.contains($0.persistentModelID) }
        #expect(netPendingInserts.count == 1)
        #expect((netPendingInserts.first as? NoteItem)?.content == "Unrelated pending note")
        #expect(try counts(in: context) == (1, 0, 1))

        // Unrelated pending changes were not rolled back.
        #expect(existing.title == "Existing (edited)")
        #expect(context.hasChanges)

        // A later, unrelated save (e.g. autosave) must not persist the failed draft items.
        saveSwitch.shouldFail = false
        try context.save()
        #expect(context.insertedModelsArray.isEmpty)
        #expect(context.deletedModelsArray.isEmpty)
        #expect(context.hasChanges == false)
        let storeAfterUnrelatedSave = ModelContext(container)
        #expect(try counts(in: storeAfterUnrelatedSave) == (1, 0, 1))
        #expect(try storeAfterUnrelatedSave.fetch(FetchDescriptor<TaskItem>()).map(\.title) == ["Existing (edited)"])

        // Retrying the same draft saves exactly one copy of each item.
        #expect(viewModel.persist(draft, in: context))
        #expect(context.hasChanges == false)
        let store = ModelContext(container)
        let titles = try store.fetch(FetchDescriptor<TaskItem>()).map(\.title).sorted()
        #expect(titles == ["Call the bank", "Existing (edited)", "Read chapter 3"])
        #expect(try counts(in: store) == (3, 1, 2))
        #expect(viewModel.saveErrorMessage == nil)
        #expect(viewModel.inputText.isEmpty)
    }

    @Test("Edits made while AI is processing survive a successful save")
    func editsDuringProcessingSurviveSave() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let submission = Task { await viewModel.submit() }
        try await service.waitForPending(1)

        let newerText = originalInput + " Also: book dentist."
        viewModel.inputText = newerText
        service.resumeOldest(with: .success(sampleResult))
        let draft = try #require(await submission.value)

        #expect(draft.sourceText == originalInput.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(viewModel.persist(draft, in: context))
        #expect(viewModel.inputText == newerText, "Newer edits must not be cleared by saving an older draft")
        #expect(try counts(in: context) == (2, 1, 1))
    }

    @Test("A second submission while one is in flight is ignored")
    func duplicateSubmission() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let first = Task { await viewModel.submit() }
        try await service.waitForPending(1)
        #expect(viewModel.isProcessing)
        #expect(viewModel.canSubmit == false)

        let duplicate = await viewModel.submit()
        #expect(duplicate == nil)
        #expect(service.processCallCount == 1)

        service.resumeOldest(with: .success(sampleResult))
        let firstDraft = await first.value
        #expect(firstDraft != nil)
        #expect(viewModel.isProcessing == false)
    }

    @Test("Task cancellation is not reported as an error")
    func cancellationIsSilent() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let task = Task { await viewModel.submit() }
        try await service.waitForPending(1)
        task.cancel()
        service.resumeOldest(with: .failure(AIServiceError.network(URLError(.cancelled))))

        #expect(await task.value == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.inputText == originalInput)
    }

    @Test("A successful result that arrives after the task was cancelled is discarded")
    func cancelledTaskIgnoresLateSuccess() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let task = Task { await viewModel.submit() }
        try await service.waitForPending(1)
        task.cancel()
        service.resumeOldest(with: .success(sampleResult))

        #expect(await task.value == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isProcessing == false)
    }

    @Test("Results from an abandoned submission do not affect a newer one")
    func staleResponseIgnored() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let stale = Task { await viewModel.submit() }
        try await service.waitForPending(1)

        // Composer dismissed: the in-flight request is abandoned.
        viewModel.cancelSubmission()
        #expect(viewModel.isProcessing == false)

        // User reopens and submits again.
        let current = Task { await viewModel.submit() }
        try await service.waitForPending(2)

        // The stale request fails late; it must not surface an error or end the current request.
        service.resumeOldest(with: .failure(AIServiceError.invalidResponse))
        #expect(await stale.value == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isProcessing, "Newer submission is still in flight")

        service.resumeOldest(with: .success(sampleResult))
        let draft = try #require(await current.value)
        #expect(draft.tasks.count == 2)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.inputText == originalInput)
    }

    @Test("A late success after dismissal is dropped")
    func lateSuccessAfterDismissalDropped() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput

        let task = Task { await viewModel.submit() }
        try await service.waitForPending(1)
        viewModel.cancelSubmission()
        service.resumeOldest(with: .success(sampleResult))

        #expect(await task.value == nil)
        #expect(viewModel.isProcessing == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("UI submission delivers the draft once and becomes idle")
    func startSubmissionDeliversDraft() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput
        var delivered: [CaptureDraft] = []

        #expect(viewModel.startSubmission { delivered.append($0) })
        #expect(viewModel.hasActiveSubmission)
        let task = try #require(viewModel.submissionTask)
        try await service.waitForPending(1)

        service.resumeOldest(with: .success(sampleResult))
        await task.value

        #expect(delivered.count == 1)
        #expect(viewModel.hasActiveSubmission == false)
        #expect(viewModel.canSubmit)
    }

    @Test("Dismissal cancels immediately: a result arriving afterwards is never delivered")
    func dismissalBeforeLateResult() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput
        var delivered = 0

        viewModel.startSubmission { _ in delivered += 1 }
        let task = try #require(viewModel.submissionTask)
        try await service.waitForPending(1)

        // Dismissal begins (Close tapped / isPresented flips to false).
        viewModel.cancelSubmission()
        #expect(viewModel.hasActiveSubmission == false)

        service.resumeOldest(with: .success(sampleResult))
        await task.value

        #expect(delivered == 0)
        #expect(service.observedCancellations == 1, "The in-flight request's task must be cancelled")
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.inputText == originalInput)
    }

    @Test("Cancelling before the submission task starts does not call the AI service")
    func cancelBeforeTaskStarts() async throws {
        let service = ControllableAIService(mode: .immediate(.success(sampleResult)))
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput
        var delivered = 0

        viewModel.startSubmission { _ in delivered += 1 }
        let task = try #require(viewModel.submissionTask)
        viewModel.cancelSubmission()
        await task.value

        #expect(delivered == 0)
        #expect(service.processCallCount == 0)
        #expect(viewModel.isProcessing == false)
    }

    @Test("Rapid repeated taps start only one UI submission, and cancellation targets it")
    func rapidTapsStartOneSubmission() async throws {
        let service = ControllableAIService(mode: .suspended)
        let viewModel = BrainCaptureViewModel(aiService: service)
        viewModel.inputText = originalInput
        var delivered = 0

        // Synchronous back-to-back taps, before the first task has run and set isProcessing.
        #expect(viewModel.startSubmission { _ in delivered += 1 })
        let active = try #require(viewModel.submissionTask)
        #expect(viewModel.startSubmission { _ in delivered += 100 } == false)
        #expect(viewModel.startSubmission { _ in delivered += 100 } == false)
        #expect(viewModel.canSubmit == false)

        try await service.waitForPending(1)
        for _ in 0 ..< 50 { await Task.yield() }
        #expect(service.processCallCount == 1)

        viewModel.cancelSubmission()
        service.resumeOldest(with: .success(sampleResult))
        await active.value

        #expect(service.observedCancellations == 1)
        #expect(delivered == 0)
        #expect(viewModel.canSubmit)
    }

    @Test("Cancellation errors are recognised, ordinary failures are not")
    func cancellationClassification() {
        #expect(BrainCaptureViewModel.isCancellation(CancellationError()))
        #expect(BrainCaptureViewModel.isCancellation(URLError(.cancelled)))
        #expect(BrainCaptureViewModel.isCancellation(AIServiceError.network(URLError(.cancelled))))
        #expect(!BrainCaptureViewModel.isCancellation(AIServiceError.network(URLError(.notConnectedToInternet))))
        #expect(!BrainCaptureViewModel.isCancellation(AIServiceError.invalidResponse))
    }
}
