import Foundation
import Observation
import Security
import SwiftUI

struct ProLicenseCredential: Codable, Equatable, Sendable {
    let licenseKey: String
    let activationID: String
}

struct ProLicenseIdentity: Equatable, Sendable {
    let storeID: String
    let productID: String
}

struct ProLicenseVerification: Equatable, Sendable {
    let credential: ProLicenseCredential
    let identity: ProLicenseIdentity
}

protocol ProLicenseServicing: Sendable {
    func activate(licenseKey: String) async throws -> ProLicenseVerification
    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification
    func deactivate(credential: ProLicenseCredential) async throws
}

protocol ProLicenseCredentialStoring: Sendable {
    func load() throws -> ProLicenseCredential?
    func save(_ credential: ProLicenseCredential) throws
    func delete() throws
}

struct KeychainProLicenseCredentialStore: ProLicenseCredentialStoring {
    static let service = "com.plutonightlabs.UsageGrid.license"
    static let account = "lemonsqueezy.pro-license"

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
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
    }

    enum KeychainStoreError: Error { case operationFailed, invalidStoredValue }
}

struct UnavailableProLicenseService: ProLicenseServicing {
    func activate(licenseKey: String) async throws -> ProLicenseVerification { throw Error.unavailable }
    func validate(credential: ProLicenseCredential) async throws -> ProLicenseVerification { throw Error.unavailable }
    func deactivate(credential: ProLicenseCredential) async throws { throw Error.unavailable }
    enum Error: Swift.Error { case unavailable }
}

struct UnavailableProLicenseCredentialStore: ProLicenseCredentialStoring {
    func load() throws -> ProLicenseCredential? { nil }
    func save(_ credential: ProLicenseCredential) throws { throw Error.unavailable }
    func delete() throws {}
    enum Error: Swift.Error { case unavailable }
}

enum ProLicenseFailure: Equatable {
    case invalidEntry
    case activationRejected
    case validationFailed
    case productMismatch
    case storageFailed
    case deactivationFailed

    var userMessage: String {
        switch self {
        case .invalidEntry: "Enter a licence key."
        case .activationRejected: "Activation could not be completed. Check the key and try again."
        case .validationFailed: "The saved licence could not be verified."
        case .productMismatch: "The licence is not valid for this UsageGrid Pro product."
        case .storageFailed: "The verified licence could not be stored securely."
        case .deactivationFailed: "Deactivation could not be completed. Try again."
        }
    }
}

enum ProLicenseState: Equatable {
    case unavailable
    case inactive
    case activating
    case verifiedActive
    case failed(ProLicenseFailure)
}

@MainActor @Observable
final class ProLicenseController {
    private let service: any ProLicenseServicing
    private let storage: any ProLicenseCredentialStoring
    private let expectedIdentity: ProLicenseIdentity?
    private(set) var state: ProLicenseState
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var revision = 0

    init(
        service: any ProLicenseServicing,
        storage: any ProLicenseCredentialStoring,
        expectedIdentity: ProLicenseIdentity?,
        activationAvailable: Bool
    ) {
        self.service = service
        self.storage = storage
        self.expectedIdentity = expectedIdentity
        state = activationAvailable && expectedIdentity != nil ? .inactive : .unavailable
    }

    static func productionFoundation() -> ProLicenseController {
        ProLicenseController(
            service: UnavailableProLicenseService(),
            storage: UnavailableProLicenseCredentialStore(),
            expectedIdentity: nil,
            activationAvailable: false
        )
    }

    var hasVerifiedEntitlement: Bool { state == .verifiedActive }

    @discardableResult
    func activate(licenseKey: String) -> Bool {
        guard state != .unavailable, state != .activating, expectedIdentity != nil else { return false }
        let candidate = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            state = .failed(.invalidEntry)
            return false
        }

        revision += 1
        let operationRevision = revision
        state = .activating
        operation = Task { [weak self, service, storage, expectedIdentity] in
            do {
                let verification = try await service.activate(licenseKey: candidate)
                guard !Task.isCancelled, let self, operationRevision == self.revision else { return }
                guard verification.identity == expectedIdentity else {
                    self.state = .failed(.productMismatch)
                    self.operation = nil
                    return
                }
                do {
                    try storage.save(verification.credential)
                } catch {
                    self.state = .failed(.storageFailed)
                    self.operation = nil
                    return
                }
                self.state = .verifiedActive
                self.operation = nil
            } catch {
                guard !Task.isCancelled, let self, operationRevision == self.revision else { return }
                self.state = .failed(.activationRejected)
                self.operation = nil
            }
        }
        return true
    }

    func validateStoredCredential() async {
        guard state != .unavailable, let expectedIdentity else { return }
        let credential: ProLicenseCredential
        do {
            guard let stored = try storage.load() else {
                state = .inactive
                return
            }
            credential = stored
        } catch {
            state = .failed(.storageFailed)
            return
        }

        revision += 1
        let operationRevision = revision
        state = .activating
        do {
            let verification = try await service.validate(credential: credential)
            guard !Task.isCancelled, operationRevision == revision else { return }
            state = verification.identity == expectedIdentity ? .verifiedActive : .failed(.productMismatch)
        } catch {
            guard !Task.isCancelled, operationRevision == revision else { return }
            state = .failed(.validationFailed)
        }
    }

    func deactivate() async {
        guard state == .verifiedActive else { return }
        let credential: ProLicenseCredential
        do {
            guard let stored = try storage.load() else {
                state = .inactive
                return
            }
            credential = stored
            try await service.deactivate(credential: credential)
            try storage.delete()
            state = .inactive
        } catch {
            state = .failed(.deactivationFailed)
        }
    }

    func cancelPendingOperation() {
        guard state == .activating else { return }
        revision += 1
        operation?.cancel()
        operation = nil
        state = .inactive
    }

    func waitForOperation() async { await operation?.value }
}

struct ProLicenseActivationSheet: View {
    @State private var controller = ProLicenseController.productionFoundation()

    var body: some View {
        ProLicenseActivationView(controller: controller)
    }
}

struct ProLicenseActivationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var controller: ProLicenseController
    @State private var licenseKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("UsageGrid Pro activation").font(.headline)
                Spacer()
                Button("Close") {
                    controller.cancelPendingOperation()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Text("One-off purchase through Lemon Squeezy is planned. Purchasing and production activation are not available yet.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("Licence key", text: $licenseKey)
                .textContentType(.password)
                .disabled(controller.state == .unavailable || controller.state == .activating)

            HStack {
                Button("Activate") { controller.activate(licenseKey: licenseKey) }
                    .disabled(controller.state == .unavailable || controller.state == .activating)
                if controller.state == .activating {
                    ProgressView().controlSize(.small)
                    Text("Activating…").foregroundStyle(.secondary)
                }
            }

            status
        }
        .padding(18)
        .frame(width: 420)
        .onDisappear { controller.cancelPendingOperation() }
    }

    @ViewBuilder private var status: some View {
        switch controller.state {
        case .unavailable:
            Label("Activation is not available in this build.", systemImage: "lock.fill").foregroundStyle(.secondary)
        case .inactive:
            Text("Enter a licence key to activate when integration becomes available.").foregroundStyle(.secondary)
        case .activating:
            EmptyView()
        case .verifiedActive:
            Label("UsageGrid Pro licence verified.", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .failed(let failure):
            Label(failure.userMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
