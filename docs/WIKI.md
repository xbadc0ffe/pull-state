# Pull State — Project Wiki

The working reference for anyone (human or agent) touching this repo. DESIGN.md is the long-form spec of *what the app does*; this page is *how the project is built, shipped and organised*. When the two disagree with the code, the code wins; fix the doc.

---

## 1. At a glance

| | |
|---|---|
| App | Pull State — local-only espresso shot logbook |
| Platforms | iPhone + iPad (iOS / iPadOS 26.0+), single SwiftUI target + unit-test target |
| Stack | SwiftUI, SwiftData, StoreKit 2, PhotosUI, Swift 6 language mode. No third-party dependencies |
| Bundle ID | `com.badc0ffe.pullstate` |
| Team | ZWS3TP3W3Z |
| Repo | github.com/xbadc0ffe/pull-state (MIT) |
| Current release | 1.4 (App Store) → 26.1.5 on TestFlight (version scheme: §5) |
| Tip-jar IAP | `com.badc0ffe.pullstate.tip`, non-consumable, nothing gated |

---

## 2. Repository layout

```
pull-state/
├── CLAUDE.md                 project rules for Claude Code sessions
├── README.md / SECURITY.md / LICENSE
├── Pull State.xcodeproj/     single target "Pull State", shared scheme "Pull State"
├── Pull State/               app sources (see §3)
├── Pull StateTests/          Swift Testing unit tests (recipe prompt rules, codable, formatters)
├── docs/
│   ├── DESIGN.md             full design + behaviour spec (screens, data model, timer, IAP)
│   ├── WIKI.md               this file
│   ├── AUDIT-YYYY-MM-DD.md   dated audit reports; newest is the open backlog
│   └── privacy.html          privacy policy published via GitHub Pages
├── branding/                 app icon sources (light/dark) and the badc0ffe logo
└── design/                   the original Claude Design prototype (one handoff zip: HTML + JSX)
```

Notes about a particular machine (build server, ship script, local paths) go in a git-ignored `CLAUDE.local.md` next to `CLAUDE.md`, not in the committed docs.

### Source tree (`Pull State/`)

| Folder | Contents |
|---|---|
| `Pull_StateApp.swift` | `@main`; builds the `ModelContainer`, installs `SelectAllOnFocus` |
| `Models/` | SwiftData `@Model`s: `Shot`, `Bean`, `Equipment`, `AppSettings`; value types `Recipe`, `BeanRatingPoint`; enums; `PersistentModel.isDetached` (behind the display-safe `photo`) |
| `Resources/` | `Theme.swift` (palette, fonts, formatters, env keys), `PullState.storekit` |
| `Utilities/` | `StoreManager` (StoreKit 2), `RecipePromptEvaluator` (pure prompt rules), `ShotReassignment` (re-filing shots, "Unknown" clean-up, hardware backfill), `ShotCSV` (CSV export + file), `ShareSheet` (share sheet for that file), `DataWiper` (Wipe Data scopes), `PSThumbnailCache`, `SeedData`, `HardwareCatalog`, `SwipeBackFix`, `SelectAllOnFocus` |
| `Views/RootView.swift` | onboarding ↔ main switch, applies colour scheme |
| `Views/MainTabView.swift` | the single `NavigationStack`, `NavRoute`, tab switch, About/Add sheets |
| `Views/Components/` | `PS*` design-system views (card, field, pill, stars, nav bar, tab bar, photo picker/crop/thumb, toggle, attention glow, layout) |
| `Views/Log/` | Log tab: `LogScreen`, `DualTrackTimer`, `SliderField`, `PickerRow`, `GrindSettingField` |
| `Views/History/` | History tab (with Select mode), `ShotCard`, `ShotDetailView`, `ShotBulkEditSheet`, filter + sort sheets |
| `Views/Beans/` | Beans tab, `BeanDetailView`, `BeanAddForm`, `RecipeRows` (shared), `RecipeBlock`, `RecipeSheet`, `RatingChart` |
| `Views/Hardware/` | Hardware tab, detail, add form |
| `Views/Onboarding/` | four-step onboarding; also home of `OnbField` / `OnbCombobox` |
| `Views/About/` | About sheet, `ModeSwitch`, `TempUnitSwitch` |

---

## 3. Architecture in five lines

1. **One `NavigationStack`** in `MainTabView`; all four tab screens stay mounted (opacity-switched) so Log state survives tab changes; detail screens push via `NavRoute(PersistentIdentifier)` and render their own `PSNavBar`.
2. **Design system via environment.** `\.psPalette` (resolved from `colorScheme`) and `\.psTempUnit` are injected once in `MainTabView`. Sheets do not inherit environment: every `.sheet { }` re-applies both.
3. **SwiftData, local only.** Four models; bean→shots and equipment→shots are both nullify, and deleting a bean files its shots under "Unknown" (`ShotReassignment.deleteBean`). Photos use `@Attribute(.externalStorage)`. `AppSettings` is a singleton row created by `SeedData`.
4. **`Recipe` is a Codable value** stored as JSON on `Bean`; every field optional, nil means "not specified". Temperatures are stored in Celsius everywhere and converted only at the UI edge.
5. **Four deliberate UIKit exceptions** live in `Utilities/` (swipe-back, select-all-on-focus, share sheet) and `SliderField` (pan recognizer). Everything else is SwiftUI.

Read DESIGN.md §2–§6 before changing navigation, the data model, the recipe-prompt rules or the timer.

---

## 4. Conventions

- SwiftUI first; add UIKit only as an isolated, documented utility.
- No force unwraps, no `print`/logging, no `UserDefaults` (settings live in `AppSettings`).
- New persisted properties on a `@Model` **must carry an inline default** (`var foo: Bool = false`) so SwiftData lightweight migration backfills existing rows.
- Never call `.navigationBarBackButtonHidden(true)`; it kills the swipe-back gesture.
- Every photo entry point goes through `PSPhotoSourceMenu` → `PSPhotoCropSheet` (square JPEG).
- Strings are English-only and hard-coded. Dates on screen go through `PSFmt`, which follows the phone's region and 12/24-hour setting; only the CSV export keeps fixed ISO dates (`yyyy-MM-dd HH:mm`).
- Fonts go through `PSFont` (Dynamic Type scaled, capped 1.5×); every `PSIconBtn` needs an accessibility label; `PSToggle` takes one too.
- Sub-page top bars use the compact `PSNavBar` with `PSNavBackButton` / `PSNavTextButton` / `PSNavSaveButton` (`PSNavMetrics` sizes: 48 pt buttons, 22 pt title, 21 pt actions); don't hand-roll small header buttons.
- Views **show** photos through the models' `photo`, never `photoData`: once a model is deleted and saved, loading its external-storage photo is a fatal SwiftData error, and SwiftUI may redraw a card for it one last time (DESIGN.md §4.1, §10.3).
- Pure logic (recipe prompt rules, conversions, formatters) gets a unit test in `Pull StateTests`.
- Doc comments on every type explain *why* it exists; keep them current when behaviour changes.
- When a screen's behaviour changes, update the matching DESIGN.md section in the same commit.

---

## 5. Build & ship

Building needs Xcode on macOS.

```bash
# compile-only sanity check (no signing)
xcodebuild build -scheme "Pull State" -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

# unit tests on the simulator (LiveDeleteTests also opens real windows in the test host;
# -collect-test-diagnostics never stops a crashing test from hanging the run)
xcodebuild test -scheme "Pull State" -destination 'platform=iOS Simulator,name=iPhone 17' -collect-test-diagnostics never
```

- Releases are archived, signed with an App Store Connect API key and uploaded to TestFlight by the maintainer's release script, which is not part of this repo.
- Build number (`CURRENT_PROJECT_VERSION`) is a `YYYYMMDDHHMM` timestamp set by the release script.
- Marketing version is passed to the release script **and** should be bumped in `project.pbxproj` so the repo matches TestFlight.
- Marketing versions are `<YY>.<major>.<minor>` from 26.1.5 on (1.0–1.4 were plain `1.x`). `YY` is the last two digits of the year the release ships. `major` goes up only for major updates and never resets, not even on a new year. `minor` goes up by one on every TestFlight or App Store upload and goes back to 0 when `major` goes up: 26.1.5 → 26.1.6 → 26.2.0 → 27.2.1. The App Store compares versions number by number (26.1.10 is above 26.1.9) and only needs each release to be higher than the live one, which this scheme always is; once a 26.x release is live, no 1.x version can be submitted again. Bump `minor` in `project.pbxproj` in the commit being shipped and pass the same version to the release script; only a `major` bump needs the user's go-ahead. 26.1.5 was uploaded twice (builds 202611041742 and 202611041806) before this rule, so 26.1.6 is next. Since every build has its own version, an App Store submission uses the version of the build picked for it. TestFlight has only the internal group, so a new version needs no beta review.

The shared scheme already selects `PullState.storekit` (Run → Options → StoreKit Configuration), so the tip jar works in the Simulator.

---

## 6. Release history

| Version | Highlights |
|---|---|
| 1.0 | Initial App Store release: Log / History / Beans / Hardware, SwiftData, tip jar |
| 1.1 | Photos, recipe sheet, temperature unit, smarter recipe prompts, scrollable rating chart |
| 1.2 | Full-width scroll, editable photo headers, paper-filter filter, light/dark icons |
| 1.3 | Data protection entitlement, pre-infusion pressure, recipe-prompt toggle, slider scroll passthrough |
| 1.4 | Pre-infusion pressure slider range, pull pressure label, Restore Purchases, version read from bundle |
| 26.1.5 | First release on the `<YY>.<major>.<minor>` scheme; its first TestFlight builds (202610302343, 202611012216) were labelled 1.5. Documentation pass (audit, wiki, CLAUDE.md), then the audit cleanup: Log state survives tab switches, °F recipe fix, notes no longer select-all, downscaled + cached photos, StoreKit transaction listener, Dynamic Type, accessibility, iOS-only build config, Swift 6, unit tests. Then (30 Oct) logging without setup: Source rows always shown and pulsing until set up, "+ New …" in every picker, hardware optional, bean named at save time (blank = "Unknown"); re-filing shots later (Shot edit with None / + New / grind, History Select → bulk edit, backfill offer when hardware is added, empty "Unknown" bean tidied away); About → Export shots (CSV) and Wipe Data (three scopes, double confirmation). Then (1 Nov, TestFlight feedback on build 202610302343): Export Shots became a row under Recipe Suggestions that asks first and shares a real `.csv` file, Wipe Data moved right under it; the Wipe Data crash (deleted hardware's photo read during a redraw) fixed via the display-safe `photo`; sub-page top bars 1.5× larger, with Cancel replacing Back while editing. Then (4 Nov): renamed 1.5 → 26.1.5; About gained a **Website** row (badc0ffe.net) between Built by and Contact. Then (4 Nov, the audit's open decisions): deleting a bean keeps its shots under "Unknown" (bean→shots is now `.nullify`); dates follow the phone's region and 12/24-hour setting; the tab screens' "…", "+", Select and "+ Add" buttons are 1.5× larger; the App Store screenshots and duplicate design files left the repo |

---

## 7. Where to look when…

| Task | Start at |
|---|---|
| Change what happens after Save Shot | `Utilities/RecipePromptEvaluator.swift` (rules in DESIGN.md §3.1, tests in `Pull StateTests`) |
| Add a field to a shot | `Models/Shot.swift` (inline default!), `LogScreen` state + `save()`, `ShotDetailView` draft/commit, DESIGN.md §4.2 |
| Add a recipe field | `Models/Recipe.swift` (CodingKeys + decodeIfPresent), `RecipeBlock` + `RecipeSheet` (rows from `RecipeRows.swift`), preload in `LogScreen.preloadFromBean` |
| Tweak colours or type | `Resources/Theme.swift` |
| Timer behaviour | `LogScreen` state machine + `DualTrackTimer` (DESIGN.md §6) |
| Saving with no setup, the bean-name prompt | `LogScreen.save` / `saveWithQuickBean`, `Bean.quickAdd` (DESIGN.md §3.1) |
| Deleting a bean (shots move to "Unknown") | `ShotReassignment.deleteBean`, `BeanDetailView.deleteMessage` (DESIGN.md §3.3, §4) |
| Date formats | `PSFmt` in `Resources/Theme.swift` (tests in `ModelAndFormatTests`; DESIGN.md §5.2) |
| Moving shots between beans / hardware | `Utilities/ShotReassignment.swift`, `ShotDetailView` edit mode, `ShotBulkEditSheet`, `HardwareAddForm` backfill (DESIGN.md §3.2, §3.4) |
| CSV export columns / format | `Utilities/ShotCSV.swift` (tests in `ShotCSVTests`; DESIGN.md §10.3) |
| How the export reaches the share sheet | `AboutSheet.exportRow` / `exportShots`, `Utilities/ShareSheet.swift` (DESIGN.md §10.3, §15.5) |
| Wipe Data | `Utilities/DataWiper.swift`, `AboutSheet` Wipe Data button (DESIGN.md §10.3; UI-level tests in `LiveDeleteTests`) |
| A crash reading a photo after a delete | `Models/PersistentModel+Detached.swift`; show photos via `photo` (DESIGN.md §4.1) |
| Top bar sizes and layout (tabs and sub-pages) | `Views/Components/PSNavBar.swift` (`PSNavMetrics`, DESIGN.md §5.3) |
| Reading TestFlight crash reports | App Store Connect API: `GET /v1/apps/{id}/betaFeedbackCrashSubmissions`, then `/v1/betaFeedbackCrashSubmissions/{id}/crashLog` (already symbolicated). Pull State's app id is 6765922700 |
| Hardware autocomplete list | `Utilities/HardwareCatalog.swift` |
| IAP | `Utilities/StoreManager.swift`, `AboutSheet`, `PullState.storekit` |
| Privacy / App Store compliance | `PrivacyInfo.xcprivacy`, entitlements, `INFOPLIST_KEY_*` in pbxproj, `docs/privacy.html` |
| Open bugs and cleanup backlog | newest `docs/AUDIT-*.md` |

---

## 8. Deferred (V2) — do not build without scoping

Barcode scanning, AI shot diagnosis, iCloud sync, Home Screen widget, share-as-image, cross-bean charts. See DESIGN.md §17. (CSV export shipped in 26.1.5.)
