import Foundation

public struct QuotaWindow: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let usedPercentage: Double
    public let resetText: String
    public let durationMinutes: Int
    public let resetsAt: Date?

    public init(id: String, label: String, usedPercentage: Double, resetText: String, durationMinutes: Int, resetsAt: Date? = nil) {
        self.id = id
        self.label = label
        self.usedPercentage = usedPercentage
        self.resetText = resetText
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
    }
}

public struct ClaudeUsageSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let capturedAt: Date
    public let measurementObservedAt: Date
    public let sourceVersion: String?
    public let windows: [QuotaWindow]

    public init(
        capturedAt: Date,
        measurementObservedAt: Date,
        sourceVersion: String?,
        windows: [QuotaWindow],
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.measurementObservedAt = measurementObservedAt
        self.sourceVersion = sourceVersion
        self.windows = windows
    }

    public func sameMeasurement(as other: ClaudeUsageSnapshot) -> Bool {
        sourceVersion == other.sourceVersion
            && windows.count == other.windows.count
            && zip(windows, other.windows).allSatisfy { lhs, rhs in
                lhs.id == rhs.id
                    && lhs.usedPercentage == rhs.usedPercentage
                    && lhs.durationMinutes == rhs.durationMinutes
                    && lhs.resetsAt == rhs.resetsAt
            }
    }
}

public enum ClaudeStatusLineDecodeError: Error, Equatable, Sendable {
    case malformedJSON
    case unsupportedPayload
    case invalidWindow
}

public enum ClaudeStatusLineDecoder {
    private struct Payload: Decodable {
        let version: String?
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case version
            case rateLimits = "rate_limits"
        }
    }

    private struct RateLimits: Decodable {
        let fiveHour: RawWindow?
        let sevenDay: RawWindow?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private struct RawWindow: Decodable {
        let usedPercentage: Double
        let resetsAt: Double

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }
    }

    public static func decode(_ data: Data, capturedAt: Date, previous: ClaudeUsageSnapshot? = nil) throws -> ClaudeUsageSnapshot {
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) }
        catch { throw ClaudeStatusLineDecodeError.malformedJSON }

        guard let limits = payload.rateLimits else { throw ClaudeStatusLineDecodeError.unsupportedPayload }
        var windows: [QuotaWindow] = []
        if let value = limits.fiveHour {
            windows.append(try window(value, id: "five_hour", label: "5-hour limit", durationMinutes: 300, now: capturedAt))
        }
        if let value = limits.sevenDay {
            windows.append(try window(value, id: "seven_day", label: "Weekly limit", durationMinutes: 10_080, now: capturedAt))
        }
        guard !windows.isEmpty else { throw ClaudeStatusLineDecodeError.unsupportedPayload }

        let candidate = ClaudeUsageSnapshot(
            capturedAt: capturedAt,
            measurementObservedAt: capturedAt,
            sourceVersion: sanitizedVersion(payload.version),
            windows: windows
        )
        let freshnessAnchor = previous.map { candidate.sameMeasurement(as: $0) ? $0.measurementObservedAt : capturedAt } ?? capturedAt
        return ClaudeUsageSnapshot(
            capturedAt: capturedAt,
            measurementObservedAt: freshnessAnchor,
            sourceVersion: candidate.sourceVersion,
            windows: windows
        )
    }

    private static func window(_ raw: RawWindow, id: String, label: String, durationMinutes: Int, now: Date) throws -> QuotaWindow {
        guard raw.usedPercentage.isFinite, (0...100).contains(raw.usedPercentage), raw.resetsAt.isFinite,
              raw.resetsAt >= 0, raw.resetsAt <= 4_102_444_800 else {
            throw ClaudeStatusLineDecodeError.invalidWindow
        }
        let reset = Date(timeIntervalSince1970: raw.resetsAt)
        return QuotaWindow(
            id: id,
            label: label,
            usedPercentage: raw.usedPercentage,
            resetText: resetText(reset, now: now),
            durationMinutes: durationMinutes,
            resetsAt: reset
        )
    }

    private static func sanitizedVersion(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value.utf8.count <= 64,
              value.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789.-+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ").contains($0) }) else {
            return nil
        }
        return value
    }

    public static func resetText(_ reset: Date, now: Date) -> String {
        let seconds = reset.timeIntervalSince(now)
        guard seconds > 0 else { return "Expired · refresh Claude Code" }
        if seconds >= 86_400 {
            let hours = Int(ceil(seconds / 3_600)), days = hours / 24, remainingHours = hours % 24
            return remainingHours == 0 ? "Resets in \(days)d" : "Resets in \(days)d \(remainingHours)h"
        }
        let minutes = Int(ceil(seconds / 60))
        if minutes >= 60 {
            let hours = minutes / 60, remainingMinutes = minutes % 60
            return remainingMinutes == 0 ? "Resets in \(hours)h" : "Resets in \(hours)h \(remainingMinutes)m"
        }
        return "Resets in \(minutes)m"
    }
}

public enum ClaudeSnapshotStoreError: Error, Equatable, Sendable {
    case missing, corrupt, unsupportedSchema, insecureLocation
}

public struct ClaudeSnapshotStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL }
        else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = root.appendingPathComponent("UsageGrid", isDirectory: true).appendingPathComponent("claude-usage-snapshot.json")
        }
    }

    public func load() throws -> ClaudeUsageSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw ClaudeSnapshotStoreError.missing }
        let snapshot: ClaudeUsageSnapshot
        do { snapshot = try JSONDecoder().decode(ClaudeUsageSnapshot.self, from: Data(contentsOf: fileURL)) }
        catch { throw ClaudeSnapshotStoreError.corrupt }
        guard snapshot.schemaVersion == ClaudeUsageSnapshot.currentSchemaVersion else { throw ClaudeSnapshotStoreError.unsupportedSchema }
        guard !snapshot.windows.isEmpty,
              snapshot.windows.allSatisfy({ $0.usedPercentage.isFinite && (0...100).contains($0.usedPercentage) && $0.resetsAt != nil }) else {
            throw ClaudeSnapshotStoreError.corrupt
        }
        return snapshot
    }

    public func capture(statusLineData: Data, at date: Date = Date()) throws -> ClaudeUsageSnapshot {
        let previous = try? load()
        let snapshot = try ClaudeStatusLineDecoder.decode(statusLineData, capturedAt: date, previous: previous)
        try save(snapshot)
        return snapshot
    }

    public func save(_ snapshot: ClaudeUsageSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
