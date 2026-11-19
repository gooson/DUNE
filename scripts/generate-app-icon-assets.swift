#!/usr/bin/env swift

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Reproduces the four-anchor sRGB feColorMatrix in color-lab/lab.js.
private struct PaletteData: Decodable {
    let palettes: [Palette]
    let sourceAnchors: Anchors
}

private struct Palette: Decodable {
    let id: String
    let a: String
    let b: String
    let background: String
}

private struct Anchors: Decodable {
    let background: String
    let a: String
    let b: String
    let highlight: String
}

private struct IconStyle {
    let name: String
    let source: String
}

private struct ThemePalette {
    let theme: String
    let palette: String
}

private let styles = [
    IconStyle(name: "interleave", source: "108-duo-82.png"),
    IconStyle(name: "ocean", source: "112-duo-71.png"),
    IconStyle(name: "flow", source: "105-duo-87.png"),
]

private let themes = [
    ThemePalette(theme: "desertWarm", palette: "coral-sand"),
    ThemePalette(theme: "oceanCool", palette: "mint-periwinkle"),
    ThemePalette(theme: "forestGreen", palette: "sage-cream"),
    ThemePalette(theme: "sakuraCalm", palette: "rose-plum"),
    ThemePalette(theme: "arcticDawn", palette: "ice-denim"),
    ThemePalette(theme: "solarPop", palette: "ultra-coral"),
    ThemePalette(theme: "contourAtlas", palette: "moss-jade"),
    ThemePalette(theme: "waterLilies", palette: "violet-mint"),
    ThemePalette(theme: "patisserie", palette: "rose-cream"),
]

private func rgb(_ hex: String) throws -> [Double] {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
        throw GeneratorError.invalidColor(hex)
    }
    return [16, 8, 0].map { Double((value >> $0) & 0xff) / 255 }
}

private enum GeneratorError: Error {
    case invalidColor(String)
    case singularAnchors
    case missingPalette(String)
    case unreadableImage(URL)
    case unexpectedImageSize(URL)
    case renderFailed(String)
}

private func inverse(_ matrix: [[Double]]) throws -> [[Double]] {
    var rows = matrix.enumerated().map { rowIndex, row in
        row + (0..<4).map { rowIndex == $0 ? 1.0 : 0.0 }
    }
    for column in 0..<4 {
        let pivot = (column..<4).max { abs(rows[$0][column]) < abs(rows[$1][column]) }!
        rows.swapAt(column, pivot)
        let divisor = rows[column][column]
        guard abs(divisor) >= 1e-9 else { throw GeneratorError.singularAnchors }
        rows[column] = rows[column].map { $0 / divisor }
        for row in 0..<4 where row != column {
            let factor = rows[row][column]
            rows[row] = zip(rows[row], rows[column]).map { $0 - factor * $1 }
        }
    }
    return rows.map { Array($0[4...]) }
}

private func matrix(for palette: Palette, anchors: Anchors) throws -> (CIVector, CIVector, CIVector, CIVector) {
    let source = try [anchors.background, anchors.a, anchors.b, anchors.highlight]
        .map { try rgb($0) + [1] }
    let inverted = try inverse(source)
    let colorA = try rgb(palette.a)
    let colorB = try rgb(palette.b)
    let highlight = zip(colorA, colorB).map { (($0 + $1) / 2) * 0.55 + 0.45 }
    let targets = try [rgb(palette.background), colorA, colorB, highlight]
    let coefficients = (0..<3).map { channel in
        inverted.map { row in
            let value = zip(row, targets).reduce(0.0) { $0 + $1.0 * $1.1[channel] }
            return (value * 10_000_000).rounded() / 10_000_000
        }
    }
    let vectors = coefficients.map { CIVector(x: $0[0], y: $0[1], z: $0[2], w: 0) }
    let bias = CIVector(x: coefficients[0][3], y: coefficients[1][3], z: coefficients[2][3], w: 0)
    return (vectors[0], vectors[1], vectors[2], bias)
}

private func writeJSON(_ object: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}

private func writePNG(_ image: CIImage, source: CGImage, colorMatrix: (CIVector, CIVector, CIVector, CIVector),
                      to url: URL, context: CIContext, colorSpace: CGColorSpace) throws {
    let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024 * 1024 * 4)
    pixels.initialize(repeating: 0, count: 1024 * 1024 * 4)
    defer { pixels.deallocate() }
    guard let bitmap = CGContext(data: pixels, width: 1024, height: 1024, bitsPerComponent: 8,
                                 bytesPerRow: 1024 * 4, space: colorSpace,
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw GeneratorError.renderFailed("RGB bitmap: \(url.lastPathComponent)")
    }
    if let rendered = context.createCGImage(image, from: bounds, format: .RGBA8, colorSpace: colorSpace) {
        bitmap.draw(rendered, in: bounds)
    } else {
        // Some headless Macs cannot create any CI CGImage. Apply the same matrix to sRGB bytes.
        bitmap.interpolationQuality = .high
        bitmap.draw(source, in: bounds)
        let rows = [colorMatrix.0, colorMatrix.1, colorMatrix.2]
        let bias = colorMatrix.3
        for index in stride(from: 0, to: 1024 * 1024 * 4, by: 4) {
            let input = (Double(pixels[index]) / 255, Double(pixels[index + 1]) / 255,
                         Double(pixels[index + 2]) / 255)
            for channel in 0..<3 {
                let vector = rows[channel]
                let value = vector.x * input.0 + vector.y * input.1 + vector.z * input.2
                    + [bias.x, bias.y, bias.z][channel]
                pixels[index + channel] = UInt8((min(1, max(0, value)) * 255).rounded())
            }
        }
    }
    guard let opaque = bitmap.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw GeneratorError.renderFailed("PNG destination: \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, opaque, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw GeneratorError.renderFailed("PNG finalize: \(url.lastPathComponent)")
    }
}

private func writeTransparentBrand(from iconURL: URL, background: String, to url: URL,
                                   colorSpace: CGColorSpace) throws {
    guard let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
          let icon = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw GeneratorError.unreadableImage(iconURL)
    }
    let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024 * 1024 * 4)
    pixels.initialize(repeating: 0, count: 1024 * 1024 * 4)
    defer { pixels.deallocate() }
    guard let bitmap = CGContext(data: pixels, width: 1024, height: 1024, bitsPerComponent: 8,
                                 bytesPerRow: 1024 * 4, space: colorSpace,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw GeneratorError.renderFailed("Launch brand bitmap")
    }
    bitmap.draw(icon, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let base = try rgb(background)
    let baseR = base[0], baseG = base[1], baseB = base[2]
    for index in stride(from: 0, to: 1024 * 1024 * 4, by: 4) {
        let red = Double(pixels[index]) / 255
        let green = Double(pixels[index + 1]) / 255
        let blue = Double(pixels[index + 2]) / 255
        let distance = max(abs(red - baseR), abs(green - baseG), abs(blue - baseB))
        // The palette backgrounds vary by less than 0.03. A soft 0.04–0.10 matte
        // removes that texture while retaining the artwork's antialiased boundary.
        if distance <= 0.04 {
            pixels[index] = 0
            pixels[index + 1] = 0
            pixels[index + 2] = 0
            pixels[index + 3] = 0
            continue
        }
        if distance >= 0.10 { continue }
        let t = (distance - 0.04) / 0.06
        let alpha = t * t * (3 - 2 * t)
        // Undo the background contribution before storing premultiplied RGB.
        let removed = 1 - alpha
        let foregroundR = (red - removed * baseR) / alpha
        let foregroundG = (green - removed * baseG) / alpha
        let foregroundB = (blue - removed * baseB) / alpha
        pixels[index] = UInt8((min(1, max(0, foregroundR)) * alpha * 255).rounded())
        pixels[index + 1] = UInt8((min(1, max(0, foregroundG)) * alpha * 255).rounded())
        pixels[index + 2] = UInt8((min(1, max(0, foregroundB)) * alpha * 255).rounded())
        pixels[index + 3] = UInt8((alpha * 255).rounded())
    }
    guard let image = bitmap.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw GeneratorError.renderFailed("Launch brand destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw GeneratorError.renderFailed("Launch brand finalize")
    }
}

private func writeLaunchAssets(in assetDirectory: URL, colorSpace: CGColorSpace) throws {
    let primaryURL = assetDirectory.appendingPathComponent("LaunchBrand-interleave-desertWarm.imageset/LaunchBrand.png")
    guard let source = CGImageSourceCreateWithURL(primaryURL as CFURL, nil),
          let icon = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let bitmap = CGContext(data: nil, width: 500, height: 500, bitsPerComponent: 8,
                                 bytesPerRow: 0, space: colorSpace,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw GeneratorError.renderFailed("LaunchLogo")
    }
    bitmap.interpolationQuality = .high
    bitmap.draw(icon, in: CGRect(x: 0, y: 0, width: 500, height: 500))
    let logoSet = assetDirectory.appendingPathComponent("LaunchLogo.imageset")
    try FileManager.default.createDirectory(at: logoSet, withIntermediateDirectories: true)
    let logoURL = logoSet.appendingPathComponent("LaunchLogo.png")
    guard let image = bitmap.makeImage(),
          let destination = CGImageDestinationCreateWithURL(logoURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw GeneratorError.renderFailed("LaunchLogo destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw GeneratorError.renderFailed("LaunchLogo finalize")
    }
    try writeJSON(["images": [["filename": "LaunchLogo.png", "idiom": "universal"]],
                   "info": ["author": "xcode", "version": 1],
                   "properties": ["template-rendering-intent": "original"]],
                  to: logoSet.appendingPathComponent("Contents.json"))
    let backgroundSet = assetDirectory.appendingPathComponent("Colors/LaunchBackground.colorset")
    try FileManager.default.createDirectory(at: backgroundSet, withIntermediateDirectories: true)
    let backgroundURL = backgroundSet.appendingPathComponent("Contents.json")
    try writeJSON(["colors": [["color": ["color-space": "srgb",
                                            "components": ["alpha": "1.000", "red": "0.204",
                                                           "green": "0.165", "blue": "0.169"]],
                                "idiom": "universal"]],
                   "info": ["author": "xcode", "version": 1]], to: backgroundURL)
}

private func generate() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let design = root.appendingPathComponent("docs/design/theme-map/themes/assets/dune-icon-development")
    let sourceDirectory = design.appendingPathComponent("v6")
    let paletteURL = design.appendingPathComponent("color-lab/palettes.json")
    let arguments = CommandLine.arguments
    guard arguments.count == 1 || (arguments.count == 3 && arguments[1] == "--output-dir") else {
        throw GeneratorError.renderFailed("Usage: swift scripts/generate-app-icon-assets.swift [--output-dir /private/tmp/path]")
    }
    let assetDirectory = arguments.count == 3
        ? URL(fileURLWithPath: arguments[2])
        : root.appendingPathComponent("DUNE/Resources/Assets.xcassets")
    let data = try JSONDecoder().decode(PaletteData.self, from: Data(contentsOf: paletteURL))
    let palettes = Dictionary(uniqueKeysWithValues: data.palettes.map { ($0.id, $0) })
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])
    let files = FileManager.default

    for style in styles {
        let sourceURL = sourceDirectory.appendingPathComponent(style.source)
        guard let source = CIImage(contentsOf: sourceURL, options: [.colorSpace: colorSpace]) else {
            throw GeneratorError.unreadableImage(sourceURL)
        }
        guard source.extent.width == 1254, source.extent.height == 1254 else {
            throw GeneratorError.unexpectedImageSize(sourceURL)
        }
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceBitmap = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw GeneratorError.unreadableImage(sourceURL)
        }
        let scaled = source.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": 1024.0 / 1254.0, "inputAspectRatio": 1.0,
        ])
        for item in themes {
            guard let palette = palettes[item.palette] else { throw GeneratorError.missingPalette(item.palette) }
            let (red, green, blue, bias) = try matrix(for: palette, anchors: data.sourceAnchors)
            let colored = scaled.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": red, "inputGVector": green, "inputBVector": blue,
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputBiasVector": bias,
            ])
            let isPrimary = style.name == "interleave" && item.theme == "desertWarm"
            let iconName = isPrimary ? "AppIcon" : "AppIcon-\(style.name)-\(item.theme)"
            let iconSet = assetDirectory.appendingPathComponent("\(iconName).appiconset")
            try files.createDirectory(at: iconSet, withIntermediateDirectories: true)
            let iconURL = iconSet.appendingPathComponent("AppIcon.png")
            if files.fileExists(atPath: iconURL.path) { try files.removeItem(at: iconURL) }
            try writePNG(colored, source: sourceBitmap, colorMatrix: (red, green, blue, bias),
                         to: iconURL, context: context, colorSpace: colorSpace)
            try writeJSON(["images": [["filename": "AppIcon.png", "idiom": "universal",
                                         "platform": "ios", "size": "1024x1024"]],
                           "info": ["author": "xcode", "version": 1]],
                          to: iconSet.appendingPathComponent("Contents.json"))

            let previewSet = assetDirectory.appendingPathComponent("AppIconPreview-\(style.name)-\(item.theme).imageset")
            try files.createDirectory(at: previewSet, withIntermediateDirectories: true)
            let previewURL = previewSet.appendingPathComponent("Preview.png")
            if files.fileExists(atPath: previewURL.path) { try files.removeItem(at: previewURL) }
            try files.linkItem(at: iconURL, to: previewURL)
            try writeJSON(["images": [["filename": "Preview.png", "idiom": "universal"]],
                           "info": ["author": "xcode", "version": 1]],
                          to: previewSet.appendingPathComponent("Contents.json"))
            let brandSet = assetDirectory.appendingPathComponent("LaunchBrand-\(style.name)-\(item.theme).imageset")
            try files.createDirectory(at: brandSet, withIntermediateDirectories: true)
            let brandURL = brandSet.appendingPathComponent("LaunchBrand.png")
            if files.fileExists(atPath: brandURL.path) { try files.removeItem(at: brandURL) }
            try writeTransparentBrand(from: iconURL, background: palette.background,
                                      to: brandURL, colorSpace: colorSpace)
            try writeJSON(["images": [["filename": "LaunchBrand.png", "idiom": "universal"]],
                           "info": ["author": "xcode", "version": 1]],
                          to: brandSet.appendingPathComponent("Contents.json"))
            print("\(iconName) → \(previewSet.lastPathComponent)")
        }
    }
    try writeLaunchAssets(in: assetDirectory, colorSpace: colorSpace)

    // A custom output directory is an isolated preview of the iOS catalog.
    if arguments.count == 1 {
        let primaryIcon = assetDirectory.appendingPathComponent("AppIcon.appiconset/AppIcon.png")
        let watchIcon = root.appendingPathComponent("DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        try Data(contentsOf: primaryIcon).write(to: watchIcon, options: .atomic)
    }
}

do {
    try generate()
} catch {
    fputs("App icon generation failed: \(error)\n", stderr)
    exit(1)
}
