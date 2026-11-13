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
    private let aiService: AIService = OpenAIService.live()

    private static var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

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
            if Self.isHostingUnitTests {
                // Unit tests use their own in-memory containers and mock AI services;
                // don't start the real UI (which can trigger network AI calls) in the test host.
                Color.clear
            } else {
                ContentView(viewModel: BrainCaptureViewModel(aiService: aiService))
                    .environment(\.aiService, aiService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
