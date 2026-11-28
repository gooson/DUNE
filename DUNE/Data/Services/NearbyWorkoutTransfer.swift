import CloudKit
import CryptoKit
import Foundation
import Network
import Security

/// Transfers a single framed snapshot over a mutually authenticated local connection.
@MainActor
final class NearbyWorkoutTransfer {
    nonisolated static let preferenceKey = "nearbyWorkoutTransferEnabled"
    private static let serviceType = "_dune-workouts._tcp"
    private static let maximumBytes = 16 * 1024 * 1024
    private static let pskCipher = UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256)
    private static let queue = DispatchQueue(label: "com.raftel.dailve.nearby-workouts")

    private enum TransferError: Error {
        case unavailable, malformedFrame, unauthenticated
    }

    private enum Role {
        case publish(@MainActor (NearbyWorkoutPageRequest) async throws -> Data)
        case receive(@MainActor (UUID, String) async throws -> NearbyWorkoutPageRequest, @MainActor (Data, String) async throws -> Void)
    }

    private struct Identity: Equatable {
        let scope: String
        let localAccount: String?
        let key: Data
    }

    private var waitingForIdentity = false
    private var role: Role?
    private var generation = UUID()
    private var identity: Identity?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var recentlyReceived: [NWEndpoint: ContinuousClock.Instant] = [:]
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var watchdogs: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var refresh: Task<Void, Never>?

    func startPublishing(snapshot: @escaping @MainActor (NearbyWorkoutPageRequest) async throws -> Data) {
        start(.publish(snapshot))
    }

    func startReceiving(
        request: @escaping @MainActor (UUID, String) async throws -> NearbyWorkoutPageRequest,
        consume: @escaping @MainActor (Data, String) async throws -> Void
    ) {
        start(.receive(request, consume))
    }

    func stop() {
        generation = UUID()
        waitingForIdentity = false
        role = nil
        refresh?.cancel()
        refresh = nil
        resetNetwork()
        identity = nil
    }

    private func start(_ mode: Role) {
        stop()
        role = mode
        let run = generation
        refresh = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshNetwork(run: run)
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    /// A device-local invalidation token; never use this as a cross-device identifier.
    nonisolated static func currentAccountScope() -> String? {
        guard let token = FileManager.default.ubiquityIdentityToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false)
        else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// CloudKit is used only for the signed-in account identity. No workout payload is sent to CloudKit.
    nonisolated static func accountScope() async throws -> String {
        let localToken = currentAccountScope()
        let defaults = UserDefaults.standard
        let cacheKey = "nearbyWorkoutVerifiedAccount"
        do {
            let scope = try await verifiedAccountScope()
            guard currentAccountScope() == localToken else { throw TransferError.unavailable }
            if let localToken {
                defaults.set(["token": localToken, "scope": scope], forKey: cacheKey)
            }
            return scope
        } catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
            guard let localToken, currentAccountScope() == localToken,
                  let cached = defaults.dictionary(forKey: cacheKey) as? [String: String],
                  cached["token"] == localToken, let scope = cached["scope"]
            else { throw error }
            return scope
        }
    }

    private nonisolated static func verifiedAccountScope() async throws -> String {
        let record = try await CKContainer(identifier: "iCloud.com.raftel.dailve").userRecordID()
        return SHA256.hash(data: Data(record.recordName.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func refreshNetwork(run: UUID) async {
        guard generation == run, let role else { return }
        do {
            let localAccount = Self.currentAccountScope()
            let scope = try await Self.verifiedAccountScope()
            guard generation == run else { return }
            let publisher = if case .publish = role { true } else { false }
            let key = try Self.key(for: scope, create: publisher)
            let current = Identity(scope: scope, localAccount: localAccount, key: key)
            waitingForIdentity = false
            if current != identity {
                resetNetwork()
                identity = current
            }
            switch role {
            case .publish:
                if listener == nil { try advertise(current) }
            case .receive:
                if browser == nil { browse(current) }
                else if let browser { connect(to: browser.browseResults, identity: current) }
            }
        } catch {
            guard generation == run else { return }
            if !waitingForIdentity {
                AppLogger.data.info("Nearby workout sync is waiting for its account or keychain credential")
                waitingForIdentity = true
            }
            resetNetwork()
            identity = nil
        }
    }

    private static func key(for scope: String, create: Bool) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.raftel.dailve.nearby-workouts.v1",
            kSecAttrAccount: scope,
            kSecAttrSynchronizable: true,
            kSecUseDataProtectionKeychain: true
        ]
        var lookup = query
        lookup[kSecReturnData] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return data }
        guard status == errSecItemNotFound, create else { throw TransferError.unavailable }
        let data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        var attributes = query
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        attributes[kSecValueData] = data
        switch SecItemAdd(attributes as CFDictionary, nil) {
        case errSecSuccess: return data
        case errSecDuplicateItem: return try key(for: scope, create: false)
        default: throw TransferError.unavailable
        }
    }

    private func parameters(_ identity: Identity) throws -> NWParameters {
        guard let cipher = tls_ciphersuite_t(rawValue: Self.pskCipher) else { throw TransferError.unavailable }
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_append_tls_ciphersuite(options, cipher)
        let secret = identity.key.withUnsafeBytes { DispatchData(bytes: $0) }
        let label = Data("DUNE workouts v2".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(options, secret as __DispatchData, label as __DispatchData)
        let params = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        params.prohibitedInterfaceTypes = [.cellular]
        params.includePeerToPeer = true
        return params
    }

    private func advertise(_ current: Identity) throws {
        let service = try NWListener(using: parameters(current))
        service.service = NWListener.Service(name: UUID().uuidString, type: Self.serviceType)
        service.newConnectionHandler = { [weak self, weak service] connection in
            Task { @MainActor in
                guard let self, self.listener === service, self.identity == current else {
                    connection.cancel()
                    return
                }
                self.start(connection, as: current)
            }
        }
        service.stateUpdateHandler = { [weak self, weak service] state in
            if case .failed = state {
                Task { @MainActor in
                    guard let self, self.listener === service else { return }
                    self.listener?.cancel()
                    self.listener = nil
                }
            }
        }
        listener = service
        service.start(queue: Self.queue)
    }

    private func browse(_ current: Identity) {
        let params = NWParameters.tcp
        params.prohibitedInterfaceTypes = [.cellular]
        params.includePeerToPeer = true
        let discovery = NWBrowser(for: .bonjour(type: Self.serviceType, domain: "local."), using: params)
        discovery.browseResultsChangedHandler = { [weak self, weak discovery] results, _ in
            Task { @MainActor in
                guard let self, self.browser === discovery else { return }
                self.connect(to: results, identity: current)
            }
        }
        discovery.stateUpdateHandler = { [weak self, weak discovery] state in
            if case .failed = state {
                Task { @MainActor in
                    guard let self, self.browser === discovery else { return }
                    self.browser?.cancel()
                    self.browser = nil
                }
            }
        }
        browser = discovery
        discovery.start(queue: Self.queue)
    }

    private func connect(to results: Set<NWBrowser.Result>, identity current: Identity) {
        guard identity == current else { return }
        let now = ContinuousClock.now
        recentlyReceived = recentlyReceived.filter { now - $0.value < .seconds(300) }
        for result in results.shuffled() where connections.count < 4 {
            guard recentlyReceived[result.endpoint] == nil,
                  !connections.values.contains(where: { $0.endpoint == result.endpoint }) else { continue }
            guard let params = try? parameters(current) else { return }
            start(NWConnection(to: result.endpoint, using: params), as: current)
        }
    }

    private func start(_ connection: NWConnection, as current: Identity) {
        guard connections.count < 4 else { connection.cancel(); return }
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        renewDeadline(id)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, let active = self.connections[id] else { return }
                switch state {
                case .ready:
                    await self.exchange(active, identity: current)
                    self.finish(id)
                case .failed, .cancelled: self.finish(id)
                default: break
                }
            }
        }
        connection.start(queue: Self.queue)
    }

    private func renewDeadline(_ id: ObjectIdentifier) {
        watchdogs[id]?.cancel()
        watchdogs[id] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(90)) } catch { return }
            self?.finish(id)
        }
    }

    private func active(_ connection: NWConnection, _ current: Identity) -> Bool {
        connections[ObjectIdentifier(connection)] != nil && identity == current &&
            Self.currentAccountScope() == current.localAccount
    }

    private func exchange(_ connection: NWConnection, identity current: Identity) async {
        guard active(connection, current), let role,
              let tls = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata,
              sec_protocol_metadata_get_negotiated_tls_ciphersuite(tls.securityProtocolMetadata).rawValue == Self.pskCipher
        else { return }
        do {
            guard try await Self.verifiedAccountScope() == current.scope, active(connection, current) else { return }
            switch role {
            case .publish(let snapshot):
                let source = try NearbyWorkoutHistory.installationID()
                try await send(Data(source.uuidString.utf8), on: connection)
                // Each committed page has its own cursor and timeout; reconnects resume at that cursor.
                while active(connection, current) {
                    renewDeadline(ObjectIdentifier(connection))
                    let requestData = try await readFrame(limit: 16_384, from: connection)
                    let request = try JSONDecoder().decode(NearbyWorkoutPageRequest.self, from: requestData)
                    guard request.sourceID == source, request.kind != .idle else { return }
                    let data = try await snapshot(request)
                    guard try await Self.verifiedAccountScope() == current.scope, active(connection, current) else { return }
                    try await sendFrame(data, limit: Self.maximumBytes, on: connection)
                    guard try await read(1, from: connection) == Data([1]) else { throw TransferError.malformedFrame }
                    AppLogger.data.debug("Nearby workout page acknowledged")
                }
            case .receive(let makeRequest, let consume):
                let name = try await read(36, from: connection)
                guard let text = String(data: name, encoding: .utf8), let source = UUID(uuidString: text) else { return }
                var previousRequest: NearbyWorkoutPageRequest?
                while active(connection, current) {
                    renewDeadline(ObjectIdentifier(connection))
                    let request = try await makeRequest(source, current.scope)
                    // An unchanged request means no checkpoint advanced. Retry on discovery, not in a tight loop.
                    guard request != previousRequest else { return }
                    previousRequest = request
                    try await sendFrame(JSONEncoder().encode(request), limit: 16_384, on: connection)
                    if request.kind == .idle {
                        recentlyReceived[connection.endpoint] = .now
                        AppLogger.data.info("Nearby workout history is up to date")
                        return
                    }
                    let data = try await readFrame(limit: Self.maximumBytes, from: connection)
                    struct ResponseHeader: Decodable { let request: NearbyWorkoutPageRequest }
                    guard try JSONDecoder().decode(ResponseHeader.self, from: data).request == request,
                          try await Self.verifiedAccountScope() == current.scope, active(connection, current) else { return }
                    try await consume(data, current.scope)
                    try await send(Data([1]), on: connection)
                }
            }
        } catch {
            AppLogger.data.debug("Nearby workout exchange interrupted; will retry while enabled")
        }
    }

    private func sendFrame(_ data: Data, limit: Int, on connection: NWConnection) async throws {
        guard !data.isEmpty, data.count <= limit else { throw TransferError.malformedFrame }
        var size = UInt32(data.count).bigEndian
        try await send(withUnsafeBytes(of: &size) { Data($0) }, on: connection)
        try await send(data, on: connection)
    }

    private func readFrame(limit: Int, from connection: NWConnection) async throws -> Data {
        let header = try await read(4, from: connection)
        let size = Int(header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian })
        guard size > 0, size <= limit else { throw TransferError.malformedFrame }
        return try await read(size, from: connection)
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    private func read(_ size: Int, from connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, error in
                if let data, data.count == size { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error.map { $0 as Error } ?? TransferError.malformedFrame) }
            }
        }
    }

    private func finish(_ id: ObjectIdentifier) {
        watchdogs.removeValue(forKey: id)?.cancel()
        connections.removeValue(forKey: id)?.cancel()
    }

    private func resetNetwork() {
        recentlyReceived.removeAll()
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        for id in Array(connections.keys) { finish(id) }
    }
}
