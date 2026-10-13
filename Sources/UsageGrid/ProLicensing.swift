import Foundation
import Observation
import Security
import SwiftUI

struct ProLicenseCredential: Codable, Equatable, Sendable {
    let licenseKey: String
    let activationID: String
}

struct ProLicenseIdentity: Equatable, Sendable {
    let storeID: Int
    let productID: Int
    let variantID: Int
}

struct ProLicenseVerification: Equatable, Sendable {
    let credential: ProLicenseCredential
    let identity: ProLicenseIdentity
}

enum ProLicenseServiceError: Error, Equatable, Sendable {
    case invalidOrRevoked, rejected, invalidLicense, activationLimitReached
    case expired, revokedOrDisabled, networkUnavailable, timedOut
    case invalidResponse, productMismatch, majorVersionMismatch, instanceMismatch
    case configurationUnavailable, operationInProgress
}

protocol ProLicenseServicing: Sendable {
    func activate(licenseKey: String) async throws -> ProLicenseVerification
    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification
    func deactivate(credential: ProLicenseCredential) async throws -> ProLicenseIdentity
}

protocol ProLicenseCredentialStoring: Sendable {
    func load() throws -> ProLicenseCredential?
    func save(_ credential: ProLicenseCredential) throws
    func delete() throws
}

struct KeychainProLicenseCredentialStore: ProLicenseCredentialStoring {
    static let productionService = "com.plutonightlabs.UsageGrid.license"
    static let productionAccount = "lemonsqueezy.pro-license"
    #if DEBUG
    static let testService = "com.plutonightlabs.UsageGrid.license.test"
    static let testAccount = "lemonsqueezy.test-pro-license"
    #endif

    private let service: String
    private let account: String

    init(service: String = Self.productionService, account: String = Self.productionAccount) {
        self.service = service
        self.account = account
    }

    #if DEBUG
    static var testMode: Self { Self(service: testService, account: testAccount) }
    #endif

    func load() throws -> ProLicenseCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainStoreError.operationFailed }
        do { return try JSONDecoder().decode(ProLicenseCredential.self, from: data) }
        catch { throw KeychainStoreError.invalidStoredValue }
    }

    func save(_ credential: ProLicenseCredential) throws {
        let data = try JSONEncoder().encode(credential)
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainStoreError.operationFailed }
        } else if status != errSecSuccess {
            throw KeychainStoreError.operationFailed
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStoreError.operationFailed }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    enum KeychainStoreError: Error { case operationFailed, invalidStoredValue }
}

protocol ProLicenseInstanceIdentifying: Sendable {
    func instanceName() throws -> String
}

struct KeychainProLicenseInstanceIdentity: ProLicenseInstanceIdentifying {
    static let service = "com.plutonightlabs.UsageGrid.license"
    static let account = "lemonsqueezy.installation-id"

    func instanceName() throws -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        let identifier: String
        if status == errSecSuccess, let data = result as? Data,
           let stored = String(data: data, encoding: .utf8), !stored.isEmpty {
            identifier = stored
        } else if status == errSecItemNotFound {
            identifier = UUID().uuidString.lowercased()
            var item = baseQuery
            item[kSecValueData as String] = Data(identifier.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw ProLicenseServiceError.configurationUnavailable
            }
        } else {
            throw ProLicenseServiceError.configurationUnavailable
        }
        return "UsageGrid Mac \(identifier.prefix(12))"
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Self.service,
         kSecAttrAccount as String: Self.account]
    }
}

struct ProductionProLicenseConfiguration: Equatable, Sendable {
    let identity: ProLicenseIdentity
    let licensedMajorVersion: Int
    let requestTimeout: TimeInterval

    init(identity: ProLicenseIdentity, licensedMajorVersion: Int, requestTimeout: TimeInterval = 15) {
        self.identity = identity
        self.licensedMajorVersion = licensedMajorVersion
        self.requestTimeout = min(max(requestTimeout, 1), 30)
    }

    // Intentionally incomplete until owner-approved live Lemon Squeezy IDs exist.
    static let current: ProductionProLicenseConfiguration? = nil
}

struct UnavailableProLicenseService: ProLicenseServicing {
    func activate(licenseKey: String) async throws -> ProLicenseVerification { throw ProLicenseServiceError.networkUnavailable }
    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification { throw ProLicenseServiceError.networkUnavailable }
    func deactivate(credential: ProLicenseCredential) async throws -> ProLicenseIdentity { throw ProLicenseServiceError.networkUnavailable }
}

struct UnavailableProLicenseCredentialStore: ProLicenseCredentialStoring {
    func load() throws -> ProLicenseCredential? { nil }
    func save(_ credential: ProLicenseCredential) throws { throw Error.unavailable }
    func delete() throws {}
    enum Error: Swift.Error { case unavailable }
}

enum ProLicenseFailure: Equatable {
    case invalidEntry, invalidOrRevoked, activationLimitReached, expired, revokedOrDisabled
    case networkUnavailable, timedOut, invalidResponse, productMismatch, majorVersionMismatch, instanceMismatch
    case configurationUnavailable, operationInProgress
    case storageFailedAfterActivation, storageFailed, deactivationFailed

    var userMessage: String {
        switch self {
        case .invalidEntry: "Enter a licence key."
        case .invalidOrRevoked: "The licence is invalid, expired, disabled, or no longer active."
        case .activationLimitReached: "This licence is already active on three Macs. Deactivate another Mac before trying again."
        case .expired: "This licence has expired."
        case .revokedOrDisabled: "This licence is disabled or no longer active."
        case .networkUnavailable: "Couldn’t reach Lemon Squeezy. Check the connection and try again."
        case .timedOut: "Licence validation timed out. Check the connection and try again."
        case .invalidResponse: "Lemon Squeezy returned an unsupported response. Try again later."
        case .productMismatch: "The licence does not match this UsageGrid Pro product."
        case .majorVersionMismatch: "This licence does not cover this UsageGrid major version."
        case .instanceMismatch: "The licence activation does not match this stored Mac activation."
        case .configurationUnavailable: "Production licensing is not configured in this build."
        case .operationInProgress: "Another licence operation is already in progress."
        case .storageFailedAfterActivation: "Remote activation succeeded, but the credentials could not be stored. Retry secure storage; do not activate again."
        case .storageFailed: "The licence credentials could not be read or stored securely."
        case .deactivationFailed: "Deactivation was not confirmed. Credentials were retained so you can retry."
        }
    }
}

enum ProLicenseOperation: Equatable { case activating, validating, deactivating }
enum ProLicenseState: Equatable {
    case unavailable, inactive, working(ProLicenseOperation), verifiedActive, failed(ProLicenseFailure)
}

@MainActor @Observable
final class ProLicenseController {
    private let service: any ProLicenseServicing
    private let storage: any ProLicenseCredentialStoring
    private let expectedIdentity: ProLicenseIdentity?
    private let entitlementChanged: @MainActor (Bool) -> Void
    private(set) var state: ProLicenseState
    private(set) var hasStoredCredential = false
    private(set) var hasPendingStorageRecovery = false
    @ObservationIgnored private var pendingCredential: ProLicenseCredential?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var attemptedInitialValidation = false

    init(service: any ProLicenseServicing, storage: any ProLicenseCredentialStoring,
         expectedIdentity: ProLicenseIdentity?, activationAvailable: Bool,
         entitlementChanged: @escaping @MainActor (Bool) -> Void = { _ in }) {
        self.service = service
        self.storage = storage
        self.expectedIdentity = expectedIdentity
        self.entitlementChanged = entitlementChanged
        state = activationAvailable && expectedIdentity != nil ? .inactive : .unavailable
    }

    static func productionFoundation() -> ProLicenseController {
        ProLicenseController(service: UnavailableProLicenseService(), storage: UnavailableProLicenseCredentialStore(),
                             expectedIdentity: nil, activationAvailable: false)
    }

    var hasVerifiedEntitlement: Bool { state == .verifiedActive }
    var isWorking: Bool { if case .working = state { true } else { false } }

    @discardableResult func activate(licenseKey: String) -> Bool {
        guard canStartOperation else { return false }
        let candidate = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { state = .failed(.invalidEntry); return false }
        begin(.activating)
        let currentRevision = revision
        operation = Task { [weak self, service, expectedIdentity] in
            do {
                let verification = try await service.activate(licenseKey: candidate)
                guard let self, self.isCurrent(currentRevision) else { return }
                guard verification.identity == expectedIdentity else { self.finishFailure(.productMismatch); return }
                do {
                    try self.storage.save(verification.credential)
                    self.hasStoredCredential = true
                    self.pendingCredential = nil
                    self.hasPendingStorageRecovery = false
                    self.finishVerified()
                } catch {
                    self.pendingCredential = verification.credential
                    self.hasPendingStorageRecovery = true
                    self.finishFailure(.storageFailedAfterActivation)
                }
            } catch {
                guard let self, self.isCurrent(currentRevision) else { return }
                self.finishFailure(Self.failure(for: error))
            }
        }
        return true
    }

    @discardableResult func retryPendingCredentialStorage() -> Bool {
        guard !isWorking, let credential = pendingCredential else { return false }
        do {
            try storage.save(credential)
            hasStoredCredential = true
            pendingCredential = nil
            hasPendingStorageRecovery = false
            finishVerified()
            return true
        } catch {
            state = .failed(.storageFailedAfterActivation)
            return false
        }
    }

    @discardableResult func validateStoredCredential(initial: Bool = false) -> Bool {
        guard canStartOperation else { return false }
        if initial { guard !attemptedInitialValidation else { return false }; attemptedInitialValidation = true }
        let credential: ProLicenseCredential
        do {
            guard let stored = try storage.load() else {
                hasStoredCredential = false; entitlementChanged(false); state = .inactive; return false
            }
            credential = stored
            hasStoredCredential = true
        } catch {
            entitlementChanged(false); state = .failed(.storageFailed); return false
        }
        begin(.validating)
        let currentRevision = revision
        operation = Task { [weak self, service, expectedIdentity] in
            do {
                let verification = try await service.validate(credential: credential)
                guard let self, self.isCurrent(currentRevision) else { return }
                guard verification.identity == expectedIdentity else { self.finishFailure(.productMismatch); return }
                self.finishVerified()
            } catch {
                guard let self, self.isCurrent(currentRevision) else { return }
                self.finishFailure(Self.failure(for: error))
            }
        }
        return true
    }

    @discardableResult func deactivate() -> Bool {
        guard canStartOperation else { return false }
        let credential: ProLicenseCredential
        do {
            guard let stored = try storage.load() else {
                hasStoredCredential = false; entitlementChanged(false); state = .inactive; return false
            }
            credential = stored
            hasStoredCredential = true
        } catch { finishFailure(.storageFailed); return false }
        begin(.deactivating)
        let currentRevision = revision
        operation = Task { [weak self, service, expectedIdentity] in
            do {
                let identity = try await service.deactivate(credential: credential)
                guard let self, self.isCurrent(currentRevision) else { return }
                guard identity == expectedIdentity else { self.finishFailure(.productMismatch); return }
                do {
                    try self.storage.delete()
                    self.hasStoredCredential = false
                    self.operation = nil
                    self.state = .inactive
                } catch { self.finishFailure(.storageFailed) }
            } catch {
                guard let self, self.isCurrent(currentRevision) else { return }
                self.finishFailure(.deactivationFailed)
            }
        }
        return true
    }

    func cancelPendingOperation() {
        guard isWorking else { return }
        revision += 1
        operation?.cancel()
        operation = nil
        entitlementChanged(false)
        state = hasStoredCredential ? .failed(.networkUnavailable) : .inactive
    }

    func waitForOperation() async { await operation?.value }

    private var canStartOperation: Bool { state != .unavailable && !isWorking && expectedIdentity != nil }
    private func begin(_ kind: ProLicenseOperation) {
        revision += 1; operation?.cancel(); operation = nil; entitlementChanged(false); state = .working(kind)
    }
    private func isCurrent(_ candidate: Int) -> Bool { !Task.isCancelled && candidate == revision }
    private func finishVerified() { operation = nil; state = .verifiedActive; entitlementChanged(true) }
    private func finishFailure(_ failure: ProLicenseFailure) {
        operation = nil; state = .failed(failure); entitlementChanged(false)
    }
    private static func failure(for error: Error) -> ProLicenseFailure {
        guard let value = error as? ProLicenseServiceError else { return .networkUnavailable }
        switch value {
        case .invalidOrRevoked, .rejected, .invalidLicense: return ProLicenseFailure.invalidOrRevoked
        case .activationLimitReached: return .activationLimitReached
        case .expired: return .expired
        case .revokedOrDisabled: return .revokedOrDisabled
        case .networkUnavailable: return ProLicenseFailure.networkUnavailable
        case .timedOut: return .timedOut
        case .invalidResponse: return ProLicenseFailure.invalidResponse
        case .productMismatch: return .productMismatch
        case .majorVersionMismatch: return .majorVersionMismatch
        case .instanceMismatch: return .instanceMismatch
        case .configurationUnavailable: return .configurationUnavailable
        case .operationInProgress: return .operationInProgress
        }
    }
}

#if DEBUG
struct ProLicenseActivationView: View {
    @Bindable var controller: ProLicenseController
    @State private var licenseKey = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("Test licence key", text: $licenseKey)
                .textContentType(.password)
                .disabled(controller.state == .unavailable || controller.isWorking || controller.hasStoredCredential)
            HStack {
                Button("Activate test licence") {
                    if controller.activate(licenseKey: licenseKey) { licenseKey = "" }
                }
                .disabled(controller.state == .unavailable || controller.isWorking || controller.hasStoredCredential || controller.hasPendingStorageRecovery)
                if controller.hasStoredCredential {
                    Button("Validate") { controller.validateStoredCredential() }.disabled(controller.isWorking)
                    Button("Deactivate", role: .destructive) { controller.deactivate() }.disabled(controller.isWorking)
                }
                if controller.hasPendingStorageRecovery {
                    Button("Retry secure storage") { controller.retryPendingCredentialStorage() }.disabled(controller.isWorking)
                }
            }
            if case .working(let operation) = controller.state {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(operation.title).foregroundStyle(.secondary)
                    Button("Cancel") { controller.cancelPendingOperation() }
                }
            }
            status
        }
    }
    @ViewBuilder private var status: some View {
        switch controller.state {
        case .unavailable: Label("Test activation is unavailable in this build.", systemImage: "lock.fill").foregroundStyle(.secondary)
        case .inactive: Text("No verified test licence. Test Pro access is off.").foregroundStyle(.secondary)
        case .working: EmptyView()
        case .verifiedActive: Label("Test licence verified online · Test Pro access active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .failed(let failure): Label(failure.userMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

private extension ProLicenseOperation {
    var title: String {
        switch self { case .activating: "Activating…"; case .validating: "Validating…"; case .deactivating: "Deactivating…" }
    }
}
#endif

protocol ProLicenseHTTPTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionProLicenseHTTPTransport: ProLicenseHTTPTransporting {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProLicenseServiceError.invalidResponse }
        return (data, http)
    }
}

private struct LemonSqueezyLicenseAPIClient: Sendable {
    let expectedIdentity: ProLicenseIdentity
    let instanceIdentity: any ProLicenseInstanceIdentifying
    private let transport: any ProLicenseHTTPTransporting
    private let baseURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses")!
    private let requestTimeout: TimeInterval

    init(expectedIdentity: ProLicenseIdentity,
         instanceIdentity: any ProLicenseInstanceIdentifying,
         requestTimeout: TimeInterval,
         transport: any ProLicenseHTTPTransporting) {
        self.expectedIdentity = expectedIdentity
        self.instanceIdentity = instanceIdentity
        self.requestTimeout = requestTimeout
        self.transport = transport
    }

    func activate(licenseKey: String) async throws -> ProLicenseVerification {
        let response: LicenseResponse = try await post(path: "activate", fields: [
            "license_key": licenseKey,
            "instance_name": try instanceIdentity.instanceName()
        ])
        guard response.activated == true else { throw response.failure }
        try verify(response.identity)
        try response.requireActiveStatus()
        guard let instanceID = response.instance?.id else { throw ProLicenseServiceError.invalidResponse }
        return ProLicenseVerification(credential: ProLicenseCredential(licenseKey: licenseKey, activationID: instanceID), identity: expectedIdentity)
    }

    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification {
        let response: LicenseResponse = try await post(path: "validate", fields: ["license_key": credential.licenseKey, "instance_id": credential.activationID])
        guard response.valid == true else { throw response.failure }
        try verify(response.identity)
        try response.requireActiveStatus()
        guard response.instance?.id == credential.activationID else { throw ProLicenseServiceError.instanceMismatch }
        return ProLicenseVerification(credential: credential, identity: expectedIdentity)
    }

    func deactivate(credential: ProLicenseCredential) async throws -> ProLicenseIdentity {
        let response: LicenseResponse = try await post(path: "deactivate", fields: ["license_key": credential.licenseKey, "instance_id": credential.activationID])
        guard response.deactivated == true else { throw response.failure }
        try verify(response.identity)
        return expectedIdentity
    }

    private func verify(_ identity: ProLicenseIdentity) throws {
        guard identity == expectedIdentity else { throw ProLicenseServiceError.productMismatch }
    }

    private func post<Response: Decodable>(path: String, fields: [String: String]) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields.sorted(by: { $0.key < $1.key })
            .map { "\(Self.formEncode($0.key))=\(Self.formEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .timedOut { throw ProLicenseServiceError.timedOut }
        catch { throw ProLicenseServiceError.networkUnavailable }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 408 || response.statusCode == 504 { throw ProLicenseServiceError.timedOut }
            if let decoded = try? JSONDecoder().decode(LicenseResponse.self, from: data) { throw decoded.failure }
            throw ProLicenseServiceError.invalidResponse
        }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw ProLicenseServiceError.invalidResponse }
    }
    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed; allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

actor LemonSqueezyProductionLicenseService: ProLicenseServicing {
    private let configuration: ProductionProLicenseConfiguration?
    private let runningMajorVersion: Int
    private let client: LemonSqueezyLicenseAPIClient?
    private var operationInProgress = false

    init(configuration: ProductionProLicenseConfiguration? = .current,
         runningMajorVersion: Int,
         instanceIdentity: any ProLicenseInstanceIdentifying = KeychainProLicenseInstanceIdentity(),
         transport: any ProLicenseHTTPTransporting = URLSessionProLicenseHTTPTransport()) {
        self.configuration = configuration
        self.runningMajorVersion = runningMajorVersion
        if let configuration {
            client = LemonSqueezyLicenseAPIClient(
                expectedIdentity: configuration.identity,
                instanceIdentity: instanceIdentity,
                requestTimeout: configuration.requestTimeout,
                transport: transport
            )
        } else {
            client = nil
        }
    }

    nonisolated static func runningMajorVersion(bundle: Bundle = .main) -> Int? {
        guard let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let first = raw.split(separator: ".").first else { return nil }
        return Int(first)
    }

    func activate(licenseKey: String) async throws -> ProLicenseVerification {
        try await perform { try await $0.activate(licenseKey: licenseKey) }
    }

    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification {
        try await perform { try await $0.validate(credential: credential) }
    }

    func deactivate(credential: ProLicenseCredential) async throws -> ProLicenseIdentity {
        try await perform { try await $0.deactivate(credential: credential) }
    }

    private func perform<T: Sendable>(_ body: (LemonSqueezyLicenseAPIClient) async throws -> T) async throws -> T {
        guard let configuration, let client else { throw ProLicenseServiceError.configurationUnavailable }
        guard configuration.licensedMajorVersion == runningMajorVersion else { throw ProLicenseServiceError.majorVersionMismatch }
        guard !operationInProgress else { throw ProLicenseServiceError.operationInProgress }
        operationInProgress = true
        defer { operationInProgress = false }
        return try await body(client)
    }
}

#if DEBUG
private struct DebugProLicenseInstanceIdentity: ProLicenseInstanceIdentifying {
    func instanceName() -> String { "UsageGrid Debug on macOS" }
}

struct LemonSqueezyTestLicenseService: ProLicenseServicing {
    static let identity = ProLicenseIdentity(storeID: 485681, productID: 1395768, variantID: 2179685)
    private let client: LemonSqueezyLicenseAPIClient

    init(transport: any ProLicenseHTTPTransporting = URLSessionProLicenseHTTPTransport()) {
        client = LemonSqueezyLicenseAPIClient(
            expectedIdentity: Self.identity,
            instanceIdentity: DebugProLicenseInstanceIdentity(),
            requestTimeout: 15,
            transport: transport
        )
    }

    func activate(licenseKey: String) async throws -> ProLicenseVerification {
        do { return try await client.activate(licenseKey: licenseKey) }
        catch { throw Self.legacyError(error) }
    }
    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification {
        do { return try await client.validate(credential: credential) }
        catch { throw Self.legacyError(error) }
    }
    func deactivate(credential: ProLicenseCredential) async throws -> ProLicenseIdentity {
        do { return try await client.deactivate(credential: credential) }
        catch { throw Self.legacyError(error) }
    }

    private static func legacyError(_ error: Error) -> Error {
        switch error as? ProLicenseServiceError {
        case .expired, .revokedOrDisabled, .invalidLicense: ProLicenseServiceError.invalidOrRevoked
        default: error
        }
    }
}
#endif

private struct LicenseResponse: Decodable {
    let activated: Bool?, valid: Bool?, deactivated: Bool?, error: String?
    let licenseKey: LicenseKey?, instance: Instance?, meta: Meta?
    struct LicenseKey: Decodable { let status: String? }
    struct Instance: Decodable { let id: String }
    struct Meta: Decodable {
        let storeID: Int
        let productID: Int
        let variantID: Int

        enum CodingKeys: String, CodingKey {
            case storeID = "store_id"
            case productID = "product_id"
            case variantID = "variant_id"
        }
    }
    enum CodingKeys: String, CodingKey { case activated, valid, deactivated, error, instance, meta; case licenseKey = "license_key" }
    var identity: ProLicenseIdentity {
        get throws {
            guard let meta else { throw ProLicenseServiceError.invalidResponse }
            return ProLicenseIdentity(storeID: meta.storeID, productID: meta.productID, variantID: meta.variantID)
        }
    }
    var failure: ProLicenseServiceError {
        let normalizedError = error?.lowercased() ?? ""
        if normalizedError.contains("activation limit") { return .activationLimitReached }
        switch licenseKey?.status {
        case "expired": return .expired
        case "disabled": return .revokedOrDisabled
        case "inactive": return .invalidLicense
        case "active": return normalizedError.isEmpty ? .invalidResponse : .invalidLicense
        default: return normalizedError.isEmpty ? .invalidResponse : .invalidLicense
        }
    }

    func requireActiveStatus() throws {
        switch licenseKey?.status {
        case "active": return
        case "expired": throw ProLicenseServiceError.expired
        case "disabled": throw ProLicenseServiceError.revokedOrDisabled
        case "inactive": throw ProLicenseServiceError.invalidLicense
        default: throw ProLicenseServiceError.invalidResponse
        }
    }
}
