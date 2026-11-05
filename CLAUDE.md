# Pull State — project instructions

iOS/iPadOS espresso logbook. SwiftUI + SwiftData, single target, no dependencies, local-only data. Read `docs/WIKI.md` first (layout, conventions, ship flow); `docs/DESIGN.md` is the behaviour spec; the newest `docs/AUDIT-*.md` is the open backlog.

## Working here
- Code is authored on Windows and pushed; this Mac mini only builds and ships. Always `git pull --ff-only` before building.
- Compile check: `xcodebuild build -scheme "Pull State" -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
- Ship: `ship "Pull State" <marketing-version>` (see `~/bin/ship`). Versions are `<YY>.<major>.<minor>` (WIKI.md §5). Every TestFlight/App Store upload gets the next minor version: bump `MARKETING_VERSION` in `Pull State.xcodeproj/project.pbxproj` (e.g. 26.1.5 → 26.1.6) in the commit being shipped and pass the same version to `ship`. Major bumps are the user's call.
- Commit messages follow the existing style: `v<version> <short summary>` for release passes (e.g. `v26.1.5 …`; older commits say `v1.x`), imperative otherwise.

## Code rules
- SwiftUI only. UIKit is allowed solely as a small, documented utility (`Utilities/`, `SliderField`); explain *why* in the file header.
- No force unwraps, no `print`/logging, no `UserDefaults`, no network, no third-party packages.
- New `@Model` properties need an inline default so existing stores migrate.
- `Recipe` fields are optional and nil means "unset"; never write a default over nil. Temperatures are stored in Celsius; convert only at the UI boundary via `\.psTempUnit`.
- Every `.sheet` must re-apply `.environment(\.psPalette, …)` and `.environment(\.psTempUnit, …)`.
- Never use `.navigationBarBackButtonHidden(true)` (breaks swipe-back).
- Photos go through `PSPhotoSourceMenu` + `PSPhotoCropSheet`; store square JPEG `Data?` with `@Attribute(.externalStorage)`.
- Views display photos through the model's `photo`, never `photoData` (reading a deleted model's photo crashes SwiftData; DESIGN.md §4.1). Forms still load/save `photoData`.
- Dates on screen go through `PSFmt` (region and 12/24-hour aware); only the CSV export uses fixed ISO dates.
- Delete beans through `ShotReassignment.deleteBean`, which keeps their shots under "Unknown".
- Sub-page top bars: compact `PSNavBar` + `PSNavBackButton` / `PSNavTextButton` / `PSNavSaveButton` / `PSNavCloseButton`, sized by `PSNavMetrics`.
- Keep doc comments and the matching DESIGN.md section in sync with any behaviour change.
- Features on the V2 list (DESIGN.md §17) are out of scope unless explicitly requested.

## Before reporting done
- Compile check passes with no new warnings.
- DESIGN.md / WIKI.md updated if behaviour, data model, or build process changed.
