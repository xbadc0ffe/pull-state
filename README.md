# Pull State

A local-only espresso shot logbook for iPhone and iPad — for home baristas who want to dial in beans deliberately rather than guess.

## Screenshots

App Store screenshots for iPhone and iPad live in [`branding/`](branding/).

## Features

- Shot logging with a dual-track pre-infusion + pull timer
- Per-bean recipes (grind, dose, yield, water temperature, pre-infusion and pull times and pressures), preloaded onto the Log screen and updated through smart "Save recipe?" / "Adjust recipe?" prompts
- Equipment library for espresso machines and grinders, with autocomplete catalog and live shot counts
- Bean library with bag numbering, photos, processing details, the bag's claimed tasting notes, and a per-bean rating trend chart
- Filterable and sortable shot history (extraction, tasting tags, rating, bean, machine, grinder, with/without paper filter)
- Tip-jar in-app purchase — no features are gated behind it
- Light / dark / system appearance and Celsius / Fahrenheit, selectable from Onboarding and About
- iPhone and iPad layouts from a single SwiftUI codebase

## Requirements

- iOS 26.0+ / iPadOS 26.0+
- Xcode 27+ (Swift 6 language mode)
- No third-party dependencies

## Building

1. Clone the repository.
2. Open `Pull State.xcodeproj` in Xcode.
3. Select an iOS or iPadOS simulator (or a connected device with provisioning configured).
4. Build and run with ⌘R.

The shared **Pull State** scheme references `Pull State/Resources/PullState.storekit` as its StoreKit Configuration, so the tip-jar purchase sheet works in the Simulator without any App Store Connect setup.

Unit tests (Swift Testing) live in `Pull StateTests` and run with ⌘U or:

```
xcodebuild test -scheme "Pull State" -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Architecture

Pull State is a SwiftUI app backed by SwiftData, with no third-party dependencies. All data is local to the device — no accounts, no backend, no analytics, no network requests.

The UI is structured around a single `NavigationStack` and four launch-time tabs — **Log**, **History**, **Beans**, **Hardware** — wrapped by a custom design system (`PSPalette`, `PSFont`, and the reusable components in `Views/Components/`). Detail screens push onto the same stack via a `NavRoute` enum and render their own navigation chrome. Sheets handle add-bean / add-hardware / about / recipe / filter / sort flows.

For the full file map, the SwiftData schema, screen specifications, timer behaviour, IAP wiring, and the deferred V2 list, see [docs/DESIGN.md](docs/DESIGN.md). [docs/WIKI.md](docs/WIKI.md) covers repo layout, conventions and the build/ship flow.

## Contributing

Pull State is open source under the MIT licence. Issues and pull requests are welcome — for anything non-trivial, please open an issue first so we can align on the approach. Match the existing style: SwiftUI-first (the few intentional UIKit exceptions are documented in `Pull State/Utilities/`), no force unwraps in shipped code, and no third-party SPM dependencies.

## Licence

MIT — see [LICENSE](LICENSE).
