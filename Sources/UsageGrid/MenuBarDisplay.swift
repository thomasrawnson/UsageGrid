import Foundation
import Observation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly
    case usageUsed
    case usageRemaining

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly: "Icon only"
        case .usageUsed: "Icon + usage used"
        case .usageRemaining: "Icon + usage remaining"
        }
    }
}

enum MenuBarWindowSelection: String, CaseIterable, Identifiable {
    case primary
    case secondary

    var id: String { rawValue }

    var fallbackTitle: String {
        switch self {
        case .primary: "Primary window"
        case .secondary: "Secondary window"
        }
    }
}

@Observable
final class MenuBarPreferences {
    static let displayModeKey = "menuBarDisplayMode"
    static let windowSelectionKey = "menuBarWindowSelection"

    private let defaults: UserDefaults

    var displayMode: MenuBarDisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Self.displayModeKey) }
    }

    var windowSelection: MenuBarWindowSelection {
        didSet { defaults.set(windowSelection.rawValue, forKey: Self.windowSelectionKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = MenuBarDisplayMode(rawValue: defaults.string(forKey: Self.displayModeKey) ?? "") ?? .iconOnly
        windowSelection = MenuBarWindowSelection(rawValue: defaults.string(forKey: Self.windowSelectionKey) ?? "") ?? .primary
    }
}

struct MenuBarUsagePresentation: Equatable {
    let text: String?
    let accessibilityLabel: String

    static func make(
        mode: MenuBarDisplayMode,
        selection: MenuBarWindowSelection,
        windows: [CodexUsageWindow]?,
        isStale: Bool,
        isRefreshing: Bool,
        lastUpdated: Date?
    ) -> Self {
        let window = windows?.first { $0.id == selection.rawValue }
        let windowLabel = window?.label ?? selection.fallbackTitle
        let staleMarker = isStale ? " ⚠︎" : ""

        guard let window else {
            let text = mode == .iconOnly ? nil : "—\(staleMarker)"
            let freshness = isRefreshing ? "refresh in progress" : "no current reading"
            return Self(
                text: text,
                accessibilityLabel: "Codex, \(windowLabel), usage unavailable, \(freshness)"
            )
        }

        let used = min(100, max(0, Int(window.usedPercentage.rounded())))
        let remaining = 100 - used
        let valueText: String
        let valueDescription: String
        switch mode {
        case .iconOnly, .usageUsed:
            valueText = "\(used)% used"
            valueDescription = "\(used) percent used"
        case .usageRemaining:
            valueText = "\(remaining)% left"
            valueDescription = "\(remaining) percent remaining"
        }

        let freshness: String
        if isStale {
            freshness = lastUpdated.map { "stale, last updated \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "stale"
        } else if isRefreshing {
            freshness = lastUpdated.map { "refresh in progress, last updated \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "refresh in progress"
        } else {
            freshness = lastUpdated.map { "fresh, updated \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "fresh"
        }

        return Self(
            text: mode == .iconOnly ? nil : valueText + staleMarker,
            accessibilityLabel: "Codex, \(windowLabel), \(valueDescription), \(freshness)"
        )
    }

    static func windowTitle(for selection: MenuBarWindowSelection, windows: [CodexUsageWindow]?) -> String {
        windows?.first { $0.id == selection.rawValue }?.label ?? selection.fallbackTitle
    }
}
