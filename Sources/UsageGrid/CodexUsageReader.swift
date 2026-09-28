import Darwin
import Foundation
import OSLog

struct CodexUsageWindow {
    let id: String
    let label: String
    let usedPercentage: Double
    let resetText: String
    let durationMinutes: Int
    let resetsAt: Date?

    init(id: String, label: String, usedPercentage: Double, resetText: String, durationMinutes: Int, resetsAt: Date? = nil) {
        self.id = id
        self.label = label
        self.usedPercentage = usedPercentage
        self.resetText = resetText
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
    }
}

enum CodexUsageReadError: Equatable {
    case executableNotFound, processLaunchFailed, initializationTimedOut, initializationFailed
    case requestTimedOut, authenticationRequired, requestFailed, decodingFailed, cancelled

    var userMessage: String {
        switch self {
        case .executableNotFound: "Supported Codex executable not found. Open or update ChatGPT, then retry."
        case .processLaunchFailed: "Could not start Codex. Check the ChatGPT installation."
        case .initializationTimedOut: "Codex did not initialize in time. Try again."
        case .initializationFailed: "Codex initialization failed. Update ChatGPT and try again."
        case .requestTimedOut: "Codex usage request timed out. Try again."
        case .authenticationRequired: "Codex is signed out. Sign in with Codex, then refresh."
        case .requestFailed: "Codex rejected the usage request. Check Codex /status."
        case .decodingFailed: "Codex returned no supported usage windows. Update UsageGrid if /status works."
        case .cancelled: "Codex usage refresh was cancelled. Retry."
        }
    }
}

struct CodexUsageReadResult {
    let windows: [CodexUsageWindow]?
    let error: CodexUsageReadError?
    static func success(_ windows: [CodexUsageWindow]) -> Self { Self(windows: windows, error: nil) }
    static func failure(_ error: CodexUsageReadError) -> Self { Self(windows: nil, error: error) }
}

enum CodexUsageReader {
    private static let logger = Logger(subsystem: "com.plutonightlabs.UsageGrid", category: "CodexUsage")
    static let executableCandidates = [
        "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
        "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "/Applications/ChatGPT.app/Contents/Resources/codex"
    ]

    static func read(timeout: TimeInterval = 10) async -> CodexUsageReadResult {
        guard let path = resolveExecutable() else {
            logger.error("Codex executable not found in supported ChatGPT locations")
            return .failure(.executableNotFound)
        }
        return await read(executablePath: path, timeout: timeout)
    }

    static func read(executablePath: String, timeout: TimeInterval) async -> CodexUsageReadResult {
        let worker = Task.detached(priority: .userInitiated) {
            readFromAppServer(path: executablePath, deadline: Date().addingTimeInterval(timeout))
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func resolveExecutable(isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> String? {
        executableCandidates.first(where: isExecutable)
    }

    static func parse(_ data: Data, now: Date) -> [CodexUsageWindow]? {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              message["error"] == nil,
              let result = message["result"] as? [String: Any],
              let buckets = result["rateLimitsByLimitId"] as? [String: Any],
              let codex = buckets["codex"] as? [String: Any] else { return nil }

        let windows = ["primary", "secondary"].compactMap { key -> CodexUsageWindow? in
            guard let value = codex[key] as? [String: Any] else { return nil }
            return parseWindow(value, id: key, now: now)
        }.sorted { $0.durationMinutes < $1.durationMinutes }
        return windows.isEmpty ? nil : windows
    }

    private static func parseWindow(_ value: [String: Any], id: String, now: Date) -> CodexUsageWindow? {
        guard let used = value["usedPercent"] as? Double, used.isFinite,
              let duration = value["windowDurationMins"] as? Int, duration > 0 else { return nil }
        let label: String
        if duration == 10_080 { label = "Weekly limit" }
        else if duration.isMultiple(of: 1_440) { label = "\(duration / 1_440)-day limit" }
        else if duration.isMultiple(of: 60) { label = "\(duration / 60)-hour limit" }
        else { label = "\(duration)-minute limit" }
        let resetDate = resetDate(value["resetsAt"] as? Double, now: now)
        return CodexUsageWindow(id: id, label: label, usedPercentage: min(100, max(0, used)),
                                resetText: resetText(resetDate, now: now), durationMinutes: duration, resetsAt: resetDate)
    }

    private static func resetDate(_ epoch: Double?, now: Date) -> Date? {
        guard let epoch, epoch.isFinite, abs(epoch - now.timeIntervalSince1970) <= 366 * 24 * 60 * 60 else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }

    private static func resetText(_ resetDate: Date?, now: Date) -> String {
        guard let resetDate else { return "Reset unavailable" }
        let seconds = max(0, resetDate.timeIntervalSince(now))
        if seconds == 0 { return "Reset due" }
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

    private static func readFromAppServer(path: String, deadline: Date) -> CodexUsageReadResult {
        logger.info("Starting bundled Codex app-server; configuration environment is inherited")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["app-server"]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch {
            logger.error("Codex app-server process launch failed")
            return .failure(.processLaunchFailed)
        }
        defer {
            input.fileHandleForWriting.closeFile()
            output.fileHandleForReading.closeFile()
            stop(process)
        }

        var buffer = Data()
        let initialize = #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"usagegrid","title":"UsageGrid","version":"0.1.0"}}}"#
        input.fileHandleForWriting.write(Data((initialize + "\n").utf8))
        guard let initializationReply = readReply(id: 1, from: output, buffer: &buffer, deadline: deadline) else {
            if Task.isCancelled { return .failure(.cancelled) }
            logger.error("Codex app-server initialization timed out")
            return .failure(.initializationTimedOut)
        }
        if responseHasError(initializationReply) {
            logger.error("Codex app-server initialization returned an error")
            return .failure(.initializationFailed)
        }

        input.fileHandleForWriting.write(Data((#"{"method":"initialized"}"# + "\n").utf8))
        input.fileHandleForWriting.write(Data((#"{"method":"account/rateLimits/read","id":2,"params":{"supportsLunaReserve":false,"excludeResetCreditDetails":true}}"# + "\n").utf8))
        guard let reply = readReply(id: 2, from: output, buffer: &buffer, deadline: deadline) else {
            if Task.isCancelled { return .failure(.cancelled) }
            logger.error("Codex rate-limit request timed out")
            return .failure(.requestTimedOut)
        }
        if responseHasError(reply) {
            let error = responseIndicatesAuthenticationFailure(reply) ? CodexUsageReadError.authenticationRequired : .requestFailed
            logger.error("Codex rate-limit request returned an error; category=\(String(describing: error), privacy: .public)")
            return .failure(error)
        }
        guard let windows = parse(reply, now: Date()) else {
            logger.error("Codex rate-limit response contained no supported valid windows")
            return .failure(.decodingFailed)
        }
        logger.info("Codex rate-limit request succeeded with \(windows.count, privacy: .public) window(s)")
        return .success(windows)
    }

    private static func responseHasError(_ data: Data) -> Bool {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return true }
        return message["error"] != nil
    }

    private static func responseIndicatesAuthenticationFailure(_ data: Data) -> Bool {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = message["error"] as? [String: Any], let text = error["message"] as? String else { return false }
        let normalized = text.lowercased()
        return normalized.contains("auth") || normalized.contains("sign in") || normalized.contains("login")
    }

    private static func readReply(id: Int, from pipe: Pipe, buffer: inout Data, deadline: Date) -> Data? {
        while Date() < deadline {
            guard !Task.isCancelled else { return nil }
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                if let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any], message["id"] as? Int == id { return line }
            }
            let timeout = Int32(max(1, min(100, (deadline.timeIntervalSinceNow * 1000).rounded(.up))))
            var descriptor = pollfd(fd: pipe.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, timeout) > 0 else { continue }
            var chunk = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(descriptor.fd, &chunk, chunk.count)
            guard count > 0, buffer.count + count <= 1_000_000 else { return nil }
            buffer.append(contentsOf: chunk[..<count])
        }
        return nil
    }

    private static func stop(_ process: Process) {
        guard process.isRunning else {
            process.waitUntilExit()
            return
        }
        process.terminate()
        let graceDeadline = Date().addingTimeInterval(0.5)
        while process.isRunning, Date() < graceDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }
}
