import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PSTab: String, CaseIterable, Identifiable {
    case log, history, beans, hardware

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var systemImage: String {
        switch self {
        case .log:      return "doc.text"
        case .history:  return "clock.arrow.circlepath"
        case .beans:    return ""
        case .hardware: return Self.hardwareSymbol
        }
    }

    private static let hardwareSymbol: String = {
        #if canImport(UIKit)
        if UIImage(systemName: "espresso.machine") != nil {
            return "espresso.machine"
        }
        #endif
        return "cup.and.saucer.fill"
    }()
}

struct BeanIcon: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let baseR = min(size.width, size.height) / 2
            let beanR = baseR * 0.42
            let cx = size.width / 2, cy = size.height / 2

            // Three beans in a loose cluster:
            // center, upper-left, lower-right
            let placements: [(CGPoint, Double)] = [
                (CGPoint(x: cx,                     y: cy),                     -22),
                (CGPoint(x: cx - baseR * 0.45,      y: cy - baseR * 0.45),       18),
                (CGPoint(x: cx + baseR * 0.45,      y: cy + baseR * 0.45),      -52)
            ]

            for (center, angle) in placements {
                ctx.drawLayer { layer in
                    layer.translateBy(x: center.x, y: center.y)
                    layer.rotate(by: .degrees(angle))
                    drawBean(in: layer, radius: beanR, color: color)
                }
            }
        }
    }

    private func drawBean(in ctx: GraphicsContext, radius r: CGFloat, color: Color) {
        let oval = Path(ellipseIn: CGRect(
            x: -r, y: -r * 0.7,
            width: r * 2, height: r * 1.4
        ))
        ctx.stroke(oval, with: .color(color),
                   style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

        var seam = Path()
        seam.move(to: CGPoint(x: -r * 0.85, y: r * 0.35))
        seam.addQuadCurve(
            to: CGPoint(x: r * 0.85, y: -r * 0.35),
            control: .zero
        )
        ctx.stroke(seam, with: .color(color),
                   style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }
}

struct PSTabBar: View {
    @Binding var selected: PSTab
    @Environment(\.psPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PSTab.allCases) { tab in
                let isActive = tab == selected
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Group {
                            if tab == .beans {
                                BeanIcon(color: isActive ? palette.accent : palette.inkSoft)
                            } else {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(isActive ? palette.accent : palette.inkSoft)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(tab.label)
                            .font(PSFont.body(10, weight: .semibold))
                            .tracking(0.2)
                            .foregroundStyle(isActive ? palette.ink : palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(isActive ? palette.card : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(isActive ? palette.line : Color.clear, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(palette.chrome, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 0.5)
        )
        .psShadow(strong: true)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}
