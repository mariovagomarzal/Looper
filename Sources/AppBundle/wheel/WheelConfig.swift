import Common

struct WheelConfig: Withable, Equatable, Sendable {
    /// Percentage of the maximum corner radius: 0 is a square, 100 is a circle
    var cornerRadius: Int = 100
    /// Points. Bounded so that the center zone stays reachable
    var thickness: Int = 22
    var accentColor: WheelAccentColor = .system
    /// Trackpad haptic feedback when the selection changes
    var haptics: Bool = true

    static let cornerRadiusRange = 0 ... 100
    static let thicknessRange = 10 ... 35
}

enum WheelAccentColor: Equatable, Sendable {
    /// The macOS accent color
    case system
    /// The most vibrant color of the wallpaper under the pointer
    case wallpaper
    case custom(RgbColor, gradientEnd: RgbColor?)
}

struct RgbColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    /// Parses '#RRGGBB'
    init?(hex: String) {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

private let wheelParser: [String: any ParserProtocol<WheelConfig>] = [
    "corner-radius": Parser(\.cornerRadius) { parseIntInRange($0, $1, WheelConfig.cornerRadiusRange) },
    "thickness": Parser(\.thickness) { parseIntInRange($0, $1, WheelConfig.thicknessRange) },
    "accent-color": Parser(\.accentColor, parseWheelAccentColor),
    "haptics": Parser(\.haptics, parseBool),
]

func parseWheel(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> WheelConfig {
    parseNonEmptyTable(raw, WheelConfig(), wheelParser, backtrace, &c)
}

private func parseIntInRange(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ range: ClosedRange<Int>) -> ResOrConfigParseDiagnostic<Int> {
    parseInt(raw, backtrace).flatMap { value in
        range.contains(value)
            ? .success(value)
            : .failure(.init(backtrace, "Must be in [\(range.lowerBound), \(range.upperBound)] range"))
    }
}

private func parseWheelAccentColor(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<WheelAccentColor> {
    let error = ConfigParseDiagnostic(backtrace, "Expected 'system', 'wallpaper', a '#RRGGBB' color, or an array of two '#RRGGBB' colors for a gradient")
    if let string = raw.asStringOrNil {
        return switch string {
            case "system": .success(.system)
            case "wallpaper": .success(.wallpaper)
            default: RgbColor(hex: string).map { .custom($0, gradientEnd: nil) }.toResult(error)
        }
    }
    if let array = raw.asArrayOrNil, array.count == 2,
       let start = array[0].asStringOrNil.flatMap(RgbColor.init(hex:)),
       let end = array[1].asStringOrNil.flatMap(RgbColor.init(hex:))
    {
        return .success(.custom(start, gradientEnd: end))
    }
    return .failure(error)
}
