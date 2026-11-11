import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BrainCaptureViewModel {
    typealias ContextSaver = @MainActor (ModelContext) throws -> Void

    /// The user's original capture text. Only cleared after the resulting draft is saved successfully.
    var inputText = ""
    var isProcessing = false
    /// AI processing error, shown in the composer.
    var errorMessage: String?
    /// Persistence error, shown while the preview (and its unsaved draft) stays on screen.
    var saveErrorMessage: String?

    private let aiService: AIService
    private let saveContext: ContextSaver
    /// Identifies the in-flight submission. Results from any other (stale or cancelled) submission are ignored.
    private var activeSubmissionID: UUID?

    init(
        aiService: AIService,
        saveContext: @escaping ContextSaver = { try $0.save() }
    ) {
        self.aiService = aiService
        self.saveContext = saveContext
    }

    var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    /// Sends the current input to the AI service and returns a draft for review.
    ///
    /// Returns `nil` (without an error) for empty input, duplicate submissions while one is in flight,
    /// cancellation, or results that arrive after `cancelSubmission()`. `inputText` is never modified here.
    func submit() async -> CaptureDraft? {
        guard !isProcessing else { return nil }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let submissionID = UUID()
        activeSubmissionID = submissionID
        isProcessing = true
        errorMessage = nil

        defer {
            if activeSubmissionID == submissionID {
                activeSubmissionID = nil
                isProcessing = false
            }
        }

        do {
            let result = try await aiService.process(input: text)
            guard activeSubmissionID == submissionID, !Task.isCancelled else { return nil }
            return CaptureDraft(result: result)
        } catch {
            guard activeSubmissionID == submissionID, !Task.isCancelled, !Self.isCancellation(error) else {
                return nil
            }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Abandons the in-flight submission (e.g. the composer was dismissed). Any late result is discarded.
    func cancelSubmission() {
        activeSubmissionID = nil
        isProcessing = false
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSaveError() {
        saveErrorMessage = nil
    }

    /// Inserts the kept draft items and saves them.
    ///
    /// On success the original input is cleared and `true` is returned. On failure the items inserted here
    /// are removed from the context again (so a retry or a later autosave cannot create duplicates),
    /// `inputText` is preserved, `saveErrorMessage` is set, and `false` is returned.
    @discardableResult
    func persist(_ draft: CaptureDraft, in modelContext: ModelContext) -> Bool {
        var inserted: [any PersistentModel] = []

        withAnimation(.snappy) {
            for item in draft.tasks where item.isKept {
                let task = TaskItem(title: item.text, priorityTag: item.tag ?? .important)
                modelContext.insert(task)
                inserted.append(task)
            }
            for content in draft.keptIdeas {
                let idea = IdeaItem(content: content)
                modelContext.insert(idea)
                inserted.append(idea)
            }
            for content in draft.keptNotes {
                let note = NoteItem(content: content)
                modelContext.insert(note)
                inserted.append(note)
            }
        }

        do {
            try saveContext(modelContext)
        } catch {
            inserted.forEach { modelContext.delete($0) }
            saveErrorMessage = error.localizedDescription
            return false
        }

        saveErrorMessage = nil
        errorMessage = nil
        inputText = ""
        return true
    }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        if case let AIServiceError.network(underlying) = error { return isCancellation(underlying) }
        return false
    }
}
