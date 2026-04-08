import SwiftUI

struct CapturePreviewScreen: View {
    @State private var draft: CaptureDraft
    let onDiscard: () -> Void
    let onSave: (CaptureDraft) -> Void

    @Bindable private var languageStore = AppLanguageStore.shared

    init(
        initialDraft: CaptureDraft,
        onDiscard: @escaping () -> Void,
        onSave: @escaping (CaptureDraft) -> Void
    ) {
        _draft = State(initialValue: initialDraft)
        self.onDiscard = onDiscard
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                if !draft.tasks.isEmpty {
                    section(
                        title: languageStore.localized("preview.section.tasks"),
                        systemImage: "checklist",
                        items: $draft.tasks
                    )
                }

                if !draft.ideas.isEmpty {
                    section(
                        title: languageStore.localized("preview.section.ideas"),
                        systemImage: "sparkles.rectangle.stack",
                        items: $draft.ideas
                    )
                }

                if !draft.notes.isEmpty {
                    section(
                        title: languageStore.localized("preview.section.notes"),
                        systemImage: "note.text",
                        items: $draft.notes
                    )
                }

                if draft.tasks.isEmpty, draft.ideas.isEmpty, draft.notes.isEmpty {
                    Text(languageStore.localized("preview.empty"))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(languageStore.localized("preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageStore.localized("preview.discard")) {
                        onDiscard()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(languageStore.localized("preview.keep_all")) {
                        draft.keepAll()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        draft.removeAll()
                    } label: {
                        Text(languageStore.localized("preview.remove_all"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onSave(draft)
                    } label: {
                        Text(languageStore.localized("preview.save"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.keptTasks.isEmpty && draft.keptIdeas.isEmpty && draft.keptNotes.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private func section(
        title: String,
        systemImage: String,
        items: Binding<[CaptureDraft.Item]>
    ) -> some View {
        let keptCount = items.wrappedValue.filter(\.isKept).count
        let totalCount = items.wrappedValue.count

        Section {
            ForEach(items) { $item in
                Button {
                    item.isKept.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.isKept ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isKept ? Color(red: 0.28, green: 0.35, blue: 0.96) : .secondary)

                        Text(item.text)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if let idx = items.wrappedValue.firstIndex(where: { $0.id == item.id }) {
                            items.wrappedValue.remove(at: idx)
                        }
                    } label: {
                        Label(languageStore.localized("preview.delete"), systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(languageStore.localizedFormat("preview.count", keptCount, totalCount))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

