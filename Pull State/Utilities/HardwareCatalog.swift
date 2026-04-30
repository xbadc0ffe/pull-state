// HardwareCatalog.swift
//
// Curated suggestion list for the espresso-machine and grinder pickers.
// Coverage is intentionally narrow — manual / lever espresso machines and
// the popular hand-grinder + electric-grinder ranges that the app's audience
// actually uses. The combobox accepts any custom name not in this list, so
// the catalog is suggestions only, never a closed set.
//
// When a suggestion is tapped, `brand(forName:kind:)` looks up the matching
// brand so the Brand field auto-fills. The Brand field stays user-editable
// after auto-fill.
import Foundation

/// One row in `HardwareCatalog` — a model name and its brand.
struct HardwareEntry: Hashable, Identifiable {
    let name: String
    let brand: String
    var id: String { "\(brand)::\(name)" }
}

/// Static, in-memory autocomplete source for espresso machines and grinders.
enum HardwareCatalog {
    static let machines: [HardwareEntry] = [
        HardwareEntry(name: "Flair Pro 3 Updated", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair Pro 3", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair Pro 2", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair 58", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair 58x", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair Classic", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair Neo", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair Neo Flex", brand: "Flair Espresso"),
        HardwareEntry(name: "Flair Signature", brand: "Flair Espresso"),
        HardwareEntry(name: "Cafelat Robot", brand: "Cafelat"),
        HardwareEntry(name: "Cafelat Robot Barista", brand: "Cafelat"),
        HardwareEntry(name: "Rok EspressoGC", brand: "ROK Coffee"),
        HardwareEntry(name: "Rok GC", brand: "ROK Coffee"),
        HardwareEntry(name: "Nomad", brand: "Wacaco"),
        HardwareEntry(name: "Picopresso", brand: "Wacaco"),
        HardwareEntry(name: "Minipresso GR", brand: "Wacaco"),
        HardwareEntry(name: "Minipresso NS", brand: "Wacaco"),
        HardwareEntry(name: "Nanopresso", brand: "Wacaco"),
        HardwareEntry(name: "Barista", brand: "Wacaco"),
        HardwareEntry(name: "La Pavoni Europiccola", brand: "La Pavoni"),
        HardwareEntry(name: "La Pavoni Professional", brand: "La Pavoni"),
        HardwareEntry(name: "La Pavoni Cellini", brand: "La Pavoni"),
        HardwareEntry(name: "Elektra Micro Casa a Leva", brand: "Elektra"),
        HardwareEntry(name: "Cremina SL", brand: "Olympia Express"),
        HardwareEntry(name: "Ponte Vecchio Lusso", brand: "Ponte Vecchio"),
        HardwareEntry(name: "Portaspresso Rossa", brand: "Portaspresso"),
        HardwareEntry(name: "Gaggiuino (DIY)", brand: "Gaggiuino"),
    ]

    static let grinders: [HardwareEntry] = [
        HardwareEntry(name: "J-Ultra", brand: "1Zpresso"),
        HardwareEntry(name: "J-Max S", brand: "1Zpresso"),
        HardwareEntry(name: "J-Max", brand: "1Zpresso"),
        HardwareEntry(name: "J-Pro S", brand: "1Zpresso"),
        HardwareEntry(name: "J-Pro", brand: "1Zpresso"),
        HardwareEntry(name: "ZP6 Special Edition", brand: "1Zpresso"),
        HardwareEntry(name: "ZP6 S", brand: "1Zpresso"),
        HardwareEntry(name: "K-Ultra", brand: "1Zpresso"),
        HardwareEntry(name: "K-Max", brand: "1Zpresso"),
        HardwareEntry(name: "K-Pro", brand: "1Zpresso"),
        HardwareEntry(name: "Q2 S", brand: "1Zpresso"),
        HardwareEntry(name: "E-Pro", brand: "1Zpresso"),
        HardwareEntry(name: "Commandante C40 MK4", brand: "Commandante"),
        HardwareEntry(name: "Commandante C40 MK3", brand: "Commandante"),
        HardwareEntry(name: "Commandante C60", brand: "Commandante"),
        HardwareEntry(name: "Timemore Chestnut X Plus", brand: "Timemore"),
        HardwareEntry(name: "Timemore Chestnut X", brand: "Timemore"),
        HardwareEntry(name: "Timemore Chestnut X Lite", brand: "Timemore"),
        HardwareEntry(name: "Timemore Chestnut S3", brand: "Timemore"),
        HardwareEntry(name: "Timemore Chestnut C3 Pro", brand: "Timemore"),
        HardwareEntry(name: "Timemore Chestnut C3", brand: "Timemore"),
        HardwareEntry(name: "Timemore Chestnut C2", brand: "Timemore"),
        HardwareEntry(name: "Timemore Slim 3", brand: "Timemore"),
        HardwareEntry(name: "Timemore Slim Plus", brand: "Timemore"),
        HardwareEntry(name: "Kinu M47 Phoenix", brand: "Kinu"),
        HardwareEntry(name: "Kinu M47 Forte", brand: "Kinu"),
        HardwareEntry(name: "Kinu M47 Classic", brand: "Kinu"),
        HardwareEntry(name: "Kinu M47 Simplicity", brand: "Kinu"),
        HardwareEntry(name: "Lido 3", brand: "Orphan Espresso"),
        HardwareEntry(name: "Lido ET", brand: "Orphan Espresso"),
        HardwareEntry(name: "Lido 2", brand: "Orphan Espresso"),
        HardwareEntry(name: "Aergrind", brand: "Knock"),
        HardwareEntry(name: "Feldgrind 2", brand: "Knock"),
        HardwareEntry(name: "Feldgrind", brand: "Knock"),
        HardwareEntry(name: "Feld 2", brand: "Knock"),
        HardwareEntry(name: "Key", brand: "Weber Workshops"),
        HardwareEntry(name: "Ara", brand: "Weber Workshops"),
        HardwareEntry(name: "EG-1", brand: "Weber Workshops"),
        HardwareEntry(name: "HG-2", brand: "Weber Workshops"),
        HardwareEntry(name: "Lagom P100", brand: "Option-O"),
        HardwareEntry(name: "Lagom P64", brand: "Option-O"),
        HardwareEntry(name: "Lagom Mini", brand: "Option-O"),
        HardwareEntry(name: "Ode Brew Grinder Gen 2", brand: "Fellow"),
        HardwareEntry(name: "Opus", brand: "Fellow"),
        HardwareEntry(name: "Niche Zero", brand: "Niche Coffee"),
        HardwareEntry(name: "Niche Duo", brand: "Niche Coffee"),
        HardwareEntry(name: "DF64 Gen 2", brand: "DF Grinders"),
        HardwareEntry(name: "DF64E", brand: "DF Grinders"),
        HardwareEntry(name: "DF54", brand: "DF Grinders"),
        HardwareEntry(name: "Sette 270Wi", brand: "Baratza"),
        HardwareEntry(name: "Sette 270", brand: "Baratza"),
        HardwareEntry(name: "Forte BG", brand: "Baratza"),
        HardwareEntry(name: "Vario+", brand: "Baratza"),
        HardwareEntry(name: "Mazzer Mini Electronic", brand: "Mazzer"),
        HardwareEntry(name: "Mazzer Mini", brand: "Mazzer"),
        HardwareEntry(name: "Mazzer Super Jolly", brand: "Mazzer"),
        HardwareEntry(name: "Eureka Mignon Specialita", brand: "Eureka"),
        HardwareEntry(name: "Eureka Mignon Perfetto", brand: "Eureka"),
        HardwareEntry(name: "Eureka Mignon Filtro", brand: "Eureka"),
        HardwareEntry(name: "Eureka Atom 65", brand: "Eureka"),
        HardwareEntry(name: "Eureka Oro Mignon XL", brand: "Eureka"),
        HardwareEntry(name: "Fiorenzato F4E Nano", brand: "Fiorenzato"),
        HardwareEntry(name: "Fiorenzato F64E", brand: "Fiorenzato"),
    ]

    static func entries(for kind: EquipmentKind) -> [HardwareEntry] {
        kind == .machine ? machines : grinders
    }

    static func brand(forName name: String, kind: EquipmentKind) -> String? {
        entries(for: kind).first(where: { $0.name == name })?.brand
    }
}
