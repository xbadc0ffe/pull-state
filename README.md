# Pull State

A precision logbook for your espresso practice — track every shot, dial in your beans, watch yourself improve.

## Features

- Log shots with a dual-track pre-infusion + pull timer, with green target windows when the bean's recipe sets a target time
- Per-bean recipes that auto-preload dose, yield, temperature, and pressure on the Log screen — and an "Save as recipe?" prompt that fills in missing fields after a shot
- View / edit a bean's full recipe from the Log screen via a dedicated sheet
- Bean library with rating-trend sparklines, photos, and editable recipes
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
