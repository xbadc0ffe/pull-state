import SwiftUI
import SwiftData

/// App shell. Owns the single `NavigationStack`, the four-tab switcher, and
/// every modal sheet (About, Add Bean, Add Hardware). Pushes `\.psPalette`
/// and `\.psTempUnit` into the environment for the whole tree, including
/// every sheet (sheets do not inherit environment automatically).
///
/// All four tab screens stay mounted for the life of the shell and are shown
/// or hidden with opacity. A `switch` would destroy the inactive screen and
/// with it every `@State` it owns — on the Log tab that means a running timer
/// and a half-written shot. Keeping them alive costs four live `@Query`s,
/// which is negligible at this app's data size.
struct MainTabView: View {
    @Bindable var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var selected: PSTab = .log
    @State private var navPath = NavigationPath()
    @State private var showAbout: Bool = false
    @State private var showAddBean: Bool = false
    @State private var addHardwareKind: EquipmentKind? = nil

    private var palette: PSPalette { PSPalette.resolve(for: scheme, typeSize: typeSize) }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                PSPageBackground()

                VStack(spacing: 0) {
                    ZStack {
                        pane(.log) {
                            LogScreen(onShowAbout: { showAbout = true })
                        }
                        pane(.history) {
                            HistoryScreen(onShowAbout: { showAbout = true })
                        }
                        pane(.beans) {
                            BeansScreen(
                                onAdd: { showAddBean = true },
                                onShowAbout: { showAbout = true }
                            )
                        }
                        pane(.hardware) {
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
                Group {
                    switch route {
                    case .shot(let id):
                        ShotDetailView(shotID: id)
                    case .bean(let id):
                        BeanDetailView(beanID: id)
                    case .hardware(let id):
                        HardwareDetailView(hardwareID: id)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .toolbar(.hidden, for: .navigationBar)
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
            BeanAddForm(settings: settings, onCancel: { showAddBean = false }, onSaved: { _ in showAddBean = false })
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, settings.temperatureUnit)
                .presentationBackground(palette.page)
        }
        .sheet(item: $addHardwareKind) { kind in
            HardwareAddForm(kind: kind, onCancel: { addHardwareKind = nil }, onSaved: { _ in addHardwareKind = nil })
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, settings.temperatureUnit)
                .presentationBackground(palette.page)
        }
    }

    /// One always-mounted tab surface. Inactive panes are invisible, ignore
    /// touches, and are hidden from VoiceOver so only the selected tab reads.
    @ViewBuilder
    private func pane<Content: View>(_ tab: PSTab, @ViewBuilder content: () -> Content) -> some View {
        let active = selected == tab
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
            .zIndex(active ? 1 : 0)
    }
}

/// Destinations pushable on the shared `NavigationStack`. Each case carries the
/// `PersistentIdentifier` of the SwiftData model the detail view will load.
enum NavRoute: Hashable {
    case shot(PersistentIdentifier)
    case bean(PersistentIdentifier)
    case hardware(PersistentIdentifier)
}
