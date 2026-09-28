import SwiftUI
import AppKit
import Observation

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var alerts: UsageAlertController
    @Bindable var themePreferences: ThemePreferences
    @Bindable var history: UsageHistoryController
    @State private var selectedProvider: SelectedProvider = .codex
    @State private var presentation = PopupPresentationState()

    private var palette: UsageThemePalette { UsageThemePalette(theme: themePreferences.activeTheme, colorScheme: colorScheme) }

    var body: some View {
        Group {
            switch presentation.page {
            case .usage:
                ViewThatFits(in: .vertical) {
                    usagePanel
                    ScrollView {
                        usagePanel
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            case .historyPreview:
                UsageHistoryPreviewContent(theme: themePreferences.activeTheme, closeTitle: "Back to usage") {
                    presentation.showUsage()
                }
            }
        }
        .frame(width: 350)
        .frame(maxHeight: maximumPopupHeight, alignment: .top)
        .background {
            ZStack {
                palette.canvas
                ThemeDecorationView(theme: themePreferences.activeTheme, palette: palette)
            }
        }
        .onAppear {
            presentation.showUsage()
            codex.successfulRefreshHandler = { windows, observedAt in
                Task { await alerts.evaluate(windows: windows, isFresh: true) }
                Task { await history.record(windows: windows, observedAt: observedAt) }
            }
            Task { await history.load() }
            codex.activate()
            refreshCodex()
        }
        .onDisappear { presentation.popupDismissed() }
    }

    private var maximumPopupHeight: CGFloat {
        min(680, max(360, (NSScreen.main?.visibleFrame.height ?? 760) - 48))
    }

    private var usagePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("//")
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                Text("UsageGrid")
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 4)
                if selectedProvider == .codex, let lastUpdated = codex.lastUpdated {
                    Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(.caption, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(palette.secondaryText)
                        .accessibilityLabel("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                }
                if selectedProvider == .codex {
                    if codex.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                            .accessibilityLabel("Refreshing Codex usage")
                    } else {
                        Button(action: refreshCodex) {
                            Image(systemName: "arrow.clockwise")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("Refresh Codex usage")
                        .help("Refresh Codex usage")
                    }
                }
            }
            .font(.system(.headline, design: .monospaced))

            HStack(spacing: 0) {
                providerTab(.codex, title: "Codex")
                providerTab(.claude, title: "Claude")
            }
            .background(palette.surface)
            .overlay(Rectangle().stroke(palette.border, lineWidth: 1).allowsHitTesting(false))

            if selectedProvider == .codex {
                if codex.isStale {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(">")
                                .foregroundStyle(palette.syntax)
                                .accessibilityHidden(true)
                            Text("Stale · \(codex.errorMessage ?? "Refresh failed")")
                                .foregroundStyle(palette.secondaryText)
                        }
                        Button("Retry", action: refreshCodex)
                            .buttonStyle(.plain)
                            .foregroundStyle(palette.accent)
                    }
                    .font(.system(.caption, design: .monospaced))
                }

                HStack(spacing: 6) {
                    Text("#")
                        .foregroundStyle(palette.syntax)
                        .accessibilityHidden(true)
                    Text("Codex")
                }
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(palette.primaryText)

                VStack(alignment: .leading, spacing: 14) {
                    if let setupState = codex.setupState {
                        CodexSetupStatusView(state: setupState, retry: refreshCodex)
                    } else if let codexWindows = codex.windows {
                        ForEach(codexWindows, id: \.id) { window in
                            CodexWindowRow(window: window, palette: palette)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border, lineWidth: 1))
                .shadow(color: palette.usesGlow ? palette.accent.opacity(0.22) : .clear, radius: 7)
            } else {
                HStack(spacing: 6) {
                    Text("#")
                        .foregroundStyle(palette.syntax)
                        .accessibilityHidden(true)
                    Text("Claude")
                }
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(palette.secondaryText)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(">")
                            .foregroundStyle(palette.syntax)
                            .accessibilityHidden(true)
                        Text("Usage unavailable")
                    }
                    .foregroundStyle(palette.secondaryText)
                    Text("Claude integration is unavailable. Codex setup does not connect Claude.")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border, lineWidth: 1))
            }

            Divider()

            if selectedProvider == .codex {
                VStack(alignment: .leading, spacing: 5) {
                    if ThemeAccess.production.canViewUsageHistory {
                        UsageSessionChangeView(change: history.session.change, isFresh: !codex.isStale && !codex.refreshFailed, isRecording: history.isRecording)
                    } else {
                        Text(history.isRecording ? "History recording on · viewing planned for Pro" : "History recording off")
                            .font(.caption)
                    }
                    Button("Preview usage history") { presentation.showHistoryPreview() }
                        .foregroundStyle(palette.accent)
                }
                .foregroundStyle(palette.secondaryText)
                .buttonStyle(.plain)
            }

            HStack {
                Button("Settings") {
                    openSettings()
                }
                .foregroundStyle(palette.accent)
                Spacer()
                Button("Quit UsageGrid") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(palette.secondaryText)
            }
            .buttonStyle(.plain)
            .font(.system(.callout, design: .monospaced))
            .padding(.horizontal, 4)
        }
        .padding(14)
        .fontDesign(palette.fontDesign)
    }

    private func refreshCodex() {
        codex.requestRefresh()
    }

    private func providerTab(_ provider: SelectedProvider, title: String) -> some View {
        let isSelected = selectedProvider == provider
        return Button {
            switch provider {
            case .codex: selectedProvider = .codex
            case .claude: selectedProvider = .claude
            }
        } label: {
            Text(title)
                .font(.system(.callout, design: .monospaced).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(isSelected ? palette.selectedTab : Color.clear)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? palette.accent : Color.clear)
                        .frame(height: 2)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) provider")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum SelectedProvider {
    case codex
    case claude
}

enum PopupPage {
    case usage
    case historyPreview
}

struct PopupPresentationState {
    private(set) var page: PopupPage = .usage
    mutating func showHistoryPreview() { page = .historyPreview }
    mutating func showUsage() { page = .usage }
    mutating func popupDismissed() { page = .usage }
}

struct CodexRefreshState {
    private(set) var windows: [CodexUsageWindow]?
    private(set) var isRefreshing = false
    private(set) var refreshFailed = false
    private(set) var lastUpdated: Date?
    private(set) var errorMessage: String?
    private(set) var lastError: CodexUsageReadError?
    var isStale: Bool { refreshFailed && windows != nil }

    mutating func start() -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        return true
    }

    mutating func finish(with newWindows: [CodexUsageWindow]?, at date: Date) {
        finish(with: CodexUsageReadResult(windows: newWindows, error: newWindows == nil ? .decodingFailed : nil), at: date)
    }

    mutating func finish(with result: CodexUsageReadResult, at date: Date) {
        guard isRefreshing else { return }
        isRefreshing = false
        if let newWindows = result.windows {
            windows = newWindows
            lastUpdated = date
            refreshFailed = false
            errorMessage = nil
            lastError = nil
        } else {
            refreshFailed = true
            errorMessage = result.error?.userMessage
            lastError = result.error
        }
    }
}

@MainActor
@Observable
final class CodexRefreshCoordinator {
    private var state = CodexRefreshState()
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var lastWakeRequestAt: Date?
    @ObservationIgnored var successfulRefreshHandler: (([CodexUsageWindow], Date) -> Void)?

    var windows: [CodexUsageWindow]? { state.windows }
    var isRefreshing: Bool { state.isRefreshing }
    var refreshFailed: Bool { state.refreshFailed }
    var isStale: Bool { state.isStale }
    var lastUpdated: Date? { state.lastUpdated }
    var errorMessage: String? { state.errorMessage }
    var lastError: CodexUsageReadError? { state.lastError }
    var setupState: CodexSetupState? { CodexSetupState.from(state) }

    func activate() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.requestRefresh() }
        }
    }

    @discardableResult
    func requestRefresh(
        reader: @escaping @Sendable () async -> CodexUsageReadResult = { await CodexUsageReader.read() }
    ) -> Bool {
        guard refreshTask == nil, state.start() else { return false }
        refreshTask = Task { [weak self] in
            let result = await reader()
            guard let self else { return }
            state.finish(with: result, at: Date())
            if let windows = result.windows, let lastUpdated = state.lastUpdated {
                successfulRefreshHandler?(windows, lastUpdated)
            }
            refreshTask = nil
        }
        return true
    }

    @discardableResult
    func handleWake(
        at date: Date = Date(),
        reader: @escaping @Sendable () async -> CodexUsageReadResult = { await CodexUsageReader.read() }
    ) -> Bool {
        if let lastWakeRequestAt, date.timeIntervalSince(lastWakeRequestAt) < 2 { return false }
        lastWakeRequestAt = date
        return requestRefresh(reader: reader)
    }

    func waitForRefresh() async {
        await refreshTask?.value
    }

    func stop() async {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        refreshTask?.cancel()
        await refreshTask?.value
        refreshTask = nil
    }
}

struct CodexWindowRow: View {
    let window: CodexUsageWindow
    let palette: UsageThemePalette

    private var usedCells: Int {
        min(100, max(0, Int(window.usedPercentage.rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("#")
                    .foregroundStyle(palette.syntax)
                    .accessibilityHidden(true)
                Text(window.label)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(palette.secondaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 20), spacing: 3) {
                ForEach(0..<100, id: \.self) { index in
                    usageCell(filled: index < usedCells)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Codex \(window.label) usage")
                .accessibilityValue("\(Int(window.usedPercentage.rounded())) percent used")

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("const")
                    .foregroundStyle(palette.syntax)
                Text("used")
                    .foregroundStyle(palette.secondaryText)
                (Text(window.usedPercentage, format: .number.precision(.fractionLength(0))) + Text("%"))
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 4)
                Text(window.resetText)
                    .foregroundStyle(palette.resetText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(.caption, design: .monospaced))
            .monospacedDigit()
        }
        .fontDesign(palette.fontDesign)
    }

    @ViewBuilder
    private func usageCell(filled: Bool) -> some View {
        let color = filled ? palette.accent : palette.remainingCell
        switch palette.cellShape {
        case .square:
            Rectangle().fill(color).aspectRatio(1, contentMode: .fit)
                .shadow(color: filled && palette.usesGlow ? palette.accent.opacity(0.45) : .clear, radius: 2)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: 2).fill(color).aspectRatio(1, contentMode: .fit)
        case .circle:
            Circle().fill(color).aspectRatio(1, contentMode: .fit)
                .shadow(color: filled && palette.usesGlow ? palette.accent.opacity(0.55) : .clear, radius: 3)
        }
    }
}
