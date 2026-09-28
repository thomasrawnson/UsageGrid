import SwiftUI

struct ThemeGalleryView: View {
    @Bindable var preferences: ThemePreferences
    @Binding var previewTheme: UsageTheme?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(UsageTheme.all) { theme in
                ThemeGalleryCard(
                    theme: theme,
                    isSelected: preferences.activeTheme.id == theme.id,
                    select: { preferences.select(theme) },
                    preview: { previewTheme = theme }
                )
            }
        }
    }
}

private struct ThemeGalleryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: UsageTheme
    let isSelected: Bool
    let select: () -> Void
    let preview: () -> Void

    private var palette: UsageThemePalette { UsageThemePalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(theme.name).fontWeight(.semibold)
                if theme.isPremium {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.14), in: Capsule())
                        .accessibilityLabel("Pro theme")
                }
                Spacer()
                if isSelected {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Selected")
                }
            }

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(palette.canvas)
                RoundedRectangle(cornerRadius: 3).fill(palette.surface)
                RoundedRectangle(cornerRadius: 3).fill(palette.accent)
                RoundedRectangle(cornerRadius: 3).fill(palette.syntax)
            }
            .frame(height: 24)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border))
            .accessibilityHidden(true)

            if theme.isPremium {
                Button("Preview", action: preview)
            } else {
                Button(isSelected ? "Selected" : "Use theme", action: select)
                    .disabled(isSelected)
            }
        }
        .padding(9)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(theme.name) theme\(theme.isPremium ? ", Pro" : "")\(isSelected ? ", selected" : "")")
    }
}

struct ProThemePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTheme: UsageTheme

    init(theme: UsageTheme) {
        _selectedTheme = State(initialValue: theme)
    }

    private var palette: UsageThemePalette { UsageThemePalette(theme: selectedTheme, colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedTheme.name) Preview")
                        .font(.headline)
                    Text("Sample data — not live usage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            HStack(spacing: 8) {
                ForEach(UsageTheme.all.filter(\.isPremium)) { theme in
                    Button(theme.name) { selectedTheme = theme }
                        .buttonStyle(.bordered)
                        .tint(selectedTheme.id == theme.id ? palette.accent : nil)
                        .accessibilityAddTraits(selectedTheme.id == theme.id ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 12) {
                    ThemeSampleCard(state: .normal, palette: palette)
                    ThemeSampleCard(state: .stale, palette: palette)
                    ThemeSampleCard(state: .unavailable, palette: palette)
                    ThemeSampleCard(state: .error, palette: palette)
                }
                .padding([.horizontal, .bottom])
            }
        }
        .frame(width: 500, height: 640)
        .background(palette.canvas)
        .foregroundStyle(palette.primaryText)
    }
}

enum ThemePreviewState: String, CaseIterable {
    case normal
    case stale
    case unavailable
    case error

    var title: String {
        switch self {
        case .normal: "Normal"
        case .stale: "Stale"
        case .unavailable: "Unavailable"
        case .error: "Error"
        }
    }
}

struct ThemeSampleCard: View {
    let state: ThemePreviewState
    let palette: UsageThemePalette

    private let sampleWindow = CodexUsageWindow(
        id: "sample-primary",
        label: "3-hour limit · Sample",
        usedPercentage: 42,
        resetText: "Resets in 1h 24m",
        durationMinutes: 180
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusLabel
            if state == .normal || state == .stale {
                CodexWindowRow(
                    window: sampleWindow,
                    accent: palette.accent,
                    remainingCell: palette.remainingCell,
                    syntax: palette.syntax,
                    primaryText: palette.primaryText,
                    secondaryText: palette.secondaryText,
                    resetTextColor: palette.resetText
                )
            } else {
                Text(state == .unavailable ? "No sample usage window available" : "Sample request failed · Retry")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sample \(state.title.lowercased()) usage state")
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .normal:
            Label("Sample · Current", systemImage: "checkmark.circle.fill").foregroundStyle(palette.success)
        case .stale:
            Label("Sample · Stale · Refresh failed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(palette.warning)
        case .unavailable:
            Label("Sample · Usage unavailable", systemImage: "minus.circle.fill").foregroundStyle(palette.secondaryText)
        case .error:
            Label("Sample · Connection error", systemImage: "xmark.octagon.fill").foregroundStyle(palette.error)
        }
    }
}
