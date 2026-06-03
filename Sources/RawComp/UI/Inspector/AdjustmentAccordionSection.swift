import SwiftUI

struct AdjustmentAccordionSection<Content: View>: View {
    let section: AdjustmentSectionID
    let isExpanded: Bool
    let isEnabled: Bool
    let showsEnableToggle: Bool
    let isActive: Bool
    let onToggleExpanded: () -> Void
    let onToggleEnabled: () -> Void
    let onReset: () -> Void
    var onCopySection: (() -> Void)?
    var onPasteSection: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .padding(.top, 4)
                .opacity(isEnabled ? 1 : 0.45)
                .allowsHitTesting(isEnabled)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.28))
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onToggleExpanded) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    L10n.text(section.titleKey)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if isActive {
                        Text(L10n.string("inspector.badge.active"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsEnableToggle {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            guard newValue != isEnabled else {
                                return
                            }
                            Task { @MainActor in
                                onToggleEnabled()
                            }
                        }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            if showsEnableToggle {
                Button(action: { onCopySection?() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help(L10n.string("section.copy"))

                Button(action: { onPasteSection?() }) {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help(L10n.string("section.paste"))
            }

            Button(L10n.string("common.reset"), action: onReset)
                .buttonStyle(.borderless)
                .font(.caption)
                .help(L10n.string("inspector.section.reset_option_hint"))
                .disabled(!isActive && !showsEnableToggle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(headerBarBackground)
        .overlay(headerBarBorder)
        .overlay(alignment: .bottom) {
            if isExpanded {
                Divider()
                    .opacity(0.35)
            }
        }
    }

    private var headerBarBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                Color(nsColor: .controlBackgroundColor)
                    .opacity(isExpanded ? 0.78 : 0.52)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(isActive ? 0.06 : 0))
            )
    }

    private var headerBarBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(isExpanded ? 0.1 : 0.07), lineWidth: 0.5)
    }
}
