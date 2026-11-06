# Plan — Pour over support

Status: **proposed, not started** (written 2026-11-06). Nothing here is built yet. When work starts, settle the open questions in §6 with the user first, then move the decisions into DESIGN.md as each part ships.

---

## 1. Why

The maintainer no longer drinks espresso but brews pour over daily. Adding pour over keeps the app in daily use, and it suits the app's main loop: dial in a bean → brew → rate → adjust the recipe.

Pour over brewers track as much as espresso people do, often more:

| Variable | Typical range | Notes |
|---|---|---|
| Coffee dose | 10–40 g | |
| Total water | 150–700 g | Shown as a ratio, usually 1:15–1:17 |
| Grind setting | free text | Much coarser than espresso; same grinder can serve both |
| Water temperature | 85–100 °C | Often varied by roast (lighter = hotter) |
| Bloom water / time | ~2–3× dose, 30–45 s | |
| Number of pours | 1–6 | Single pour, pulse pours, etc. |
| Total brew / drawdown time | ~2:30–4:00 | |
| Brewer and filter | V60, Kalita Wave, Chemex, Origami, April, Hario Switch… | |

## 2. Who it must serve

Two kinds of pour over user, and the design has to work well for both:

1. **Hands-off / automatic brewers.** The maintainer has ordered a Fellow pour-and-walk-away brewer. The machine handles the pouring, so what matters is **grind, dose, water weight and temperature** (plus the machine's program settings such as bloom and pulses, if the user wants to record them). A timer is not needed. Logging one should take a few seconds.
2. **Manual, more involved brewers.** Kettle and dripper users who care about bloom, pour count and timing and want a timer. The pour over side should be strong enough for them too, not a reduced copy of the espresso side.

So the core fields are **grind, dose, water, temp** (always shown). Everything else (bloom, pours, timer, brewer program details) is **optional**: a blank value means "not recorded", in the same way `Recipe` fields use nil.

## 3. What carries over unchanged

Beans, grinders, photos, rating, tasting tags, Sour / Perfect / Bitter, History (cards, detail, select + bulk edit), re-filing to beans and hardware, CSV export, Wipe Data, °C/°F handling and the recipe-suggestion prompts all apply to pour over as they are. Most of the work is in the data model, the Log screen and the recipe prompts.

| Part | Espresso today | Pour over |
|---|---|---|
| Beans, grinders, photos, rating, tasting notes, extraction | ✓ | Reused as is |
| Dose / yield / temp sliders | 7–25 g / 7–75 g / 70–105 °C | Same fields, ranges ~10–40 g dose, ~150–700 g water; show the ratio live |
| Two-stage timer (pre-infusion → pull) | ✓ | **Bloom → brew**, longer tracks; optional (hidden or collapsed for automatic brewers) |
| Pressure sliders, Paper Filter toggle | ✓ | Hidden |
| Espresso machine | ✓ | Replaced by a **Brewer** (dripper or automatic machine) |
| Bean recipe + "Save / Adjust recipe?" prompts | One recipe | A **separate pour over recipe** per bean (grind and ratio differ completely) |

## 4. Plan

1. **Data model** (all new `@Model` properties need inline defaults so existing stores migrate)
   - `Shot` gets a method (`methodRaw: String = "espresso"`), so every existing entry stays espresso. Reusing `Shot` rather than adding a separate `Brew` model keeps History, reassignment, Wipe Data and CSV working without duplicating them. (Decide in code review whether the UI calls pour over entries "brews"; it should.)
   - New optional pour over fields on `Shot`: bloom water, bloom time, pour count, total brew time, and a free-text or structured note of the brewer's program settings (for automatic brewers).
   - `Shot.yield` holds total water for pour over (document this), or add a dedicated `water` field if that reads more clearly. Decide when implementing.
   - `EquipmentKind` gets `.brewer`, with an "automatic" flag or sub-type so the Log screen can hide the timer for automatic brewers. `HardwareCatalog` gains common drippers and automatic brewers (Fellow included).
   - `Bean` gets a second recipe (`pourOverRecipeData`), using a pour over `Recipe` variant: grind, dose, water, temp, bloom water/time, pours, brew time. All optional, nil = unset, Celsius stored.
2. **Log screen**
   - An **Espresso | Pour Over** switch at the top of Log (see §6, question 1), remembered in `AppSettings` (not `UserDefaults`).
   - Pour over mode: Source shows Brewer / Grinder / Beans; sliders for dose, water, temp with a live ratio; optional bloom and pours section; pressure and paper filter hidden.
   - Recipe preload and the "Loaded from … recipe" caption use the pour over recipe.
3. **Timer**
   - `DualTrackTimer` gets a mode: **BLOOM → BREW**, buttons START / BLOOM DONE / DONE, default tracks ~45 s bloom and ~3:30 brew, and green windows of about ±5 s bloom / ±15 s brew around the recipe targets.
   - Hidden or collapsed when the selected brewer is automatic. Manual time entry still works.
4. **Recipe prompts**
   - `RecipePromptEvaluator` gets pour over rules: required fields dose / water / temp (and grind?), tolerances to be tuned (e.g. ±10 % weights, 0.6 °C temp, timer windows as above).
   - Add unit tests next to the espresso ones.
5. **History, Beans, Hardware**
   - Method badge on History cards and detail; method filter in the Filter sheet.
   - Shot detail edit shows the right fields for the method.
   - The bean page shows both recipes (only those with values) and splits the rating chart by method.
   - The Hardware tab gets a Brewers section.
6. **Onboarding, export, docs**
   - Onboarding asks which method(s) the user brews and offers a brewer instead of an espresso machine.
   - CSV export gets a method column plus the pour over columns (update `ShotCSVTests`).
   - Update DESIGN.md (screens, data model, timer, prompts) and WIKI.md (release history, "where to look").
7. **Release** as the next **major** version (see §6, question 2).

Estimated size: a few focused sessions. The Log screen and the recipe prompts are most of the work.

## 5. Out of scope for the first pass

- Other methods (AeroPress, French press, cold brew). The method field makes them easy to add later.
- Talking to the Fellow brewer or any scale over Bluetooth (the app is offline-only, no network).
- The V2 list in DESIGN.md §17.

## 6. Open questions for the user

1. **New tab or a switch?** The user's first idea was a new tab. Recommendation: keep four tabs and put an **Espresso | Pour Over** switch at the top of Log that remembers the last choice (so it always opens on pour over for this user). A fifth "BREW" tab would duplicate Log and crowd the tab bar. User's call.
2. **Version:** pour over is a major feature, so it would be the next major version: 26.2.0 (or 27.2.0 if it ships in 2027). Major bumps need the user's go-ahead.
3. **App name and App Store copy:** "Pull State" is an espresso term. Keep it as a brand? Update the App Store description only when the user says they're ready.
4. **Automatic brewer details:** which Fellow model, and which of its settings (bloom, pulses, temp) are worth recording per brew?
5. **Other methods:** pour over only for now (recommended), or include AeroPress / French press in the first pass?
