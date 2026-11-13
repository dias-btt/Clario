import Observation
import SwiftUI

struct CaptureComposerView: View {
    @Bindable var viewModel: BrainCaptureViewModel
    @Bindable private var languageStore = AppLanguageStore.shared
    let onSubmit: () -> Void

    var body: some View {
        composerContent()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 30, y: 14)
            .animation(.snappy, value: viewModel.isProcessing)
            .animation(.snappy, value: viewModel.errorMessage)
    }

    @ViewBuilder
    private func composerContent() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            composerHeaderRow()
            composerEditor()
            composerFooterRow()
        }
    }

    @ViewBuilder
    private func composerHeaderRow() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(languageStore.localized("composer.title"))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text(languageStore.localized("composer.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
            } label: {
                Image(systemName: "waveform")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(languageStore.localized("composer.voice_a11y"))
        }
    }

    @ViewBuilder
    private func composerEditor() -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.7), lineWidth: 1)
                }

            TextEditor(text: $viewModel.inputText)
                .scrollContentBackground(.hidden)
                .font(.system(.body, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 96, maxHeight: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.clear)

            if viewModel.inputText.isEmpty {
                Text(languageStore.localized("composer.placeholder"))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 21)
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(0.07), radius: 18, y: 10)
    }

    @ViewBuilder
    private func composerFooterRow() -> some View {
        HStack(spacing: 12) {
            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text(languageStore.localized("composer.organizing"))
                        .font(.footnote.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.76), in: Capsule())
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if let errorMessage = viewModel.errorMessage {
                Button {
                    viewModel.clearError()
                } label: {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.red)
                .transition(.opacity)
            }

            Spacer()

            Button(action: onSubmit) {
                HStack(spacing: 8) {
                    Text(viewModel.isProcessing ? languageStore.localized("composer.thinking") : languageStore.localized("composer.capture"))
                    Image(systemName: "arrow.up.circle.fill")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.33, green: 0.44, blue: 0.99),
                            Color(red: 0.51, green: 0.32, blue: 0.96)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: Color(red: 0.39, green: 0.37, blue: 0.98).opacity(0.3), radius: 16, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit)
            .opacity(viewModel.canSubmit ? 1 : 0.55)
            .scaleEffect(viewModel.canSubmit ? 1 : 0.98)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.canSubmit)
        }
    }
}
