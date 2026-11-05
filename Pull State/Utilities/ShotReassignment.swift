// ShotReassignment.swift
//
// Moving shots between beans and hardware after they were logged. Shots can
// be saved with no machine or grinder and with a quick-added "Unknown" bean,
// so three flows fix them up later: editing one shot (ShotDetailView), bulk
// editing a selection (History → Select), and back-filling a newly added
// machine or grinder onto every shot that has none (HardwareAddForm). All
// three write through here so the "Unknown" clean-up happens the same way.
// Deleting a bean (BeanDetailView) also goes through here: its shots are
// filed under "Unknown" instead of being deleted.
import Foundation
import SwiftData

/// A bulk-edit choice for one hardware slot: leave each shot as it is, clear
/// the slot, or set it to one item.
enum SourceChoice<Model: PersistentModel>: Equatable {
    case keep
    case clear
    case set(Model)
}

enum ShotReassignment {
    /// Applies a bulk edit. `bean` nil keeps every shot's bean (a shot always
    /// has one, so there is no "clear"). Saves, then deletes any placeholder
    /// bean the move left without shots.
    static func apply(
        bean: Bean?,
        machine: SourceChoice<Equipment>,
        grinder: SourceChoice<Equipment>,
        to shots: [Shot],
        in context: ModelContext
    ) {
        var previousBeans: [Bean] = []
        for shot in shots {
            if let bean, shot.bean?.persistentModelID != bean.persistentModelID {
                if let old = shot.bean { previousBeans.append(old) }
                shot.bean = bean
            }
            switch machine {
            case .keep: break
            case .clear: shot.machine = nil
            case .set(let item): shot.machine = item
            }
            switch grinder {
            case .keep: break
            case .clear: shot.grinder = nil
            case .set(let item): shot.grinder = item
            }
        }
        try? context.save()
        removeEmptyPlaceholders(previousBeans, in: context)
    }

    /// Deletes each placeholder ("Unknown") bean in `beans` that no longer
    /// has any shots. Call after the move has been saved.
    static func removeEmptyPlaceholders(_ beans: [Bean], in context: ModelContext) {
        var seen = Set<PersistentIdentifier>()
        var removed = false
        for bean in beans where seen.insert(bean.persistentModelID).inserted {
            if bean.isPlaceholder && bean.shots.isEmpty {
                context.delete(bean)
                removed = true
            }
        }
        if removed { try? context.save() }
    }

    /// Deletes `bean` and keeps its shots: they move to the "Unknown"
    /// placeholder (the existing one, or a new one with the next bag
    /// number), where Shot edit or History's bulk edit can re-file them.
    /// Deleting the placeholder itself also deletes its shots, since there
    /// is nowhere left to file them. The Bean page's confirmation says which.
    static func deleteBean(_ bean: Bean, in context: ModelContext, settings: AppSettings?) {
        let shots = bean.shots
        if bean.isPlaceholder {
            for shot in shots { context.delete(shot) }
        } else if !shots.isEmpty {
            let unknown = unknownBean(in: context) ?? insertUnknownBean(in: context, settings: settings)
            for shot in shots { shot.bean = unknown }
        }
        context.delete(bean)
        try? context.save()
    }

    /// The placeholder ("Unknown") bean with the lowest bag number, if any.
    static func unknownBean(in context: ModelContext) -> Bean? {
        let beans = (try? context.fetch(FetchDescriptor<Bean>())) ?? []
        return beans.filter(\.isPlaceholder).min { $0.bagNumber < $1.bagNumber }
    }

    /// A new "Unknown" placeholder with the next bag number.
    private static func insertUnknownBean(in context: ModelContext, settings: AppSettings?) -> Bean {
        let bagNumber = settings?.nextBagNumber ?? 1
        let unknown = Bean.quickAdd(name: "", bagNumber: bagNumber)
        context.insert(unknown)
        settings?.nextBagNumber = bagNumber + 1
        return unknown
    }

    /// Shots with no item of `kind` attached: logged before any machine or
    /// grinder existed, or whose hardware was deleted.
    static func shotsMissing(_ kind: EquipmentKind, in context: ModelContext) -> [Shot] {
        let all = (try? context.fetch(FetchDescriptor<Shot>())) ?? []
        return all.filter { kind == .machine ? $0.machine == nil : $0.grinder == nil }
    }

    /// Attaches `item` to every shot that has no machine (or grinder) yet.
    /// Shots that already have one are left alone.
    static func backfill(_ item: Equipment, in context: ModelContext) {
        for shot in shotsMissing(item.kind, in: context) {
            if item.kind == .machine { shot.machine = item } else { shot.grinder = item }
        }
        try? context.save()
    }
}
