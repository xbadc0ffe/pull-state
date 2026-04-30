# Pull State

A precision logbook for your espresso practice — track every shot, dial in your beans, watch yourself improve.

## Features

- Log shots with a dual-track pre-infusion + pull timer; the bar and First Drip / Done buttons turn green while you're inside the bean's target window
- Per-bean recipes that auto-preload grind, dose, yield, temperature, and pressure on the Log screen
- After each shot, a smart prompt either offers to **save** the recipe (when fields are missing) or to **adjust** it (when the pull matches or beats your best for that bean and the values differ from the saved recipe — dose/yield compared with ±10% tolerance)
- Equipment pre-fills from your most recent shot, and a new bag with the same Name + Roaster as a previous bean inherits that bean's recipe
- View / edit a bean's full recipe from the Log screen via a dedicated sheet
- Bean library with rating trend charts (10 most recent shots, horizontally scrollable, smooth Catmull-Rom curve), photos, and editable recipes
- Hardware library for espresso machines and grinders, with photos, shot counts, and an autocomplete catalog of common manual / lever machines and grinders
- Filter and sort shot history by extraction, rating, tasting notes, bean, machine, or grinder
- Light / dark / system appearance and Celsius / Fahrenheit — selectable on first run and from About
- Take photos in-app or pick from the library for shots, beans, and hardware
- Optional tip jar via in-app purchase, with prior-purchase restore on fresh installs

## Tech Stack

- **SwiftUI** — declarative UI, custom design system
- **SwiftData** — local persistence, no third-party dependencies
- **iOS 18** — minimum deployment target
- **Multiplatform** — iPhone and iPad, single Swift codebase

## Documentation

See [docs/DESIGN.md](docs/DESIGN.md) for architecture, screen specs, and the data model.

## Contributing

Issues and pull requests welcome. Read `CLAUDE.md` for project conventions before opening a PR.

## License

MIT — see [LICENSE](LICENSE).

## Contact

**badc0ffe** · github.com/xbadc0ffe/pull-state
info@badc0ffe.net
