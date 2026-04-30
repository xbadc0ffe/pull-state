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

The tab bar is a custom rounded chrome at the bottom of the screen (`PSTabBar`), not the system `TabView`. Active tab gets an inset card background and the accent-colored icon. The Beans tab uses a custom `BeanIcon` shape (Canvas-drawn three-bean cluster — three rotated-oval-with-seam glyphs in a loose triangle, each in its own `drawLayer` block for isolated transforms) since SF Symbols has no coffee-bean glyph. The Hardware tab tries `espresso.machine` (iOS 18+ SF Symbols 6) and falls back to `cup.and.saucer.fill` if the symbol isn't available.

### Navigation model

A single `NavigationStack` lives in `MainTabView`. Tab switches are state-driven, not pushed. Detail views are pushed onto the stack via a `NavRoute` enum:

```
enum NavRoute: Hashable {
    case shot(PersistentIdentifier)
    case bean(PersistentIdentifier)
    case hardware(PersistentIdentifier)
}
```

Detail views render their own `PSNavBar` with a chevron back button. The system navigation bar is hidden via `.toolbar(.hidden, for: .navigationBar)` (gated for iOS via the `HideNavBar` modifier so the build still compiles for macOS). Critically, **`.navigationBarBackButtonHidden(true)` is never called anywhere** — that modifier silently disables the interactive swipe-from-left pop gesture. To make swipe-back continue working even with a hidden toolbar, a `UINavigationController` extension (`Utilities/SwipeBackFix.swift`, see §15.1) installs itself as the `interactivePopGestureRecognizer` delegate.

Sheet presentations propagate `\.psPalette` and `\.psTempUnit` into the sheet's environment explicitly — sheets do not inherit environment by default in SwiftUI, so each `.sheet { … .environment(\.psPalette, palette).environment(\.psTempUnit, settings.temperatureUnit) }` block sets them.

### iPad layout

The single-column iPhone design is preserved on iPad by capping content to **560pt** centered, via `PSContentColumn`. The page background fills the whole screen, but cards, navigation bars, and the tab bar live inside the constrained column. This avoids stretched-thin rows while keeping the warm-wash gradient edge-to-edge.

### Sheets and modals

- **About sheet** — large detent, custom × close in top-right
- **Recipe sheet** — large detent over `palette.surface`, opened from the Log screen's "View Recipe" chip; matches About sheet chrome
- **Add bean** / **Add hardware** — full-screen sheets (page background)
- **Filter** / **Sort** — large/medium detents over palette.surface
- **Onboarding** — full-screen overlay rendered in place of `MainTabView` until `AppSettings.hasCompletedOnboarding` flips
- **Camera capture** — full-screen cover hosting `UIImagePickerController(.camera)` from `PSPhotoSourceMenu` (see §14)

---

## 3. Screens

### 3.1 Log a shot

Section order, top to bottom:

1. **Source** — three picker rows in one card: Machine, Grinder, Beans. Each row expands inline when tapped to show options. If any list is empty, a single placeholder card directs the user to set up their gear first; the Save button stays disabled. When a bean is selected, a **View Recipe** chip appears under the card → opens `RecipeSheet` (§3.7). On first appear, machine/grinder/bean are pre-selected from the **most recently logged shot** (`Shot.date` descending, take 1); when no shots exist yet, each picker falls back to the first item in its respective list. After a save the same equipment stays selected, so the next shot starts with the just-saved gear.
2. **Timer** — `DualTrackTimer`. See §6.
3. **Settings** — `Grind Setting` text field at the top (free-text, e.g. `"22"`), then sliders for `Dose / Weight In` (7–25 g, 0.1 step), `Yield / Weight Out` (7–75 g, 0.1 step), `Water Temp` (70–105 °C, 0.5 step — converted to Fahrenheit when the user has chosen °F, see §11.1), `Pressure` (4–12 bar, 0.1 step). When the bean changes, **only the recipe fields that are non-nil pre-populate their slider** — nil fields leave the slider where it was. The Grind Setting field also preloads from `recipe.grind` (and clears when the recipe value is nil). A small caption under the card reads "Loaded from {bean name} recipe."
4. **Extraction** — three pills (Sour / Perfect / Bitter), tone-colored. Tappable to toggle on/off (single-select).
5. **Tasting notes** — a flow-laid grid of all eight `TastingTag` values, **horizontally centered** within the column (`FlowLayout(spacing: 6, alignment: .center)`). Multi-select. (Tag set: Chocolate, Caramel, Fruity, Citrus, Floral, Nutty, Smoky, Earthy.)
6. **Rating** — five stars (`PSStars`), bound to an Int 0–5.
7. **Photo + Date card** — `PSPhotoSourceMenu` (Take Photo / Choose from Photos action sheet, see §14), with thumbnail + Change/Add/× actions. Date defaults to `.now` and is editable via a compact `DatePicker`.
8. **Notes** — multi-line `TextEditor` over the card background, with placeholder.
9. **Save shot button** — disabled unless bean + machine + grinder are all selected. Briefly flashes "SAVED ✓" after success and resets the form (timer, rating, extraction, tags, notes, photo, date back to `.now`, grind cleared then re-populated from the still-selected bean's recipe). Equipment selection is preserved across saves; the slider values for dose/yield/temp/pressure are also preserved.

**After saving:** at most one of two prompts may appear (mutually exclusive):

- **"Save recipe?"** — fires when the bean's recipe is missing any of `dose`/`yield`/`temp`/`pullPressure`. Title: `Save recipe?`, message: `Save these settings as the recipe for {bean name}?`, buttons: **Save Recipe** / **Skip**. Save writes the shot's values into the bean's recipe **only filling nil fields** — including `grind`, `preInfTime`, and `pullTime` when the shot has a value for them — and never overwrites an already-set field.
- **"Adjust recipe?"** — fires when the recipe is complete (all four required fields non-nil), the just-saved shot's rating is `>= max(rating)` across the bean's other shots, AND any logged value differs from the recipe. Difference rules: `dose` and `yield` use **±10% tolerance** of the recipe value; `waterTemp` and `pullPressure` use exact comparison (epsilon `0.01`); `preInfTime` and `pullTime` only count as differing when the recipe field is non-nil, the user actually used the timer for that track, and the logged time falls outside the green window (±1 s pre, ±3 s pull). Title: `Adjust recipe?`, message: `This pull matches or beats your best for {bean name}. Update the recipe with these settings?`, buttons: **Update Recipe** / **Skip**. Update **overwrites all four required fields** unconditionally, plus `grind`/`preInfTime`/`pullTime` whenever the shot has a value for them (skip if the shot value is absent — never write nil over an existing recipe value).

If neither condition is met, no prompt appears. Both prompts use `Bean.shots` (which already includes the just-inserted shot) when computing the rating maximum.

**Keyboard handling:** the scroll view uses `.scrollDismissesKeyboard(.interactively)` plus a `simultaneousGesture(TapGesture)` that calls `dismissKeyboard()` (UIKit `resignFirstResponder` shim), so tapping outside the manual-time entry field dismisses its keyboard immediately. See §15 for the global "select all on focus" behavior that applies to every editable text/numeric field.

### 3.2 History

**Empty state:** circular icon + "No shots logged yet" headline + subtitle pointing to the Log tab.

**Populated:**
- Large title with subtitle "N SHOTS LOGGED"
- Three stat cards: SHOTS / GRAMS (sum of yield) / AVG ★ (the AVG card uses accent color)
- Filter chip (with badge showing active filter count) + Sort chip + filtered/total ratio
- Vertical list of `ShotCard` rows, each tappable to push `ShotDetailView`

**Filter sheet** — extraction tone pills, **tasting-notes pills** (multi-select; AND-match — only shots that contain *all* selected tags pass), min-rating pills (Any / 2+ / 3+ / 4+ / 5+), and three select rows (any beans / any machine / any grinder, populated from the actual library). The filter chip's badge counter on History sums extraction + min-rating + each select + **each active tag**. Clear-all button on the left, Apply on the right.

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
Same screen, but every field becomes editable: source pickers, extraction, tags (rendered in `FlowLayout` matching Log spacing), six sliders (dose, yield, temp, pressure, pre-infusion, pull) with the same ranges as the Log screen and the same C/F display conversion, photo (inline card over `PSPhotoSourceMenu` — same shape as the Log screen's photo row, not `PhotoEditCard`), date picker, notes editor. Cancel + Save in the nav bar trailing slot. A red **Delete shot** button at the bottom triggers a confirmation alert.

### 3.3 Beans

List of `BeanRowCard`s sorted by bag number descending. Each card shows: photo placeholder, name, bag #, roaster, roast badge, process tag, optional "SINGLE ORIGIN" label.

**Empty state:** circular leaf icon, "No beans yet", "Tap + to log your first bag."

**Bean detail (view mode):**
- Bag photo (or placeholder if `bean.photoData` is nil) — 4:3 at the top
- Name + "BAG #X" + roaster line
- Roast badge + process chip + optional Single Origin chip
- **Rating trend chart** — `RatingChart`, a Path-drawn line chart. The visible viewport sizes for **10 slots** (most-recent shots fill from the right; if fewer than 10 shots exist, points sit on the left and the right slots stay empty). When more than 10 shots exist the chart is **horizontally scrollable** (`ScrollView(.horizontal)` with a fixed Y-axis column outside the scroll area) and starts scrolled to the trailing edge so the newest shots are visible. The line is a uniform **Catmull-Rom curve** (factor `1/6`) built from `Path.addCurve(to:control1:control2:)` and **passes exactly through every data point** — interpolation, not approximation. Dots, gridlines, MM-DD x labels, and the translucent fill below the curve carry over from the original sparkline.
- Dates card: Roast date, Purchase date
- Notes card (if any)
- **Recipe card** — inline-editable. Tap "Edit" to flip the recipe block into edit mode (Cancel / Save). The recipe object lives as JSON `Data` on the bean; see §4. Each row shows "—" when its underlying field is nil.
- Footer: shot count + average rating

**Bean detail (edit mode):**
Top-level Edit toggles all bean metadata (name, roaster, single-origin toggle, process pills inside a `PSCard` with an inline "Specify" text row revealed below the pills when **Other** is chosen — pills + reveal share the same card so the row participates in normal flow and never overlaps the Roast Level section below; roast pills inside their own matching `PSCard`; dates, **Photo** card via `PhotoEditCard`, notes). The recipe has its own separate Edit flow (mid-page) so users can dial in a recipe without entering the full edit flow. Bottom: red **Delete bean** button. Confirmation: *"Delete {bean name}? All associated pulls will be deleted too. N shots will be removed."* Implemented via SwiftData `@Relationship(deleteRule: .cascade, inverse: \Shot.bean)`.

**Add bean form** — full-screen sheet over the page background. Bag number is auto-assigned (`AppSettings.nextBagNumber`) and shown in an accent banner. Sections: Identity (Bean Name + Roaster), Single Origin toggle, **Process card** (pills inside a `PSCard`; selecting **Other** reveals an inline "Specify process" text row inside the same card with a 0.5pt divider above), **Roast Level card** (pills inside a matching `PSCard` for visual consistency with Process), Dates (real `DatePicker`s), **Photo card** (`PhotoEditCard` over `PSPhotoSourceMenu`), Notes, Recipe block (editable). **Recipe preload from existing bag** — as the user types Name and Roaster, the form looks for an existing bean whose name AND roaster match (case-insensitive, trimmed); when a match is found, the most recent matching bean's `recipe` is copied into the draft. The match is tracked by `persistentModelID`, so re-typing the same combination never overwrites in-progress recipe edits, but switching to a different match does refresh. Save creates the bean (with optional `photoData`) and increments `nextBagNumber`. Cancel discards.

### 3.4 Hardware

Two stacked sections: **Espresso Machines** and **Grinders**. Each section header has a small accent "+ Add" button. Cards (`HardwareCard`) show photo placeholder, name, brand, and a "N SHOTS" pill (live count via the inverse relationship).

The Hardware tab icon uses the SF Symbol `espresso.machine` when available (iOS 18+ SF Symbols 6) and falls back to `cup.and.saucer.fill`. The Beans tab icon is a Canvas-drawn three-bean cluster (drawn via repeated `GraphicsContext.drawLayer` blocks for per-bean translation/rotation).

**Hardware detail (view mode):**
- Photo (or placeholder) — 4:3 at top, sourced from `equipment.photoData`
- Name + brand
- Stats card: Shots pulled (live count), Date added (`createdAt`)
- Red **Delete machine/grinder** button. Confirmation note: *"Past shots logged on this machine/grinder will stay in your history but will no longer reference it."* Implemented via `@Relationship(deleteRule: .nullify, …)` — so shot data is preserved even after the hardware is deleted.

**Hardware detail (edit mode):** Edit button in the nav bar trailing slot. Identity card with editable Name + Brand `PSTextInput`s, plus a **Photo** card (`PhotoEditCard`). Cancel + Save in the trailing slot.

**Add hardware form** — full-screen sheet, kind-aware: same form for "Add Machine" and "Add Grinder". Name uses `OnbCombobox` driven by `HardwareCatalog` (substring case-insensitive match against name; selecting a suggestion auto-fills Brand via `HardwareCatalog.brand(forName:kind:)`, and Brand stays user-editable). Brand uses `OnbField`. The catalog covers manual/lever espresso machines and the common hand-grinder + electric-grinder ranges (Flair, Cafelat, Wacaco, La Pavoni, 1Zpresso, Commandante, Timemore, Kinu, Knock, Weber Workshops, Option-O, Fellow, Niche, DF, Baratza, Mazzer, Eureka, Fiorenzato, …). The user can type a fully custom name not in the catalog. The Add form shows a non-interactive "Add a photo" card as a hint — photos are attached afterwards from the Hardware detail edit flow.

### 3.5 About sheet

Presented from any tab via the `…` (ellipsis) icon in the top-right of the navigation bar. Large detent. Contents:

- × close button (top-right)
- App logo — `Image("badc0ffe-logo")` from the asset catalog, capped at 160 pt wide
- Title "Pull State"
- Version line "v 1.0.0 · APR 26 2026"
- Card with rows: **Built by** (badc0ffe), **Contact** (info@badc0ffe.net), **GitHub** (tappable `Link` to `https://github.com/xbadc0ffe/pull-state`, accent-colored + underlined), **Temperature** (Celsius / Fahrenheit switch — see §11.1), **Appearance** (System / Light / Dark switch)
- **Tip jar** — see §10
- Footer copy block on `surfaceAlt` background

### 3.6 Onboarding

Four steps, progress dots at the top:

1. **Welcome** — logo, title, "Three quick steps" card listing the three onboarding stages, then a **Temperature Unit** card (Celsius / Fahrenheit `TempUnitSwitch`) and an **Appearance** card (`ModeSwitch`). Choosing in either writes immediately to `AppSettings.temperatureUnit` / `AppSettings.appearance`.
2. **Hardware** — two sections (Espresso Machine / Grinder), each with `OnbCombobox` driven by `HardwareCatalog` (substring case-insensitive match against name; selecting a suggestion auto-fills the corresponding Brand `OnbField` via the catalog's brand lookup). The user can pick a suggestion or type a custom name; brand stays editable after auto-fill.
3. **Bean** — Bean name, Roaster, Roast level pills, plus a "BAG #001" reminder card.
4. **Ready** — green-checked "You're dialed." summary card listing what was entered.

Footer: primary action button (BEGIN SETUP / CONTINUE / PULL YOUR FIRST SHOT) plus a `< Back` link and a "Skip setup" link.

On finish: any non-empty machine, grinder, and bean entered are inserted into SwiftData; `nextBagNumber` increments; `hasCompletedOnboarding` flips true. Skipping does the same — entries with empty names are skipped, the rest is saved.

### 3.7 Recipe sheet

Presented from the **View Recipe** chip on the Log screen's Source card (when a bean is selected). Large detent over `palette.surface`, × close button top-right, swipe-down dismissible — same chrome conventions as the About sheet.

Header: bean name, "BAG #X · RECIPE".

Body: one card with eight rows — Grind, Dose (g), Yield (g), Water Temp (°C/°F), Pre-Infusion Time (s), Pre-Infusion Pressure (bar), Pull Time (s), Pull Pressure (bar). Fields whose `Recipe` value is nil display "—". `RecipeBlock` (used inline on the Bean detail and add-bean form) shows the same set of rows in the same order.

**Edit mode** — top-left **Edit** button toggles every row to a focused decimal/text input bound to a draft `Recipe`. Top-right shows **Save** (writes the draft back to `bean.recipe` via the JSON encode/decode path; only enabled when the draft differs from the saved recipe) and **Cancel** (discards the draft). The temperature row converts on display and on commit so the user always types in their chosen unit while storage stays in Celsius.

**Closing with pending edits** — if the user taps × while edits are dirty, an alert *"Discard changes? Your edits to this recipe will be lost."* gates the dismiss. Clean closes go through immediately.

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
    var processRaw: String                                  // BeanProcess.rawValue
    var processOther: String                                // free-text when process == .other
    var roastRaw: String                                    // Roast.rawValue
    var roastDate: Date
    var purchaseDate: Date
    var notes: String
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?
    private var recipeData: Data?                           // JSON-encoded Recipe

    @Relationship(deleteRule: .cascade, inverse: \Shot.bean)
    var shots: [Shot] = []
}
```

Computed/exposed:
- `process: BeanProcess` and `roast: Roast` — get/set wrappers over the raw strings
- `processDisplay: String` — uses `processOther` when process is `.other`
- `recipe: Recipe` — JSON-decoded; **falls back to an empty `Recipe()` (all-nil)** when `recipeData` is nil or fails to decode. Setter encodes.
- `ratingTrend: [BeanRatingPoint]` — shots sorted by date, mapped to (date, rating) for the sparkline
- `averageRating: Double?` — nil when no shots

Delete rule: `.cascade` on `shots` — deleting a bean removes all its shots. This is what the Bean detail's delete confirmation describes to the user.

`photoData` uses `@Attribute(.externalStorage)` so bag photos live outside the SQLite file.

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
    var kindRaw: String                                     // EquipmentKind.rawValue
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?

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

Delete rule: `.nullify` for both — deleting hardware preserves the shots, just nulls the reference. `photoData` uses external storage, same pattern as `Bean.photoData` and `Shot.photoData`.

### 4.4 AppSettings

Singleton row holding app-wide preferences:

```
@Model
final class AppSettings {
    var appearanceRaw: String                       // AppearanceMode.rawValue
    var temperatureUnitRaw: String = "celsius"      // TemperatureUnit.rawValue
    var hasCompletedOnboarding: Bool
    var hasTipped: Bool                             // set after IAP success
    var nextBagNumber: Int                          // monotonic, never decremented
    var seedDataInstalled: Bool                     // currently always true after first install
}
```

`temperatureUnitRaw` carries an inline default (`= "celsius"`) so SwiftData lightweight migration can backfill existing AppSettings rows when this column is added.

Computed: `appearance: AppearanceMode`, `temperatureUnit: TemperatureUnit` — get/set wrappers over the raw strings.

`SeedData.installIfNeeded(context:)` runs in `RootView.task` and creates the `AppSettings` singleton if absent. The app starts empty — no demo beans, hardware, or shots. First bag added becomes `#1`.

### 4.5 Recipe (value type)

Stored as JSON `Data` on `Bean.recipeData`. Not a `@Model` — `Recipe` is a `nonisolated struct Codable, Equatable, Sendable` so it can cross actor boundaries without warnings.

**All fields are optional. There are no hardcoded defaults.** A fresh `Recipe()` is all-nil; an "unspecified" field is genuinely unspecified, not "default 18".

```
struct Recipe {
    var grind: String?
    var dose: Double?
    var yield: Double?
    var temp: Double?               // stored in Celsius
    var preInfTime: Double?         // seconds
    var preInfPressure: Double?     // bar
    var pullTime: Double?           // seconds
    var pullPressure: Double?       // bar
}
```

`init(from: Decoder)` decodes every key with `decodeIfPresent`; a missing or null key decodes to nil. Old bean records that pre-date a field decode cleanly with that field as nil.

**Every read site must guard for nil before using a value.** Anything that previously assumed a default (e.g. "the slider preloads to 18 g") now no-ops when the corresponding field is nil:
- The Log screen's bean preload sets each slider only when its recipe field is non-nil; nil leaves the slider at its current value. The Grind Setting field preloads from `recipe.grind` when non-nil and clears when nil.
- The "Save recipe?" / "Adjust recipe?" alerts (§3.1) and `RecipeSheet` (§3.7) treat nil as "not specified" — Save fires when *any* of dose/yield/temp/pullPressure is nil and only fills nil fields; Adjust fires when the recipe is complete, the rating qualifies, and a value differs (dose/yield use ±10% tolerance, timer fields use the green window).
- Timer green-target windows and the green-bar/button visual (§6) render only when `recipe.preInfTime` / `recipe.pullTime` are non-nil.

The bean's full recipe is shown and editable on the Bean detail card (`RecipeBlock`) and in the Log screen's `RecipeSheet`. Both surface the same set of rows in the same order — Grind, Dose, Yield, Water Temp, Pre-Infuse Time, Pre-Infuse Pressure, Pull Time, Pull Pressure.

### 4.6 Enums

| Enum              | Values                                                            | Where used                                |
| ----------------- | ----------------------------------------------------------------- | ----------------------------------------- |
| `Extraction`      | sour, perfect, bitter                                             | Shot.extraction; shows as colored pill    |
| `Roast`           | light, medium, dark                                               | Bean.roast; pip color in `PSRoastBadge`   |
| `BeanProcess`     | washed, natural, honey, wetHulled, other                          | Bean.process; "Other" reveals text input  |
| `EquipmentKind`   | machine, grinder                                                  | Equipment.kind                            |
| `TastingTag`      | chocolate, caramel, fruity, citrus, floral, nutty, smoky, earthy  | Shot.tags (multi-select); History filter  |
| `SortOrder`       | newest, oldest, highest, lowest                                   | History sort                              |
| `AppearanceMode`  | system, light, dark                                               | AppSettings.appearance                    |
| `TemperatureUnit` | celsius, fahrenheit                                               | AppSettings.temperatureUnit; display only |

`TastingTag` exposes a `label: String` (capitalized rawValue) for display — the rawValue is lowercase so it persists cleanly. **Unknown raw values are silently dropped** on read via `compactMap(TastingTag.init(rawValue:))` — older shot records that referenced the previous tag set (Acidic / Bitter / Sour / Sweet / …) decode to an empty subset of the new set with no crash, no migration step, and no UI surfacing.

`TemperatureUnit` provides:
- `label: String` — `"°C"` / `"°F"`, used as a unit suffix
- `pickerLabel: String` — `"Celsius"` / `"Fahrenheit"`, used in the toggle UI
- `display(celsius:) -> Double` — Celsius → user's chosen unit
- `toCelsius(_:) -> Double` — inverse, applied on input

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
- `PSTabBar` — custom rounded chrome bar; the Beans tab uses a Canvas-drawn three-bean cluster (`BeanIcon`); the Hardware tab tries `espresso.machine` and falls back to `cup.and.saucer.fill`
- `PSIconBtn`, `PSTextBtn`, `PSToggle`, `PSRoastBadge`, `IconChip`, `StatCard`
- `FlowLayout` — custom `Layout` for tag clouds. `alignment: HorizontalAlignment` parameter (`.leading` default; supports `.center` and `.trailing`) is set per-callsite — the Log screen's Tasting notes use `.center`, Process pills in the Bean form use the default `.leading`. Two-pass placement: first pass groups subviews into lines by width, second pass places each line with the requested horizontal alignment.
- `PSPageBackground` — radial-gradient warm wash, full screen
- `PSContentColumn` — caps content to 560pt centered (iPad layout)
- `PSPhotoSourceMenu` — universal photo entry point (§14): action sheet over Take Photo / Choose from Photos, falls back to Photos-only when the camera is unavailable
- `PhotoEditCard` — thumbnail row with Add/Change + ✕ remove, used by Bean add/edit and Hardware edit. The Log and Shot edit screens use a custom inline card with the same affordances
- `ModeSwitch` (Appearance) and `TempUnitSwitch` (Celsius/Fahrenheit) — capsule segmented controls used by both About and Onboarding

Slider note: `SliderField` (in `Views/Log/`) does its own gesture handling — a `DragGesture(minimumDistance: 0)` over the visual track maps tap/drag x-position to a stepped, clamped value. There is no hidden `Slider` underneath; the visible thumb is the only thing that exists.

### 5.4 Decisions worth flagging

- **No Form / List**. The whole app uses `ScrollView` + `VStack` + cards because the design language doesn't match the iOS Form aesthetic and because the warm page background needs to bleed into the empty space around the cards.
- **No third-party deps.** First-party Apple frameworks only (per `CLAUDE.md`).
- **Photos** go through `PSPhotoSourceMenu` everywhere, never `PhotosPicker` directly. The menu wraps `PhotosPicker` for the library path and a `UIImagePickerController` `UIViewControllerRepresentable` for the camera path. Required Info.plist keys (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`) are set as `INFOPLIST_KEY_*` build settings on both Debug and Release configurations.
- **No force unwraps** in shipped code; optionals are unwrapped via `if let` / `guard`.
- **Cross-platform shims.** `HideNavBar` and `PSDecimalKeyboard` ViewModifiers gate iOS-only modifiers behind `#if os(iOS)` so the project also builds for macOS. The `HideBackButton` modifier was removed — it was unused and dangerous (calling `.navigationBarBackButtonHidden(true)` silently kills the swipe-back gesture).

---

## 6. Timer Flow

`DualTrackTimer` shows two stacked tracks: **PRE-INFUSION** and **PULL**, plus a large total-elapsed readout in the top-left and a status badge in the top-right (READY / PRE-INFUSION / PULLING / DONE). When the pulse animation runs, the status dot pulses.

### Track scaling and target windows

Each track's full width represents `trackMax` seconds:
- If the selected bean's `Recipe.preInfTime` / `pullTime` is **non-nil**, `trackMax = target / 0.75` so the recipe target sits at exactly the **75% mark** of the track. A green band rendered at `palette.good.opacity(0.30)` spans `target ± tolerance` (±1 s for pre-infusion, ±3 s for pull) **behind** the elapsed-fill gradient.
- If the field is nil, `trackMax` falls back to the previous fixed scaling (10 s pre / 30 s pull) and **no green band renders** — layout is unchanged.

The targets and bands re-derive automatically when the user changes the bean mid-session; nothing is cached.

### Green-window visual feedback

While a track's elapsed time falls inside its green window, the entire elapsed-fill bar swaps from the accent gradient to a solid `palette.good` fill (with a soft `palette.good.opacity(0.45)` shadow when the track is active). Once the elapsed time crosses the upper bound, the bar reverts to the accent gradient — it never goes red. The same window check colors the **FIRST DRIP** and **DONE** buttons green (text turns white, accent stroke removed) for the current phase only; disabled buttons never show the green state. All checks return `false` when the corresponding `Recipe` field is nil, so the green visual only ever appears when the user has set a target.

### State machine

```
TimerState: .idle → .running → .done → (reset) → .idle
TimerPhase: .pre  → .pull
```

### Buttons

- **START** / **FIRST DRIP** / **DONE** — three equal-width squares in a horizontal row (`.aspectRatio(1, contentMode: .fit)` + `minWidth: 64`, `minHeight: 64`), aiming for ~72×72 pt on a typical iPhone. The label inside each button uses `frame(maxWidth: .infinity, maxHeight: .infinity)` so the accent/surface background fills the full square.
  - **START** — only enabled in `.idle`; resets elapsed and enters `.running` / `.pre`
  - **FIRST DRIP** — only enabled in `.running` / `.pre`; records `preEnd = elapsed`, switches phase to `.pull`
  - **DONE** — enabled in `.running`; if `preEnd` is still nil (no first-drip pressed), it's set to current elapsed (zero pre-infusion); `pullEnd = elapsed`; state goes to `.done`
- **RESET TIMER** — replaces the three buttons in `.done`; full-width pill (≥18 pt vertical padding) so it stays a clean tap target; clears state back to `.idle`

### Tick

A `Timer.publish(every: 0.067, on: .main, in: .common).autoconnect()` (~15Hz) updates `elapsed` while running. The total readout, both track widths, and the active track's pulse all derive from this.

### Manual entry

Tapping the value label on either track (when timer is not running) flips it into a focused decimal-keyboard text field. Submitting writes through `setManualPre` or `setManualPull`, which jumps the state machine to `.done` and back-fills the other track if needed. This lets users log a shot retroactively without the timer. The Log screen's tap-outside-to-dismiss handler (§3.1) closes the keyboard.

### Shot save

On Save, the timer's `preEnd` and `(pullEnd - preEnd)` are **rounded to one decimal place** (`(value * 10).rounded() / 10`) and written to `Shot.preInfusion` and `Shot.pull` respectively. The same rounded values flow into the recipe-prompt (§3.1) so any saved/adjusted recipe also stays at 0.1 s precision. The timer then resets along with the form fields.

---

## 7. Extraction & Tasting Note Systems

### Extraction

Single-select pill row with three values: **Sour** (red), **Perfect** (green), **Bitter** (deep brown). The active state uses a tone-specific background. `Shot.extractionRaw` stores `.rawValue`; nil means "not specified" (allowed). The History filter uses the same tones and supports filtering by extraction.

### Tasting tags

Eight values: **Chocolate, Caramel, Fruity, Citrus, Floral, Nutty, Smoky, Earthy**. Multi-select via flow-laid pills. Active state is filled with the accent color. Stored as `[String]` of lowercase raw values; the convenience `tags: [TastingTag]` getter maps them back via `compactMap`, so any unrecognized rawValue (e.g. a tag from a previous tag-set version) is silently dropped without a crash and without surfacing a migration prompt.

The History filter sheet exposes the same eight pills as a multi-select group. Selecting more than one applies an **AND match** — only shots whose tag set is a superset of the selected tags pass.

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

1. App logo — `Image("badc0ffe-logo")` from the asset catalog (max 160 pt wide, `.scaledToFit()`)
2. Title "Pull State" + version line "v 1.0.0 · APR 26 2026"
3. Identity card — Built by, Contact, GitHub (tappable `Link`), **Temperature** (Celsius/Fahrenheit `TempUnitSwitch`), **Appearance** (System/Light/Dark `ModeSwitch`)
4. Tip jar (see below)
5. Tagline footer on `surfaceAlt`

### 10.1 In-App Purchase — Tip Jar

- **Product ID:** `com.badc0ffe.pullstate.tip`
- **Type:** Non-Consumable
- **Price:** $2.99 (display price loaded from StoreKit when available)
- **Title:** "Buy Me a Coffee"

Implemented via **StoreKit 2**, async/await, in `Utilities/StoreManager.swift` — an `@Observable @MainActor` class that loads the product on `init()` (eager), runs the purchase, and finishes the transaction. Verification uses `Transaction.verified` and discards unverified results.

State persistence: on a verified purchase, `AppSettings.hasTipped` flips true. The button visually flips to a checkmark + "Thanks for the coffee!" + "Means the world. Now back to dialing in." It stays in this state across launches.

`StoreManager.hasPriorEntitlement()` walks `Transaction.currentEntitlements` for the tip product. The About sheet's `.task` calls it on appear and re-flips `hasTipped` true if a prior purchase exists — this restores the tipped state on a fresh install or after wiping local data, without requiring a re-purchase.

**No features are gated behind the IAP** — per the project's design rules. It's purely a tip jar.

### 10.2 Local StoreKit testing

`Resources/PullState.storekit` defines the product locally so the purchase sheet works in the Simulator without setting it up in App Store Connect. To enable: edit the **Pull State** scheme → Run → Options → set **StoreKit Configuration** to `PullState.storekit`. When the live product is created in App Store Connect with the same ID, the live store takes over automatically — no code change.

A reminder comment in `StoreManager.swift` calls this scheme setup out so it isn't forgotten when the file is opened cold.

---

## 11. User preferences (Appearance + Temperature unit)

Two app-wide preferences live on `AppSettings` and are pushed into the SwiftUI environment by `MainTabView`, so deep child views read them without prop drilling.

### 11.1 Appearance (Dark / Light / System)

`AppearanceMode` is a three-value enum on `AppSettings`. `RootView` reads it and applies `.preferredColorScheme(...)` to the entire scene:
- `.system` → no override (`nil`), follows OS
- `.light` → `.light`
- `.dark` → `.dark`

Both `PSPalette.light` and `PSPalette.dark` are hand-tuned with separate hex values for every token (not a `colorScheme`-conditional opacity hack). The active palette is resolved via `PSPalette.resolve(for: ColorScheme)` and pushed into `EnvironmentValues.psPalette`.

### 11.2 Temperature unit (Celsius / Fahrenheit)

`TemperatureUnit` is stored on `AppSettings.temperatureUnitRaw` (default `"celsius"`). `MainTabView` exposes the resolved value via the `\.psTempUnit` environment key (`PSTempUnitKey.defaultValue == .celsius`).

**All temperatures are stored in Celsius internally.** Display and input convert at the UI layer only:

- The Log screen's water-temp slider wraps `$waterTemp` in a `Binding<Double>` whose `get` calls `tempUnit.display(celsius:)` and whose `set` calls `tempUnit.toCelsius(_:)`. The slider's range and step also flip with the unit (70–105 °C / 0.5 step ↔ 158–221 °F / 1 step). The stored `Shot.waterTemp` is always Celsius.
- `ShotDetailView` uses the same wrapper for its edit-mode slider and a `formattedTemp(_:)` helper for the read-only display.
- `RecipeSheet` uses a dedicated `RecipeTempField` row that converts on display and on commit, so the user always types in their chosen unit while `Recipe.temp` stays in Celsius.

### 11.3 Where the user can change them

Both preferences are exposed in two places:
- **Onboarding Welcome step** — a Temperature Unit card and an Appearance card, written live to `AppSettings`.
- **About sheet** — Temperature row above Appearance row in the identity card, same writes.

---

## 12. Onboarding Flow

Lives in `Views/Onboarding/`. Rendered by `RootView` when `AppSettings.hasCompletedOnboarding` is false.

Four steps with a top progress-dot indicator: **Welcome → Hardware → Bean → Ready**.

- **Welcome** — logo, three-step explainer card, **Temperature Unit** card, **Appearance picker** card (both write to settings live)
- **Hardware** — Machine combobox + Brand text field; Grinder combobox + Brand text field. `OnbCombobox` is driven by `HardwareCatalog` (substring case-insensitive name match); selecting a suggestion auto-fills the Brand field via `HardwareCatalog.brand(forName:kind:)`. Brand stays user-editable and the user can also type a fully custom name.
- **Bean** — Name, Roaster, Roast level pills. Sidebar info card "BAG #001 · auto-increment".
- **Ready** — green-checked summary card with the user's machine, grinder, and bean entries.

Footer: primary action button changes per step (BEGIN SETUP / CONTINUE / PULL YOUR FIRST SHOT). Below it: `< Back` (after step 0) and "Skip setup" (always).

On finish or skip, any non-empty entries are persisted, `nextBagNumber` increments if a bean was added, and `hasCompletedOnboarding` flips. The user lands on the Log tab.

---

## 13. Hardware Catalog

`Utilities/HardwareCatalog.swift` is the single source of truth for the autocomplete suggestions used by both the onboarding hardware step and the Add Hardware form.

```swift
struct HardwareEntry: Hashable, Identifiable {
    let name: String
    let brand: String
    var id: String { "\(brand)::\(name)" }
}

enum HardwareCatalog {
    static let machines: [HardwareEntry] = [...]
    static let grinders: [HardwareEntry] = [...]
    static func entries(for: EquipmentKind) -> [HardwareEntry]
    static func brand(forName: String, kind: EquipmentKind) -> String?
}
```

Lists are intentionally focused on the audience: manual/lever espresso machines (Flair, Cafelat, Wacaco, La Pavoni, Elektra, Olympia Express, Ponte Vecchio, Portaspresso, Gaggiuino) and the popular hand- and electric-grinder ranges (1Zpresso, Commandante, Timemore, Kinu, Orphan Espresso, Knock, Weber Workshops, Option-O, Fellow, Niche, DF Grinders, Baratza, Mazzer, Eureka, Fiorenzato).

The catalog is *suggestions only* — the combobox accepts any custom name and the brand field stays editable after auto-fill.

---

## 14. Photo Capture

A single component, `PSPhotoSourceMenu`, is used everywhere the user can attach a photo (Log shot, Bean add/edit, Hardware edit, Shot edit). It owns:

- A `confirmationDialog` action sheet with **Take Photo** and **Choose from Photos** options
- A `.photosPicker(isPresented:selection:matching:photoLibrary:)` for the library path
- A `.fullScreenCover` (iOS-only) hosting a `UIViewControllerRepresentable` wrapper around `UIImagePickerController(sourceType: .camera)` for the camera path

Camera availability is gated by `UIImagePickerController.isSourceTypeAvailable(.camera)`. When the camera is unavailable (e.g. iOS Simulator, iPad without rear camera, macOS Catalyst), the action sheet is bypassed and the picker opens directly into Photos. On macOS the camera path is compiled out via `#if canImport(UIKit)`.

The wrapped `CameraImagePicker` writes the captured image as JPEG (`compressionQuality: 0.85`) into the bound `Data?`. All photo storage on the SwiftData side uses `@Attribute(.externalStorage)` (Bean, Equipment, Shot).

`PhotoEditCard` composes `PSPhotoSourceMenu` into the standard thumbnail row used by the bean and hardware edit cards: thumbnail (or `PSPlaceholder`) on the left, label + hint in the middle, and an Add/Change capsule plus an ✕ remove circle on the right. The Log screen and Shot edit screen wire `PSPhotoSourceMenu` into their own inline cards with matching affordances.

**Info.plist keys** (added as `INFOPLIST_KEY_*` build settings on Debug + Release):
- `NSCameraUsageDescription` — "Pull State uses the camera to take photos of beans, hardware, and shots."
- `NSPhotoLibraryUsageDescription` — "Pull State adds selected photos to beans, hardware, and shots."

---

## 15. Behavioral Utilities

Three small pieces of UIKit-adjacent behavior live in `Utilities/`. Each is a deliberate, narrow exception to "SwiftUI only" — kept tiny and isolated so the rest of the codebase stays declarative.

### 15.1 Swipe-back fix (`Utilities/SwipeBackFix.swift`)

`UINavigationController` retroactively conforms to `UIGestureRecognizerDelegate`, sets the `interactivePopGestureRecognizer.delegate` to `self` in `viewDidLoad`, and returns `true` from `gestureRecognizerShouldBegin` whenever the stack has more than one controller.

Without this, hiding the toolbar with `.toolbar(.hidden, for: .navigationBar)` causes UIKit to disable the swipe-from-edge pop gesture (because the back button — its default trigger — isn't visible). Detail views hide the toolbar but **never** call `.navigationBarBackButtonHidden(true)`, which would silently break the gesture for a different reason.

### 15.2 Select-all-on-focus (`Utilities/SelectAllOnFocus.swift`)

A global, idempotent `install()` (called once from `Pull_StateApp.init()`) adds two notification observers — `UITextField.textDidBeginEditingNotification` and `UITextView.textDidBeginEditingNotification` — that call `selectAll(_:)` on the field/view (only when the existing content is non-empty). The result: tapping any editable numeric or text field with prior content immediately selects all of it, so the user's first keystroke replaces the value.

### 15.3 Seed data (`Utilities/SeedData.swift`)

Creates the `AppSettings` singleton on first launch only. The app starts empty — no demo beans, hardware, or shots. Bag #1 is the user's first real bag.

---

## 16. Privacy & Security

Pull State is local-only by design. No accounts, no backend, no network requests, no analytics, no third-party SDKs. Everything in this section is enforced by build configuration and the project layout — keep it that way.

- **Privacy manifest** — `Pull State/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking: false`, no tracking domains, no collected data types, no required-reason API access. App Store submissions assume this manifest is present and accurate.
- **Encryption flag** — `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` on both Debug and Release. The app only relies on OS-level file protection — no custom crypto. Without this key App Store Connect re-asks the encryption question on every upload.
- **File protection** — `Pull State/Pull State.entitlements` sets `com.apple.developer.default-data-protection = NSFileProtectionCompleteUnlessOpen`. Wired via `CODE_SIGN_ENTITLEMENTS` in both build configs. `UnlessOpen` (rather than `Complete`) keeps the SwiftData store readable while the device is locked but the app is foregrounded — required so the timer survives a screen-sleep mid-shot.
- **Storage** — SwiftData store lives in the app's default Application Support directory (no App Group, no shared container). Photos use `@Attribute(.externalStorage)` so blobs live in the protected subdirectory rather than inline in the SQLite file. No `UserDefaults` writes anywhere — `AppSettings` is a SwiftData `@Model`.
- **No File Sharing surfaces** — `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are absent. The app sandbox is not exposed via Files or iTunes File Sharing.
- **No ATS exceptions** — `NSAppTransportSecurity` is not set. The app makes zero network requests, so any ATS exception would be a smell.
- **StoreKit verification** — `Utilities/StoreManager.swift` switches on `VerificationResult` for both purchase and restore; unverified transactions are explicitly discarded. Restore uses `Transaction.currentEntitlements` (not a local flag). `AppSettings.hasTipped` is a UI cache that's re-derived from `currentEntitlements` on every About-sheet appear — never the source of truth.
- **No logging** — there are zero `print` / `NSLog` / `os.Logger` / `debugPrint` calls in the codebase. If logging is ever introduced, gate it behind `#if DEBUG` and keep user content (bean names, notes, ratings, transaction data, photo bytes, sandbox paths) out of the log entirely.
- **Repo hygiene** — `SECURITY.md` at the repo root documents the disclosure path. `.gitignore` covers `.DS_Store`, `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `*.p8` / `*.p12` / `AuthKey_*.p8`, `*.cer`, `*.mobileprovision`. `CLAUDE.md` and `prompts/` stay gitignored.

`REGISTER_APP_GROUPS = YES` is left in the build config in anticipation of the v2 Home Screen widget (§17) — without a matching `com.apple.security.application-groups` entitlement key, no app group is actually granted, so the flag is harmless until the widget lands.

---

## 17. Deferred V2 Features

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
├── Pull_StateApp.swift            (@main, Application Support bootstrap, ModelContainer, SelectAllOnFocus.install())
├── Pull State.entitlements        (data-protection class — see §16)
├── PrivacyInfo.xcprivacy          (no tracking, no collection — see §16)
├── Models/
│   ├── Bean.swift                 (incl. photoData: Data?, recipe accessor)
│   ├── Shot.swift                 (photoData: Data?)
│   ├── Equipment.swift            (incl. photoData: Data?)
│   ├── AppSettings.swift          (AppearanceMode + TemperatureUnit enums)
│   ├── Recipe.swift               (all-optional Codable value type, BeanRatingPoint)
│   └── Enums.swift                (Extraction, Roast, BeanProcess, EquipmentKind, TastingTag, SortOrder)
├── Resources/
│   ├── Theme.swift                (PSPalette, PSFont, PSFmt, PSShadow, \.psPalette + \.psTempUnit env keys)
│   └── PullState.storekit         (local IAP config)
├── Utilities/
│   ├── SeedData.swift             (creates AppSettings singleton)
│   ├── StoreManager.swift         (StoreKit 2 + entitlement restore)
│   ├── HardwareCatalog.swift      (machines + grinders for the combobox)
│   ├── SwipeBackFix.swift         (UINavigationController gesture delegate)
│   └── SelectAllOnFocus.swift     (global UITextField/UITextView observer)
└── Views/
    ├── RootView.swift             (onboarding ↔ main switch)
    ├── MainTabView.swift          (NavigationStack, NavRoute, sheets, env injection)
    ├── Components/                (palette-aware reusable views; PSPhotoSourceMenu, PhotoEditCard)
    ├── Log/                       (LogScreen, DualTrackTimer, SliderField, PickerRow)
    ├── History/                   (HistoryScreen, ShotCard, ShotDetailView, FilterSheet, SortSheet)
    ├── Beans/                     (BeansScreen, BeanDetailView, BeanAddForm, RecipeBlock, RecipeSheet, RatingChart)
    ├── Hardware/                  (HardwareScreen, HardwareDetailView, HardwareAddForm)
    ├── About/                     (AboutSheet — also defines ModeSwitch + TempUnitSwitch)
    └── Onboarding/                (OnboardingFlow + 4 step views; OnbCombobox/OnbField in OnbHardwareStep)
```

Asset catalog: `Assets.xcassets/badc0ffe-logo.imageset/` (sourced from `branding/badc0ffe-logo.png`) — used by the About sheet header.

App icon: `Assets.xcassets/AppIcon.appiconset/` is a Single Size 1024×1024 universal-iOS set with two appearance slots — Any (light) → `AppIcon-light-1024.png`, Dark → `AppIcon-dark-1024.png`. Sourced from `branding/icon-light.png` and `branding/icon-dark.png`. No tinted variant. Xcode generates all derivative sizes from the 1024 source.
