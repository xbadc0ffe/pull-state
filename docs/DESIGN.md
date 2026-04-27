# Pull State — Design Document

A precision logbook for espresso practice. Free, open source (MIT), distributed on the App Store under the handle **badc0ffe**. iPhone + iPad, SwiftUI + SwiftData, no third-party dependencies.

This document reflects the implementation as committed. When code and doc disagree, the code is the source of truth.

---

## 1. App Overview

Pull State is built around a single user (no accounts, no sync in v1) tracking espresso shots against a personal library of beans and hardware. The app launches into a four-tab structure with a custom warm-toned design system. All data lives in a local SwiftData store. The app starts empty: an onboarding flow gathers the user's first machine, grinder, and bean, after which the Log tab becomes usable.

**Primary loop:** dial in a bean → log a shot → review the result → adjust the bean's saved recipe → repeat.

---

## 2. Tab Structure & Navigation

### Tabs (in order)

1. **LOG** — launch tab. Where shots are timed and saved.
2. **HISTORY** — chronological list of all shots, with filter and sort.
3. **BEANS** — bag library, including per-bag recipes and rating-trend charts.
4. **HARDWARE** — machines and grinders, with shot counts.

The tab bar is a custom rounded chrome at the bottom of the screen (`PSTabBar`), not the system `TabView`. Active tab gets an inset card background and the accent-colored icon. The Beans tab uses a custom `BeanIcon` shape (Canvas-drawn rotated oval + curved seam) since SF Symbols has no coffee-bean glyph.

### Navigation model

A single `NavigationStack` lives in `MainTabView`. Tab switches are state-driven, not pushed. Detail views are pushed onto the stack via a `NavRoute` enum:

```
enum NavRoute: Hashable {
    case shot(PersistentIdentifier)
    case bean(PersistentIdentifier)
    case hardware(PersistentIdentifier)
}
```

Detail views render their own `PSNavBar` with a chevron back button. The system navigation bar is hidden via `.toolbar(.hidden, for: .navigationBar)` (gated for iOS via `HideNavBar`/`HideBackButton` modifiers so the build still compiles for macOS). Critically, the system back button is **not** hidden via `.navigationBarBackButtonHidden(true)` — that modifier silently disables the interactive swipe-from-left pop gesture. Hiding only the toolbar preserves swipe-back.

### iPad layout

The single-column iPhone design is preserved on iPad by capping content to **560pt** centered, via `PSContentColumn`. The page background fills the whole screen, but cards, navigation bars, and the tab bar live inside the constrained column. This avoids stretched-thin rows while keeping the warm-wash gradient edge-to-edge.

### Sheets and modals

- **About sheet** — large detent, custom × close in top-right
- **Add bean** / **Add hardware** — full-screen sheets (page background)
- **Filter** / **Sort** — large/medium detents over palette.surface
- **Onboarding** — full-screen overlay rendered in place of `MainTabView` until `AppSettings.hasCompletedOnboarding` flips

---

## 3. Screens

### 3.1 Log a shot

Section order, top to bottom:

1. **Source** — three picker rows in one card: Machine, Grinder, Beans. Each row expands inline when tapped to show options. If any list is empty, a single placeholder card directs the user to set up their gear first; the Save button stays disabled.
2. **Timer** — `DualTrackTimer`. See §6.
3. **Settings** — sliders for `Dose / Weight In`, `Yield / Weight Out`, `Water Temp`, `Pressure`. **Pre-loaded from the selected bean's `Recipe` (`dose`, `yield`, `temp`, `pullPressure`)** when the bean changes. A small caption under the card reads "Loaded from {bean name} recipe." The grind setting itself is no longer entered on Log — it's pulled from the bean's recipe at save time, so dialing in a bean centralizes its grind in one place.
4. **Extraction** — three pills (Sour / Perfect / Bitter), tone-colored. Tappable to toggle on/off (single-select).
5. **Tasting notes** — a flow-laid grid of all eight `TastingTag` values. Multi-select.
6. **Rating** — five stars (`PSStars`), bound to an Int 0–5.
7. **Photo + Date card** — photo via `PhotosPicker` (real picker, with thumbnail + Change/Add/× actions). Date defaults to `.now` and is editable via a compact `DatePicker`.
8. **Notes** — multi-line `TextEditor` over the card background, with placeholder.
9. **Save shot button** — disabled unless bean + machine + grinder are all selected. Briefly flashes "SAVED ✓" after success and resets the form (timer, rating, extraction, tags, notes, photo, date back to `.now`).

### 3.2 History

**Empty state:** circular icon + "No shots logged yet" headline + subtitle pointing to the Log tab.

**Populated:**
- Large title with subtitle "N SHOTS LOGGED"
- Three stat cards: SHOTS / GRAMS (sum of yield) / AVG ★ (the AVG card uses accent color)
- Filter chip (with badge showing active filter count) + Sort chip + filtered/total ratio
- Vertical list of `ShotCard` rows, each tappable to push `ShotDetailView`

**Filter sheet** — extraction tone pills, min-rating pills (Any / 2+ / 3+ / 4+ / 5+), and three select rows (any beans / any machine / any grinder, populated from the actual library). Clear-all button on the left, Apply on the right.

**Sort sheet** — four options: Newest first, Oldest first, Highest rated, Lowest rated. Selection is highlighted with accent ring and a checkmark.

**Shot detail (view mode):**
- Photo (or placeholder)
- Bean name + bag # + stars + extraction pill
- "Numbers" card: Pre-infusion, Pull time, Dose, Yield (with `1:X.YY` ratio suffix), Grind, Water, Pressure
- "Hardware" card: Machine, Grinder
- "Tasting notes" — pills (or "No tags")
- Notes (if non-empty)
- Detail timestamp footer

**Shot detail (edit mode):**
Same screen, but every field becomes editable: source pickers, extraction, tags, six sliders (dose, yield, temp, pressure, pre-infusion, pull), photo picker, date picker, notes editor. Cancel + Save in the nav bar trailing slot. A red **Delete shot** button at the bottom triggers a confirmation alert.

### 3.3 Beans

List of `BeanRowCard`s sorted by bag number descending. Each card shows: photo placeholder, name, bag #, roaster, roast badge, process tag, optional "SINGLE ORIGIN" label.

**Empty state:** circular leaf icon, "No beans yet", "Tap + to log your first bag."

**Bean detail (view mode):**
- Bag photo placeholder
- Name + "BAG #X" + roaster line
- Roast badge + process chip + optional Single Origin chip
- **Rating trend chart** — `RatingChart`, a Canvas-drawn sparkline of every shot for this bean ordered by date
- Dates card: Roast date, Purchase date
- Notes card (if any)
- **Recipe card** — inline-editable. Tap "Edit" to flip the recipe block into edit mode (Cancel / Save). The recipe object lives as JSON `Data` on the bean; see §4.
- Footer: shot count + average rating

**Bean detail (edit mode):**
Top-level Edit toggles all bean metadata (name, roaster, single-origin toggle, process pills, roast pills, dates, notes). The recipe has its own separate Edit flow (mid-page) so users can dial in a recipe without entering the full edit flow. Bottom: red **Delete bean** button. Confirmation: *"Delete {bean name}? All associated pulls will be deleted too. N shots will be removed."* Implemented via SwiftData `@Relationship(deleteRule: .cascade, inverse: \Shot.bean)`.

**Add bean form** — full-screen sheet over the page background. Bag number is auto-assigned (`AppSettings.nextBagNumber`) and shown in an accent banner. Sections: Identity, Single Origin toggle, Process pills (with optional "specify" field for Other), Roast Level pills, Dates (real `DatePicker`s), Photo placeholder card, Notes, Recipe block (editable). Save creates the bean and increments `nextBagNumber`. Cancel discards.

### 3.4 Hardware

Two stacked sections: **Espresso Machines** and **Grinders**. Each section header has a small accent "+ Add" button. Cards (`HardwareCard`) show photo placeholder, name, brand, and a "N SHOTS" pill (live count via the inverse relationship).

**Hardware detail** — pushed when a card is tapped:
- Photo placeholder (4:3)
- Name + brand
- Stats card: Shots pulled (live count), Date added (`createdAt`)
- Red **Delete machine/grinder** button. Confirmation note: *"Past shots logged on this machine/grinder will stay in your history but will no longer reference it."* Implemented via `@Relationship(deleteRule: .nullify, …)` — so shot data is preserved even after the hardware is deleted.

**Add hardware form** — full-screen sheet, kind-aware: same form for "Add Machine" and "Add Grinder". Fields: Name, Brand, photo placeholder card, explanatory footer.

### 3.5 About sheet

Presented from any tab via the `…` (ellipsis) icon in the top-right of the navigation bar. Large detent. Contents:

- × close button (top-right)
- App icon (custom Canvas-drawn cup with crema dot, on an accent-gradient rounded square)
- Title "Pull State"
- Version line "v 1.0.0 · APR 26 2026"
- Card with rows: **Built by** (badc0ffe), **Contact** (info@badc0ffe.net), **GitHub** (github.com/xbadc0ffe/pull-state), **Appearance** (System / Light / Dark switch)
- **Tip jar** — see §10
- Footer copy block on `surfaceAlt` background

### 3.6 Onboarding

Four steps, progress dots at the top:

1. **Welcome** — logo, title, "Three quick steps" card listing the three onboarding stages, plus an **Appearance** card with the same System/Light/Dark switch as About. Choosing here writes immediately to `AppSettings.appearance`.
2. **Hardware** — two sections (Espresso Machine / Grinder), each with a custom `OnbCombobox` populated with a list of common models for autocomplete suggestions, plus a Brand text field. The user can pick a suggestion or type a custom name.
3. **Bean** — Bean name, Roaster, Roast level pills, plus a "BAG #001" reminder card.
4. **Ready** — green-checked "You're dialed." summary card listing what was entered.

Footer: primary action button (BEGIN SETUP / CONTINUE / PULL YOUR FIRST SHOT) plus a `< Back` link and a "Skip setup" link.

On finish: any non-empty machine, grinder, and bean entered are inserted into SwiftData; `nextBagNumber` increments; `hasCompletedOnboarding` flips true. Skipping does the same — entries with empty names are skipped, the rest is saved.

---

## 4. SwiftData Data Model

Four `@Model` classes plus one Codable value type. All persistence is local; no CloudKit / no server in v1.

### 4.1 Bean

```
@Model
final class Bean {
    var name: String
    var bagNumber: Int
    var roaster: String
    var singleOrigin: Bool
    var processRaw: String           // BeanProcess.rawValue
    var processOther: String         // free-text when process == .other
    var roastRaw: String             // Roast.rawValue
    var roastDate: Date
    var purchaseDate: Date
    var notes: String
    var createdAt: Date
    private var recipeData: Data?    // JSON-encoded Recipe

    @Relationship(deleteRule: .cascade, inverse: \Shot.bean)
    var shots: [Shot] = []
}
```

Computed/exposed:
- `process: BeanProcess` and `roast: Roast` — get/set wrappers over the raw strings
- `processDisplay: String` — uses `processOther` when process is `.other`
- `recipe: Recipe` — JSON-decoded with backwards-compatible defaults; setter encodes
- `ratingTrend: [BeanRatingPoint]` — shots sorted by date, mapped to (date, rating) for the sparkline
- `averageRating: Double?` — nil when no shots

Delete rule: `.cascade` on `shots` — deleting a bean removes all its shots. This is what the Bean detail's delete confirmation describes to the user.

### 4.2 Shot

```
@Model
final class Shot {
    var date: Date
    var grindSetting: String         // copied from bean.recipe.grind at save time
    var dose: Double
    var yield: Double
    var waterTemp: Double
    var pressure: Double
    var preInfusion: Double          // seconds
    var pull: Double                 // seconds
    var extractionRaw: String?       // Extraction.rawValue
    var tagsRaw: [String]            // [TastingTag.rawValue]
    var rating: Int                  // 0...5
    var notes: String
    @Attribute(.externalStorage) var photoData: Data?

    var bean: Bean?
    var machine: Equipment?
    var grinder: Equipment?
}
```

Computed:
- `hasPhoto: Bool`, `extraction: Extraction?`, `tags: [TastingTag]`, `ratio: Double` (yield / dose)

`@Attribute(.externalStorage)` keeps photo blobs out of the main SQLite file, so the DB stays small even with many photos.

The references to Bean/Machine/Grinder are optional — a hardware item can be deleted without orphaning the shot's data.

### 4.3 Equipment

```
@Model
final class Equipment {
    var name: String
    var brand: String
    var kindRaw: String              // EquipmentKind.rawValue
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Shot.machine)
    var machineShots: [Shot] = []

    @Relationship(deleteRule: .nullify, inverse: \Shot.grinder)
    var grinderShots: [Shot] = []
}
```

A single `Equipment` model is used for both machines and grinders, distinguished by `kind`. Two relationships exist because a Shot has separate `machine` and `grinder` references; only one collection is populated for any given Equipment instance.

Computed:
- `kind: EquipmentKind`
- `shotCount: Int` — returns the right collection's count based on `kind`

Delete rule: `.nullify` for both — deleting hardware preserves the shots, just nulls the reference.

### 4.4 AppSettings

Singleton row holding app-wide preferences:

```
@Model
final class AppSettings {
    var appearanceRaw: String        // AppearanceMode.rawValue
    var hasCompletedOnboarding: Bool
    var hasTipped: Bool              // set after IAP success
    var nextBagNumber: Int           // monotonic, never decremented
    var seedDataInstalled: Bool      // currently always true after first install
}
```

`SeedData.installIfNeeded(context:)` runs in `RootView.task` and creates the `AppSettings` singleton if absent. The app starts empty — no demo beans, hardware, or shots. First bag added becomes `#1`.

### 4.5 Recipe (value type)

Stored as JSON `Data` on `Bean.recipeData`. Not a `@Model` — `Recipe` is a `nonisolated struct Codable, Equatable, Sendable` so it can cross actor boundaries without warnings.

```
struct Recipe {
    var grind: String
    var dose: Double             // default 18
    var yield: Double            // default 38
    var temp: Double             // default 93°C
    var preInfTime: Double       // default 7s
    var preInfPressure: Double   // default 3 bar
    var pullTime: Double         // default 28s
    var pullPressure: Double     // default 9 bar
}
```

`init(from: Decoder)` decodes each key with `decodeIfPresent` and falls back to the default — so beans saved before `dose` and `yield` were added migrate cleanly.

The Log screen reads `dose`, `yield`, `temp`, `pullPressure` to pre-populate its Settings sliders when a bean is selected. The bean's full recipe is shown and editable on the Bean detail.

### 4.6 Enums

| Enum            | Values                                                       | Where used                                |
| --------------- | ------------------------------------------------------------ | ----------------------------------------- |
| `Extraction`    | sour, perfect, bitter                                        | Shot.extraction; shows as colored pill    |
| `Roast`         | light, medium, dark                                          | Bean.roast; pip color in `PSRoastBadge`   |
| `BeanProcess`   | washed, natural, honey, wetHulled, other                     | Bean.process; "Other" reveals text input  |
| `EquipmentKind` | machine, grinder                                             | Equipment.kind                            |
| `TastingTag`    | acidic, bitter, sour, sweet, smoky, nutty, floral, perfect   | Shot.tags (multi-select)                  |
| `SortOrder`     | newest, oldest, highest, lowest                              | History sort                              |
| `AppearanceMode`| system, light, dark                                          | AppSettings.appearance                    |

---

## 5. UI / UX Decisions

### 5.1 Design system

Two color palettes (`PSPalette.light`, `PSPalette.dark`) with hand-picked warm-leather tokens — page, surface, surfaceAlt, card, line, lineStrong, ink, inkSoft, inkMuted, accent, accentDeep, accentSoft, good, bad, chrome, plus two placeholder stripe colors. The accent is the espresso-crema orange `#C8794A` (light) / `#D88B5A` (dark).

Active palette is delivered via SwiftUI environment (`\.psPalette`), resolved against the current color scheme. Every reusable component reads it from environment, so no view passes the palette down the tree.

### 5.2 Typography

- **Display** — `.system(.serif)` (Fraunces analogue) for titles
- **Body** — `.system(.default)` for general text
- **Mono** — `.system(.monospaced)` for numeric values, timestamps, and small caps labels

Sizes are explicit `CGFloat`s rather than `.title`/`.body` so the layout matches the visual prototype, but they are still rendered through `Font.system(size:)` which respects Dynamic Type at the user's preferred scale.

### 5.3 Reusable components

Defined in `Views/Components/` and used everywhere:

- `PSCard` — rounded card with palette stroke and shadow (strong or soft variant)
- `PSField` — label/value row with bottom divider; Spacer-based layout so labels survive long values
- `PSSectionLabel`, `PSDisplay`, `PSValueText`, `PSTextInput`
- `PSPill` — capsule button with neutral/sour/perfect/bitter tone palette
- `PSStars` — interactive or read-only star rating
- `PSPlaceholder` — diagonal-stripe Canvas (mirrors the prototype's placeholder)
- `PSNavBar` — top bar (small or large variant), with leading and trailing slots
- `PSTabBar` — custom rounded chrome bar; `BeanIcon` sub-shape for the Beans tab
- `PSIconBtn`, `PSTextBtn`, `PSToggle`, `PSRoastBadge`, `IconChip`, `StatCard`
- `FlowLayout` — custom `Layout` for tag clouds
- `PSPageBackground` — radial-gradient warm wash, full screen
- `PSContentColumn` — caps content to 560pt centered (iPad layout)

### 5.4 Decisions worth flagging

- **No Form / List**. The whole app uses `ScrollView` + `VStack` + cards because the design language doesn't match the iOS Form aesthetic and because the warm page background needs to bleed into the empty space around the cards.
- **No third-party deps.** First-party Apple frameworks only (per `CLAUDE.md`).
- **Photos** use `PhotosPicker` from `PhotosUI` (no PHPickerViewController bridging).
- **No force unwraps** in shipped code; optionals are unwrapped via `if let` / `guard`.
- **Cross-platform shims.** `HideNavBar`, `HideBackButton`, `PSDecimalKeyboard` ViewModifiers gate iOS-only modifiers behind `#if os(iOS)` so the project also builds for macOS.

---

## 6. Timer Flow

`DualTrackTimer` shows two stacked tracks: **PRE-INFUSION** (display range 0–10s) and **PULL** (display range 0–30s), plus a large total-elapsed readout in the top-left and a status badge in the top-right (READY / PRE-INFUSION / PULLING / DONE). When the pulse animation runs, the status dot pulses.

### State machine

```
TimerState: .idle → .running → .done → (reset) → .idle
TimerPhase: .pre  → .pull
```

### Buttons (mutually visible while not done)

- **START** — only enabled in `.idle`; resets elapsed and enters `.running` / `.pre`
- **FIRST DRIP** — only enabled in `.running` / `.pre`; records `preEnd = elapsed`, switches phase to `.pull`
- **DONE** — enabled in `.running`; if `preEnd` is still nil (no first-drip pressed), it's set to current elapsed (zero pre-infusion); `pullEnd = elapsed`; state goes to `.done`
- **RESET TIMER** — replaces the three buttons in `.done`; clears state back to `.idle`

### Tick

A `Timer.publish(every: 0.067, on: .main, in: .common).autoconnect()` (~15Hz) updates `elapsed` while running. The total readout, both track widths, and the active track's pulse all derive from this.

### Manual entry

Tapping the value label on either track (when timer is not running) flips it into a focused decimal-keyboard text field. Submitting writes through `setManualPre` or `setManualPull`, which jumps the state machine to `.done` and back-fills the other track if needed. This lets users log a shot retroactively without the timer.

### Shot save

On Save, the timer's `preEnd` and `(pullEnd - preEnd)` are written to `Shot.preInfusion` and `Shot.pull` respectively, then the timer resets along with the form fields.

---

## 7. Extraction & Tasting Note Systems

### Extraction

Single-select pill row with three values: **Sour** (red), **Perfect** (green), **Bitter** (deep brown). The active state uses a tone-specific background. `Shot.extractionRaw` stores `.rawValue`; nil means "not specified" (allowed). The History filter uses the same tones and supports filtering by extraction.

### Tasting tags

Eight values: **Acidic, Bitter, Sour, Sweet, Smoky, Nutty, Floral, Perfect**. Multi-select via flow-laid pills. Active state is filled with the accent color. Stored as `[String]` of raw values; the convenience `tags: [TastingTag]` getter maps them back. (Yes, "Bitter" exists in both Extraction and Tags — by design: extraction is the diagnosis, tags are the descriptors.)

Both systems are intentionally small and fixed for v1 — no custom tags. This keeps filtering clean and keeps tagging from becoming a categorization chore.

---

## 8. Bean Bag Numbering

Every Bean has a `bagNumber: Int`. The next number is held on `AppSettings.nextBagNumber`, starting at **1** for a fresh install. When a bean is created (via the Add Bean form or onboarding), it's stamped with the current `nextBagNumber` and the counter increments.

**The counter is monotonic — it is never decremented when a bean is deleted.** Bag #7 stays unique even if you delete bean #7, then add a new one (which would be bag #N+1). This preserves a stable identifier in shot history and notes that reference the bag.

The bag # appears on bean rows, bean detail header, and on every shot card and shot detail, so users have a stable mental anchor across reorderings.

---

## 9. Hardware Tracking

Two kinds of equipment via the `EquipmentKind` enum on a single `Equipment` model. Per-instance shot count is computed live from the inverse relationship — no denormalized counter to keep in sync.

The Hardware tab shows machines and grinders in two sections, with a per-section "+ Add" affordance. Tapping a card pushes `HardwareDetailView` with photo placeholder, live shot count, date added (`createdAt`), and a delete button.

Delete behavior: cascade rule is `.nullify`. Past shots stay in History but their `machine` / `grinder` reference becomes nil. The detail's confirmation message tells the user this so deletion doesn't feel destructive.

---

## 10. About Sheet

Presented from the `…` icon in any tab's nav bar. Large detent over `palette.surface`. Custom × close button (top-right) on top of the standard sheet drag handle.

Layout (top to bottom):

1. App icon — Canvas-drawn cup with crema dot, on accent gradient
2. Title "Pull State" + version line "v 1.0.0 · APR 26 2026"
3. Identity card — Built by, Contact, GitHub, Appearance switch
4. Tip jar (see below)
5. Tagline footer on `surfaceAlt`

### 10.1 In-App Purchase — Tip Jar

- **Product ID:** `com.badc0ffe.pullstate.tip`
- **Type:** Non-Consumable
- **Price:** $2.99 (display price loaded from StoreKit when available)
- **Title:** "Buy Me a Coffee"

Implemented via **StoreKit 2**, async/await, in `Utilities/StoreManager.swift` — an `@Observable @MainActor` class that loads the product, runs the purchase, and finishes the transaction. Verification uses `Transaction.verified` and discards unverified results.

State persistence: on a verified purchase, `AppSettings.hasTipped` flips true. The button visually flips to a checkmark + "Thanks for the coffee!" + "Means the world. Now back to dialing in." It stays in this state across launches.

**No features are gated behind the IAP** — per the project's design rules. It's purely a tip jar.

### 10.2 Local StoreKit testing

`Resources/PullState.storekit` defines the product locally so the purchase sheet works in the Simulator without setting it up in App Store Connect. To enable: edit the **Pull State** scheme → Run → Options → set **StoreKit Configuration** to `PullState.storekit`. When the live product is created in App Store Connect with the same ID, the live store takes over automatically — no code change.

---

## 11. Dark / Light / System Appearance

`AppearanceMode` is a three-value enum stored on `AppSettings`. `RootView` reads it and applies `.preferredColorScheme(...)` to the entire scene:
- `.system` → no override (`nil`), follows OS
- `.light` → `.light`
- `.dark` → `.dark`

Both `PSPalette.light` and `PSPalette.dark` are hand-tuned with separate hex values for every token (not a `colorScheme`-conditional opacity hack). The active palette is resolved via `PSPalette.resolve(for: ColorScheme)` and pushed into `EnvironmentValues.psPalette`.

The user can change appearance from two places: the **Welcome step of onboarding** (so they pick the right look on first run) and the **About sheet** (any time after).

---

## 12. Onboarding Flow

Lives in `Views/Onboarding/`. Rendered by `RootView` when `AppSettings.hasCompletedOnboarding` is false.

Four steps with a top progress-dot indicator: **Welcome → Hardware → Bean → Ready**.

- **Welcome** — logo, three-step explainer card, **Appearance picker** card (writes to settings live)
- **Hardware** — Machine combobox + Brand text field; Grinder combobox + Brand text field. The `OnbCombobox` lets the user pick from a list of common models or type a custom name; selecting a suggestion fills the text field.
- **Bean** — Name, Roaster, Roast level pills. Sidebar info card "BAG #001 · auto-increment".
- **Ready** — green-checked summary card with the user's machine, grinder, and bean entries.

Footer: primary action button changes per step (BEGIN SETUP / CONTINUE / PULL YOUR FIRST SHOT). Below it: `< Back` (after step 0) and "Skip setup" (always).

On finish or skip, any non-empty entries are persisted, `nextBagNumber` increments if a bean was added, and `hasCompletedOnboarding` flips. The user lands on the Log tab.

---

## 13. Deferred V2 Features

Per `CLAUDE.md`, **not** in v1 — do not implement until explicitly scoped:

- Barcode / QR scanning for bean bags
- AI shot diagnosis ("why was this sour?")
- CSV export of shot history
- iCloud sync (currently local only)
- Home Screen widget
- Share-shot-as-image card
- Rating trend charts beyond the per-bean sparkline (a v1.1 candidate)

These are deliberate omissions, not unbuilt features. The data model and architecture leave room for each: `Shot` already stores everything needed for export; `Bean.ratingTrend` is the seed for richer charts; the on-device-only model is what makes iCloud sync a v2 add rather than a refactor.

---

## Appendix — File map

```
Pull State/
├── Pull_StateApp.swift            (@main, ModelContainer)
├── Models/
│   ├── Bean.swift
│   ├── Shot.swift
│   ├── Equipment.swift
│   ├── AppSettings.swift
│   ├── Recipe.swift               (Codable value type, BeanRatingPoint)
│   └── Enums.swift
├── Resources/
│   ├── Theme.swift                (PSPalette, PSFont, PSFmt, PSShadow)
│   └── PullState.storekit         (local IAP config)
├── Utilities/
│   ├── SeedData.swift             (creates AppSettings singleton)
│   └── StoreManager.swift         (StoreKit 2)
└── Views/
    ├── RootView.swift             (onboarding ↔ main switch)
    ├── MainTabView.swift          (NavigationStack, NavRoute, sheets)
    ├── Components/                (palette-aware reusable views)
    ├── Log/                       (LogScreen, DualTrackTimer, SliderField, PickerRow)
    ├── History/                   (HistoryScreen, ShotCard, ShotDetailView, FilterSheet, SortSheet)
    ├── Beans/                     (BeansScreen, BeanDetailView, BeanAddForm, RecipeBlock, RatingChart)
    ├── Hardware/                  (HardwareScreen, HardwareDetailView, HardwareAddForm)
    ├── About/                     (AboutSheet)
    └── Onboarding/                (OnboardingFlow + 4 step views)
```
