//
//  ContentView.swift
//  Clario
//
//  Created by Диас Сайынов on 19.03.2026.
//

import SwiftData
import SwiftUI
import UIKit

private enum AppTab {
    case tasks
    case ideas
    case notes
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var languageStore = AppLanguageStore.shared
    @State private var viewModel: BrainCaptureViewModel
    @State private var selectedTab = AppTab.tasks
    @State private var isComposerPresented = false
    @State private var draft: CaptureDraft?

    init(viewModel: BrainCaptureViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.saveErrorMessage != nil },
            set: { if !$0 { viewModel.clearSaveError() } }
        )
    }

    /// Invalidates any in-flight AI request. Called synchronously as soon as dismissal begins.
    private func cancelPendingSubmission() {
        viewModel.cancelSubmission()
    }

    private func dismissComposer() {
        cancelPendingSubmission()
        isComposerPresented = false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clarioScreenBackground(colorScheme: colorScheme)

                GeometryReader { geo in
                    ZStack(alignment: .bottomTrailing) {
                        tabView()
                        FloatingCaptureButton(
                            accessibilityLabel: languageStore.localized("accessibility.new_capture")
                        ) {
                            isComposerPresented = true
                        }
                        .padding(.trailing, 22)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 54)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [ClarioPalette.indigo, ClarioPalette.indigoDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .accessibilityLabel(languageStore.localized("accessibility.language_menu"))
                }
            }
            .environment(\.locale, Locale(identifier: languageStore.code))
            .onChange(of: isComposerPresented) { _, isPresented in
                if !isPresented { cancelPendingSubmission() }
            }
            .sheet(isPresented: $isComposerPresented, onDismiss: cancelPendingSubmission) {
                NavigationStack {
                    CaptureComposerView(viewModel: viewModel) {
                        viewModel.startSubmission { result in
                            // Never present a result once the composer is going away.
                            guard isComposerPresented else { return }
                            draft = result
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(languageStore.localized("button.close")) {
                                dismissComposer()
                            }
                        }
                    }
                }
                // While AI is processing, dismissal goes through Close, which cancels before dismissing.
                .interactiveDismissDisabled(viewModel.hasActiveSubmission)
                .sheet(item: $draft) { initial in
                    CapturePreviewScreen(
                        initialDraft: initial,
                        onDiscard: {
                            // The original input stays in the composer.
                            draft = nil
                        },
                        onSave: { final in
                            // Only dismiss after a confirmed save; on failure the preview keeps the edited draft.
                            guard viewModel.persist(final, in: modelContext) else { return }
                            draft = nil
                            dismissComposer()
                        }
                    )
                    .alert(
                        languageStore.localized("preview.save_error.title"),
                        isPresented: saveErrorBinding
                    ) {
                        Button(languageStore.localized("button.ok"), role: .cancel) {
                            viewModel.clearSaveError()
                        }
                    } message: {
                        Text(languageStore.localizedFormat(
                            "preview.save_error.message",
                            (viewModel.saveErrorMessage ?? "") as NSString
                        ))
                    }
                }
            }
        }
        .tint(ClarioPalette.indigo)
        .onAppear {
            configureTabBarAppearance()
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
    private func tabView() -> some View {
        TabView(selection: $selectedTab) {
            TasksScreen()
                .screenContainer(colorScheme: colorScheme)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .tag(AppTab.tasks)
                .tabItem {
                    Label(languageStore.localized("tab.tasks"), systemImage: "checklist")
                }

            IdeasScreen()
                .screenContainer(colorScheme: colorScheme)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .tag(AppTab.ideas)
                .tabItem {
                    Label(languageStore.localized("tab.ideas"), systemImage: "sparkles.rectangle.stack")
                }

            NotesScreen()
                .screenContainer(colorScheme: colorScheme)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .tag(AppTab.notes)
                .tabItem {
                    Label(languageStore.localized("tab.notes"), systemImage: "note.text")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.backgroundColor = UIColor(red: 248 / 255, green: 250 / 255, blue: 252 / 255, alpha: 0.88)
        let muted = UIColor(red: 100 / 255, green: 116 / 255, blue: 139 / 255, alpha: 1)
        let indigo = UIColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255, alpha: 1)
        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = muted
        normal.titleTextAttributes = [.foregroundColor: muted]
        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = indigo
        selected.titleTextAttributes = [.foregroundColor: indigo]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    func screenContainer(colorScheme: ColorScheme) -> some View {
        self
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(ClarioPalette.cardSurface(colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ClarioPalette.cardStroke(colorScheme), lineWidth: 1)
                    )
                    .clarioCardShadow(colorScheme: colorScheme)
            )
    }
}
