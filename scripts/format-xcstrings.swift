#!/usr/bin/env swift

import Foundation

private enum CatalogError: LocalizedError {
    case duplicateKey(String)
    case malformed

    var errorDescription: String? {
        switch self {
        case .duplicateKey(let key): "Duplicate JSON key: \(key)"
        case .malformed: "Invalid JSON structure"
        }
    }
}

private struct DuplicateKeyValidator {
    private let bytes: [UInt8]
    private var position = 0

    init(_ data: Data) {
        bytes = Array(data)
    }

    mutating func validate() throws {
        try parseValue()
    }

    private mutating func skipWhitespace() {
        while position < bytes.count && [9, 10, 13, 32].contains(bytes[position]) {
            position += 1
        }
    }

    private mutating func parseString() throws -> String {
        guard position < bytes.count, bytes[position] == 34 else { throw CatalogError.malformed }
        let start = position
        position += 1
        while position < bytes.count {
            if bytes[position] == 92 {
                position += 2
            } else if bytes[position] == 34 {
                position += 1
                return try JSONDecoder().decode(String.self, from: Data(bytes[start..<position]))
            } else {
                position += 1
            }
        }
        throw CatalogError.malformed
    }

    private mutating func parseValue() throws {
        skipWhitespace()
        guard position < bytes.count else { throw CatalogError.malformed }
        switch bytes[position] {
        case 123: try parseObject()
        case 91: try parseArray()
        case 34: _ = try parseString()
        default:
            while position < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[position]) {
                position += 1
            }
        }
    }

    private mutating func parseObject() throws {
        position += 1
        var keys = Set<String>()
        skipWhitespace()
        if position < bytes.count, bytes[position] == 125 {
            position += 1
            return
        }
        while position < bytes.count {
            let key = try parseString()
            guard keys.insert(key).inserted else { throw CatalogError.duplicateKey(key) }
            skipWhitespace()
            guard position < bytes.count, bytes[position] == 58 else { throw CatalogError.malformed }
            position += 1
            try parseValue()
            skipWhitespace()
            guard position < bytes.count else { throw CatalogError.malformed }
            if bytes[position] == 125 {
                position += 1
                return
            }
            guard bytes[position] == 44 else { throw CatalogError.malformed }
            position += 1
            skipWhitespace()
        }
        throw CatalogError.malformed
    }

    private mutating func parseArray() throws {
        position += 1
        skipWhitespace()
        if position < bytes.count, bytes[position] == 93 {
            position += 1
            return
        }
        while position < bytes.count {
            try parseValue()
            skipWhitespace()
            guard position < bytes.count else { throw CatalogError.malformed }
            if bytes[position] == 93 {
                position += 1
                return
            }
            guard bytes[position] == 44 else { throw CatalogError.malformed }
            position += 1
        }
        throw CatalogError.malformed
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
let checkOnly = arguments.contains("--check")
let requestedPaths = arguments.filter { $0 != "--check" }
let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let defaultPaths = [
    "Shared/Resources/Localizable.xcstrings",
    "DUNEWatch/Resources/Localizable.xcstrings"
]
let paths = requestedPaths.isEmpty ? defaultPaths.map { repositoryRoot.appendingPathComponent($0).path } : requestedPaths

var hasChanges = false

for path in paths {
    do {
        let url = URL(fileURLWithPath: path)
        let original = try Data(contentsOf: url)
        var validator = DuplicateKeyValidator(original)
        try validator.validate()
        let catalog = try JSONSerialization.jsonObject(with: original)
        guard let root = catalog as? [String: Any],
              root["sourceLanguage"] is String,
              root["strings"] is [String: Any],
              root["version"] is String else {
            throw NSError(domain: "StringCatalogFormat", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid string catalog structure"])
        }

        // Xcode's catalog serializer uses these Foundation options and no trailing newline.
        let formatted = try JSONSerialization.data(
            withJSONObject: catalog,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard original != formatted else { continue }

        hasChanges = true
        if checkOnly {
            fputs("Needs formatting: \(path)\n", stderr)
        } else {
            try formatted.write(to: url, options: .atomic)
            print("Formatted: \(path)")
        }
    } catch {
        fputs("Cannot format \(path): \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

if checkOnly && hasChanges {
    exit(1)
}
