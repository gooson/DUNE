import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension UTType {
    static let duneEncryptedBackup = UTType(exportedAs: "com.raftel.dailve.encrypted-backup", conformingTo: .data)
}

struct EncryptedBackupDocument: FileDocument {
    static let readableContentTypes = [UTType.duneEncryptedBackup]
    let ciphertext: Data

    init(ciphertext: Data) {
        self.ciphertext = ciphertext
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= EncryptedRecoveryArchive.maximumArchiveBytes else { throw CocoaError(.fileReadCorruptFile) }
        ciphertext = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: ciphertext)
    }

    /// Coordinates with Files providers and bounds memory even if the file grows during the read.
    static func read(from url: URL) throws -> Data {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { available in
            result = Result {
                let handle = try FileHandle(forReadingFrom: available)
                defer { try? handle.close() }
                let limit = EncryptedRecoveryArchive.maximumArchiveBytes
                let size = try handle.seekToEnd()
                guard size <= UInt64(limit) else { throw EncryptedRecoveryArchive.ArchiveError.sizeLimitExceeded }
                try handle.seek(toOffset: 0)
                var bytes = Data()
                while let part = try handle.read(upToCount: min(65_536, limit + 1 - bytes.count)), !part.isEmpty {
                    bytes.append(part)
                    guard bytes.count <= limit else { throw EncryptedRecoveryArchive.ArchiveError.sizeLimitExceeded }
                }
                return bytes
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
}

@MainActor
@Observable
final class BackupFileWorkflow {
    static let didRestoreRecords = Notification.Name("DUNEBackupFileDidRestoreRecords")

    enum Step { case home, exportKey, restoreKey }
    enum Scope { case records, settings }
    private(set) var scope: Scope = .records
    private(set) var savedFilename: String?
    private(set) var restoredRecords: AppOwnedBackup.RestoreResult?
    private(set) var step: Step = .home
    private(set) var exportKey = ""
    var savedKey = false
    var inputKey = ""
    private(set) var canCombine = false
    var confirmedOwnership = false
    private(set) var document: EncryptedBackupDocument?
    private var selectedCiphertext: Data?
    private(set) var busy = false
    private(set) var message: LocalizedStringResource?

    func startExport(_ scope: Scope) {
        reset()
        self.scope = scope
        exportKey = EncryptedRecoveryArchive.makeRecoveryKey()
        step = .exportKey
    }

    /// The generic Files exporter only accepts the closed list of appearance and unit preferences.
    func prepareSettingsExport(defaults: UserDefaults = .standard) async -> Bool {
        guard scope == .settings, step == .exportKey, savedKey, !exportKey.isEmpty, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let bytes = try AppOwnedBackup.encodeDriveSettings(defaults: defaults)
            let key = exportKey
            let encrypted = try await Task.detached(priority: .userInitiated) {
                try EncryptedRecoveryArchive.seal(bytes, recoveryKey: key)
            }.value
            document = EncryptedBackupDocument(ciphertext: encrypted)
            message = nil
            return true
        } catch {
            message = "Couldn’t create the backup file. Finish any edits and try again."
            return false
        }
    }

    func saveRecords(context: ModelContext, removableFolder: URL? = nil, defaults: UserDefaults = .standard) async {
        guard scope == .records, step == .exportKey, savedKey, !exportKey.isEmpty, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let bytes = try AppOwnedBackup.encode(from: context, defaults: defaults)
            let key = exportKey
            let url = try await Task.detached(priority: .userInitiated) {
                let encrypted = try EncryptedRecoveryArchive.seal(bytes, recoveryKey: key)
                return try LocalRecoveryFiles.saveArchive(encrypted, toRemovableFolder: removableFolder)
            }.value
            reset()
            savedFilename = url.lastPathComponent
            message = removableFolder == nil ? "Backup saved on this device." : "Backup saved to the external drive."
        } catch {
            message = removableFolder == nil
                ? "Couldn’t create the backup file. Finish any edits and try again."
                : "Couldn’t save the backup. Check that the external drive is connected and has enough space."
        }
    }

    func copyLocalArchive(_ source: URL, to folder: URL) async {
        guard !busy else { return }
        reset()
        busy = true
        defer { busy = false }
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                guard try LocalRecoveryFiles.archives().contains(source) else { throw CocoaError(.fileReadNoSuchFile) }
                let bytes = try EncryptedBackupDocument.read(from: source)
                return try LocalRecoveryFiles.saveArchive(bytes, toRemovableFolder: folder)
            }.value
            savedFilename = url.lastPathComponent
            message = "Backup saved to the external drive."
        } catch {
            savedFilename = nil
            message = "Couldn’t save the backup. Check that the external drive is connected and has enough space."
        }
    }

    func removableSelectionFailed(_ error: Error) {
        guard !Self.isCancellation(error) else { return }
        restoredRecords = nil
        savedFilename = nil
        message = "Choose a folder on a connected external drive."
    }

    func finishedExport(_ result: Result<URL, Error>) {
        guard scope == .settings, document != nil else { return }
        document = nil
        switch result {
        case .success:
            reset()
            message = "Encrypted backup file saved."
        case .failure(let error):
            if !Self.isCancellation(error) { message = "Couldn’t save the backup file. Choose another location and try again." }
        }
    }

    func selectFile(_ result: Result<URL, Error>) async {
        guard !busy else { return }
        reset()
        busy = true
        defer { busy = false }
        do {
            let url = try result.get()
            selectedCiphertext = try await Task.detached(priority: .userInitiated) {
                try EncryptedBackupDocument.read(from: url)
            }.value
            step = .restoreKey
        } catch {
            if !Self.isCancellation(error) { message = "Couldn’t read the backup file. Choose a DUNE backup file and try again." }
        }
    }

    func restore(context: ModelContext, defaults: UserDefaults = .standard) async {
        guard step == .restoreKey, let selectedCiphertext, !inputKey.isEmpty, !busy else { return }
        busy = true
        defer { busy = false }
        let key = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        inputKey = ""
        do {
            let bytes = try await Task.detached(priority: .userInitiated) {
                try EncryptedRecoveryArchive.open(selectedCiphertext, recoveryKey: key)
            }.value
            do {
                if try AppOwnedBackup.restoreDriveSettingsIfPresent(bytes, defaults: defaults) {
                    reset()
                    message = "Appearance and unit settings restored."
                    return
                }
            } catch AppOwnedBackup.Failure.destinationConflict {
                message = "These settings conflict with preferences on this device. Your preferences are unchanged."
                return
            }
            let mode: AppOwnedBackup.RestoreMode = canCombine && confirmedOwnership ? .mergeAfterOwnershipVerification : .emptyOrMatching
            let result = try AppOwnedBackup.restore(bytes, into: context, defaults: defaults, mode: mode)
            reset()
            restoredRecords = result
            NotificationCenter.default.post(name: Self.didRestoreRecords, object: context.container)
            message = result.archiveRowCount == 0 ? "No DUNE records in this backup." : "Backup file restored to this device."
        } catch AppOwnedBackup.Failure.destinationConflict {
            canCombine = true
            message = confirmedOwnership
                ? "The backup conflicts with records on this device. Your records are unchanged."
                : "This device already has records. To combine them, confirm ownership and enter the key again."
        } catch {
            message = "Couldn’t restore this file. Check the recovery key and backup file."
        }
    }

    func reset() {
        step = .home
        canCombine = false
        confirmedOwnership = false
        savedKey = false
        inputKey = ""
        exportKey = ""
        document = nil
        selectedCiphertext = nil
        savedFilename = nil
        restoredRecords = nil
        message = nil
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let failure = error as NSError
        return failure.domain == NSCocoaErrorDomain && failure.code == NSUserCancelledError
    }
}

struct CloudRecoverySettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Environment(\.isSceneCaptured) private var isCaptured
    @State private var workflow = BackupFileWorkflow()
    @State private var showingKey = false
    @State private var accessedKey = false
    @State private var exporting = false
    @State private var selecting = false
    @State private var selectingDrive = false
    @State private var localArchives: [URL] = []
    @State private var listUnavailable = false
    @State private var archiveToCopy: URL?

    var body: some View {
        Form {
            switch workflow.step {
            case .home:
                Section {
                    Button("Back Up DUNE Records") { startExport(.records) }
                        .accessibilityIdentifier("backup-file-create")
                } footer: {
                    Text("The full backup includes 13 types of DUNE records, including workouts, sets, notes and posture photos, plus rewards. Save it on this device or a connected external drive. Keep a copy off this device to recover after loss.")
                }
                Section {
                    Button("Export Appearance and Units") { startExport(.settings) }
                        .accessibilityIdentifier("backup-file-create-settings")
                } footer: {
                    Text("Save your theme, app icon and weight unit to iCloud Drive or another location in Files. Create a new file when these settings change.")
                }
                Section {
                    Button("Restore from Backup File") {
                        selectingDrive = false
                        selecting = true
                    }
                    .accessibilityIdentifier("backup-file-choose")
                }
                localArchiveSection
            case .exportKey:
                exportControls
            case .restoreKey:
                restoreControls
            }
            if workflow.busy {
                ProgressView()
            }
            if let message = workflow.message {
                Text(message)
                    .accessibilityIdentifier("backup-file-status")
                if let restored = workflow.restoredRecords {
                    LabeledContent("Workouts in File", value: restored.workoutCount.formatted())
                    LabeledContent("Sets in File", value: restored.setCount.formatted())
                    LabeledContent("New or Updated Records", value: (restored.insertedRowCount + restored.enrichedRowCount).formatted())
                }
                if let filename = workflow.savedFilename {
                    Text(verbatim: filename).font(.footnote)
                }
            }
        }
        .disabled(workflow.busy)
        .navigationTitle("Encrypted Backup File")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: workflow.document, contentType: .duneEncryptedBackup,
                      defaultFilename: "DUNE-Settings-\(Date.now.ISO8601Format(.iso8601.year().month().day()))") { result in
            workflow.finishedExport(result)
        }
        .fileImporter(isPresented: $selecting, allowedContentTypes: selectingDrive ? [.folder] : [.duneEncryptedBackup]) { result in
            if selectingDrive {
                switch result {
                case let .success(folder):
                    if let source = archiveToCopy {
                        archiveToCopy = nil
                        Task { await workflow.copyLocalArchive(source, to: folder) }
                    } else {
                        Task { await workflow.saveRecords(context: context, removableFolder: folder) }
                    }
                case let .failure(error): workflow.removableSelectionFailed(error)
                }
            } else {
                Task { await workflow.selectFile(result) }
            }
        }
        .task(id: workflow.step) {
            guard workflow.step == .home else { return }
            do {
                localArchives = try await Task.detached { try LocalRecoveryFiles.archives() }.value
                listUnavailable = false
            } catch {
                localArchives = []
                listUnavailable = true
            }
        }
        .onChange(of: phase) { _, next in
            if next != .active {
                showingKey = false
                workflow.inputKey = ""
            }
        }
        .onChange(of: isCaptured) { _, captured in if captured { showingKey = false } }
    }

    @ViewBuilder
    private var localArchiveSection: some View {
        if listUnavailable {
            Text("Couldn’t list backups on this device.")
        } else if !localArchives.isEmpty {
            Section("Backups on This Device") {
                ForEach(localArchives, id: \.self) { url in
                    Menu {
                        Button("Restore from Backup File") { Task { await workflow.selectFile(.success(url)) } }
                        Button("Save to External Drive") {
                            archiveToCopy = url
                            selectingDrive = true
                            selecting = true
                        }
                    } label: {
                        Label {
                            Text(verbatim: url.lastPathComponent)
                        } icon: {
                            Image(systemName: "lock.document")
                        }
                    }
                }
            }
        }
    }

    private func startExport(_ scope: BackupFileWorkflow.Scope) {
        archiveToCopy = nil
        accessedKey = false
        showingKey = false
        workflow.startExport(scope)
    }

    private var exportControls: some View {
        Section {
            if showingKey && phase == .active && !isCaptured {
                Text(verbatim: workflow.exportKey)
                    .font(.body.monospaced())
                    .privacySensitive()
            }
            Button {
                showingKey.toggle()
                if showingKey { accessedKey = true }
            } label: {
                if showingKey { Text("Hide Recovery Key") } else { Text("Show Recovery Key") }
            }
            .disabled(isCaptured)
            .accessibilityIdentifier("backup-file-show-key")
            Button("Copy Recovery Key on This Device") {
                UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: workflow.exportKey]],
                                              options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                accessedKey = true
            }
            .accessibilityIdentifier("backup-file-copy-key")
            Toggle("I saved the recovery key separately", isOn: $workflow.savedKey)
                .disabled(!accessedKey)
                .accessibilityIdentifier("backup-file-saved-key")
            if workflow.scope == .records {
                Button("Save to This Device") {
                    showingKey = false
                    Task { await workflow.saveRecords(context: context) }
                }
                .disabled(!workflow.savedKey)
                .accessibilityIdentifier("backup-file-export")
                Button("Save to External Drive") {
                    showingKey = false
                    selectingDrive = true
                    selecting = true
                }
                .disabled(!workflow.savedKey)
                .accessibilityIdentifier("backup-file-external")
            } else {
                Button("Choose Where to Save") {
                    showingKey = false
                    Task { exporting = await workflow.prepareSettingsExport() }
                }
                .disabled(!workflow.savedKey)
                .accessibilityIdentifier("backup-file-export-settings")
            }
            Button("Cancel", role: .cancel) {
                showingKey = false
                workflow.reset()
            }
        } header: {
            Text("Save Your Recovery Key")
        } footer: {
            Text("Keep this key somewhere you can reach if you lose this device. You need both this key and the file to restore this backup.")
        }
    }

    private var restoreControls: some View {
        Section {
            SecureField("Recovery Key", text: $workflow.inputKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .accessibilityIdentifier("backup-file-key")
            if workflow.canCombine {
                Toggle("This backup and the records on this device are mine", isOn: $workflow.confirmedOwnership)
            }
            Button("Restore to This Device") {
                Task { await workflow.restore(context: context) }
            }
            .disabled(workflow.inputKey.isEmpty || (workflow.canCombine && !workflow.confirmedOwnership))
            Button("Cancel", role: .cancel) { workflow.reset() }
        } footer: {
            Text("Enter the recovery key saved with this backup. Restoration stops if the file conflicts with existing records.")
        }
    }
}
