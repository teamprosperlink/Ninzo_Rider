# Building the Rider App from Figma

The app is being rebuilt to match the Figma design **screen for screen**.
Figma file `SJCZJDDoZBP2Skwvu7zdvs` ("Ninzo Project"), page **Rider App - High-Fi Screens**.
All screens, with node ids, are listed in [figma_screens.md](figma_screens.md).
The flow (where each button leads) is on the page **Rider App - 🧭 Flow Map** (`128717:2188`).

## Rule 1: Figma is read-only

Only *read* Figma: `get_metadata`, `get_screenshot`, `get_design_context`, `get_variable_defs`.
Never call `use_figma`, `generate_figma_design`, `upload_assets`, `add_code_connect_map`,
`send_code_connect_mappings`, `create_new_file` or anything else that writes to Figma.

## What to build (from the Developer handoff frame in Figma)

- All 168 screens except: the 7 **Offer** screens (on hold). **Choose a spot** (Shift 13–18) is built but reachable in demo only: the flow map has no arrow into it.
- Main flow: Onboarding → Login → Register → morning stock request push → Home → Before you start →
  hub trip → Stock scan → Go online at spot → Online waiting (main map) → Order → Gate arrival →
  Handover → next order or back to waiting.
- Rules:
  - Orders are **auto-assigned** when the rider is at the spot. No Accept button. The **90 s clock**
    starts at assignment.
  - The system assigns hub and spot. Registration asks for the rider's **area** (town, junction or
    city) via search or current location (Register 14–16). One rider per spot.
  - Go online only after stock is scanned and confirmed (Stock 06); otherwise Shift 51 "Stock empty".
  - 1 hour before shift start: push asking the rider to confirm they're coming. Hub packs only after
    confirmation. No reply: reminder at 30 min, no stock packed.
  - Offline scans are saved and synced later. Going online needs signal.
  - Payment: **UPI or cash on delivery** only. The customer code step is for **UPI orders only**.
  - Order queue: up to 5 orders (1 now + 4 queued). Low stock alert at 5 items or fewer.
  - Add time options: 15, 30, 45 min, 1, 2, 3, 4 h. No action: shift ends on time.
  - Go offline ends the shift (Shift 48–50).
  - Cash order cancelled: no cancellation charge, no trip pay (Navigate 05).
  - The scooter is electric; Shift 31 shows battery %.
  - Login 16 "Account on hold" when the account is on hold.
  - Wording: screens say "items"; item lists show quantity on the right.
- Sample values in the designs (Ravi, Hub 2, Yelahanka Node, 9:00 AM, amounts, menu names) are
  placeholders: real values come from data. In demo mode use the same sample values.

## Design system: reuse, don't redraw

- Tokens: `lib/core/constants/app_colors.dart` and `lib/core/theme/app_theme.dart` (`RiderColors`, `RiderText`, `RiderSpace`, `RiderRadius`,
  `riderShadow`). Names match the Figma variables (e.g. `Text/Grey` = `RiderColors.grey`,
  `Heading/H4` = `RiderText.h4`). Font: Inter (bundled).
- Components: `import 'core/widgets/rider/rider_ui.dart'` gives `RiderScaffold`, `RiderHeader`,
  `RiderTitleBlock`, `RiderButton` (primary / secondary / ghost / inverse / danger), `RiderBackButton`,
  `RiderLink`, `RiderCard`, `RiderListRow`, `RiderIconTile`, `RiderKeyValueRow`, `RiderItemRow`,
  `RiderStatsCard`, `RiderStatusPill`, `RiderAvatar`, `RiderStepBars`, `RiderProgressBar`,
  `RiderCountdownRing`, `RiderCheckCircle`, `RiderNotice`, `RiderTextField`, `RiderCodeBoxes`,
  `RiderKeypad`, `RiderMapLayout`, `RiderSheet`, `showRiderSheet`, `RiderMapCard`, `RiderMapLabel`.
- If a design needs something these can't express, extend the component (keep existing callers
  working) or add a new one under `lib/core/widgets/rider/`. Don't hardcode one-off styles in screens
  when a token exists.
- Maps: the grey blocks in the designs are a placeholder ("swap for MapLibre / Mapbox"). Use the real
  `MapView` (`lib/core/widgets/map_view.dart`) and draw the design's markers/labels on it.
- Status bar and gesture bar in the designs are the phone's own: don't draw them.
- Icons: use the closest Material icon. Download a Figma asset (illustration/photo) into
  `assets/images/` only when no icon fits, and never reference temporary Figma URLs in code.

## Architecture: Clean Architecture + MVVM (keep it)

By layer: `lib/domain/{entities,repositories,usecases}` (pure Dart) →
`lib/data/{models,repositories,datasources/{remote,local}}` → `lib/injection_container.dart` (providers;
the only place that imports `data/`) → `lib/presentation/<feature>/{views,viewmodels,providers,widgets}`.
Business rules live in use cases; views hold
no logic. Riverpod 3. Every enum-to-screen link lives in `lib/routing/app_router.dart`.

## Demo mode

`kDemoMode` (`lib/core/constants/app_mode.dart`, `--dart-define=DEMO=true`). `lib/injection_container.dart`
returns an in-memory demo repository in demo mode, seeded with the Figma sample values, so every
screen is reachable on a phone without a backend. Time-based backend events (hub packing, order
assignment) are simulated with short delays.

## Checking each screen against Figma

1. For each screen: `get_design_context` (high fidelity) + its screenshot. Build it.
2. Add it to the on-device screenshot test for the section:
   `integration_test/figma/<section>_test.dart`, screenshot named after the Figma title,
   e.g. `login_06_wrong_code`. Drive state through fake repositories (see `test/fakes.dart`).
3. Run on the emulator:
   `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/figma/<section>_test.dart -d emulator-5554`
   (screenshots land in `build/screens/`).
4. Compare each screenshot with the Figma screenshot; fix layout, spacing, colour, type and copy
   until they match. Text must match the design exactly.
5. Keep `flutter analyze` clean and `flutter test` green.
