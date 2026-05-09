import SwiftUI

struct ShotCard: View {
    let shot: Shot
    @Environment(\.psPalette) private var palette

    private var tone: PSPillTone {
        switch shot.extraction {
        case .sour: return .sour
        case .bitter: return .bitter
        default: return .perfect
        }
    }

    var body: some View {
        PSCard(soft: true) {
            HStack(spacing: 12) {
                PSPhotoThumb(
                    data: shot.photoData,
                    label: "SHOT",
                    radius: 10,
                    fallback: shot.bean?.photoData
                )
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text((shot.bean?.name ?? "Unknown").uppercased())
                            .font(PSFont.display(16, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        Text("#\(shot.bean?.bagNumber ?? 0)")
                            .font(PSFont.mono(10))
                            .foregroundStyle(palette.inkMuted)
                    }

                    HStack(spacing: 8) {
                        PSStars(staticValue: shot.rating, size: 13)
                        PSPill(
                            label: shot.extraction?.rawValue ?? "—",
                            active: shot.extraction != nil,
                            tone: tone,
                            horizontalPadding: 8,
                            verticalPadding: 3,
                            fontSize: 10
                        )
                    }

                    HStack(spacing: 10) {
                        Text(String(format: "%.1fs", shot.pull))
                        Text("-")
                        Text(String(format: "1:%.2f", shot.ratio))
                        Text("-")
                        Text("\(formatted(shot.dose))g → \(formatted(shot.yield))g")
                    }
                    .font(PSFont.mono(10))
                    .foregroundStyle(palette.inkSoft)

                    Text(PSFmt.cardDate(shot.date).uppercased())
                        .font(PSFont.mono(9.5))
                        .tracking(0.6)
                        .foregroundStyle(palette.inkMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(12)
        }
    }

    private func formatted(_ d: Double) -> String {
        d == d.rounded() ? "\(Int(d))" : String(format: "%.1f", d)
    }
}
