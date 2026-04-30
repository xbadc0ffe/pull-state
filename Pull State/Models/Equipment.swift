import Foundation
import SwiftData

/// A piece of espresso gear — either a machine or a grinder, distinguished by
/// `kind`. One model serves both because their per-shot relationship to `Shot`
/// has the same shape; only one of `machineShots` / `grinderShots` is populated
/// for any given instance. Delete rule is `.nullify` so historical shots
/// survive a deletion with their `machine` / `grinder` reference cleared.
@Model
final class Equipment {
    var name: String
    var brand: String
    var kindRaw: String
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?

    @Relationship(deleteRule: .nullify, inverse: \Shot.machine)
    var machineShots: [Shot] = []

    @Relationship(deleteRule: .nullify, inverse: \Shot.grinder)
    var grinderShots: [Shot] = []

    init(
        name: String,
        brand: String,
        kind: EquipmentKind,
        photoData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.brand = brand
        self.kindRaw = kind.rawValue
        self.photoData = photoData
        self.createdAt = createdAt
    }

    var kind: EquipmentKind {
        get { EquipmentKind(rawValue: kindRaw) ?? .machine }
        set { kindRaw = newValue.rawValue }
    }

    var shotCount: Int {
        kind == .machine ? machineShots.count : grinderShots.count
    }
}
