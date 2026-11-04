import Common
import Foundation
import SwiftUI

/// Draws the `menu-bar` templates as one image: text, SF Symbols and Looper's glyph in one line
@MainActor
struct MenuBarLabel: View {
    @Environment(\.colorScheme) var menuColorScheme: ColorScheme
    @EnvironmentObject var viewModel: TrayMenuModel

    var body: some View {
        let segments = viewModel.menuBar
        menuBarImage(label: segments.plainText, colorScheme: menuColorScheme) {
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                        case .text(let string): Text(string)
                        case .symbol(looperGlyphSymbol): LooperGlyph().frame(width: menuBarGlyphSize, height: menuBarGlyphSize)
                        case .symbol(let name): Image(systemName: name)
                    }
                }
            }
            .font(.system(size: menuBarFontSize, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
        }
    }
}

/// Points of the menu bar content, drawn at twice the size of the menu bar
let menuBarFontSize: CGFloat = 32
/// Looper's glyph is a bit bigger than the text, like the icons of other menu bar items
let menuBarGlyphSize: CGFloat = 36

/// The menu bar shows images: views drawn in the color of the menu bar
@MainActor
func menuBarImage(label: String, colorScheme: ColorScheme, @ViewBuilder content: () -> some View) -> some View {
    let renderer = ImageRenderer(content: content().foregroundStyle(colorScheme == .dark ? Color.white : Color.black))
    return Group {
        switch renderer.cgImage {
            // Scale 1 results in a blurry image
            case let cgImage?: Image(cgImage, scale: 2, label: Text(label))
            case nil: Text(label)
        }
    }
}
