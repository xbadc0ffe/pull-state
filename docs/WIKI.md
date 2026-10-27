# Pull State — Project Wiki

The working reference for anyone (human or agent) touching this repo. DESIGN.md is the long-form spec of *what the app does*; this page is *how the project is built, shipped and organised*. When the two disagree with the code, the code wins; fix the doc.

---

## 1. At a glance

| | |
|---|---|
| App | Pull State — local-only espresso shot logbook |
| Platforms | iPhone + iPad (iOS / iPadOS 26.4+), single SwiftUI target |
| Stack | SwiftUI, SwiftData, StoreKit 2, PhotosUI. No third-party dependencies |
| Bundle ID | `com.badc0ffe.pullstate` |
| Team | ZWS3TP3W3Z |
| Repo | github.com/xbadc0ffe/pull-state (MIT) |
| Current release | 1.4 (App Store) → 1.5 on TestFlight |
| Tip-jar IAP | `com.badc0ffe.pullstate.tip`, non-consumable, nothing gated |

---

## 2. Repository layout

```
pull-state/
├── CLAUDE.md                 project rules for Claude Code sessions
├── README.md / SECURITY.md / LICENSE
├── Pull State.xcodeproj/     single target "Pull State", shared scheme "Pull State"
├── Pull State/               app sources (see §3)
├── docs/
│   ├── DESIGN.md             full design + behaviour spec (screens, data model, timer, IAP)
│   ├── WIKI.md               this file
│   ├── AUDIT-YYYY-MM-DD.md   dated audit reports; newest is the open backlog
│   └── privacy.html          privacy policy published via GitHub Pages
├── branding/                 app icons, logo, App Store screenshots
└── design/                   original Claude Design mockups (HTML/PDF/zip)
```

### Source tree (`Pull State/`)

| Folder | Contents |
|---|---|
| `Pull_StateApp.swift` | `@main`; builds the `ModelContainer`, installs `SelectAllOnFocus` |
| `Models/` | SwiftData `@Model`s: `Shot`, `Bean`, `Equipment`, `AppSettings`; value types `Recipe`, `BeanRatingPoint`; enums |
| `Resources/` | `Theme.swift` (palette, fonts, formatters, env keys), `PullState.storekit` |
| `Utilities/` | `StoreManager` (StoreKit 2), `SeedData` (settings singleton), `HardwareCatalog`, `SwipeBackFix`, `SelectAllOnFocus` |
| `Views/RootView.swift` | onboarding ↔ main switch, applies colour scheme |
| `Views/MainTabView.swift` | the single `NavigationStack`, `NavRoute`, tab switch, About/Add sheets |
| `Views/Components/` | `PS*` design-system views (card, field, pill, stars, nav bar, tab bar, photo picker/crop/thumb, toggle, layout) |
| `Views/Log/` | Log tab: `LogScreen`, `DualTrackTimer`, `SliderField`, `PickerRow` |
| `Views/History/` | History tab, `ShotCard`, `ShotDetailView`, filter + sort sheets |
| `Views/Beans/` | Beans tab, `BeanDetailView`, `BeanAddForm`, `RecipeBlock`, `RecipeSheet`, `RatingChart` |
| `Views/Hardware/` | Hardware tab, detail, add form |
| `Views/Onboarding/` | four-step onboarding; also home of `OnbField` / `OnbCombobox` |
| `Views/About/` | About sheet, `ModeSwitch`, `TempUnitSwitch` |

---

## 3. Architecture in five lines

1. **One `NavigationStack`** in `MainTabView`; tabs are a state switch, detail screens push via `NavRoute(PersistentIdentifier)` and render their own `PSNavBar`.
2. **Design system via environment.** `\.psPalette` (resolved from `colorScheme`) and `\.psTempUnit` are injected once in `MainTabView`. Sheets do not inherit environment: every `.sheet { }` re-applies both.
3. **SwiftData, local only.** Four models, cascade on bean→shots, nullify on equipment→shots. Photos use `@Attribute(.externalStorage)`. `AppSettings` is a singleton row created by `SeedData`.
4. **`Recipe` is a Codable value** stored as JSON on `Bean`; every field optional, nil means "not specified". Temperatures are stored in Celsius everywhere and converted only at the UI edge.
5. **Three deliberate UIKit exceptions** live in `Utilities/` (swipe-back, select-all-on-focus) and `SliderField` (pan recognizer). Everything else is SwiftUI.

Read DESIGN.md §2–§6 before changing navigation, the data model, the recipe-prompt rules or the timer.

---

## 4. Conventions

- SwiftUI first; add UIKit only as an isolated, documented utility.
- No force unwraps, no `print`/logging, no `UserDefaults` (settings live in `AppSettings`).
- New persisted properties on a `@Model` **must carry an inline default** (`var foo: Bool = false`) so SwiftData lightweight migration backfills existing rows.
- Never call `.navigationBarBackButtonHidden(true)`; it kills the swipe-back gesture.
- Every photo entry point goes through `PSPhotoSourceMenu` → `PSPhotoCropSheet` (square JPEG).
- Strings are English-only and hard-coded; date formats are fixed `yyyy-MM-dd HH:mm`.
- Doc comments on every type explain *why* it exists; keep them current when behaviour changes.
- When a screen's behaviour changes, update the matching DESIGN.md section in the same commit.

---

## 5. Build & ship

Work is written on Windows, pushed to GitHub, and built on the headless Mac mini over SSH.

```bash
# compile-only sanity check (no signing)
xcodebuild build -scheme "Pull State" -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

# archive, sign with the ASC API key and upload to TestFlight
ship "Pull State" 1.5          # ~/bin/ship; pulls first, build number = timestamp
```

- Build number (`CURRENT_PROJECT_VERSION`) is a `YYYYMMDDHHMM` timestamp set by `ship`.
- Marketing version is passed to `ship` **and** should be bumped in `project.pbxproj` so the repo matches TestFlight.
- Signing is automatic with the App Store Connect API key (`~/.asc_env`, `~/ExportOptions.plist`). Never sign in with an Apple ID on the server.
- Archives land in `~/Archives`; prune when disk is tight.
- If signing fails with a keychain error the login keychain is locked: `security unlock-keychain ~/Library/Keychains/login.keychain-db`.

Simulator tip-jar testing needs `PullState.storekit` selected under the scheme's Run → Options → StoreKit Configuration (not currently saved in the shared scheme).

---

## 6. Release history

| Version | Highlights |
|---|---|
| 1.0 | Initial App Store release: Log / History / Beans / Hardware, SwiftData, tip jar |
| 1.1 | Photos, recipe sheet, temperature unit, smarter recipe prompts, scrollable rating chart |
| 1.2 | Full-width scroll, editable photo headers, paper-filter filter, light/dark icons |
| 1.3 | Data protection entitlement, pre-infusion pressure, recipe-prompt toggle, slider scroll passthrough |
| 1.4 | Pre-infusion pressure slider range, pull pressure label, Restore Purchases, version read from bundle |
| 1.5 | Documentation pass (audit, wiki, CLAUDE.md); no functional change — baseline for the cleanup round |

---

## 7. Where to look when…

| Task | Start at |
|---|---|
| Change what happens after Save Shot | `LogScreen.save()` → `evaluateRecipePrompt` (rules in DESIGN.md §3.1) |
| Add a field to a shot | `Models/Shot.swift` (inline default!), `LogScreen` state + `save()`, `ShotDetailView` draft/commit, DESIGN.md §4.2 |
| Add a recipe field | `Models/Recipe.swift` (CodingKeys + decodeIfPresent), `RecipeBlock`, `RecipeSheet`, preload in `LogScreen.preloadFromBean` |
| Tweak colours or type | `Resources/Theme.swift` |
| Timer behaviour | `LogScreen` state machine + `DualTrackTimer` (DESIGN.md §6) |
| Hardware autocomplete list | `Utilities/HardwareCatalog.swift` |
| IAP | `Utilities/StoreManager.swift`, `AboutSheet`, `PullState.storekit` |
| Privacy / App Store compliance | `PrivacyInfo.xcprivacy`, entitlements, `INFOPLIST_KEY_*` in pbxproj, `docs/privacy.html` |
| Open bugs and cleanup backlog | newest `docs/AUDIT-*.md` |

---

## 8. Deferred (V2) — do not build without scoping

Barcode scanning, AI shot diagnosis, CSV export, iCloud sync, Home Screen widget, share-as-image, cross-bean charts. See DESIGN.md §17.
