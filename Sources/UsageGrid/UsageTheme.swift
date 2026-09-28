import Foundation
import Observation
import SwiftUI

enum UsageThemeID: String, CaseIterable, Identifiable {
    case programming
    case midnight
    case paper
    case aurora

    var id: String { rawValue }
}

struct UsageTheme: Identifiable, Equatable {
    let id: UsageThemeID
    let name: String
    let isPremium: Bool

    static let all: [UsageTheme] = [
        UsageTheme(id: .programming, name: "Programming", isPremium: false),
        UsageTheme(id: .midnight, name: "Midnight", isPremium: true),
        UsageTheme(id: .paper, name: "Paper", isPremium: true),
        UsageTheme(id: .aurora, name: "Aurora", isPremium: true)
    ]

    static let defaultTheme = all[0]

    static func lookup(_ rawValue: String?) -> UsageTheme {
        guard let rawValue,
              let id = UsageThemeID(rawValue: rawValue),
              let theme = all.first(where: { $0.id == id }) else { return defaultTheme }
        return theme
    }
}

struct ThemeAccess: Equatable {
    let hasProEntitlement: Bool

    static let production = ThemeAccess(hasProEntitlement: false)

    func canSelect(_ theme: UsageTheme) -> Bool {
        !theme.isPremium || hasProEntitlement
    }
}

@Observable
final class ThemePreferences {
    static let activeThemeKey = "activeUsageTheme"

    private let defaults: UserDefaults
    private let access: ThemeAccess
    private(set) var activeTheme: UsageTheme

    init(defaults: UserDefaults = .standard, access: ThemeAccess = .production) {
        self.defaults = defaults
        self.access = access
        let saved = UsageTheme.lookup(defaults.string(forKey: Self.activeThemeKey))
        activeTheme = access.canSelect(saved) ? saved : .defaultTheme
    }

    @discardableResult
    func select(_ theme: UsageTheme) -> Bool {
        guard access.canSelect(theme) else { return false }
        activeTheme = theme
        defaults.set(theme.id.rawValue, forKey: Self.activeThemeKey)
        return true
    }
}

struct UsageThemePalette {
    let canvas: Color
    let surface: Color
    let border: Color
    let accent: Color
    let remainingCell: Color
    let syntax: Color
    let primaryText: Color
    let secondaryText: Color
    let resetText: Color
    let selectedTab: Color
    let success: Color
    let warning: Color
    let error: Color

    init(theme: UsageTheme, colorScheme: ColorScheme) {
        switch theme.id {
        case .programming:
            if colorScheme == .dark {
                self.init(canvas: rgb(30, 30, 30), surface: rgb(37, 37, 38), border: rgb(65, 65, 67), accent: rgb(78, 201, 176), remainingCell: rgb(62, 62, 63), syntax: rgb(133, 183, 111), primaryText: .white, secondaryText: rgb(194, 199, 201), resetText: rgb(194, 199, 201), selectedTab: rgb(45, 62, 60), success: rgb(111, 193, 127), warning: rgb(238, 188, 85), error: rgb(238, 116, 116))
            } else {
                self.init(canvas: rgb(243, 244, 246), surface: .white, border: rgb(211, 216, 220), accent: rgb(11, 112, 99), remainingCell: rgb(222, 227, 230), syntax: rgb(55, 115, 69), primaryText: rgb(28, 32, 34), secondaryText: rgb(75, 84, 88), resetText: rgb(75, 84, 88), selectedTab: rgb(223, 239, 235), success: rgb(35, 119, 67), warning: rgb(151, 91, 12), error: rgb(174, 48, 48))
            }
        case .midnight:
            self.init(canvas: rgb(8, 18, 35), surface: rgb(14, 29, 51), border: rgb(43, 70, 94), accent: rgb(66, 211, 224), remainingCell: rgb(30, 51, 73), syntax: rgb(128, 205, 220), primaryText: rgb(235, 246, 250), secondaryText: rgb(166, 190, 204), resetText: rgb(180, 207, 218), selectedTab: rgb(18, 54, 70), success: rgb(104, 210, 168), warning: rgb(244, 191, 91), error: rgb(248, 126, 135))
        case .paper:
            self.init(canvas: rgb(244, 237, 221), surface: rgb(255, 251, 241), border: rgb(203, 188, 159), accent: rgb(174, 105, 28), remainingCell: rgb(226, 216, 195), syntax: rgb(129, 91, 44), primaryText: rgb(48, 43, 36), secondaryText: rgb(103, 91, 73), resetText: rgb(92, 79, 62), selectedTab: rgb(239, 222, 188), success: rgb(56, 115, 72), warning: rgb(155, 88, 16), error: rgb(164, 53, 45))
        case .aurora:
            self.init(canvas: rgb(30, 14, 38), surface: rgb(46, 24, 57), border: rgb(84, 55, 95), accent: rgb(170, 123, 255), remainingCell: rgb(68, 43, 76), syntax: rgb(77, 214, 190), primaryText: rgb(247, 237, 250), secondaryText: rgb(202, 177, 207), resetText: rgb(204, 184, 211), selectedTab: rgb(68, 38, 82), success: rgb(84, 215, 177), warning: rgb(246, 185, 83), error: rgb(250, 115, 153))
        }
    }

    private init(canvas: Color, surface: Color, border: Color, accent: Color, remainingCell: Color, syntax: Color, primaryText: Color, secondaryText: Color, resetText: Color, selectedTab: Color, success: Color, warning: Color, error: Color) {
        self.canvas = canvas
        self.surface = surface
        self.border = border
        self.accent = accent
        self.remainingCell = remainingCell
        self.syntax = syntax
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.resetText = resetText
        self.selectedTab = selectedTab
        self.success = success
        self.warning = warning
        self.error = error
    }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
}
