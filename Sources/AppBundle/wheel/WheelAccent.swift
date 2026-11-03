import AppKit
import ImageIO
import SwiftUI

/// The two colors of the wheel selector gradient
struct WheelColors: Equatable {
    let start: Color
    let end: Color

    init(start: Color, end: Color) {
        self.start = start
        self.end = end
    }

    /// A gradient from the color to a lighter variant of it
    init(single: Color) {
        self.init(start: single, end: single.mix(with: .white, by: 0.35))
    }

    @MainActor static var system: WheelColors { WheelColors(single: Color(nsColor: .controlAccentColor)) }
}

extension RgbColor {
    var color: Color { Color(red: red, green: green, blue: blue) }
}

/// Resolves the configured accent color. Wallpaper colors are computed in the background and cached per wallpaper
/// file; until they are ready, the system accent color is used.
@MainActor
final class WheelAccentResolver {
    static let shared = WheelAccentResolver()

    private var cachedWallpaper: (url: URL, colors: WheelColors?)? = nil
    private var pendingWallpaper: URL? = nil

    private init() {}

    /// `onUpdate` is called if the colors become available later
    func colors(for accent: WheelAccentColor, at point: CGPoint, onUpdate: @escaping @MainActor (WheelColors) -> ()) -> WheelColors {
        switch accent {
            case .system:
                return .system
            case .custom(let start, let end):
                return end.map { WheelColors(start: start.color, end: $0.color) } ?? WheelColors(single: start.color)
            case .wallpaper:
                guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main,
                      let url = NSWorkspace.shared.desktopImageURL(for: screen)
                else { return .system }
                if let cachedWallpaper, cachedWallpaper.url == url {
                    return cachedWallpaper.colors ?? .system
                }
                if pendingWallpaper != url {
                    pendingWallpaper = url
                    Task.startUnstructured { @MainActor in
                        let rgb = await wallpaperAccent(url)
                        let colors = rgb.map { WheelColors(single: $0.color) }
                        WheelAccentResolver.shared.cachedWallpaper = (url, colors)
                        WheelAccentResolver.shared.pendingWallpaper = nil
                        if let colors { onUpdate(colors) }
                    }
                }
                return .system
        }
    }
}

@concurrent private func wallpaperAccent(_ url: URL) async -> RgbColor? {
    // Some wallpapers (e.g. dynamic or aerial ones) aren't plain images. They fall back to the system accent color
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: 64,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
        guard let context = unsafe CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { return nil }
    let pixels = stride(from: 0, to: bytes.count, by: 4).map { i in
        RgbColor(red: Double(bytes[i]) / 255, green: Double(bytes[i + 1]) / 255, blue: Double(bytes[i + 2]) / 255)
    }
    return vibrantAccent(of: pixels)
}

/// The most prominent vibrant hue among the pixels, as an accent color. nil for grayscale images.
///
/// Pixels are grouped by hue and weighted by how good they'd look as an accent: saturated, neither too dark nor too
/// bright. The winning hue group is averaged and lifted to a legible brightness.
func vibrantAccent(of pixels: [RgbColor]) -> RgbColor? {
    let binCount = 18
    var weights = [Double](repeating: 0, count: binCount)
    var sums = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: binCount)
    for pixel in pixels {
        let (hue, saturation, brightness) = pixel.hsb
        // Near white pixels are filtered out by their low saturation
        guard saturation > 0.2, brightness > 0.15 else { continue }
        let weight = saturation * (1 - abs(brightness - 0.6))
        let bin = min(Int(hue * Double(binCount)), binCount - 1)
        weights[bin] += weight
        sums[bin].r += pixel.red * weight
        sums[bin].g += pixel.green * weight
        sums[bin].b += pixel.blue * weight
    }
    guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[best] > 0 else { return nil }
    let total = weights[best]
    let average = RgbColor(red: sums[best].r / total, green: sums[best].g / total, blue: sums[best].b / total)
    let (hue, saturation, brightness) = average.hsb
    return RgbColor(hue: hue, saturation: max(saturation, 0.45), brightness: max(brightness, 0.65))
}

extension RgbColor {
    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maxComponent = max(red, green, blue)
        let minComponent = min(red, green, blue)
        let delta = maxComponent - minComponent
        let saturation = maxComponent == 0 ? 0 : delta / maxComponent
        guard delta > 0 else { return (0, saturation, maxComponent) }
        var hue = switch maxComponent {
            case red: (green - blue) / delta
            case green: 2 + (blue - red) / delta
            default: 4 + (red - green) / delta
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return (hue, saturation, maxComponent)
    }

    init(hue: Double, saturation: Double, brightness: Double) {
        let color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        self.init(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
}
