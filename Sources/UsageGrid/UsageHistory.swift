import Foundation
import Observation
import OSLog

enum UsageHistoryWindow: String, Codable, CaseIterable, Identifiable, Sendable {
    case primary, secondary
    var id: String { rawValue }
}

struct UsageHistorySample: Codable, Equatable, Identifiable, Sendable {
    let observedAt: Date
    let window: UsageHistoryWindow
    let durationMinutes: Int
    let resetsAt: Date
    let usedPercentage: Double
    let processRunID: UUID

    var id: String { "\(processRunID.uuidString)-\(window.rawValue)-\(observedAt.timeIntervalSince1970)" }

    private enum CodingKeys: String, CodingKey { case observedAt, window, durationMinutes, resetsAt, usedPercentage }
    init(observedAt: Date, window: UsageHistoryWindow, durationMinutes: Int, resetsAt: Date, usedPercentage: Double, processRunID: UUID) {
        self.observedAt = observedAt; self.window = window; self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt; self.usedPercentage = usedPercentage; self.processRunID = processRunID
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        observedAt = try values.decode(Date.self, forKey: .observedAt)
        window = try values.decode(UsageHistoryWindow.self, forKey: .window)
        durationMinutes = try values.decode(Int.self, forKey: .durationMinutes)
        resetsAt = try values.decode(Date.self, forKey: .resetsAt)
        usedPercentage = try values.decode(Double.self, forKey: .usedPercentage)
        processRunID = Self.persistedRunID
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(observedAt, forKey: .observedAt); try values.encode(window, forKey: .window)
        try values.encode(durationMinutes, forKey: .durationMinutes); try values.encode(resetsAt, forKey: .resetsAt)
        try values.encode(usedPercentage, forKey: .usedPercentage)
    }
    private static let persistedRunID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

struct UsageHistorySegment: Equatable, Sendable {
    let samples: [UsageHistorySample]
}

enum UsageHistoryMath {
    static let retention: TimeInterval = 7 * 24 * 60 * 60
    static let sampleLimit = 25_000
    static let maximumGap: TimeInterval = 3 * 60

    static func retained(_ samples: [UsageHistorySample], now: Date) -> [UsageHistorySample] {
        Array(samples.filter { $0.observedAt >= now.addingTimeInterval(-retention) && $0.observedAt <= now }
            .sorted { $0.observedAt < $1.observedAt }.suffix(sampleLimit))
    }

    static func segments(_ samples: [UsageHistorySample], window: UsageHistoryWindow, reset: Date? = nil) -> [UsageHistorySegment] {
        let values = samples.filter { $0.window == window && (reset == nil || $0.resetsAt == reset) }
            .sorted { $0.observedAt < $1.observedAt }
        var result: [[UsageHistorySample]] = []
        for sample in values {
            guard let previous = result.last?.last else { result.append([sample]); continue }
            let discontinuity = sample.processRunID != previous.processRunID
                || sample.resetsAt != previous.resetsAt
                || sample.observedAt.timeIntervalSince(previous.observedAt) > maximumGap
                || sample.usedPercentage < previous.usedPercentage
            if discontinuity { result.append([sample]) } else { result[result.count - 1].append(sample) }
        }
        return result.map(UsageHistorySegment.init(samples:))
    }
}

struct UsageSessionChange: Equatable, Sendable {
    let percentagePoints: Double
    let since: Date
    let observedAt: Date
}

struct UsageSessionTracker: Sendable {
    private(set) var baseline: UsageHistorySample?
    private(set) var latest: UsageHistorySample?

    mutating func reset() { baseline = nil; latest = nil }

    mutating func observe(_ sample: UsageHistorySample) {
        guard sample.window == .primary else { return }
        guard let latest else { baseline = sample; self.latest = sample; return }
        let continuous = sample.processRunID == latest.processRunID
            && sample.resetsAt == latest.resetsAt
            && sample.observedAt.timeIntervalSince(latest.observedAt) <= UsageHistoryMath.maximumGap
            && sample.usedPercentage >= latest.usedPercentage
        if continuous {
            self.latest = sample
        } else {
            baseline = sample
            self.latest = sample
        }
    }

    var change: UsageSessionChange? {
        guard let baseline, let latest, latest.observedAt > baseline.observedAt else { return nil }
        return UsageSessionChange(percentagePoints: latest.usedPercentage - baseline.usedPercentage, since: baseline.observedAt, observedAt: latest.observedAt)
    }
}

protocol UsageHistoryPersisting: Sendable {
    func load(now: Date) async throws -> [UsageHistorySample]
    func save(_ samples: [UsageHistorySample], generation: Int) async throws
    func clear(generation: Int) async throws
}

actor UsageHistoryStore: UsageHistoryPersisting {
    static let logger = Logger(subsystem: "com.plutonightlabs.UsageGrid", category: "UsageHistory")
    private let fileURL: URL
    private var generation = 0

    init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = root.appendingPathComponent("UsageGrid", isDirectory: true).appendingPathComponent("usage-history.json")
        }
    }

    func load(now: Date) async throws -> [UsageHistorySample] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let document: StoredHistory
        if let current = try? JSONDecoder().decode(StoredHistory.self, from: data) {
            document = current
        } else {
            document = StoredHistory(samples: try JSONDecoder().decode([UsageHistorySample].self, from: data), segmentStarts: [])
        }
        let decoded = restoringBoundaries(in: document.samples, starts: Set(document.segmentStarts))
        let retained = UsageHistoryMath.retained(decoded, now: now)
        if retained != decoded { try write(retained) }
        return retained
    }

    func save(_ samples: [UsageHistorySample], generation requestedGeneration: Int) async throws {
        guard requestedGeneration >= generation else { return }
        generation = requestedGeneration
        try write(samples)
    }

    func clear(generation requestedGeneration: Int) async throws {
        generation = max(generation, requestedGeneration)
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }

    private func write(_ samples: [UsageHistorySample]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let document = StoredHistory(samples: samples, segmentStarts: persistedBoundaries(in: samples))
        try JSONEncoder().encode(document).write(to: fileURL, options: .atomic)
    }

    private func persistedBoundaries(in samples: [UsageHistorySample]) -> [StoredBoundary] {
        UsageHistoryWindow.allCases.flatMap { window in
            let values = samples.filter { $0.window == window }.sorted { $0.observedAt < $1.observedAt }
            return values.enumerated().compactMap { index, sample -> StoredBoundary? in
                guard index == 0 || sample.processRunID != values[index - 1].processRunID else { return nil }
                return StoredBoundary(observedAt: sample.observedAt, window: window)
            }
        }
    }

    private func restoringBoundaries(in samples: [UsageHistorySample], starts: Set<StoredBoundary>) -> [UsageHistorySample] {
        var identifiers: [UsageHistoryWindow: UUID] = [:]
        return samples.sorted { $0.observedAt < $1.observedAt }.map { sample in
            let key = StoredBoundary(observedAt: sample.observedAt, window: sample.window)
            if identifiers[sample.window] == nil || starts.contains(key) { identifiers[sample.window] = UUID() }
            return UsageHistorySample(observedAt: sample.observedAt, window: sample.window, durationMinutes: sample.durationMinutes,
                                      resetsAt: sample.resetsAt, usedPercentage: sample.usedPercentage,
                                      processRunID: identifiers[sample.window]!)
        }
    }
}

private struct StoredHistory: Codable {
    let samples: [UsageHistorySample]
    let segmentStarts: [StoredBoundary]
}

private struct StoredBoundary: Codable, Hashable {
    let observedAt: Date
    let window: UsageHistoryWindow
}

@MainActor @Observable
final class UsageHistoryController {
    static let recordingKey = "recordUsageHistory"
    private let defaults: UserDefaults
    private let store: any UsageHistoryPersisting
    private let now: () -> Date
    private var windowRunIDs: [UsageHistoryWindow: UUID]
    private var generation = 0
    private(set) var samples: [UsageHistorySample] = []
    private(set) var storageError: String?
    private(set) var session = UsageSessionTracker()
    var isRecording: Bool {
        didSet {
            defaults.set(isRecording, forKey: Self.recordingKey)
            session.reset()
            windowRunIDs = [.primary: UUID(), .secondary: UUID()]
        }
    }

    init(defaults: UserDefaults = .standard, store: any UsageHistoryPersisting = UsageHistoryStore(), now: @escaping () -> Date = Date.init, processRunID: UUID = UUID()) {
        self.defaults = defaults; self.store = store; self.now = now
        self.windowRunIDs = [.primary: processRunID, .secondary: processRunID]
        isRecording = defaults.bool(forKey: Self.recordingKey)
    }

    func load() async {
        do { samples = try await store.load(now: now()); storageError = nil }
        catch { samples = []; storageError = "History could not be read. You can clear it and start again." }
    }

    func record(windows: [CodexUsageWindow], observedAt: Date) async {
        guard isRecording else { return }
        let presentKinds = Set(windows.compactMap { UsageHistoryWindow(rawValue: $0.id) })
        for kind in UsageHistoryWindow.allCases where !presentKinds.contains(kind) {
            windowRunIDs[kind] = UUID()
            if kind == .primary { session.reset() }
        }
        let additions = windows.compactMap { window -> UsageHistorySample? in
            guard window.durationMinutes > 0, let reset = window.resetsAt, reset > observedAt,
                  let kind = UsageHistoryWindow(rawValue: window.id) else { return nil }
            return UsageHistorySample(observedAt: observedAt, window: kind, durationMinutes: window.durationMinutes,
                                      resetsAt: reset, usedPercentage: window.usedPercentage, processRunID: windowRunIDs[kind]!)
        }
        guard !additions.isEmpty else { return }
        samples = UsageHistoryMath.retained(samples + additions, now: observedAt)
        additions.forEach { session.observe($0) }
        await persistCurrent()
    }

    func clear() async {
        generation += 1
        samples = []
        session.reset()
        do { try await store.clear(generation: generation); storageError = nil }
        catch { storageError = "History could not be cleared. Check Application Support permissions." }
    }

    private func persistCurrent() async {
        let snapshot = samples, writeGeneration = generation
        do { try await store.save(snapshot, generation: writeGeneration); storageError = nil }
        catch { storageError = "History could not be saved. Live usage is unaffected." }
    }
}
