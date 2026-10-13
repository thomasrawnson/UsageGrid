import Foundation
import UsageGridClaudeCore

let input = FileHandle.standardInput.readDataToEndOfFile()
do {
    let snapshot = try ClaudeSnapshotStore().capture(statusLineData: input)
    if CommandLine.arguments.contains("--display") {
        let values = snapshot.windows.map { "\($0.label): \(Int($0.usedPercentage.rounded()))%" }
        print(values.joined(separator: " · "))
    }
} catch {
    // Status-line failures stay quiet: no raw payload or error details are emitted.
    exit(1)
}
