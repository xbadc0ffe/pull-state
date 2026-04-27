import SwiftUI

struct OnbHardwareStep: View {
    @Binding var machine: OnbHardwareEntry
    @Binding var grinder: OnbHardwareEntry
    @Environment(\.psPalette) private var palette

    private let machineSuggestions = [
        "Linea Mini", "Linea Micra", "GS3", "Bambino Plus", "Silvia Pro",
        "Profitec Pro 600", "Lelit Bianca", "Rancilio Silvia", "ECM Synchronika",
        "Rocket Appartamento", "Decent DE1+", "Flair 58", "Breville Dual Boiler"
    ]
    private let grinderSuggestions = [
        "Niche Zero", "Niche Duo", "DF64", "DF83", "Mahlkönig X54", "Mahlkönig E80",
        "Eureka Mignon Specialita", "Eureka Atom 75", "Lagom P64", "Weber Key",
        "Baratza Sette 270", "Fellow Ode"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                PSDisplay("Your hardware", size: 28)
                Text("Tell Pull State what you're pulling on. You can add more later.")
                    .font(PSFont.body(13))
                    .foregroundStyle(palette.inkSoft)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 12) {
                PSSectionLabel("Espresso Machine")
                OnbCombobox(label: "Name",
                            text: $machine.name,
                            placeholder: "Search or type a model…",
                            options: machineSuggestions)
                OnbField(label: "Brand", text: $machine.brand, placeholder: "e.g. La Marzocco")
            }

            Rectangle().fill(palette.line).frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                PSSectionLabel("Grinder")
                OnbCombobox(label: "Name",
                            text: $grinder.name,
                            placeholder: "Search or type a model…",
                            options: grinderSuggestions)
                OnbField(label: "Brand", text: $grinder.brand, placeholder: "e.g. Niche")
            }
        }
    }
}

struct OnbField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PSSectionLabel(label)
            TextField(placeholder, text: $text)
                .font(PSFont.body(15, weight: .medium))
                .foregroundStyle(palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(palette.lineStrong, lineWidth: 1)
                )
        }
    }
}

struct OnbCombobox: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    let options: [String]

    @Environment(\.psPalette) private var palette
    @State private var open = false
    @FocusState private var focused: Bool

    private var filtered: [String] {
        guard !text.isEmpty else { return options }
        return options.filter { $0.lowercased().contains(text.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PSSectionLabel(label)
            ZStack(alignment: .trailing) {
                TextField(placeholder, text: $text)
                    .font(PSFont.body(15, weight: .medium))
                    .foregroundStyle(palette.ink)
                    .focused($focused)
                    .padding(.horizontal, 12)
                    .padding(.trailing, 36)
                    .padding(.vertical, 11)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(open ? palette.accent : palette.lineStrong, lineWidth: 1)
                    )
                    .onChange(of: focused) { _, new in
                        if new { open = true }
                    }
                    .onChange(of: text) { _, _ in
                        open = true
                    }

                Button {
                    open.toggle()
                    if open { focused = true }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.inkSoft)
                        .rotationEffect(open ? .degrees(180) : .degrees(0))
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }

            if open {
                VStack(spacing: 0) {
                    if filtered.isEmpty {
                        Text("No matches — keep typing to add a custom name.")
                            .font(PSFont.body(13))
                            .foregroundStyle(palette.inkMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(filtered, id: \.self) { opt in
                                    let active = opt == text
                                    Button {
                                        text = opt
                                        open = false
                                        focused = false
                                    } label: {
                                        HStack {
                                            Text(opt)
                                                .font(PSFont.body(14, weight: active ? .semibold : .medium))
                                                .foregroundStyle(active ? palette.accentDeep : palette.ink)
                                            Spacer()
                                            if active {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(palette.accent)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(active ? palette.accentSoft : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(4)
                        }
                        .scrollIndicators(.hidden)
                        .frame(maxHeight: 196)
                    }
                }
                .background(palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.lineStrong, lineWidth: 0.5)
                )
                .psShadow(strong: true)
            }
        }
    }
}
