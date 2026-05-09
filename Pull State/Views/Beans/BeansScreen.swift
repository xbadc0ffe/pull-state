import SwiftUI
import SwiftData

/// Beans tab — list of bag rows sorted newest-bag-first. Empty state appears
/// when the library is empty. Tapping a row pushes `BeanDetailView`; the +
/// button presents `BeanAddForm`.
struct BeansScreen: View {
    let onAdd: () -> Void
    let onShowAbout: () -> Void

    @Environment(\.psPalette) private var palette
    @Query(sort: \Bean.bagNumber, order: .reverse) private var beans: [Bean]

    var body: some View {
        VStack(spacing: 0) {
            PSNavBar(title: "Beans",
                     subtitle: beans.isEmpty ? nil : "\(beans.count) BAGS LOGGED",
                     large: true) {
                EmptyView()
            } trailing: {
                HStack(spacing: 6) {
                    PSIconBtn(systemName: "plus", action: onAdd)
                    PSIconBtn(systemName: "ellipsis", action: onShowAbout)
                }
            }
            .psContentColumn()

            if beans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(beans) { bean in
                            NavigationLink(value: NavRoute.bean(bean.persistentModelID)) {
                                BeanRowCard(bean: bean)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .psContentColumn()
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Circle()
                .fill(palette.surface)
                .frame(width: 72, height: 72)
                .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                .overlay(
                    Image(systemName: "leaf")
                        .font(.system(size: 28))
                        .foregroundStyle(palette.inkMuted)
                )
            PSDisplay("No beans yet", size: 22)
            Text("Tap + to log your first bag.")
                .font(PSFont.body(13))
                .foregroundStyle(palette.inkSoft)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct BeanRowCard: View {
    let bean: Bean
    @Environment(\.psPalette) private var palette

    var body: some View {
        PSCard(soft: true) {
            HStack(spacing: 12) {
                PSPhotoThumb(data: bean.photoData, label: "BEAN", radius: 10)
                    .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(bean.name)
                            .font(PSFont.display(17, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        Text("#\(bean.bagNumber)")
                            .font(PSFont.mono(10))
                            .foregroundStyle(palette.inkMuted)
                    }
                    Text(bean.roaster)
                        .font(PSFont.body(12))
                        .foregroundStyle(palette.inkSoft)
                        .padding(.bottom, 4)
                    HStack(spacing: 6) {
                        PSRoastBadge(level: bean.roast)
                        Text(bean.processDisplay.uppercased())
                            .font(PSFont.mono(9.5))
                            .tracking(0.6)
                            .foregroundStyle(palette.inkMuted)
                        if bean.singleOrigin {
                            Text("· SINGLE ORIGIN")
                                .font(PSFont.mono(9.5))
                                .tracking(0.6)
                                .foregroundStyle(palette.accentDeep)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(12)
        }
    }
}
