import SwiftUI

struct OnbBeanStep: View {
    @Binding var bean: OnbBeanEntry
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                PSDisplay("What's in the hopper?", size: 28)
                Text("Log your current bag. Bag #1 starts your collection.")
                    .font(PSFont.body(13))
                    .foregroundStyle(palette.inkSoft)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 16) {
                OnbField(label: "Bean Name", text: $bean.name, placeholder: "e.g. Black Gold")
                OnbField(label: "Roaster", text: $bean.roaster, placeholder: "e.g. Onyx Coffee Lab")

                VStack(alignment: .leading, spacing: 8) {
                    PSSectionLabel("Roast Level")
                    HStack(spacing: 6) {
                        ForEach(Roast.allCases) { r in
                            PSPill(label: r.rawValue, active: bean.roast == r, action: { bean.roast = r })
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("BAG #001")
                        .font(PSFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(palette.accentDeep)
                    Text("Bag numbers auto-increment. Photos, dates and tasting notes can be added on the bean page later.")
                        .font(PSFont.body(12.5))
                        .foregroundStyle(palette.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.accent, lineWidth: 0.5)
                )
            }
        }
    }
}
