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

    func submit(using modelContext: ModelContext) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isProcessing = true
        errorMessage = nil

        do {
            let result = try await aiService.process(input: text)
            persist(result, in: modelContext)
            inputText = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func persist(_ result: BrainParseResult, in modelContext: ModelContext) {
        withAnimation(.snappy) {
            result.tasks.forEach { modelContext.insert(TaskItem(title: $0)) }
            result.ideas.forEach { modelContext.insert(IdeaItem(content: $0)) }
            result.notes.forEach { modelContext.insert(NoteItem(content: $0)) }
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
