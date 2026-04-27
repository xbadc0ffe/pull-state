import SwiftUI
import SwiftData

struct HistoryScreen: View {
    let onShowAbout: () -> Void

    @Environment(\.psPalette) private var palette
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
    @State private var showFilter = false
    @State private var showSort = false

    private var totalShots: Int { shots.count }
    private var totalGrams: Double { shots.reduce(0) { $0 + $1.yield } }
    private var avgRating: String {
        guard !shots.isEmpty else { return "—" }
        return String(format: "%.1f", Double(shots.reduce(0) { $0 + $1.rating }) / Double(shots.count))
    }

    private var filtered: [Shot] {
        var xs = shots
        if let ex = filterEx { xs = xs.filter { $0.extraction == ex } }
        if filterRating > 0 { xs = xs.filter { $0.rating >= filterRating } }
        if let bid = filterBeanID { xs = xs.filter { $0.bean?.persistentModelID == bid } }
        if let mid = filterMachineID { xs = xs.filter { $0.machine?.persistentModelID == mid } }
        if let gid = filterGrinderID { xs = xs.filter { $0.grinder?.persistentModelID == gid } }
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
                PSIconBtn(systemName: "ellipsis", action: onShowAbout)
            }

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
                            IconChip(systemName: "line.3.horizontal.decrease",
                                     label: "Filter",
                                     badge: filterCount > 0 ? filterCount : nil,
                                     action: { showFilter = true })
                            IconChip(systemName: "arrow.up.arrow.down",
                                     label: sortBy.label,
                                     action: { showSort = true })
                            Spacer()
                            Text("\(filtered.count) / \(totalShots)")
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
                                    NavigationLink(value: NavRoute.shot(shot.persistentModelID)) {
                                        ShotCard(shot: shot)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFilter) {
            FilterSheet(
                filterEx: $filterEx,
                filterRating: $filterRating,
                filterBeanID: $filterBeanID,
                filterMachineID: $filterMachineID,
                filterGrinderID: $filterGrinderID,
                beans: beans,
                machines: machines,
                grinders: grinders,
                onClose: { showFilter = false }
            )
            .environment(\.psPalette, palette)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(palette.surface)
        }
        .sheet(isPresented: $showSort) {
            SortSheet(sortBy: $sortBy, onClose: { showSort = false })
                .environment(\.psPalette, palette)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(palette.surface)
        }
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
