import SwiftUI
import SwiftData

/// Four-step onboarding: Welcome → Hardware → Bean → Ready. On finish (and on
/// "Skip setup" — same path), any non-empty entries are persisted, the bag
/// counter increments if a bean was added, and `hasCompletedOnboarding`
/// flips. The user lands on the Log tab.
struct OnboardingFlow: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @State private var step: Int = 0

    @State private var machine = OnbHardwareEntry(name: "", brand: "")
    @State private var grinder = OnbHardwareEntry(name: "", brand: "")
    @State private var bean = OnbBeanEntry(name: "", roaster: "", roast: .medium)

    private let steps = ["welcome", "hardware", "bean", "ready"]
    private var palette: PSPalette { PSPalette.resolve(for: scheme) }

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? palette.accent : palette.lineStrong)
                            .frame(width: i == step ? 22 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.25), value: step)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch steps[step] {
                        case "welcome":
                            OnbWelcomeStep(
                                appearance: Binding(
                                    get: { settings.appearance },
                                    set: { settings.appearance = $0 }
                                ),
                                temperatureUnit: Binding(
                                    get: { settings.temperatureUnit },
                                    set: { settings.temperatureUnit = $0 }
                                )
                            )
                        case "hardware":
                            OnbHardwareStep(machine: $machine, grinder: $grinder)
                        case "bean":
                            OnbBeanStep(bean: $bean)
                        default:
                            OnbReadyStep(machine: machine, grinder: grinder, bean: bean)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    Button {
                        if step == steps.count - 1 {
                            finish()
                        } else {
                            withAnimation(.easeOut(duration: 0.18)) { step += 1 }
                        }
                    } label: {
                        Text(continueLabel)
                            .font(PSFont.body(15, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .psShadow(strong: true)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        if step > 0 {
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) { step -= 1 }
                            } label: {
                                Text("‹ Back")
                                    .font(PSFont.body(15, weight: .medium))
                                    .foregroundStyle(palette.inkSoft)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Spacer().frame(height: 1)
                        }
                        Spacer()
                        Button(action: finish) {
                            Text("Skip setup")
                                .font(PSFont.body(15, weight: .medium))
                                .foregroundStyle(palette.inkMuted)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .psContentColumn()
        }
        .environment(\.psPalette, palette)
    }

    private var continueLabel: String {
        switch steps[step] {
        case "welcome": return "BEGIN SETUP"
        case "hardware": return "CONTINUE"
        case "bean": return "CONTINUE"
        default: return "PULL YOUR FIRST SHOT"
        }
    }

    private func finish() {
        // Persist anything entered, then mark onboarding complete
        if !machine.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let m = Equipment(name: machine.name, brand: machine.brand, kind: .machine)
            context.insert(m)
        }
        if !grinder.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let g = Equipment(name: grinder.name, brand: grinder.brand, kind: .grinder)
            context.insert(g)
        }
        if !bean.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let b = Bean(
                name: bean.name,
                bagNumber: settings.nextBagNumber,
                roaster: bean.roaster,
                singleOrigin: true,
                process: .washed,
                roast: bean.roast
            )
            context.insert(b)
            settings.nextBagNumber += 1
        }
        settings.hasCompletedOnboarding = true
        try? context.save()
    }
}

struct OnbHardwareEntry {
    var name: String
    var brand: String
}

struct OnbBeanEntry {
    var name: String
    var roaster: String
    var roast: Roast
}
