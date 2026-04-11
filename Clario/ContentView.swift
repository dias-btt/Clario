//
//  ContentView.swift
//  Clario
//
//  Created by Диас Сайынов on 19.03.2026.
//

import SwiftData
import SwiftUI

private enum AppTab {
    case tasks
    case ideas
    case notes
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @State private var viewModel: BrainCaptureViewModel
    @State private var selectedTab = AppTab.tasks
    @State private var isComposerPresented = false
    @State private var draft: CaptureDraft?

    init(viewModel: BrainCaptureViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                
                gradient()
                
                GeometryReader { geo in
                    ZStack(alignment: .bottomTrailing) {
                        tabView()
                        floatingButton(geo: geo)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            languageStore.code = "en"
                        } label: {
                            languageMenuRow(code: "en", title: "English")
                        }
                        Button {
                            languageStore.code = "ru"
                        } label: {
                            languageMenuRow(code: "ru", title: "Русский")
                        }
                        Button {
                            languageStore.code = "kk"
                        } label: {
                            languageMenuRow(code: "kk", title: "Қазақша")
                        }
                    } label: {
                        Image(systemName: "globe")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(red: 0.28, green: 0.35, blue: 0.96))
                    }
                    .accessibilityLabel(languageStore.localized("accessibility.language_menu"))
                }
            }
            .environment(\.locale, Locale(identifier: languageStore.code))
            .sheet(isPresented: $isComposerPresented) {
                NavigationStack {
                    CaptureComposerView(viewModel: viewModel) {
                        Task {
                            draft = await viewModel.submit()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(languageStore.localized("button.close")) {
                                isComposerPresented = false
                            }
                        }
                    }
                }
                .sheet(item: $draft) { initial in
                    CapturePreviewScreen(
                        initialDraft: initial,
                        onDiscard: {
                            draft = nil
                        },
                        onSave: { final in
                            viewModel.persist(final, in: modelContext)
                            draft = nil
                            isComposerPresented = false
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func languageMenuRow(code: String, title: String) -> some View {
        HStack {
            Text(title)
            if languageStore.code == code {
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
            }
        }
    }
    
    @ViewBuilder
    private func gradient() -> some View {
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
    }
    
    @ViewBuilder
    private func tabView() -> some View {
        TabView(selection: $selectedTab) {
            TasksScreen()
                .screenContainer()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .tag(AppTab.tasks)
                .tabItem {
                    Label(languageStore.localized("tab.tasks"), systemImage: "checklist")
                }

            IdeasScreen()
                .screenContainer()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .tag(AppTab.ideas)
                .tabItem {
                    Label(languageStore.localized("tab.ideas"), systemImage: "sparkles.rectangle.stack")
                }

            NotesScreen()
                .screenContainer()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .tag(AppTab.notes)
                .tabItem {
                    Label(languageStore.localized("tab.notes"), systemImage: "note.text")
                }
        }
        .tint(Color(red: 0.28, green: 0.35, blue: 0.96))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func floatingButton(geo: GeometryProxy) -> some View {
        Button {
            isComposerPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.33, green: 0.44, blue: 0.99),
                                    Color(red: 0.51, green: 0.32, blue: 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Color(red: 0.39, green: 0.37, blue: 0.98).opacity(0.35),
                            radius: 12,
                            y: 6
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageStore.localized("accessibility.new_capture"))
        .padding(.trailing, 20)
        .padding(.bottom, geo.safeAreaInsets.bottom + 52)
    }
}

extension View {
    func screenContainer() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 8)
            )
    }
}
