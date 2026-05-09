import SwiftUI
import SwiftData

/// App shell. Owns the single `NavigationStack`, the four-tab switcher, and
/// every modal sheet (About, Add Bean, Add Hardware). Pushes `\.psPalette`
/// and `\.psTempUnit` into the environment for the whole tree, including
/// every sheet (sheets do not inherit environment automatically).
struct MainTabView: View {
    @Bindable var settings: AppSettings
    @Environment(\.colorScheme) private var scheme

    @State private var selected: PSTab = .log
    @State private var navPath = NavigationPath()
    @State private var showAbout: Bool = false
    @State private var showAddBean: Bool = false
    @State private var addHardwareKind: EquipmentKind? = nil

    private var palette: PSPalette { PSPalette.resolve(for: scheme) }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                PSPageBackground()

                VStack(spacing: 0) {
                    Group {
                        switch selected {
                        case .log:
                            LogScreen(onShowAbout: { showAbout = true })
                        case .history:
                            HistoryScreen(onShowAbout: { showAbout = true })
                        case .beans:
                            BeansScreen(
                                onAdd: { showAddBean = true },
                                onShowAbout: { showAbout = true }
                            )
                        case .hardware:
                            HardwareScreen(
                                onAdd: { kind in addHardwareKind = kind },
                                onShowAbout: { showAbout = true }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    PSTabBar(selected: $selected)
                        .psContentColumn()
                }
            }
            .navigationDestination(for: NavRoute.self) { route in
                switch route {
                case .shot(let id):
                    ShotDetailView(shotID: id)
                        .modifier(HideNavBar())
                case .bean(let id):
                    BeanDetailView(beanID: id)
                        .modifier(HideNavBar())
                case .hardware(let id):
                    HardwareDetailView(hardwareID: id)
                        .modifier(HideNavBar())
                }
            }
            .modifier(HideNavBar())
        }
        .environment(\.psPalette, palette)
        .environment(\.psTempUnit, settings.temperatureUnit)
        .sheet(isPresented: $showAbout) {
            AboutSheet(settings: settings)
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, settings.temperatureUnit)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(palette.surface)
        }
        .sheet(isPresented: $showAddBean) {
            BeanAddForm(settings: settings, onCancel: { showAddBean = false }, onSaved: { showAddBean = false })
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, settings.temperatureUnit)
                .presentationBackground(palette.page)
        }
        .sheet(item: $addHardwareKind) { kind in
            HardwareAddForm(kind: kind, onCancel: { addHardwareKind = nil }, onSaved: { addHardwareKind = nil })
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, settings.temperatureUnit)
                .presentationBackground(palette.page)
        }
    }
}

/// Destinations pushable on the shared `NavigationStack`. Each case carries the
/// `PersistentIdentifier` of the SwiftData model the detail view will load.
enum NavRoute: Hashable {
    case shot(PersistentIdentifier)
    case bean(PersistentIdentifier)
    case hardware(PersistentIdentifier)
}

/// Cross-platform shim: hides the system navigation bar on iOS so detail views
/// can render their own `PSNavBar`, and is a no-op on macOS where the modifier
/// does not exist. The interactive swipe-back gesture is preserved by
/// `Utilities/SwipeBackFix.swift`.
struct HideNavBar: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar(.hidden, for: .navigationBar)
        #else
        content
        #endif
    }
}
