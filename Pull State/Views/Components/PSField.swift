import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One label/value row inside a `PSCard`. Handles its own bottom divider
/// (suppressed when `last` is true) and an optional trailing `suffix` (used
/// for unit hints and computed indicators like "1:2.10").
struct PSField<Content: View>: View {
    let label: String
    var suffix: String? = nil
    var last: Bool = false
    var labelWidth: CGFloat? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if let labelWidth {
                        Text(label)
                            .frame(width: labelWidth, alignment: .leading)
                    } else {
                        Text(label)
                    }
                }
                .font(PSFont.body(13, weight: .medium))
                .foregroundStyle(palette.inkSoft)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                content()
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let suffix {
                    Text(suffix)
                        .font(PSFont.mono(11))
                        .foregroundStyle(palette.inkMuted)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 50)

            if !last {
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 0.5)
            }
        }
    }
}

struct PSValueText: View {
    let text: String
    var mono: Bool = true
    var fontSize: CGFloat = 15
    var weight: Font.Weight = .semibold
    @Environment(\.psPalette) private var palette

    var body: some View {
        Text(text)
            .font(mono ? PSFont.mono(fontSize, weight: weight) : PSFont.body(fontSize, weight: weight))
            .foregroundStyle(palette.ink)
    }
}

enum PSKeyboard {
    case `default`, decimal
}

struct PSTextInput: View {
    @Binding var text: String
    var placeholder: String = ""
    var mono: Bool = false
    var alignment: TextAlignment = .trailing
    var keyboard: PSKeyboard = .default
    @Environment(\.psPalette) private var palette

    var body: some View {
        TextField(placeholder, text: $text)
            .font(mono ? PSFont.mono(15, weight: .semibold) : PSFont.body(15, weight: .semibold))
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(alignment)
            .modifier(PSDecimalKeyboard(active: keyboard == .decimal))
            .textFieldStyle(.plain)
    }
}

/// Cross-platform shim for `.keyboardType(.decimalPad)` — applies on iOS, no-op
/// on macOS where `keyboardType` does not exist.
struct PSDecimalKeyboard: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        #if os(iOS)
        if active {
            content.keyboardType(.decimalPad)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
