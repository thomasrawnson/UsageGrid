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
    case invalidOrRevoked, rejected, networkUnavailable, invalidResponse
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
    case invalidEntry, invalidOrRevoked, networkUnavailable, invalidResponse, productMismatch
    case storageFailedAfterActivation, storageFailed, deactivationFailed

    var userMessage: String {
        switch self {
        case .invalidEntry: "Enter a licence key."
        case .invalidOrRevoked: "The licence is invalid, expired, disabled, or no longer active."
        case .networkUnavailable: "Couldn’t reach Lemon Squeezy. Check the connection and try again."
        case .invalidResponse: "Lemon Squeezy returned an unsupported response. Try again later."
        case .productMismatch: "The licence does not match the configured UsageGrid Pro test product."
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
        case .invalidOrRevoked, .rejected: return ProLicenseFailure.invalidOrRevoked
        case .networkUnavailable: return ProLicenseFailure.networkUnavailable
        case .invalidResponse: return ProLicenseFailure.invalidResponse
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

struct LemonSqueezyTestLicenseService: ProLicenseServicing {
    static let identity = ProLicenseIdentity(storeID: 485681, productID: 1395768, variantID: 2179685)
    private let transport: any ProLicenseHTTPTransporting
    private let baseURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses")!
    init(transport: any ProLicenseHTTPTransporting = URLSessionProLicenseHTTPTransport()) { self.transport = transport }

    func activate(licenseKey: String) async throws -> ProLicenseVerification {
        let response: LicenseResponse = try await post(path: "activate", fields: ["license_key": licenseKey, "instance_name": "UsageGrid Debug on macOS"])
        guard response.activated == true else { throw response.failure }
        guard let instanceID = response.instance?.id else { throw ProLicenseServiceError.invalidResponse }
        return ProLicenseVerification(credential: ProLicenseCredential(licenseKey: licenseKey, activationID: instanceID), identity: try response.identity)
    }
    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification {
        let response: LicenseResponse = try await post(path: "validate", fields: ["license_key": credential.licenseKey, "instance_id": credential.activationID])
        guard response.valid == true else { throw response.failure }
        guard response.instance?.id == credential.activationID else { throw ProLicenseServiceError.invalidResponse }
        return ProLicenseVerification(credential: credential, identity: try response.identity)
    }
    func deactivate(credential: ProLicenseCredential) async throws -> ProLicenseIdentity {
        let response: LicenseResponse = try await post(path: "deactivate", fields: ["license_key": credential.licenseKey, "instance_id": credential.activationID])
        guard response.deactivated == true else { throw response.failure }
        return try response.identity
    }
    private func post<Response: Decodable>(path: String, fields: [String: String]) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields.sorted(by: { $0.key < $1.key })
            .map { "\(Self.formEncode($0.key))=\(Self.formEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw ProLicenseServiceError.networkUnavailable }
        guard (200..<300).contains(response.statusCode) else { throw ProLicenseServiceError.networkUnavailable }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw ProLicenseServiceError.invalidResponse }
    }
    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed; allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

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
        switch licenseKey?.status { case "disabled", "expired", "inactive": .invalidOrRevoked; default: .rejected }
    }
}
#endif
