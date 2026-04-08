import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BrainCaptureViewModel {
    var inputText = ""
    var isProcessing = false
    var errorMessage: String?

    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    func submit() async -> CaptureDraft? {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        isProcessing = true
        errorMessage = nil

        do {
            let result = try await aiService.process(input: text)
            inputText = ""
            isProcessing = false
            return CaptureDraft(result: result)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
        return nil
    }

    func clearError() {
        errorMessage = nil
    }

    func persist(_ draft: CaptureDraft, in modelContext: ModelContext) {
        withAnimation(.snappy) {
            draft.keptTasks.forEach { modelContext.insert(TaskItem(title: $0)) }
            draft.keptIdeas.forEach { modelContext.insert(IdeaItem(content: $0)) }
            draft.keptNotes.forEach { modelContext.insert(NoteItem(content: $0)) }
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
