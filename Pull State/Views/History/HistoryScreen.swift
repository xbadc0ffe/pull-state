import SwiftUI
import SwiftData

/// History tab — scrollable list of shots with three header stat cards, a
/// filter sheet (extraction, tasting tags AND-matched, min rating, bean,
/// machine, grinder), and a sort sheet. Empty state renders when no shots
/// exist; "no shots match" renders when filters exclude everything.
///
/// "Select" in the nav bar switches to Select mode: tapping a card ticks it
/// instead of opening it, and "Edit N shots" opens `ShotBulkEditSheet` to
/// change the bean / machine / grinder of every ticked shot that is still
/// visible under the current filters.
struct HistoryScreen: View {
    let onShowAbout: () -> Void

    @Environment(\.psPalette) private var palette
    @Environment(\.psTempUnit) private var tempUnit
    @Environment(\.modelContext) private var context

    @Query(sort: \Shot.date, order: .reverse) private var shots: [Shot]
    @Query(sort: \Bean.createdAt) private var beans: [Bean]
    @Query(sort: \Equipment.createdAt) private var equipment: [Equipment]

    @State private var sortBy: SortOrder = .newest
    @State private var filterEx: Extraction? = nil
    @State private var filterRating: Int = 0
    @State private var filterBeanID: PersistentIdentifier? = nil
    @State private var filterMachineID: PersistentIdentifier? = nil
    @State private var filterGrinderID: PersistentIdentifier? = nil
    @State private var filterTags: Set<TastingTag> = []
    @State private var filterPaper: Bool? = nil
    @State private var showFilter = false
    @State private var showSort = false
    @State private var selecting = false
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var showBulkEdit = false

    private var totalShots: Int { shots.count }

    /// Ticked shots still visible under the current filters — what the bulk
    /// edit applies to.
    private var selectedShots: [Shot] {
        filtered.filter { selection.contains($0.persistentModelID) }
    }

    private var allVisibleSelected: Bool {
        !filtered.isEmpty && selectedShots.count == filtered.count
    }
    private var totalGrams: Double { shots.reduce(0) { $0 + $1.yield } }
    /// Average over rated shots only; unrated (0) shots are not "zero stars".
    private var avgRating: String {
        let rated = shots.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return "—" }
        return String(format: "%.1f", Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count))
    }

    private var filtered: [Shot] {
        var xs = shots
        if let ex = filterEx { xs = xs.filter { $0.extraction == ex } }
        if filterRating > 0 { xs = xs.filter { $0.rating >= filterRating } }
        if let bid = filterBeanID { xs = xs.filter { $0.bean?.persistentModelID == bid } }
        if let mid = filterMachineID { xs = xs.filter { $0.machine?.persistentModelID == mid } }
        if let gid = filterGrinderID { xs = xs.filter { $0.grinder?.persistentModelID == gid } }
        if !filterTags.isEmpty {
            xs = xs.filter { shot in
                let shotTags = Set(shot.tags)
                return filterTags.isSubset(of: shotTags)
            }
        }
        if let want = filterPaper { xs = xs.filter { $0.usedPaperFilter == want } }
        switch sortBy {
        case .newest:  xs.sort { $0.date > $1.date }
        case .oldest:  xs.sort { $0.date < $1.date }
        case .highest: xs.sort { $0.rating > $1.rating }
        case .lowest:  xs.sort { $0.rating < $1.rating }
        }
        return xs
    }

    private var filterCount: Int {
        var n = 0
        if filterEx != nil { n += 1 }
        if filterRating > 0 { n += 1 }
        if filterBeanID != nil { n += 1 }
        if filterMachineID != nil { n += 1 }
        if filterGrinderID != nil { n += 1 }
        if filterPaper != nil { n += 1 }
        n += filterTags.count
        return n
    }

    private var machines: [Equipment] { equipment.filter { $0.kind == .machine } }
    private var grinders: [Equipment] { equipment.filter { $0.kind == .grinder } }

    var body: some View {
        VStack(spacing: 0) {
            PSNavBar(
                title: "History",
                subtitle: shots.isEmpty ? nil : "\(totalShots) SHOTS LOGGED",
                large: true
            ) {
                EmptyView()
            } trailing: {
                HStack(spacing: 10) {
                    if !shots.isEmpty {
                        Button(selecting ? "Done" : "Select") {
                            if selecting { endSelecting() } else { selecting = true }
                        }
                        .font(PSFont.body(14, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .buttonStyle(.plain)
                    }
                    PSIconBtn(systemName: "ellipsis", label: "More", action: onShowAbout)
                }
            }
            .psContentColumn()

            if shots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            StatCard(label: "SHOTS", value: "\(totalShots)")
                            StatCard(label: "GRAMS", value: String(format: "%.0f", totalGrams), suffix: "g")
                            StatCard(label: "AVG ★", value: avgRating, accent: true)
                        }
                        .padding(.bottom, 14)

                        HStack(spacing: 8) {
                            if selecting {
                                IconChip(systemName: allVisibleSelected ? "circle" : "checkmark.circle",
                                         label: allVisibleSelected ? "Select None" : "Select All",
                                         action: toggleSelectAll)
                            }
                            IconChip(systemName: "line.3.horizontal.decrease",
                                     label: "Filter",
                                     badge: filterCount > 0 ? filterCount : nil,
                                     action: { showFilter = true })
                            if !selecting {
                                IconChip(systemName: "arrow.up.arrow.down",
                                         label: sortBy.label,
                                         action: { showSort = true })
                            }
                            Spacer()
                            Text(selecting ? "\(selectedShots.count) selected" : "\(filtered.count) / \(totalShots)")
                                .font(PSFont.mono(10))
                                .tracking(0.6)
                                .foregroundStyle(palette.inkMuted)
                        }
                        .padding(.bottom, 14)

                        if filtered.isEmpty {
                            Text("No shots match your filters.")
                                .font(PSFont.body(13))
                                .foregroundStyle(palette.inkSoft)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(filtered) { shot in
                                    if selecting {
                                        let isSelected = selection.contains(shot.persistentModelID)
                                        Button { toggle(shot) } label: {
                                            ShotCard(shot: shot, selected: isSelected)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                                    } else {
                                        NavigationLink(value: NavRoute.shot(shot.persistentModelID)) {
                                            ShotCard(shot: shot)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .psContentColumn()
                }
                .scrollIndicators(.hidden)

                if selecting {
                    bulkEditBar
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: shots.isEmpty) { _, empty in
            if empty { endSelecting() }
        }
        // Drop filters that point at a bean or hardware item that no longer
        // exists (deleted, wiped, or an "Unknown" placeholder tidied away);
        // otherwise the list would silently stay empty.
        .onChange(of: beans.map(\.persistentModelID)) { _, ids in
            if let id = filterBeanID, !ids.contains(id) { filterBeanID = nil }
        }
        .onChange(of: equipment.map(\.persistentModelID)) { _, ids in
            if let id = filterMachineID, !ids.contains(id) { filterMachineID = nil }
            if let id = filterGrinderID, !ids.contains(id) { filterGrinderID = nil }
        }
        .sheet(isPresented: $showBulkEdit) {
            ShotBulkEditSheet(
                shots: selectedShots,
                onClose: { showBulkEdit = false },
                onApplied: {
                    showBulkEdit = false
                    endSelecting()
                }
            )
            .environment(\.psPalette, palette)
            .environment(\.psTempUnit, tempUnit)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(palette.surface)
        }
        .sheet(isPresented: $showFilter) {
            FilterSheet(
                filterEx: $filterEx,
                filterRating: $filterRating,
                filterBeanID: $filterBeanID,
                filterMachineID: $filterMachineID,
                filterGrinderID: $filterGrinderID,
                filterTags: $filterTags,
                filterPaper: $filterPaper,
                beans: beans,
                machines: machines,
                grinders: grinders,
                onClose: { showFilter = false }
            )
            .environment(\.psPalette, palette)
            .environment(\.psTempUnit, tempUnit)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(palette.surface)
        }
        .sheet(isPresented: $showSort) {
            SortSheet(sortBy: $sortBy, onClose: { showSort = false })
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, tempUnit)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(palette.surface)
        }
    }

    /// Bottom bar in Select mode; disabled until at least one visible shot
    /// is ticked.
    private var bulkEditBar: some View {
        let count = selectedShots.count
        return Button { showBulkEdit = true } label: {
            Text(count == 0 ? "Tap shots to select them" : "Edit \(count) shot\(count == 1 ? "" : "s")")
                .font(PSFont.body(15, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(count == 0 ? palette.inkMuted : palette.accent,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .psShadow(strong: count > 0)
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .psContentColumn()
    }

    private func toggle(_ shot: Shot) {
        let id = shot.persistentModelID
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func toggleSelectAll() {
        let visible = Set(filtered.map(\.persistentModelID))
        if allVisibleSelected {
            selection.subtract(visible)
        } else {
            selection.formUnion(visible)
        }
    }

    private func endSelecting() {
        selecting = false
        selection = []
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Circle()
                .fill(palette.surface)
                .frame(width: 72, height: 72)
                .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                .overlay(
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.inkMuted)
                )
            PSDisplay("No shots logged yet", size: 22)
            Text("Pull your first shot from the Log tab. It'll show up here with a star next to it.")
                .font(PSFont.body(13))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(maxWidth: 280)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
