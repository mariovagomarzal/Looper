import Common
import Foundation
import SwiftUI

/// Draws the `menu-bar` templates as one image: text and SF Symbols on one baseline
@MainActor
struct MenuBarLabel: View {
    @Environment(\.colorScheme) var menuColorScheme: ColorScheme
    @EnvironmentObject var viewModel: TrayMenuModel

    var body: some View {
        let segments = viewModel.menuBar
        let renderer = ImageRenderer(content: content(segments))
        switch renderer.cgImage {
            // Drawn at twice the size of the menu bar: scale 1 results in a blurry image
            case let cgImage?: Image(cgImage, scale: 2, label: Text(segments.plainText))
            case nil: Text(segments.plainText)
        }
    }

    private func content(_ segments: [MenuBarSegment]) -> some View {
        segments
            .reduce(Text("")) { text, segment in
                switch segment {
                    case .text(let string): Text("\(text)\(string)")
                    case .symbol(let name): Text("\(text)\(Image(systemName: name))")
                }
            }
            .font(.system(size: 28, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(menuColorScheme == .dark ? Color.white : Color.black)
            .lineLimit(1)
            .fixedSize()
    }
}
