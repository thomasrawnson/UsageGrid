import SwiftUI
import AppKit
import Observation

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var codex: CodexRefreshCoordinator
    @Bindable var alerts: UsageAlertController
    @State private var selectedProvider: SelectedProvider = .codex

    private var palette: ProgrammingPalette { ProgrammingPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("//")
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                Text("UsageGrid")
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                if selectedProvider == .codex, let lastUpdated = codex.lastUpdated {
                    Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(.caption, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
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

                VStack(alignment: .leading, spacing: 14) {
                    if let setupState = codex.setupState {
                        CodexSetupStatusView(state: setupState, retry: refreshCodex)
                    } else if let codexWindows = codex.windows {
                        ForEach(codexWindows, id: \.id) { window in
                            CodexWindowRow(window: window, accent: palette.accent, remainingCell: palette.remainingCell, syntax: palette.syntax, resetTextColor: palette.resetText)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border, lineWidth: 1))
            } else {
                HStack(spacing: 6) {
                    Text("#")
                        .foregroundStyle(palette.syntax)
                        .accessibilityHidden(true)
                    Text("Claude")
                }
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(">")
                            .foregroundStyle(palette.syntax)
                            .accessibilityHidden(true)
                        Text("Usage unavailable")
                    }
                    .foregroundStyle(.secondary)
                    Text("Claude integration is unavailable. Codex setup does not connect Claude.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border, lineWidth: 1))
            }

            Divider()

            HStack {
                Button("Settings") {
                    openSettings()
                }
                .foregroundStyle(palette.accent)
                Spacer()
                Button("Quit UsageGrid") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .font(.system(.callout, design: .monospaced))
            .padding(.horizontal, 4)
        }
        .padding(14)
        .frame(width: 350)
        .background(palette.canvas)
        .onAppear {
            codex.successfulRefreshHandler = { windows, _ in
                Task { await alerts.evaluate(windows: windows, isFresh: true) }
            }
            codex.activate()
            refreshCodex()
        }
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
                .foregroundStyle(isSelected ? palette.accent : Color.secondary)
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

private struct CodexWindowRow: View {
    let window: CodexUsageWindow
    let accent: Color
    let remainingCell: Color
    let syntax: Color
    let resetTextColor: Color

    private var usedCells: Int {
        min(100, max(0, Int(window.usedPercentage.rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("#")
                    .foregroundStyle(syntax)
                    .accessibilityHidden(true)
                Text(window.label)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 20), spacing: 3) {
                ForEach(0..<100, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < usedCells ? accent : remainingCell)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Codex \(window.label) usage")
                .accessibilityValue("\(Int(window.usedPercentage.rounded())) percent used")

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("const")
                    .foregroundStyle(syntax)
                Text("used")
                    .foregroundStyle(.secondary)
                (Text(window.usedPercentage, format: .number.precision(.fractionLength(0))) + Text("%"))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                Text(window.resetText)
                    .foregroundStyle(resetTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(.caption, design: .monospaced))
            .monospacedDigit()
        }
    }
}

private struct ProgrammingPalette {
    let canvas: Color
    let surface: Color
    let border: Color
    let accent: Color
    let remainingCell: Color
    let syntax: Color
    let resetText: Color
    let selectedTab: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            canvas = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
            surface = Color(red: 37 / 255, green: 37 / 255, blue: 38 / 255)
            border = Color(red: 65 / 255, green: 65 / 255, blue: 67 / 255)
            accent = Color(red: 78 / 255, green: 201 / 255, blue: 176 / 255)
            remainingCell = Color(red: 62 / 255, green: 62 / 255, blue: 63 / 255)
            syntax = Color(red: 133 / 255, green: 183 / 255, blue: 111 / 255)
            resetText = Color(red: 194 / 255, green: 199 / 255, blue: 201 / 255)
            selectedTab = Color(red: 45 / 255, green: 62 / 255, blue: 60 / 255)
        } else {
            canvas = Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255)
            surface = .white
            border = Color(red: 211 / 255, green: 216 / 255, blue: 220 / 255)
            accent = Color(red: 11 / 255, green: 112 / 255, blue: 99 / 255)
            remainingCell = Color(red: 222 / 255, green: 227 / 255, blue: 230 / 255)
            syntax = Color(red: 55 / 255, green: 115 / 255, blue: 69 / 255)
            resetText = Color(red: 75 / 255, green: 84 / 255, blue: 88 / 255)
            selectedTab = Color(red: 223 / 255, green: 239 / 255, blue: 235 / 255)
        }
    }
}
