//
//  ClarioApp.swift
//  Clario
//
//  Created by Диас Сайынов on 19.03.2026.
//

import SwiftUI
import SwiftData

@main
struct ClarioApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            IdeaItem.self,
            NoteItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError(AppLanguageStore.shared.localizedFormat("fatalerror.model_container", error.localizedDescription as NSString))
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: BrainCaptureViewModel(aiService: OpenAIService.live()))
        }
        .modelContainer(sharedModelContainer)
    }
}
