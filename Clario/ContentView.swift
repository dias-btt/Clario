//
//  ContentView.swift
//  Clario
//
//  Created by Диас Сайынов on 19.03.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BrainCaptureViewModel
    @State private var selectedTab = AppTab.tasks

    init(viewModel: BrainCaptureViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.0),
                        Color(red: 0.95, green: 0.96, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    CaptureComposerView(viewModel: viewModel) {
                        Task {
                            await viewModel.submit(using: modelContext)
                        }
                    }

                    TabView(selection: $selectedTab) {
                        TasksScreen()
                            .tag(AppTab.tasks)
                            .tabItem {
                                Label("Tasks", systemImage: "checklist")
                            }

                        IdeasScreen()
                            .tag(AppTab.ideas)
                            .tabItem {
                                Label("Ideas", systemImage: "sparkles.rectangle.stack")
                            }

                        NotesScreen()
                            .tag(AppTab.notes)
                            .tabItem {
                                Label("Notes", systemImage: "note.text")
                            }
                    }
                    .tint(Color(red: 0.28, green: 0.35, blue: 0.96))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private enum AppTab {
    case tasks
    case ideas
    case notes
}

#Preview {
    ContentView(viewModel: BrainCaptureViewModel(aiService: MockAIService()))
        .modelContainer(PreviewSampleData.container)
}
