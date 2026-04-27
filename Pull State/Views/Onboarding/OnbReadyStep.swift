import SwiftUI

struct OnbReadyStep: View {
    let machine: OnbHardwareEntry
    let grinder: OnbHardwareEntry
    let bean: OnbBeanEntry

    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(palette.accentSoft)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().strokeBorder(palette.accent, lineWidth: 1))
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(palette.accent)
            }
            .padding(.top, 22)

            PSDisplay("You're dialed.", size: 32)
                .padding(.top, 18)

            Text("Your setup is saved. Time to pull your first shot.")
                .font(PSFont.body(13))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .frame(maxWidth: 260)

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(label: "MACHINE", value: machine.name.isEmpty ? "—" : machine.name, sub: machine.brand)
                summaryRow(label: "GRINDER", value: grinder.name.isEmpty ? "—" : grinder.name, sub: grinder.brand)
                summaryRow(label: "BEAN", value: bean.name.isEmpty ? "—" : bean.name,
                           sub: "\(bean.roaster.isEmpty ? "—" : bean.roaster) · \(bean.roast.rawValue)")
            }
            .padding(.top, 22)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String, sub: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                PSSectionLabel(label)
                Text(value)
                    .font(PSFont.display(18, weight: .semibold))
                    .foregroundStyle(palette.ink)
                Text(sub)
                    .font(PSFont.body(11))
                    .foregroundStyle(palette.inkSoft)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 0.5)
        )
    }
}
