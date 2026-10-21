import Foundation
import Observation
import SwiftUI

enum UsageThemeID: String, CaseIterable, Identifiable {
    case programming
    case professional
    case retro
    case anime
    case zenForest
    case space

    var id: String { rawValue }
}

struct UsageTheme: Identifiable, Equatable {
    let id: UsageThemeID
    let name: String

    static let all: [UsageTheme] = [
        UsageTheme(id: .programming, name: "Programming"),
        UsageTheme(id: .professional, name: "Professional"),
        UsageTheme(id: .retro, name: "90s Retro"),
        UsageTheme(id: .anime, name: "Anime"),
        UsageTheme(id: .zenForest, name: "Zen Forest"),
        UsageTheme(id: .space, name: "Space")
    ]

    static let defaultTheme = all[0]

    static func lookup(_ rawValue: String?) -> UsageTheme {
        guard let rawValue,
              let id = UsageThemeID(rawValue: rawValue),
              let theme = all.first(where: { $0.id == id }) else { return defaultTheme }
        return theme
    }
}

@Observable
final class ThemePreferences {
    static let activeThemeKey = "activeUsageTheme"

    private let defaults: UserDefaults
    private var savedTheme: UsageTheme

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedTheme = UsageTheme.lookup(defaults.string(forKey: Self.activeThemeKey))
    }

    var activeTheme: UsageTheme {
        savedTheme
    }

    @discardableResult
    func select(_ theme: UsageTheme) -> Bool {
        savedTheme = theme
        defaults.set(theme.id.rawValue, forKey: Self.activeThemeKey)
        return true
    }
}

struct UsageThemePalette {
    enum CellShape { case square, roundedSquare, circle }
    enum Typography { case monospaced, rounded, serif, system }

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
    let cellShape: CellShape
    let typography: Typography
    let cardRadius: CGFloat
    let usesGlow: Bool

    init(theme: UsageTheme, colorScheme: ColorScheme) {
        switch theme.id {
        case .programming:
            if colorScheme == .dark {
                self.init(canvas: rgb(30, 30, 30), surface: rgb(37, 37, 38), border: rgb(65, 65, 67), accent: rgb(78, 201, 176), remainingCell: rgb(62, 62, 63), syntax: rgb(133, 183, 111), primaryText: .white, secondaryText: rgb(194, 199, 201), resetText: rgb(194, 199, 201), selectedTab: rgb(45, 62, 60), success: rgb(111, 193, 127), warning: rgb(238, 188, 85), error: rgb(238, 116, 116), cellShape: .roundedSquare, typography: .monospaced, cardRadius: 4, usesGlow: false)
            } else {
                self.init(canvas: rgb(243, 244, 246), surface: .white, border: rgb(211, 216, 220), accent: rgb(11, 112, 99), remainingCell: rgb(222, 227, 230), syntax: rgb(55, 115, 69), primaryText: rgb(28, 32, 34), secondaryText: rgb(75, 84, 88), resetText: rgb(75, 84, 88), selectedTab: rgb(223, 239, 235), success: rgb(35, 119, 67), warning: rgb(151, 91, 12), error: rgb(174, 48, 48), cellShape: .roundedSquare, typography: .monospaced, cardRadius: 4, usesGlow: false)
            }
        case .professional:
            self.init(canvas: rgb(243, 244, 246), surface: .white, border: rgb(216, 221, 229), accent: rgb(47, 111, 237), remainingCell: rgb(229, 232, 237), syntax: rgb(47, 111, 237), primaryText: rgb(28, 33, 40), secondaryText: rgb(92, 103, 118), resetText: rgb(75, 83, 94), selectedTab: rgb(222, 232, 253), success: rgb(38, 124, 70), warning: rgb(163, 91, 4), error: rgb(181, 45, 45), cellShape: .roundedSquare, typography: .system, cardRadius: 10, usesGlow: false)
        case .retro:
            self.init(canvas: rgb(25, 13, 41), surface: rgb(37, 18, 59), border: rgb(82, 43, 111), accent: rgb(0, 229, 220), remainingCell: rgb(70, 39, 101), syntax: rgb(255, 43, 190), primaryText: rgb(249, 239, 255), secondaryText: rgb(207, 184, 221), resetText: rgb(229, 211, 238), selectedTab: rgb(70, 28, 94), success: rgb(71, 235, 184), warning: rgb(255, 219, 63), error: rgb(255, 102, 139), cellShape: .square, typography: .monospaced, cardRadius: 9, usesGlow: true)
        case .anime:
            self.init(canvas: rgb(255, 241, 247), surface: .white, border: rgb(255, 198, 224), accent: rgb(243, 107, 173), remainingCell: rgb(255, 222, 236), syntax: rgb(214, 83, 147), primaryText: rgb(77, 53, 70), secondaryText: rgb(126, 91, 115), resetText: rgb(111, 75, 100), selectedTab: rgb(255, 218, 235), success: rgb(46, 124, 77), warning: rgb(172, 91, 6), error: rgb(178, 49, 75), cellShape: .circle, typography: .rounded, cardRadius: 22, usesGlow: false)
        case .zenForest:
            self.init(canvas: rgb(232, 239, 231), surface: rgb(245, 248, 242), border: rgb(190, 211, 194), accent: rgb(71, 126, 101), remainingCell: rgb(214, 227, 215), syntax: rgb(59, 111, 84), primaryText: rgb(38, 72, 56), secondaryText: rgb(84, 113, 97), resetText: rgb(68, 99, 82), selectedTab: rgb(211, 226, 215), success: rgb(45, 115, 72), warning: rgb(151, 96, 15), error: rgb(166, 54, 48), cellShape: .circle, typography: .serif, cardRadius: 16, usesGlow: false)
        case .space:
            self.init(canvas: rgb(7, 10, 19), surface: rgb(14, 20, 38), border: rgb(34, 51, 88), accent: rgb(128, 184, 255), remainingCell: rgb(29, 45, 78), syntax: rgb(177, 116, 255), primaryText: rgb(237, 244, 255), secondaryText: rgb(168, 182, 211), resetText: rgb(191, 204, 229), selectedTab: rgb(27, 48, 83), success: rgb(92, 214, 170), warning: rgb(247, 194, 78), error: rgb(249, 112, 139), cellShape: .circle, typography: .rounded, cardRadius: 12, usesGlow: true)
        }
    }

    private init(canvas: Color, surface: Color, border: Color, accent: Color, remainingCell: Color, syntax: Color, primaryText: Color, secondaryText: Color, resetText: Color, selectedTab: Color, success: Color, warning: Color, error: Color, cellShape: CellShape, typography: Typography, cardRadius: CGFloat, usesGlow: Bool) {
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
        self.cellShape = cellShape
        self.typography = typography
        self.cardRadius = cardRadius
        self.usesGlow = usesGlow
    }

    var fontDesign: Font.Design {
        switch typography {
        case .monospaced: .monospaced
        case .rounded: .rounded
        case .serif: .serif
        case .system: .default
        }
    }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
}

struct ThemeDecorationView: View {
    let theme: UsageTheme
    let palette: UsageThemePalette

    var body: some View {
        GeometryReader { proxy in
            switch theme.id {
            case .retro:
                Canvas { context, size in
                    var path = Path()
                    stride(from: 0.0, through: size.width, by: 24).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    stride(from: 0.0, through: size.height, by: 24).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(palette.syntax.opacity(0.12)), lineWidth: 0.7)
                }
            case .anime:
                decorationSymbols(["sparkles", "star.fill", "sparkle"], in: proxy.size, color: palette.accent.opacity(0.20))
            case .zenForest:
                ZStack(alignment: .bottom) {
                    Image(systemName: "mountain.2.fill")
                        .resizable().scaledToFit().frame(width: proxy.size.width * 0.72)
                        .foregroundStyle(palette.accent.opacity(0.07))
                    HStack(alignment: .bottom, spacing: proxy.size.width * 0.11) {
                        Image(systemName: "tree.fill").font(.system(size: 38))
                        Image(systemName: "tree.fill").font(.system(size: 55))
                        Image(systemName: "tree.fill").font(.system(size: 31))
                    }
                    .foregroundStyle(palette.accent.opacity(0.09))
                }
            case .space:
                decorationSymbols(["star.fill", "circle.fill", "sparkle", "star.fill", "circle.fill"], in: proxy.size, color: palette.accent.opacity(0.28))
            case .programming, .professional:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func decorationSymbols(_ names: [String], in size: CGSize, color: Color) -> some View {
        ZStack {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Image(systemName: name)
                    .font(.system(size: index.isMultiple(of: 2) ? 8 : 5))
                    .foregroundStyle(color)
                    .position(
                        x: size.width * [0.10, 0.29, 0.52, 0.73, 0.91][index % 5],
                        y: size.height * [0.12, 0.34, 0.17, 0.61, 0.42][index % 5]
                    )
            }
        }
    }
}
