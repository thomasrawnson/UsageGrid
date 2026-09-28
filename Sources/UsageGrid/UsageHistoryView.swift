import Charts
import SwiftUI

enum UsageHistoryViewState {
    case recordingOff, unavailable, collecting, data
}

struct UsageHistoryChartView: View {
    let samples: [UsageHistorySample]
    let selection: UsageHistoryWindow
    let palette: UsageThemePalette
    let isRecording: Bool
    let storageError: String?
    let isSample: Bool
    var chartHeight: CGFloat = 145

    private var relevant: [UsageHistorySample] {
        let matching = samples.filter { $0.window == selection }
        guard let latestReset = matching.max(by: { $0.observedAt < $1.observedAt })?.resetsAt else { return [] }
        return matching.filter { $0.resetsAt == latestReset }
    }
    private var segments: [UsageHistorySegment] { UsageHistoryMath.segments(relevant, window: selection) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSample { Text("Sample data").font(.caption.weight(.bold)).foregroundStyle(palette.warning) }
            if let storageError { Label(storageError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(palette.error) }
            if !isRecording && !isSample { Text("History recording is off.").foregroundStyle(palette.secondaryText) }
            else if relevant.isEmpty && samples.isEmpty && !isSample { Text("Collecting readings…").foregroundStyle(palette.secondaryText) }
            else if relevant.isEmpty { Text("No recorded observations for this window.").foregroundStyle(palette.secondaryText) }
            else {
                Text("0–100% used")
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityHidden(true)
                Chart {
                    ForEach(Array(segments.enumerated()), id: \.offset) { segmentIndex, segment in
                        ForEach(segment.samples) { sample in
                            LineMark(x: .value("Observed", sample.observedAt), y: .value("Used", sample.usedPercentage), series: .value("Segment", segmentIndex))
                                .foregroundStyle(palette.accent)
                            PointMark(x: .value("Observed", sample.observedAt), y: .value("Used", sample.usedPercentage))
                                .foregroundStyle(palette.accent)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks { AxisGridLine().foregroundStyle(palette.border); AxisTick().foregroundStyle(palette.border); AxisValueLabel().foregroundStyle(palette.secondaryText) }
                }
                .chartYAxis {
                    AxisMarks { AxisGridLine().foregroundStyle(palette.border); AxisTick().foregroundStyle(palette.border); AxisValueLabel().foregroundStyle(palette.secondaryText) }
                }
                .frame(height: chartHeight)
                .accessibilityLabel(accessibilitySummary)
            }
        }
        .font(.caption)
    }

    private var accessibilitySummary: String {
        guard let first = relevant.first, let last = relevant.last else { return "No usage history" }
        return "\(selection.rawValue.capitalized) usage history, \(relevant.count) observations, from \(Int(first.usedPercentage.rounded())) to \(Int(last.usedPercentage.rounded())) percent used, in \(segments.count) continuous segments."
    }
}

struct RecordedHistorySection: View {
    let history: UsageHistoryController
    let palette: UsageThemePalette
    let isFresh: Bool
    let compact: Bool
    let openRecordingSettings: () -> Void
    @State private var selection: UsageHistoryWindow = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recorded history")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Text("Historical observations · not the current live reading")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Picker("Usage window", selection: $selection) {
                Text(windowTitle(.primary)).tag(UsageHistoryWindow.primary)
                Text(windowTitle(.secondary)).tag(UsageHistoryWindow.secondary)
            }
            .pickerStyle(.segmented)

            UsageHistoryChartView(
                samples: history.samples,
                selection: selection,
                palette: palette,
                isRecording: history.isRecording,
                storageError: history.storageError,
                isSample: false,
                chartHeight: compact ? 90 : 145
            )

            UsageSessionChangeView(
                change: history.session.change,
                isFresh: isFresh,
                isRecording: history.isRecording
            )
            .foregroundStyle(palette.secondaryText)

            if !history.isRecording {
                Button("Open recording settings", action: openRecordingSettings)
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border, lineWidth: 1))
    }

    private func windowTitle(_ window: UsageHistoryWindow) -> String {
        guard let duration = history.samples.last(where: { $0.window == window })?.durationMinutes else {
            return window == .primary ? "Primary" : "Secondary"
        }
        if duration % 1_440 == 0 { return "\(duration / 1_440)-day window" }
        if duration % 60 == 0 { return "\(duration / 60)-hour window" }
        return "\(duration)-minute window"
    }
}

struct RealUsageHistoryContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: UsageTheme
    let history: UsageHistoryController
    let isFresh: Bool
    let close: () -> Void
    let openRecordingSettings: () -> Void

    private var palette: UsageThemePalette { UsageThemePalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    heading
                    Spacer()
                    backButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    heading
                    backButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding([.horizontal, .top]).padding(.bottom, 10)

            ScrollView {
                RecordedHistorySection(
                    history: history,
                    palette: palette,
                    isFresh: isFresh,
                    compact: false,
                    openRecordingSettings: openRecordingSettings
                )
                .padding([.horizontal, .bottom])
            }
        }
        .fontDesign(palette.fontDesign)
        .foregroundStyle(palette.primaryText)
        .background(palette.canvas)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Usage history").font(.headline)
            Text("Recorded observations from successful refreshes")
                .font(.caption).foregroundStyle(palette.secondaryText)
        }
    }

    private var backButton: some View {
        Button("Back to usage", action: close).keyboardShortcut(.cancelAction)
    }
}

struct UsageSessionChangeView: View {
    let change: UsageSessionChange?
    let isFresh: Bool
    let isRecording: Bool

    var body: some View {
        Group {
            if !isRecording { Text("Recording off") }
            else if let change {
                Text("\(change.percentagePoints, format: .number.precision(.fractionLength(0))) percentage points used since \(change.since.formatted(date: .omitted, time: .shortened))\(isFresh ? "" : " · last observed \(change.observedAt.formatted(date: .omitted, time: .shortened)); stale")")
            } else { Text("Collecting readings…") }
        }
        .font(.caption)
        .accessibilityLabel("Observed account usage. \(isFresh ? "Fresh" : "Not current").")
    }
}

struct UsageHistoryPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let theme: UsageTheme

    var body: some View {
        UsageHistoryPreviewContent(theme: theme, closeTitle: "Close preview") { dismiss() }
            .frame(minWidth: 420, idealWidth: 480, maxWidth: 560,
                   minHeight: 300, idealHeight: 380, maxHeight: 520)
    }

    static let base = Date(timeIntervalSince1970: 1_800_000_000)
    static let sampleData: [UsageHistorySample] = {
        let run = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let reset = base.addingTimeInterval(10_800)
        return [30.0, 34, 42].enumerated().map { index, used in
            UsageHistorySample(observedAt: base.addingTimeInterval(Double(index * 60)), window: .primary, durationMinutes: 180, resetsAt: reset, usedPercentage: used, processRunID: run)
        } + [18.0, 19, 21].enumerated().map { index, used in
            UsageHistorySample(observedAt: base.addingTimeInterval(Double(index * 60)), window: .secondary, durationMinutes: 10_080, resetsAt: base.addingTimeInterval(604_800), usedPercentage: used, processRunID: run)
        }
    }()
}

struct UsageHistoryPreviewContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: UsageTheme
    let closeTitle: String
    let close: () -> Void
    @State private var selection: UsageHistoryWindow = .primary

    private var palette: UsageThemePalette { UsageThemePalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Usage History Preview").font(.headline)
                    Spacer()
                    Button(closeTitle, action: close).keyboardShortcut(.cancelAction)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage History Preview").font(.headline)
                    Button(closeTitle, action: close).keyboardShortcut(.cancelAction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding([.horizontal, .top]).padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sample data — observed account usage, not usage attributable to this Mac or a particular task.")
                        .font(.caption).foregroundStyle(palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    Picker("Usage window", selection: $selection) {
                        Text("3-hour window").tag(UsageHistoryWindow.primary)
                        Text("7-day window").tag(UsageHistoryWindow.secondary)
                    }.pickerStyle(.segmented)
                    UsageHistoryChartView(samples: UsageHistoryPreviewSheet.sampleData, selection: selection, palette: palette, isRecording: true, storageError: nil, isSample: true)
                    UsageSessionChangeView(change: UsageSessionChange(percentagePoints: 12, since: UsageHistoryPreviewSheet.base, observedAt: UsageHistoryPreviewSheet.base.addingTimeInterval(120)), isFresh: true, isRecording: true)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding([.horizontal, .bottom])
            }
        }
        .fontDesign(palette.fontDesign).foregroundStyle(palette.primaryText).background(palette.canvas)
    }
}

struct UsageHistoryExportPreview: View {
    let theme: UsageTheme
    let palette: UsageThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(theme.name) · Usage History · SAMPLE DATA").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                exportCard("Chart", samples: UsageHistoryPreviewSheet.sampleData)
                exportCard("Gap / segmented", samples: gapData)
                exportCard("Single observation", samples: Array(UsageHistoryPreviewSheet.sampleData.prefix(1)))
                exportCard("Empty", samples: [])
            }
        }
        .padding(22).frame(width: 940, height: 610, alignment: .topLeading)
        .fontDesign(palette.fontDesign).foregroundStyle(palette.primaryText)
        .background { ZStack { palette.canvas; ThemeDecorationView(theme: theme, palette: palette) } }
    }

    private func exportCard(_ title: String, samples: [UsageHistorySample]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            UsageHistoryChartView(samples: samples, selection: .primary, palette: palette, isRecording: true, storageError: nil, isSample: true)
        }
        .padding(12).background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border))
    }

    private var gapData: [UsageHistorySample] {
        let base = UsageHistoryPreviewSheet.base, run = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let reset = base.addingTimeInterval(10_800)
        return [(0, 22.0), (60, 28), (360, 31), (420, 36)].map {
            UsageHistorySample(observedAt: base.addingTimeInterval(Double($0.0)), window: .primary, durationMinutes: 180, resetsAt: reset, usedPercentage: $0.1, processRunID: run)
        }
    }
}

#if DEBUG
struct CombinedPanelFixtureView: View {
    let theme: UsageTheme
    let constrained: Bool
    let palette: UsageThemePalette

    private let liveWindow = CodexUsageWindow(
        id: "primary",
        label: "3-hour limit",
        usedPercentage: 42,
        resetText: "Resets in 1h 24m",
        durationMinutes: 180
    )

    var body: some View {
        ZStack(alignment: .top) {
            palette.canvas
            ThemeDecorationView(theme: theme, palette: palette)
            panel
        }
        .frame(width: 350, height: constrained ? 400 : 620, alignment: .top)
        .clipped()
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("// UsageGrid").font(.headline)
                Spacer()
                Text("Last updated 12:34").font(.caption)
            }
            Text("Live usage · current reading").font(.caption.weight(.semibold))
            CodexWindowRow(window: liveWindow, palette: palette)
                .padding(12)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border))
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Recorded history").font(.subheadline.weight(.semibold))
                Text("Historical observations · not the current live reading").font(.caption)
                HStack(spacing: 0) {
                    Text("3-hour window")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(palette.selectedTab)
                    Text("7-day window")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .font(.caption)
                .overlay(Rectangle().stroke(palette.border))
                UsageHistoryChartView(
                    samples: UsageHistoryPreviewSheet.sampleData,
                    selection: .primary,
                    palette: palette,
                    isRecording: true,
                    storageError: nil,
                    isSample: false
                )
                .frame(height: 175)
                UsageSessionChangeView(
                    change: UsageSessionChange(
                        percentagePoints: 12,
                        since: UsageHistoryPreviewSheet.base,
                        observedAt: UsageHistoryPreviewSheet.base.addingTimeInterval(120)
                    ),
                    isFresh: true,
                    isRecording: true
                )
            }
            .padding(12)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: palette.cardRadius).stroke(palette.border))
            HStack { Button("Settings") {}; Spacer(); Button("View history") {} }
                .buttonStyle(.plain)
        }
        .padding(14)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 350, alignment: .top)
        .fontDesign(palette.fontDesign)
        .foregroundStyle(palette.primaryText)
    }
}
#endif
