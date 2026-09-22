import Darwin
import Foundation

struct CodexUsageWindow {
    let id: String
    let label: String
    let usedPercentage: Double
    let resetText: String
    let durationMinutes: Int
}

enum CodexUsageReader {
    static func read() async -> [CodexUsageWindow]? {
        await Task.detached(priority: .userInitiated) {
            readFromAppServer()
        }.value
    }

    static func parse(_ data: Data, now: Date) -> [CodexUsageWindow]? {
        guard
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = message["result"] as? [String: Any],
            let buckets = result["rateLimitsByLimitId"] as? [String: Any],
            let codex = buckets["codex"] as? [String: Any]
        else { return nil }

        let windows = ["primary", "secondary"]
            .compactMap { key -> CodexUsageWindow? in
                guard let value = codex[key] as? [String: Any] else { return nil }
                return parseWindow(value, id: key, now: now)
            }
            .sorted { $0.durationMinutes < $1.durationMinutes }
        return windows.isEmpty ? nil : windows
    }

    private static func parseWindow(_ value: [String: Any], id: String, now: Date) -> CodexUsageWindow? {
        guard let used = value["usedPercent"] as? Double, used.isFinite,
              let duration = value["windowDurationMins"] as? Int, duration > 0 else { return nil }

        let label: String
        if duration == 10_080 {
            label = "Weekly limit"
        } else if duration.isMultiple(of: 1_440) {
            label = "\(duration / 1_440)-day limit"
        } else if duration.isMultiple(of: 60) {
            label = "\(duration / 60)-hour limit"
        } else {
            label = "\(duration)-minute limit"
        }

        return CodexUsageWindow(
            id: id,
            label: label,
            usedPercentage: min(100, max(0, used)),
            resetText: resetText(value["resetsAt"] as? Double, now: now),
            durationMinutes: duration
        )
    }

    private static func resetText(_ epoch: Double?, now: Date) -> String {
        guard let epoch, epoch.isFinite,
              abs(epoch - now.timeIntervalSince1970) <= 366 * 24 * 60 * 60 else {
            return "Reset unavailable"
        }
        let seconds = max(0, epoch - now.timeIntervalSince1970)
        if seconds == 0 { return "Reset due" }
        if seconds >= 24 * 60 * 60 {
            let hours = Int(ceil(seconds / 3_600))
            let days = hours / 24
            let remainingHours = hours % 24
            return remainingHours == 0 ? "Resets in \(days)d" : "Resets in \(days)d \(remainingHours)h"
        }
        let minutes = Int(ceil(seconds / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0 ? "Resets in \(hours)h" : "Resets in \(hours)h \(remainingMinutes)m"
        }
        return "Resets in \(minutes)m"
    }

    private static func readFromAppServer() -> [CodexUsageWindow]? {
        let path = "/Applications/ChatGPT.app/Contents/Resources/codex"
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["app-server"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        defer {
            input.fileHandleForWriting.closeFile()
            output.fileHandleForReading.closeFile()
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
        }

        var buffer = Data()
        let deadline = Date().addingTimeInterval(8)
        let initialize = #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"usagegrid","title":"UsageGrid","version":"0.1.0"}}}"#
        input.fileHandleForWriting.write(Data((initialize + "\n").utf8))
        guard readReply(id: 1, from: output, buffer: &buffer, deadline: deadline) != nil else { return nil }
        input.fileHandleForWriting.write(Data((#"{"method":"initialized","params":{}}"# + "\n").utf8))
        input.fileHandleForWriting.write(Data((#"{"method":"account/rateLimits/read","id":2}"# + "\n").utf8))
        guard let reply = readReply(id: 2, from: output, buffer: &buffer, deadline: deadline) else { return nil }
        return parse(reply, now: Date())
    }

    private static func readReply(id: Int, from pipe: Pipe, buffer: inout Data, deadline: Date) -> Data? {
        while Date() < deadline {
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                if let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                   message["id"] as? Int == id {
                    return line
                }
            }
            let timeout = Int32(max(1, min(1000, (deadline.timeIntervalSinceNow * 1000).rounded(.up))))
            var descriptor = pollfd(fd: pipe.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, timeout) > 0 else { continue }
            var chunk = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(descriptor.fd, &chunk, chunk.count)
            guard count > 0, buffer.count + count <= 1_000_000 else { return nil }
            buffer.append(contentsOf: chunk[..<count])
        }
        return nil
    }
}
