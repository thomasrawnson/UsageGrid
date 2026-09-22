import Darwin
import Foundation

enum CodexUsageReader {
    static func read() async -> ProviderUsage? {
        await Task.detached(priority: .userInitiated) {
            readFromAppServer()
        }.value
    }

    static func parse(_ data: Data, now: Date) -> ProviderUsage? {
        guard
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = message["result"] as? [String: Any],
            let buckets = result["rateLimitsByLimitId"] as? [String: Any],
            let codex = buckets["codex"] as? [String: Any],
            let primary = codex["primary"] as? [String: Any],
            let used = primary["usedPercent"] as? Double,
            used.isFinite
        else { return nil }

        let resetText: String
        if let epoch = primary["resetsAt"] as? Double,
           epoch.isFinite,
           abs(epoch - now.timeIntervalSince1970) <= 366 * 24 * 60 * 60 {
            let minutes = max(0, Int(ceil((epoch - now.timeIntervalSince1970) / 60)))
            if minutes == 0 {
                resetText = "Reset due"
            } else if minutes >= 60 {
                let hours = minutes / 60
                let remainder = minutes % 60
                resetText = remainder == 0 ? "Resets in \(hours)h" : "Resets in \(hours)h \(remainder)m"
            } else {
                resetText = "Resets in \(minutes)m"
            }
        } else {
            resetText = "Reset unavailable"
        }

        return ProviderUsage(name: "Codex", usedPercentage: min(100, max(0, used)), resetText: resetText)
    }

    private static func readFromAppServer() -> ProviderUsage? {
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
