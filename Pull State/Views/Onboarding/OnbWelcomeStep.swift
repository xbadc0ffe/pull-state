import SwiftUI

struct OnbWelcomeStep: View {
    @Binding var appearance: AppearanceMode
    @Binding var temperatureUnit: TemperatureUnit
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [palette.accent, palette.accentDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 92, height: 92)
                    .psShadow(strong: true)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
            }
            .padding(.top, 20)

            PSDisplay("Pull State", size: 34)
                .padding(.top, 22)

            Text("A precision logbook for your espresso practice. Track every shot, dial in your beans, watch yourself improve.")
                .font(PSFont.body(14))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .frame(maxWidth: 280)

            VStack(alignment: .leading, spacing: 14) {
                Text("THREE QUICK STEPS")
                    .font(PSFont.mono(12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(palette.inkSoft)
                ForEach(Array(steps.enumerated()), id: \.offset) { (i, step) in
                    let (title, desc) = step
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(palette.accentSoft)
                                .frame(width: 24, height: 24)
                            Text("\(i+1)")
                                .font(PSFont.mono(12, weight: .bold))
                                .foregroundStyle(palette.accent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(PSFont.body(15, weight: .semibold))
                                .foregroundStyle(palette.ink)
                            Text(desc)
                                .font(PSFont.body(13.5))
                                .foregroundStyle(palette.inkSoft)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 0.5)
            )
            .padding(.top, 30)

            VStack(alignment: .leading, spacing: 10) {
                Text("TEMPERATURE UNIT")
                    .font(PSFont.mono(12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(palette.inkSoft)
                TempUnitSwitch(unit: $temperatureUnit)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 0.5)
            )
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 10) {
                Text("APPEARANCE")
                    .font(PSFont.mono(12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(palette.inkSoft)
                ModeSwitch(appearance: $appearance)
                Text("Change anytime from the About menu.")
                    .font(PSFont.body(12))
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 0.5)
            )
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var steps: [(String, String)] {
        [
            ("Your hardware", "Add your machine and grinder."),
            ("Your bean", "Log the bag you're currently pulling."),
            ("Your first shot", "Time the pull, log the data, taste it."),
        ]
    }
}
