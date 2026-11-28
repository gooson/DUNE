import Foundation
import CryptoKit
import Testing
@testable import DUNE

@Suite("Encrypted recovery archive")
struct EncryptedRecoveryArchiveTests {
    typealias Archive = EncryptedRecoveryArchive

    @Test func portableKeyAndLegacyArchive() throws {
        let recoveryKey = Archive.makeRecoveryKey()
        let keyBytes = try #require(Data(base64Encoded: recoveryKey))
        #expect(keyBytes.count == 32)
        let original = Data([0, 255, 1])
        let header = Data("DUNERECV".utf8) + Data([1])
        let box = try AES.GCM.seal(original, using: SymmetricKey(data: keyBytes), authenticating: header)
        let archive = try header + #require(box.combined)
        try Archive.validateEnvelope(archive)
        #expect(try Archive.open(archive, recoveryKey: recoveryKey) == original)
    }

    @Test func opensCompleteFileAbovePreviousLimit() throws {
        let key = Archive.makeRecoveryKey()
        var original = Data(repeating: 0xAC, count: (32 * 1024 * 1024) + 1)
        original[original.count - 1] = 0x53
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Archive.seal(original, recoveryKey: key).write(to: url, options: .atomic)
        let saved = try Data(contentsOf: url, options: .mappedIfSafe)
        try Archive.validateEnvelope(saved)
        #expect(try Archive.open(saved, recoveryKey: key) == original)
    }

    @Test func freshCiphertextAndPortableSmallFile() throws {
        let key = Archive.makeRecoveryKey()
        let bytes = Data([0, 1, 2, 255])
        let archive = try Archive.seal(bytes, recoveryKey: key)
        let second = try Archive.seal(bytes, recoveryKey: key)
        #expect(archive != second)
        let sliced = (Data([9]) + archive).dropFirst()
        #expect(try Archive.open(sliced, recoveryKey: key) == bytes)
        #expect(throws: Archive.ArchiveError.invalidArchive) { try Archive.seal(Data(), recoveryKey: key) }
    }

    @Test func rejectsWrongKeysAndMalformedKeyText() throws {
        let key = Archive.makeRecoveryKey()
        let archive = try Archive.seal(Data([1]), recoveryKey: key)
        let otherKey = Archive.makeRecoveryKey()
        #expect(throws: Archive.ArchiveError.authenticationFailed) { try Archive.open(archive, recoveryKey: otherKey) }
        for invalidKey in ["", "passphrase", String(repeating: "A", count: 44), key + " "] {
            #expect(throws: Archive.ArchiveError.invalidRecoveryKey) { try Archive.open(archive, recoveryKey: invalidKey) }
            #expect(throws: Archive.ArchiveError.invalidRecoveryKey) { try Archive.seal(Data([0]), recoveryKey: invalidKey) }
        }
    }

    @Test func rejectsTruncationTamperingAndOversizedDeclarations() throws {
        let key = Archive.makeRecoveryKey()
        let archive = try Archive.seal(Data([1]), recoveryKey: key)
        for (offset, expected) in [(0, Archive.ArchiveError.invalidArchive), (8, .unsupportedVersion),
                                   (9, .sizeLimitExceeded), (17, .authenticationFailed),
                                   (33, .authenticationFailed), (archive.count - 1, .authenticationFailed)] {
            var changed = archive
            changed[offset] ^= 0x80
            #expect(throws: expected) { try Archive.open(changed, recoveryKey: key) }
        }
        #expect(throws: Archive.ArchiveError.invalidArchive) { try Archive.validateEnvelope(Data()) }
        #expect(throws: Archive.ArchiveError.invalidArchive) { try Archive.open(archive.dropLast(), recoveryKey: key) }
        #expect(throws: Archive.ArchiveError.invalidArchive) { try Archive.open(archive + Data([0]), recoveryKey: key) }
    }

    @Test func rejectsReorderedAndForeignChunks() throws {
        let key = Archive.makeRecoveryKey()
        let size = 1024 * 1024
        let bytes = Data(repeating: 0x4C, count: size * 2)
        let first = try Archive.seal(bytes, recoveryKey: key)
        let second = try Archive.seal(bytes, recoveryKey: key)
        let header = first.prefix(33)
        let partSize = size + 28
        let reordered = header + first.suffix(partSize) + first.dropFirst(33).prefix(partSize)
        let spliced = header + second.dropFirst(33).prefix(partSize) + first.suffix(partSize)
        for invalid in [reordered, spliced] {
            #expect(throws: Archive.ArchiveError.authenticationFailed) { try Archive.open(invalid, recoveryKey: key) }
        }
    }
}

@Suite("Local recovery file destinations")
struct LocalRecoveryFileTests {
    @Test func completeBytesAndBackupExclusion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try EncryptedRecoveryArchive.seal(Data([1, 2, 3]), recoveryKey: EncryptedRecoveryArchive.makeRecoveryKey())
        let result = try LocalRecoveryFiles.writeLocal(archive, in: root, filename: "archive.dunebackup")
        let folder = result.deletingLastPathComponent()
        #expect(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(try Data(contentsOf: result) == archive)
        #expect(throws: (any Error).self) { try LocalRecoveryFiles.writeLocal(Data([4]), in: root, filename: "../escape") }
        #expect(throws: (any Error).self) { try LocalRecoveryFiles.writeLocal(Data(), in: root, filename: "empty") }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["archive.dunebackup"])
    }

    @Test func concurrentCollisionPreservesOneCompleteFileAndNoPartialFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let winners = await withTaskGroup(of: UInt8?.self) { group in
            for tag: UInt8 in 1...4 {
                group.addTask {
                    do {
                        _ = try LocalRecoveryFiles.writeLocal(Data(repeating: tag, count: 4096), in: root, filename: "collision")
                        return tag
                    } catch { return nil }
                }
            }
            var winners: [UInt8] = []
            for await winner in group { if let winner { winners.append(winner) } }
            return winners
        }
        #expect(winners.count == 1)
        let tag = try #require(winners.first)
        let folder = root.appendingPathComponent("DUNE Exports")
        #expect(try Data(contentsOf: folder.appendingPathComponent("collision")) == Data(repeating: tag, count: 4096))
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["collision"])
    }

    @Test func unverifiedDestinationsCannotReceivePhotosOrArchives() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try EncryptedRecoveryArchive.seal(Data([7]), recoveryKey: EncryptedRecoveryArchive.makeRecoveryKey())
        #expect(throws: LocalRecoveryFiles.Failure.unsupportedDestination) {
            try LocalRecoveryFiles.saveArchive(archive, toRemovableFolder: root)
        }
        #expect(throws: LocalRecoveryFiles.Failure.unsupportedDestination) {
            try LocalRecoveryFiles.savePosturePhoto(Data([7]), fileExtension: "jpg", toRemovableFolder: root)
        }
        #expect(throws: LocalRecoveryFiles.Failure.invalidPhoto) {
            try LocalRecoveryFiles.savePosturePhoto(Data(), fileExtension: "jpg", toRemovableFolder: root)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}
