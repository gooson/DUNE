import Foundation
import CryptoKit
import Darwin

enum EncryptedRecoveryArchive {
    enum ArchiveError: Error, Equatable {
        case invalidRecoveryKey
        case sizeLimitExceeded
        case invalidArchive
        case unsupportedVersion
        case authenticationFailed
    }

    // The current app serializes its backup into Data. Bound both the input and output
    // allocations, and keep temporary CryptoKit buffers to one chunk.
    static let maximumPlaintextBytes = 256 * 1024 * 1024
    private static let chunkBytes = 1024 * 1024
    private static let magic = Data("DUNERECV".utf8)
    private static let version: UInt8 = 2
    private static let legacyMaximum = 32 * 1024 * 1024
    // v2: magic (8), version (1), big-endian plaintext length (8), random archive ID (16).
    private static let headerLength = 33
    private static let boxOverhead = 12 + 16  // AES.GCM combined nonce and tag.
    static let maximumArchiveBytes = headerLength + maximumPlaintextBytes + (maximumPlaintextBytes / chunkBytes) * boxOverhead

    static func makeRecoveryKey() -> String {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0).base64EncodedString() }
    }

    static func seal(_ plaintext: Data, recoveryKey: String) throws -> Data {
        guard !plaintext.isEmpty else { throw ArchiveError.invalidArchive }
        guard plaintext.count <= maximumPlaintextBytes else { throw ArchiveError.sizeLimitExceeded }
        let key = try decodeKey(recoveryKey)
        var header = magic
        header.append(version)
        header.append(integerBytes(plaintext.count))
        SymmetricKey(size: .bits128).withUnsafeBytes { header.append(contentsOf: $0) }
        var archive = header
        archive.reserveCapacity(encodedSize(plaintext.count))
        for offset in stride(from: 0, to: plaintext.count, by: chunkBytes) {
            let part = plaintext.dropFirst(offset).prefix(chunkBytes)
            let box = try AES.GCM.seal(part, using: key, authenticating: header + integerBytes(offset))
            guard let combined = box.combined else { throw ArchiveError.invalidArchive }
            archive.append(combined)
        }
        return archive
    }

    /// Checks the public file structure and declared length. Only open verifies every tag.
    static func validateEnvelope(_ archive: Data) throws {
        _ = try inspect(archive)
    }

    static func open(_ archive: Data, recoveryKey: String) throws -> Data {
        let (format, size) = try inspect(archive)
        let key = try decodeKey(recoveryKey)
        if format == 1 {
            return try decrypt(archive.dropFirst(9), using: key, authenticating: archive.prefix(9))
        }
        let header = archive.prefix(headerLength)
        var cursor = archive.startIndex + headerLength
        var plaintext = Data()
        plaintext.reserveCapacity(size)
        for offset in stride(from: 0, to: size, by: chunkBytes) {
            let end = cursor + min(chunkBytes, size - offset) + boxOverhead
            let chunk = try decrypt(archive[cursor..<end], using: key, authenticating: header + integerBytes(offset))
            plaintext.append(chunk)
            cursor = end
        }
        return plaintext
    }

    private static func inspect(_ archive: Data) throws -> (format: UInt8, size: Int) {
        guard archive.count <= maximumArchiveBytes else { throw ArchiveError.sizeLimitExceeded }
        guard archive.count >= 9, archive.starts(with: magic) else { throw ArchiveError.invalidArchive }
        let format = archive[archive.startIndex + 8]
        if format == 1 {
            let size = archive.count - 9 - boxOverhead
            guard size > 0 else { throw ArchiveError.invalidArchive }
            guard size <= legacyMaximum else { throw ArchiveError.sizeLimitExceeded }
            return (format, size)
        }
        guard format == version else { throw ArchiveError.unsupportedVersion }
        guard archive.count >= headerLength else { throw ArchiveError.invalidArchive }
        let length = archive.dropFirst(9).prefix(8).reduce(UInt64.zero) { ($0 << 8) | UInt64($1) }
        guard length <= UInt64(maximumPlaintextBytes) else { throw ArchiveError.sizeLimitExceeded }
        guard length > 0, archive.count == encodedSize(Int(length)) else { throw ArchiveError.invalidArchive }
        return (format, Int(length))
    }

    private static func integerBytes(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt64(value).bigEndian) { Data($0) }
    }

    private static func encodedSize(_ size: Int) -> Int {
        headerLength + size + ((size + chunkBytes - 1) / chunkBytes) * boxOverhead
    }

    private static func decrypt(_ data: Data, using key: SymmetricKey, authenticating aad: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key, authenticating: aad)
        } catch {
            throw ArchiveError.authenticationFailed
        }
    }

    private static func decodeKey(_ encoded: String) throws -> SymmetricKey {
        guard encoded.utf8.prefix(45).count == 44,
              let data = Data(base64Encoded: encoded), data.count == 32,
              data.base64EncodedString() == encoded else { throw ArchiveError.invalidRecoveryKey }
        return SymmetricKey(data: data)
    }
}

enum LocalRecoveryFiles {
    enum Failure: Error, Equatable {
        case unsupportedDestination
        case invalidPhoto
    }

    private static let folderName = "DUNE Exports"
    private static let archiveExtension = "dunebackup"

    static func saveArchive(_ bytes: Data, toRemovableFolder folder: URL? = nil) throws -> URL {
        try EncryptedRecoveryArchive.validateEnvelope(bytes)
        return try save(bytes, prefix: "DUNE-Backup", suffix: archiveExtension, removable: folder)
    }

    static func savePosturePhoto(_ bytes: Data, fileExtension: String, toRemovableFolder folder: URL? = nil) throws -> URL {
        let suffix = fileExtension.lowercased()
        guard !bytes.isEmpty, (1...12).contains(suffix.utf8.count),
              suffix.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) }) else {
            throw Failure.invalidPhoto
        }
        return try save(bytes, prefix: "DUNE-Photo", suffix: suffix, removable: folder)
    }

    static func archives() throws -> [URL] {
        let folder = try documents().appendingPathComponent(folderName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        try verifyDirectory(folder)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys),
                                                               options: .skipsHiddenFiles)
        let entries: [(url: URL, date: Date)] = try files.compactMap { url in
            guard url.pathExtension == archiveExtension else { return nil }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink == false, values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast)
        }
        return entries.sorted { $0.date > $1.date }.map(\.url)
    }

    private static func documents() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    private static func save(_ bytes: Data, prefix: String, suffix: String, removable: URL?) throws -> URL {
        let filename = "\(prefix)-\(UUID().uuidString).\(suffix)"
        guard let removable else {
            return try writeLocal(bytes, in: documents(), filename: filename)
        }
        let scoped = removable.startAccessingSecurityScopedResource()
        defer { if scoped { removable.stopAccessingSecurityScopedResource() } }
        try verifyDirectory(removable)
        let values = try removable.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsLocalKey])
        guard values.volumeIsRemovable == true, values.volumeIsLocal == true else { throw Failure.unsupportedDestination }
        return try publish(bytes, in: removable, filename: filename, removable: true)
    }

    // The production caller supplies only the app's own Documents directory.
    static func writeLocal(_ bytes: Data, in documents: URL, filename: String) throws -> URL {
        guard !bytes.isEmpty, !filename.isEmpty, !filename.contains("/"), !filename.contains("\0"),
              !filename.hasPrefix(".") else { throw Failure.unsupportedDestination }
        var folder = documents.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try verifyDirectory(folder)
        var exclusion = URLResourceValues()
        exclusion.isExcludedFromBackup = true
        try folder.setResourceValues(exclusion)
        folder.removeAllCachedResourceValues()
        guard try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
            throw Failure.unsupportedDestination
        }
        return try publish(bytes, in: folder, filename: filename, removable: false)
    }

    private static func verifyDirectory(_ folder: URL) throws {
        guard folder.isFileURL, !FileManager.default.isUbiquitousItem(at: folder) else {
            throw Failure.unsupportedDestination
        }
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink == false else { throw Failure.unsupportedDestination }
    }

    private static func publish(_ bytes: Data, in directory: URL, filename: String, removable: Bool) throws -> URL {
        let directoryFD = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else { throw posixError() }
        defer { Darwin.close(directoryFD) }
        if removable {
            // Reject network and virtual File Provider mounts, even if a provider claims removability.
            var info = statfs()
            guard fstatfs(directoryFD, &info) == 0 else { throw posixError() }
            let filesystem = withUnsafeBytes(of: &info.f_fstypename) { raw in
                String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            guard ["apfs", "hfs", "msdos", "exfat"].contains(filesystem),
                  (info.f_flags & UInt32(MNT_LOCAL | MNT_REMOVABLE)) == UInt32(MNT_LOCAL | MNT_REMOVABLE) else { throw Failure.unsupportedDestination }
        }
        let stage = ".dune-\(UUID().uuidString).partial"
        let fd = openat(directoryFD, stage, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw posixError() }
        defer { unlinkat(directoryFD, stage, 0) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        try handle.write(contentsOf: bytes)
        try handle.synchronize()
        try handle.close()
        guard renameatx_np(directoryFD, stage, directoryFD, filename, UInt32(RENAME_EXCL)) == 0 else {
            throw posixError()
        }
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}
