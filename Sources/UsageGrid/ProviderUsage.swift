struct ProviderUsage {
    let name: String
    let usedPercentage: Double
    let resetText: String

    var statusText: String {
        usedPercentage >= 80 ? "Getting high" : "Healthy"
    }
}
