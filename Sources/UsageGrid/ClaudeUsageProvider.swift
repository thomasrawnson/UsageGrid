import Foundation
import Observation
#if SWIFT_PACKAGE
import UsageGridClaudeCore
#endif

enum ClaudeUsageAvailability: Equatable {
    case missing
    case available
    case stale
    case expired
    case corrupt
    case unsupported

    var message: String {
        switch self {
        case .missing: "No snapshot has been received. The integration may not be configured, Claude Code may not have run since setup, or the current session may not provide eligible usage fields."
        case .available: "Snapshot available"
        case .stale: "The last quota measurement may be stale. Continue using Claude Code to allow a later provider response to be captured."
        case .expired: "All captured quota windows have expired. Continue using Claude Code to capture a later provider response."
        case .corrupt: "The local snapshot cannot be read. Review setup, then let Claude Code capture a replacement."
        case .unsupported: "This snapshot format is not supported by this version of UsageGrid. Update UsageGrid or rebuild the matching capture helper."
        }
    }
}

@MainActor
@Observable
final class ClaudeUsageCoordinator {
    static let staleAfter: TimeInterval = 2 * 60

    private let store: ClaudeSnapshotStore
    private let now: () -> Date
    private(set) var snapshot: ClaudeUsageSnapshot?
    private(set) var availability: ClaudeUsageAvailability = .missing

    init(store: ClaudeSnapshotStore = ClaudeSnapshotStore(), now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    var windows: [QuotaWindow]? { snapshot?.windows }
    var capturedAt: Date? { snapshot?.capturedAt }
    var measurementObservedAt: Date? { snapshot?.measurementObservedAt }
    var sourceVersion: String? { snapshot?.sourceVersion }
    var isStale: Bool { availability == .stale || availability == .expired }
    var accessibilityFreshnessDescription: String? {
        switch availability {
        case .stale: "stale measurement"
        case .expired: "expired snapshot"
        case .missing, .available, .corrupt, .unsupported: nil
        }
    }

    func refresh() {
        let date = now()
        do {
            let loaded = try store.load()
            snapshot = refreshedResetText(in: loaded, now: date)
            availability = Self.availability(for: loaded, now: date)
        } catch ClaudeSnapshotStoreError.missing {
            snapshot = nil; availability = .missing
        } catch ClaudeSnapshotStoreError.unsupportedSchema {
            snapshot = nil; availability = .unsupported
        } catch {
            snapshot = nil; availability = .corrupt
        }
    }

    static func availability(for snapshot: ClaudeUsageSnapshot, now: Date) -> ClaudeUsageAvailability {
        let activeWindows = snapshot.windows.filter { ($0.resetsAt ?? .distantPast) > now }
        if activeWindows.isEmpty { return .expired }
        if now.timeIntervalSince(snapshot.measurementObservedAt) > staleAfter { return .stale }
        return .available
    }

    private func refreshedResetText(in snapshot: ClaudeUsageSnapshot, now: Date) -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(
            capturedAt: snapshot.capturedAt,
            measurementObservedAt: snapshot.measurementObservedAt,
            sourceVersion: snapshot.sourceVersion,
            windows: snapshot.windows.map { window in
                guard let reset = window.resetsAt else { return window }
                return QuotaWindow(
                    id: window.id, label: window.label, usedPercentage: window.usedPercentage,
                    resetText: ClaudeStatusLineDecoder.resetText(reset, now: now),
                    durationMinutes: window.durationMinutes, resetsAt: reset
                )
            }
        )
    }
}
