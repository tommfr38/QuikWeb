#!/usr/bin/env swift
//
// Rasterizes the hand-authored SVGs in Icons/ into every PNG QuikWeb needs:
// the full AppIcon.iconset (for `iconutil`), a standalone preview PNG for the
// About tab, the status-bar template icon, and the settings-tab/menu glyphs.
//
// Pure AppKit, no third-party tools (rsvg-convert/inkscape are not assumed to
// be installed). Run with the project root as the working directory:
//   swift Scripts/GenerateIcons.swift
//
import AppKit

func loadSVG(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else {
        fatalError("Failed to load SVG at \(path)")
    }
    return image
}

func rasterize(_ image: NSImage, size: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to allocate bitmap rep at size \(size)")
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG at size \(size)")
    }
    return data
}

func writeFile(_ data: Data, to path: String) throws {
    try data.write(to: URL(fileURLWithPath: path))
    print("  wrote \(path) (\(data.count) bytes)")
}

func run() throws {
    let fm = FileManager.default
    let iconsDir = "Icons"
    let outDir = "build/GeneratedResources"
    let iconsetDir = "\(outDir)/AppIcon.iconset"

    try? fm.removeItem(atPath: outDir)
    try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    print("Rasterizing app-icon.svg -> AppIcon.iconset")
    let appIcon = loadSVG("\(iconsDir)/app-icon.svg")
    let iconsetSizes: [(name: String, size: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]
    for entry in iconsetSizes {
        try writeFile(rasterize(appIcon, size: entry.size), to: "\(iconsetDir)/\(entry.name).png")
    }

    print("Rasterizing standalone AppIcon256.png (for in-app use, e.g. About tab)")
    try writeFile(rasterize(appIcon, size: 256), to: "\(outDir)/AppIcon256.png")

    print("Rasterizing status-bar-icon.svg (template)")
    let statusBarIcon = loadSVG("\(iconsDir)/status-bar-icon.svg")
    try writeFile(rasterize(statusBarIcon, size: 64), to: "\(outDir)/StatusBarIcon.png")

    print("Rasterizing UI glyphs")
    let glyphs = ["glyph-search", "glyph-globe", "tab-general", "tab-hotkey", "tab-appearance", "tab-about", "menu-exit"]
    for name in glyphs {
        let svg = loadSVG("\(iconsDir)/\(name).svg")
        try writeFile(rasterize(svg, size: 128), to: "\(outDir)/\(name).png")
    }

    print("Done. Generated resources at \(outDir)")
}

do {
    try run()
} catch {
    print("Icon generation failed: \(error)")
    exit(1)
}
