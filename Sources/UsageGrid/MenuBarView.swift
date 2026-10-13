import SwiftUI
import AppKit
import Observation

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var claude: ClaudeUsageCoordinator
    @Bindable var alerts: UsageAlertController
    @Bindable var themePreferences: ThemePreferences
    @Bindable var history: UsageHistoryController
    @Bindable var proAccess: ProAccessController
    @State private var selectedProvider: SelectedProvider = .codex
    @State private var presentation = PopupPresentationState()

    private var palette: UsageThemePalette { UsageThemePalette(theme: themePreferences.activeTheme, colorScheme: colorScheme) }

    var body: some View {
        Group {
            switch presentation.page {
            case .usage:
                usagePage
            case .history:
                RealUsageHistoryContent(
                    theme: themePreferences.activeTheme,
                    history: history,
                    isFresh: !codex.isStale && !codex.refreshFailed,
                    close: { presentation.showUsage() },
                    openRecordingSettings: { openSettings() }
                )
            case .historyPreview:
                UsageHistoryPreviewContent(theme: themePreferences.activeTheme, closeTitle: "Back to usage") {
                    presentation.showUsage()
                }
            }
        }
        .frame(width: 350)
        .frame(height: popupHeight, alignment: .top)
        .background {
            ZStack {
                palette.canvas
                ThemeDecorationView(theme: themePreferences.activeTheme, palette: palette)
            }
        }
        .onAppear {
            presentation.showUsage()
            codex.successfulRefreshHandler = { windows, observedAt in
                Task { await alerts.evaluate(windows: windows, isFresh: true, observedAt: observedAt) }
                Task { await history.record(windows: windows, observedAt: observedAt) }
            }
            Task { await history.load() }
            codex.activate()
            refreshCodex()
            claude.refresh()
        }
        .onDisappear { presentation.popupDismissed() }
        .onChange(of: proAccess.effectiveAccess.canViewUsageHistory) { _, canViewHistory in
            presentation.accessChanged(canViewHistory: canViewHistory)
        }
    }

    private var popupHeight: CGFloat {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        return PopupSizing.height(availableScreenHeight: screen?.visibleFrame.height ?? 680)
    }

    private var usagePage: some View {
        VStack(spacing: 0) {
            popupHeader
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
            Divider()
            ScrollView {
                usagePanel
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var popupHeader: some View {
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
            if selectedProvider == .claude, let capturedAt = claude.capturedAt {
                Text("Captured \(capturedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
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
            } else {
                Button(action: { claude.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(palette.accent)
                .accessibilityLabel("Reread local Claude snapshot")
                .help("Reread local snapshot; does not contact Claude")
            }
        }
        .font(.system(.headline, design: .monospaced))
        .fontDesign(palette.fontDesign)
    }

    private var usagePanel: some View {
        VStack(alignment: .leading, spacing: 14) {

            #if DEBUG
            if proAccess.isDeveloperSimulationActive {
                Label("Developer Pro simulation", systemImage: "hammer.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.warning)
            }
            #endif

            HStack(spacing: 0) {
                providerTab(.codex)
                providerTab(.claude)
            }
            .background(palette.surface)
            .overlay(Rectangle().stroke(palette.border, lineWidth: 1).allowsHitTesting(false))

            Text("Menu-bar usage, alerts and history currently track Codex only.")
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)

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
                            CodexWindowRow(
                                window: window, palette: palette, providerName: "Codex",
                                freshnessDescription: codex.isStale ? "stale" : nil
                            )
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Experimental passive snapshot integration. It does not refresh Claude usage independently.")
                        .font(.caption)
                    if let windows = claude.windows {
                        if claude.isStale {
                            Label(claude.availability == .expired ? "Expired snapshot" : "Stale measurement", systemImage: "exclamationmark.triangle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.warning)
                        }
                        ForEach(windows) { window in
                            CodexWindowRow(
                                window: window, palette: palette, providerName: "Claude",
                                freshnessDescription: claude.accessibilityFreshnessDescription
                            )
                        }
                        if let measured = claude.measurementObservedAt {
                            Text("Quota values first captured \(measured.formatted(date: .abbreviated, time: .shortened)).")
                                .font(.caption)
                        }
                        if let captured = claude.capturedAt {
                            Text("Payload captured \(captured.formatted(date: .abbreviated, time: .shortened)). Repeated identical payloads do not refresh the quota measurement time.")
                                .font(.caption)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(">").foregroundStyle(palette.syntax).accessibilityHidden(true)
                            Text("Usage unavailable")
                        }
                        Text(claude.availability.message)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Refresh rereads the local snapshot only.")
                        .font(.caption2)
                    DisclosureGroup("Claude setup and removal") {
                        ClaudeSetupGuideView()
                            .padding(.top, 4)
                    }
                    .font(.caption)
                }
                .foregroundStyle(palette.secondaryText)
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border, lineWidth: 1))
            }

            Divider()

            if selectedProvider == .codex {
                VStack(alignment: .leading, spacing: 5) {
                    if proAccess.effectiveAccess.canViewUsageHistory {
                        RecordedHistorySection(
                            history: history,
                            palette: palette,
                            isFresh: !codex.isStale && !codex.refreshFailed,
                            compact: true,
                            openRecordingSettings: { openSettings() }
                        )
                        HStack(spacing: 14) {
                            Button("View history") { presentation.showHistory() }
                            Button("Preview sample") { presentation.showHistoryPreview() }
                        }
                    } else {
                        Text(history.isRecording ? "History recording on · viewing planned for Pro" : "History recording off")
                            .font(.caption)
                        Button("Preview usage history") { presentation.showHistoryPreview() }
                            .foregroundStyle(palette.accent)
                    }
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

    private func providerTab(_ provider: SelectedProvider) -> some View {
        let isSelected = selectedProvider == provider
        return Button {
            switch provider {
            case .codex: selectedProvider = .codex
            case .claude: selectedProvider = .claude
            }
        } label: {
            Text(provider.selectorTitle)
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
        .accessibilityLabel(provider.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum ClaudeOnboardingContent {
    static let repositoryBuildCommand = "swift build -c release --product UsageGridClaudeCapture"

    static let configurationTemplate = """
    {
      "statusLine": {
        "type": "command",
        "command": "/absolute/path/to/UsageGridClaudeCapture --display"
      }
    }
    """

    static let coexistenceWrapperTemplate = """
    #!/bin/sh
    input=$(cat)
    printf '%s' "$input" | /absolute/path/to/UsageGridClaudeCapture >/dev/null 2>&1 || true
    printf '%s' "$input" | /absolute/path/to/existing-status-line
    """

    static let undetectableState = "UsageGrid cannot determine from a missing snapshot whether Claude Code is installed, authenticated, or configured."
}

struct ClaudeSetupGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requirements")
                .fontWeight(.semibold)
            Text("Claude Code CLI and an eligible Claude subscription are required. Claude Code must receive an API response containing the documented usage fields before a snapshot can exist.")
            Text("UsageGrid does not query Anthropic, inspect authentication, or edit Claude Code settings. Refresh only rereads the local snapshot.")
            Text(ClaudeOnboardingContent.undetectableState)

            Text("Set up manually")
                .fontWeight(.semibold)
            Text("Build or obtain the UsageGridClaudeCapture helper, move it to a stable location, and replace the placeholder below with its reviewed absolute path. UsageGrid cannot supply a path until one exists.")
            Text("When running from this source repository, build the helper from the repository root:")
            copyableBlock(
                ClaudeOnboardingContent.repositoryBuildCommand,
                buttonTitle: "Copy helper build command",
                accessibilityLabel: "Copy Claude capture helper build command"
            )
            copyableBlock(
                ClaudeOnboardingContent.configurationTemplate,
                buttonTitle: "Copy configuration template",
                accessibilityLabel: "Copy Claude status-line configuration template"
            )

            Text("Keep an existing status line")
                .fontWeight(.semibold)
            Text("Claude Code supports one status-line command. Back up the existing setting and use a reviewed wrapper that sends the in-memory input to both commands. Never overwrite the existing command silently.")
            copyableBlock(
                ClaudeOnboardingContent.coexistenceWrapperTemplate,
                buttonTitle: "Copy coexistence wrapper",
                accessibilityLabel: "Copy Claude status-line coexistence wrapper template"
            )

            Text("Remove safely")
                .fontWeight(.semibold)
            Text("Restore the exact previous statusLine setting, or remove only the setting you added. Do not delete unrelated Claude settings. The local UsageGrid snapshot can be removed separately.")
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }

    private func copyableBlock(_ value: String, buttonTitle: String, accessibilityLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal) {
                Text(value)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
            Button(buttonTitle) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}

enum PopupSizing {
    static func height(availableScreenHeight: CGFloat) -> CGFloat {
        max(160, min(640, availableScreenHeight - 32))
    }
}

enum SelectedProvider {
    case codex
    case claude

    var selectorTitle: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude — Experimental"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .codex: "Codex provider"
        case .claude: "Claude provider, experimental passive snapshot"
        }
    }
}

enum PopupPage {
    case usage
    case history
    case historyPreview
}

struct PopupPresentationState {
    private(set) var page: PopupPage = .usage
    mutating func showHistory() { page = .history }
    mutating func showHistoryPreview() { page = .historyPreview }
    mutating func showUsage() { page = .usage }
    mutating func popupDismissed() { page = .usage }
    mutating func accessChanged(canViewHistory: Bool) {
        if !canViewHistory && page == .history { page = .usage }
    }
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
    var providerName = "Codex"
    var freshnessDescription: String?

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
        .fontDesign(.monospaced)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(UsageWindowAccessibilityPresentation.make(
            providerName: providerName,
            window: window,
            freshnessDescription: freshnessDescription
        ).label)
        .accessibilityValue(UsageWindowAccessibilityPresentation.make(
            providerName: providerName,
            window: window,
            freshnessDescription: freshnessDescription
        ).value)
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

struct UsageWindowAccessibilityPresentation: Equatable {
    let label: String
    let value: String

    static func make(
        providerName: String,
        window: CodexUsageWindow,
        freshnessDescription: String?
    ) -> Self {
        let percentage = min(100, max(0, Int(window.usedPercentage.rounded())))
        var values = ["\(percentage) percent used", durationDescription(window.durationMinutes)]
        values.append(window.resetsAt == nil ? "reset unavailable" : window.resetText)
        if let freshnessDescription { values.append(freshnessDescription) }
        return Self(label: "\(providerName), \(window.label) usage", value: values.joined(separator: ", "))
    }

    private static func durationDescription(_ minutes: Int) -> String {
        guard minutes > 0 else { return "window duration unavailable" }
        if minutes.isMultiple(of: 1_440) {
            let days = minutes / 1_440
            return "\(days) day\(days == 1 ? "" : "s") window"
        }
        if minutes.isMultiple(of: 60) {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") window"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") window"
    }
}
