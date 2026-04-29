import SwiftUI

struct PSPalette {
    let page: Color
    let surface: Color
    let surfaceAlt: Color
    let card: Color
    let line: Color
    let lineStrong: Color
    let ink: Color
    let inkSoft: Color
    let inkMuted: Color
    let accent: Color
    let accentDeep: Color
    let accentSoft: Color
    let good: Color
    let bad: Color
    let chrome: Color
    let placeholderA: Color
    let placeholderB: Color
}

extension PSPalette {
    static let light = PSPalette(
        page:        Color(hex: 0xEBE2D5),
        surface:     Color(hex: 0xF4ECDF),
        surfaceAlt:  Color(hex: 0xE8DCC8),
        card:        Color(hex: 0xFBF6EC),
        line:        Color(red: 58/255, green: 32/255, blue: 18/255).opacity(0.12),
        lineStrong:  Color(red: 58/255, green: 32/255, blue: 18/255).opacity(0.22),
        ink:         Color(hex: 0x2A1C14),
        inkSoft:     Color(hex: 0x2A1C14).opacity(0.68),
        inkMuted:    Color(hex: 0x2A1C14).opacity(0.42),
        accent:      Color(hex: 0xC8794A),
        accentDeep:  Color(hex: 0x9A5430),
        accentSoft:  Color(hex: 0xC8794A).opacity(0.14),
        good:        Color(hex: 0x5D7A3F),
        bad:         Color(hex: 0xA14A3A),
        chrome:      Color(hex: 0xDCCBB1),
        placeholderA: Color(hex: 0xD6C4A8),
        placeholderB: Color(hex: 0xCFBB9A)
    )

    static let dark = PSPalette(
        page:        Color(hex: 0x1A1411),
        surface:     Color(hex: 0x241B16),
        surfaceAlt:  Color(hex: 0x1F1612),
        card:        Color(hex: 0x2A201A),
        line:        Color(red: 244/255, green: 237/255, blue: 228/255).opacity(0.08),
        lineStrong:  Color(red: 244/255, green: 237/255, blue: 228/255).opacity(0.16),
        ink:         Color(hex: 0xF4EDE4),
        inkSoft:     Color(hex: 0xF4EDE4).opacity(0.66),
        inkMuted:    Color(hex: 0xF4EDE4).opacity(0.40),
        accent:      Color(hex: 0xD88B5A),
        accentDeep:  Color(hex: 0xC8794A),
        accentSoft:  Color(hex: 0xD88B5A).opacity(0.16),
        good:        Color(hex: 0x9BBF6F),
        bad:         Color(hex: 0xD97A64),
        chrome:      Color(hex: 0x150F0C),
        placeholderA: Color(hex: 0x3A2C22),
        placeholderB: Color(hex: 0x2E231B)
    )

    static func resolve(for scheme: ColorScheme) -> PSPalette {
        scheme == .dark ? .dark : .light
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

private struct PSPaletteKey: EnvironmentKey {
    static let defaultValue: PSPalette = .dark
}

private struct PSTempUnitKey: EnvironmentKey {
    static let defaultValue: TemperatureUnit = .celsius
}

extension EnvironmentValues {
    var psPalette: PSPalette {
        get { self[PSPaletteKey.self] }
        set { self[PSPaletteKey.self] = newValue }
    }
    var psTempUnit: TemperatureUnit {
        get { self[PSTempUnitKey.self] }
        set { self[PSTempUnitKey.self] = newValue }
    }
}

struct PSFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum PSFmt {
    static func seconds(_ s: Double) -> String {
        guard s.isFinite else { return "0.0s" }
        if s < 60 { return String(format: "%.1fs", s) }
        let m = Int(s / 60)
        let rem = s - Double(m) * 60
        return String(format: "%d:%04.1f", m, rem)
    }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    static func shortDateMono(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f.string(from: d)
    }

    static func cardDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }

    static func detailDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd · HH:mm:ss"
        return f.string(from: d)
    }

    static func nowShortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: d)
    }
}

struct PSShadow: ViewModifier {
    let strong: Bool
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if strong {
            content
                .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.10),
                        radius: scheme == .dark ? 14 : 8, x: 0, y: 6)
                .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.10),
                        radius: 1.5, x: 0, y: 1)
        } else {
            content
                .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.06),
                        radius: 1.5, x: 0, y: 1)
        }
    }
}

extension View {
    func psShadow(strong: Bool = true) -> some View {
        modifier(PSShadow(strong: strong))
    }
}
