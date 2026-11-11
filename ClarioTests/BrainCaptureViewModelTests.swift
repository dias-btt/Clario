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
            return try await withCheckedThrowingContinuation { pending.append($0) }
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

    @Test("Persistence failure keeps the draft input, reports an error, and leaves no unsaved inserts behind")
    func persistenceFailure() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let saveSwitch = ContextSaveSwitch()
        saveSwitch.shouldFail = true
        let viewModel = BrainCaptureViewModel(
            aiService: ControllableAIService(mode: .immediate(.success(sampleResult))),
            saveContext: { try saveSwitch.save($0) }
        )
        viewModel.inputText = originalInput
        let draft = try #require(await viewModel.submit())

        let saved = viewModel.persist(draft, in: context)

        #expect(saved == false)
        #expect(viewModel.saveErrorMessage == "Simulated disk full")
        #expect(viewModel.inputText == originalInput)
        #expect(try counts(in: context) == (0, 0, 0), "Failed inserts must not linger for a later autosave")

        // Retrying the same draft after the problem is resolved saves exactly one copy.
        saveSwitch.shouldFail = false
        #expect(viewModel.persist(draft, in: context))
        #expect(try counts(in: context) == (2, 1, 1))
        #expect(viewModel.saveErrorMessage == nil)
        #expect(viewModel.inputText.isEmpty)
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

    @Test("Cancellation errors are recognised, ordinary failures are not")
    func cancellationClassification() {
        #expect(BrainCaptureViewModel.isCancellation(CancellationError()))
        #expect(BrainCaptureViewModel.isCancellation(URLError(.cancelled)))
        #expect(BrainCaptureViewModel.isCancellation(AIServiceError.network(URLError(.cancelled))))
        #expect(!BrainCaptureViewModel.isCancellation(AIServiceError.network(URLError(.notConnectedToInternet))))
        #expect(!BrainCaptureViewModel.isCancellation(AIServiceError.invalidResponse))
    }
}
