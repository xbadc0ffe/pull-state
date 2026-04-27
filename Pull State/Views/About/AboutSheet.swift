import SwiftUI

struct AboutSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.psPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager()
    @State private var purchaseSucceeded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(palette.surfaceAlt, in: Circle())
                            .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [palette.accent, palette.accentDeep],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                            .psShadow(strong: true)
                        AppLogo(deepColor: palette.accentDeep)
                            .frame(width: 38, height: 38)
                    }
                    PSDisplay("Pull State", size: 26)
                    Text("v 1.0.0 · APR 26 2026")
                        .font(PSFont.mono(11))
                        .tracking(1)
                        .foregroundStyle(palette.inkMuted)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                PSCard {
                    VStack(spacing: 0) {
                        PSField(label: "Built by") {
                            PSValueText(text: "badc0ffe", fontSize: 13)
                        }
                        PSField(label: "Contact") {
                            Text("info@badc0ffe.net")
                                .font(PSFont.mono(13, weight: .semibold))
                                .foregroundStyle(palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        PSField(label: "GitHub") {
                            Text("github.com/xbadc0ffe/pull-state")
                                .font(PSFont.mono(13, weight: .semibold))
                                .foregroundStyle(palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        PSField(label: "Appearance", last: true) {
                            ModeSwitch(appearance: Binding(
                                get: { settings.appearance },
                                set: { settings.appearance = $0 }
                            ))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // Tip jar
                Button {
                    Task {
                        await store.loadProductIfNeeded()
                        let ok = await store.purchase()
                        if ok {
                            settings.hasTipped = true
                            purchaseSucceeded = true
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.hasTipped
                                      ? AnyShapeStyle(palette.accent)
                                      : AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentDeep],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                                .frame(width: 42, height: 42)
                            if settings.hasTipped {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.hasTipped ? "Thanks for the coffee!" : "Buy me a coffee!")
                                .font(PSFont.body(14.5, weight: .bold))
                                .foregroundStyle(palette.ink)
                            Text(settings.hasTipped ? "Means the world. Now back to dialing in." : "Support development with a one-time tip.")
                                .font(PSFont.body(12))
                                .foregroundStyle(palette.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        if !settings.hasTipped {
                            Text(store.displayPrice)
                                .font(PSFont.mono(13, weight: .bold))
                                .tracking(0.3)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(palette.accent, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(settings.hasTipped ? palette.accentSoft : palette.card,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(settings.hasTipped ? palette.accent : palette.lineStrong, lineWidth: 1)
                    )
                    .psShadow(strong: !settings.hasTipped)
                }
                .buttonStyle(.plain)
                .disabled(settings.hasTipped || store.purchaseInFlight)
                .padding(.horizontal, 18)
                .padding(.top, 18)

                Text("A precision logbook for your espresso practice.\nMade for people who care about pulls.")
                    .font(PSFont.body(12))
                    .foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                if let err = store.purchaseError {
                    Text(err)
                        .font(PSFont.body(11))
                        .foregroundStyle(palette.bad)
                        .padding(.top, 10)
                        .padding(.horizontal, 18)
                }

                Spacer(minLength: 24)
            }
            .psContentColumn()
        }
        .scrollIndicators(.hidden)
        .background(palette.surface)
        .task {
            await store.loadProductIfNeeded()
        }
    }
}

private struct AppLogo: View {
    let deepColor: Color

    var body: some View {
        Canvas { ctx, size in
            // Cup top rim
            let topRim = Path { p in
                let w = size.width, h = size.height
                p.move(to: CGPoint(x: 0.292 * w, y: 0.208 * h))
                p.addLine(to: CGPoint(x: 0.708 * w, y: 0.208 * h))
                p.addLine(to: CGPoint(x: 0.667 * w, y: 0.333 * h))
                p.addLine(to: CGPoint(x: 0.333 * w, y: 0.333 * h))
                p.closeSubpath()
            }
            ctx.fill(topRim, with: .color(.white.opacity(0.95)))

            // Cup body
            let body = Path { p in
                let w = size.width, h = size.height
                p.move(to: CGPoint(x: 0.333 * w, y: 0.333 * h))
                p.addLine(to: CGPoint(x: 0.667 * w, y: 0.333 * h))
                p.addLine(to: CGPoint(x: 0.625 * w, y: 0.708 * h))
                p.addQuadCurve(to: CGPoint(x: 0.542 * w, y: 0.792 * h), control: CGPoint(x: 0.625 * w, y: 0.792 * h))
                p.addLine(to: CGPoint(x: 0.458 * w, y: 0.792 * h))
                p.addQuadCurve(to: CGPoint(x: 0.375 * w, y: 0.708 * h), control: CGPoint(x: 0.375 * w, y: 0.792 * h))
                p.closeSubpath()
            }
            ctx.fill(body, with: .color(.white.opacity(0.85)))

            // Crema dot
            let dot = Path(ellipseIn: CGRect(
                x: size.width * 0.5 - size.width * 0.073,
                y: size.height * 0.542 - size.height * 0.073,
                width: size.width * 0.146,
                height: size.width * 0.146
            ))
            ctx.fill(dot, with: .color(deepColor))
        }
    }
}

struct ModeSwitch: View {
    @Binding var appearance: AppearanceMode
    @Environment(\.psPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    appearance = mode
                } label: {
                    Text(mode.label)
                        .font(PSFont.body(11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(appearance == mode ? Color.white : palette.inkSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(appearance == mode ? AnyShapeStyle(palette.accent) : AnyShapeStyle(Color.clear),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(palette.surfaceAlt, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.lineStrong, lineWidth: 0.5))
    }
}
