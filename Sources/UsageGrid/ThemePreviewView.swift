import SwiftUI

struct ThemeGalleryView: View {
    @Bindable var preferences: ThemePreferences
    @Bindable var proAccess: ProAccessController
    @Binding var previewTheme: UsageTheme?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(UsageTheme.all) { theme in
                ThemeGalleryCard(
                    theme: theme,
                    isSelected: preferences.activeTheme.id == theme.id,
                    canSelect: proAccess.effectiveAccess.canSelect(theme),
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
    let canSelect: Bool
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

            ThemeMiniPreview(theme: theme, palette: palette)
                .frame(height: 42)
            .accessibilityHidden(true)

            if theme.isPremium {
                HStack {
                    if canSelect {
                        Button(isSelected ? "Selected" : "Use theme", action: select)
                            .disabled(isSelected)
                    }
                    Button("Preview", action: preview)
                }
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
            ViewThatFits(in: .horizontal) {
                HStack {
                    previewHeading
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                VStack(alignment: .leading, spacing: 8) {
                    previewHeading
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 7) {
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
                    ThemeSampleCard(theme: selectedTheme, state: .normal, palette: palette)
                    ThemeSampleCard(theme: selectedTheme, state: .stale, palette: palette)
                    ThemeSampleCard(theme: selectedTheme, state: .unavailable, palette: palette)
                    ThemeSampleCard(theme: selectedTheme, state: .error, palette: palette)
                }
                .padding([.horizontal, .bottom])
            }
        }
        .frame(minWidth: 440, idealWidth: 500, maxWidth: 600,
               minHeight: 420, idealHeight: 620, maxHeight: 720)
        .background {
            ZStack {
                palette.canvas
                ThemeDecorationView(theme: selectedTheme, palette: palette)
            }
        }
        .foregroundStyle(palette.primaryText)
    }

    private var previewHeading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(selectedTheme.name) Preview").font(.headline)
            Text("Sample data — not live usage")
                .font(.caption).foregroundStyle(palette.secondaryText)
        }
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
    let theme: UsageTheme
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
                    palette: palette
                )
            } else {
                Text(state == .unavailable ? "No sample usage window available" : "Sample request failed · Retry")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: palette.cardRadius).fill(palette.surface)
                ThemeDecorationView(theme: theme, palette: palette).clipShape(RoundedRectangle(cornerRadius: palette.cardRadius))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border, lineWidth: theme.id == .retro ? 2 : 1))
        .shadow(color: palette.usesGlow ? palette.accent.opacity(0.24) : .black.opacity(theme.id == .professional ? 0.10 : 0), radius: palette.usesGlow ? 7 : 3, y: 2)
        .fontDesign(palette.fontDesign)
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

private struct ThemeMiniPreview: View {
    let theme: UsageTheme
    let palette: UsageThemePalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, palette.cardRadius)).fill(palette.canvas)
            ThemeDecorationView(theme: theme, palette: palette)
                .clipShape(RoundedRectangle(cornerRadius: min(8, palette.cardRadius)))
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    miniCell(filled: index < 6)
                }
            }
            .padding(.horizontal, 8)
        }
        .overlay(RoundedRectangle(cornerRadius: min(8, palette.cardRadius)).stroke(palette.border))
    }

    @ViewBuilder
    private func miniCell(filled: Bool) -> some View {
        let color = filled ? palette.accent : palette.remainingCell
        switch palette.cellShape {
        case .square: Rectangle().fill(color).aspectRatio(1, contentMode: .fit)
        case .roundedSquare: RoundedRectangle(cornerRadius: 2).fill(color).aspectRatio(1, contentMode: .fit)
        case .circle: Circle().fill(color).aspectRatio(1, contentMode: .fit)
        }
    }
}

struct ThemeExportPreview: View {
    let theme: UsageTheme
    let palette: UsageThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.name).font(.system(.title, design: palette.fontDesign).weight(.bold))
                    Text("UsageGrid theme preview · SAMPLE DATA")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Text(theme.isPremium ? "PRO PREVIEW" : "FREE")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(palette.selectedTab, in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(ThemePreviewState.allCases, id: \.rawValue) { state in
                    ThemeSampleCard(theme: theme, state: state, palette: palette)
                }
            }
        }
        .padding(22)
        .frame(width: 940, height: 650, alignment: .topLeading)
        .background {
            ZStack {
                palette.canvas
                ThemeDecorationView(theme: theme, palette: palette)
            }
        }
        .foregroundStyle(palette.primaryText)
    }
}
