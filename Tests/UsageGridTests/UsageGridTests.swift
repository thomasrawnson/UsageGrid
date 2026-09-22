import Testing
@testable import UsageGrid

@Test func appTargetLinks() {
    #expect(String(describing: UsageGridApp.self) == "UsageGridApp")
}

@Test func usageStatusBoundary() {
    #expect(ProviderUsage(name: "Codex", usedPercentage: 79.9, resetText: "").statusText == "Healthy")
    #expect(ProviderUsage(name: "Codex", usedPercentage: 80, resetText: "").statusText == "Getting high")
}
