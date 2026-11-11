# NinzoRider

Food-delivery **rider** app for Android and iOS. A rider picks up a ready order at the restaurant and hands it to the customer **within 90 seconds**. Orders are created by the customer app or a backend; this app covers everything the rider does.

Stack: Flutter, Riverpod 3, the Ninzo rider API (staging, `STAGING_API_URL` in `.env`), Firebase Cloud Messaging for the push token only, Google Maps (`google_maps_flutter`).

## Rider features

- **Login**: mobile number + OTP, through the rider API.
- **Register** (Figma Section 3): full name, mobile number and **area** (search a town or junction, or use the current location). "Continue" sends an OTP through the rider API on Login's code screen; the API signs in only numbers the operations team has added (status `applicant`), and turns any other number away with `invalid_otp`. The rider API has no field for the name, area or photos yet, so they stay on the phone; "Send for review" starts the verification (`POST /riders/me/verification/start`) and uploads each photo to the `upload_url` it returns. The review result comes from `GET /riders/me/verification` (staging: 404 so far). After approval (`active`) the rider sees their spot, then Home.
- **Morning stock request** (Figma Section 4): 1 hour before the shift a push asks the rider to confirm they're coming (**I'm coming** / **Not today**, right on the notification). The hub packs only after a yes; with no reply a reminder comes at 30 minutes and nothing is packed. "Your stock is ready at Hub 2" when the hub finishes.
- **Home** (Section 5): the rider's day at a glance: stock not requested / off today (Ask hub to prepare), hub packing, stock ready, Start riding, then Collect your stock, Finish scanning and Stock loaded, with today's stock, spot and scooter.
- **Before you start** (Section 6): helmet, phone charged (checked: at least 50% battery), scooter battery (from telemetry), location on (checked), insulated box, scooter clean. Go to hub unlocks when all are ticked.
- **Hub trip** (Section 7): map to the hub with the next turn and directions; arriving (within 100 m) shows the hub's packing progress if it isn't done. Go online without scanned stock shows "Load stock at the hub". Going online at the spot (Section 9) comes next; a placeholder stands in for it.
- **Stock scan** (Section 8): QR scanner (`mobile_scanner`) with the portions loaded so far, the stock list, counts by hand when a code won't scan or the camera is off. Refuses labels not in today's load, duplicates, more than the load, expired lots and lots that got too warm (quarantine). Without signal, scans are saved on the phone and synced when signal returns; confirming the stock and going online need signal. Confirming unlocks Go online.
- **Order** (Figma Sections 11–13): orders are assigned automatically at the spot; there's no Accept, and the **90 s clock runs from the assignment**. The rider sees the gate, the distance and the items, then **Navigate to Gate 3** (turn card, distance, the clock; amber "Almost there" once past 90 s) or **Skip this order** with a reason (Order 04–05). Weak signal, a closed road and leaving the route show on the map (Navigate 01–03).
- **Handover and problem report** (Figma Sections 14–15): at the gate the rider ticks the items and the sealed bag (or checks the quantities, and can hand over less). **UPI**: the customer's 4-digit code, which only the backend can check; a wrong code never locks, and if it keeps failing the rider checks the order's details and hands over. **Cash**: no code, just Collect cash. Without signal the handover is saved on the phone and syncs by itself. Delivered shows the time, the pay, and the next order or the items left. **Report a problem** from the order map, Can't reach customer or Details don't match.
- **Gate arrival** (Section 12): location alone can't confirm arrival. The rider scans the QR code at the gate (`mobile_scanner`) or enters the gate's code; a wrong one says "Almost at the gate!", the camera can be off. Handing over comes next (placeholder until Section 14).
- **Cancelled orders** (Navigate 04–06): UPI pays the rider the lesser of ₹20 and the order's price; cash has no cancellation charge, so no trip pay. The food stays on the scooter, and the next order in the queue follows.
- **Live location**: shared on the order on the way to the gate, so the customer can follow.
- **Earnings**: today's earnings (Earnings 01) and the last 7 days of shifts (Profile 06).
- **Profile** (Figma Section 25): the avatar on Home opens the menu: your profile (read-only), my spot, notifications, my shifts, documents, help centre (FAQ and Contact us: Report a problem, Call hub manager) and log out. Logout is blocked while an order is on its way.
- **Other pushes** (Figma Section 26): spot assigned, shift ending soon, orders waiting elsewhere, away from spot. Local notifications from what the phone sees; FCM is backend work.

## Architecture: Clean Architecture + MVVM

Organised by layer. Data and domain are flat; presentation has one folder per feature. Dependencies only point inwards:

```
presentation  →  domain  ←  data
     (views, viewmodels)   (entities, use cases,   (rider API / device
                            repository contracts)   implementations)
                   injection_container.dart wires data implementations into the use cases
```

- `lib/domain/`: pure Dart. Entities, repository interfaces and **use cases** (one class per action; every business rule lives here: OTP and code checks, which orders to offer, the 90-second window, KYC rules, stats).
- `lib/data/`: the rider API client and session, local JSON mapping, and repository implementations.
- `lib/injection_container.dart`: Riverpod providers for repositories and use cases. The only place that imports a feature's `data/`; tests override the repository providers with fakes.
- `lib/presentation/<feature>/`: **Views** (widgets, no logic) watch **ViewModels** (Riverpod notifiers that call use cases and expose state) and shared state `providers/`.
- The rule is checked by `test/architecture_test.dart`: ViewModels reach repositories only through use cases, Views never import `injection_container.dart`, and domain and data stay free of what points at them. Demo pills (`demo_*.dart`) are the one exception, since they play the backend in demo mode.

```
lib/
  main.dart                  Firebase init (push token) + ProviderScope
  injection_container.dart   Riverpod providers for every feature
  core/
    constants/               app_colors, app_strings (all text), app_sizes, app_numbers (AppLimits, AppMapConfig, AppOpacity), app_durations, app_patterns, app_keys, app_assets, app_mode, demo_data
    api/                     api_endpoints (every endpoint)
    theme/                   app_theme (fonts, text styles, spacing, radius, ThemeData)
    utils/                   validators, formatters, time_format, launcher, clock
    errors/, widgets/, presentation/   errors, shared widgets, base ViewModel
  data/
    models/                  local JSON mapping
    repositories/            repository implementations (rider API, device, demo)
    datasources/remote/      remote lookups that are not repositories (rider directory)
    datasources/local/       local stores, notifications, photo picker
  domain/
    entities/                plain data types
    repositories/            repository contracts
    usecases/                one class per action, and the rules
  presentation/<feature>/    views/, viewmodels/, providers/, widgets/
  routing/app_router.dart    every screen link: AppStage, ShiftScreen, login, register, stock, order and handover steps

Features, in presentation/:
    app/                     MaterialApp, AppGate and AppStage (which root screen to show)
    auth/                    phone OTP login
    intro/                   splash, welcome, permissions, signed out
    account/                 the rider's user record, logout
    profile/                 Profile 01–09: menu, help centre, my spot, notifications, my shifts, your profile, documents
    register/                new rider details, area, documents, review status
    location/                GPS (geolocator)
    shift/                   the rider's day: stock request pushes, Home, pre-shift checklist, hub trip
    stock/                   scanning stock onto the scooter: QR scanner, stock list, counts by hand, offline scans
    orders/                  the order flow: 90 s clock, map, skip, gate QR, cancellations (DeliveryOrder), handover, problem reports; history and offers on hold (old Order)
test/                        unit tests for use cases and entities, widget tests against fake repositories
legacy_backup/               an earlier offline-only version, kept for reference
```

## Backend

Everything goes through the Ninzo rider API (see Rider API below); the phone keeps only what the API has no field for (the day's choices, saved handovers and scans without signal, registration details). Firebase is used for one thing: Cloud Messaging gives the push token that `POST /riders/me/devices` registers. Riders are added and approved by the operations team on the backend.

## Before release

- The backend must give each hub a `managerPhone` for "Call hub manager" (the demo's number is a placeholder).
- **Push**: the backend sends shift pushes through FCM to the token the app registers.

## Run and test

```
flutter run                         # the Ninzo rider API (the default)
flutter run --dart-define=DEMO=true # demo: sample data, no backend
flutter test
```

`flutter build apk` builds for the rider API too. Unit tests keep the flow their fakes are written for. The integration tests in `integration_test/` do the same only when told: run them with `--dart-define=RIDER_API=false`, e.g. `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/figma/home_test.dart --dart-define=RIDER_API=false`.

### Rider API

Every endpoint is in `lib/core/api/api_endpoints.dart`, every call in `lib/data/datasources/remote/rider_api.dart` (the client adds tokens, refresh and Idempotency-Key). The base URL is `STAGING_API_URL` in `.env`. A plain `flutter run` follows the backend flow: sign-in, shift at the node, stock lots, offers (accept/decline), pack before the ride, OTP handover, problems, earnings, restock and relocation all go through the API, with an offline event queue. Every endpoint is used: the live stream brings changes at once (offers via `GET /riders/me/offers`), the phone registers for push after sign-in and is removed on sign-out, the API route is the fallback when Google can't be reached, "Request hub to prepare" sends `POST /restock`, and a failed or expired verification starts again with `POST /riders/me/verification/start`. Profile, My shifts, Documents and Notifications come from the API too. Contract: https://mock-server-production-6a71.up.railway.app/contracts/rider.openapi.yaml.

### Google Maps key

Add `MAPS_API_KEY=your-key` to `.env` at the project root, which git ignores. Without it the map is blank. On iOS, set `GMSApiKey` in `ios/Runner/Info.plist`.

### Demo mode

The demo uses the phone's GPS and Google Routes, so the rider has to reach the hub, spot and gate. `--dart-define=DEMO_SIM_RIDER=true` brings back the rider who moves alone on sample turns, which the tables below describe. `--dart-define=DEMO_REVA=true` adds a first order at Reva Circle.

`flutter run --dart-define=DEMO=true` runs without a backend (code `123456` for any number).

Register (Figma Section 3): tap **New rider? Register** and use one of these numbers; the demo review answers about 8 seconds after **Submit for review** (Register 08):

| Number | Result |
|---|---|
| 90000 00000 | approved → Register 09, Sign in → 10, Got it → Home |
| 90000 00001 | needs a retake (11) → Retake driving licence → resubmit → approved |
| 90000 00002 | verification failed (12) → Upload documents by hand → resubmit → approved |
| 90000 00003 | licence expired (13) → Update driving licence → resubmit → approved |
| any other (e.g. 98765 43210) | "This number is already registered" (03) |

Typing in the area search asks Google Places (New) for real places, in demo mode too; picking one fetches its coordinates. "Use my current location" asks Google Geocoding for the area at the phone's position. With nothing typed the list shows the popular areas.

Today's shift (Figma Sections 4–7). Sign in with any registered number (e.g. 98765 43210, code 123456). The demo shift starts **3 minutes after the app opens** at Hub 2, Yelahanka Node, scooter KA 01 AB 1234, and the day runs on short timers:

| When | What you see |
|---|---|
| on Home | Shift 01 "Stock not requested" |
| 5 s after the app opens | push Notification 05 "Shift starts at …" with **I'm coming** / **Not today** |
| 35 s, with no reply | push Notification 06 "Hub needs to hear from you" |
| Not today | Shift 02 "You're off today"; **Ask hub to prepare** → 03 |
| I'm coming / Ask hub to prepare | Shift 03 "Hub is packing your stock"; the hub accepts after 3 s and packs for 45 s |
| packed | push Notification 07 "Your stock is ready at Hub 2"; Shift 04 |
| the shift starts | Shift 05 "You're offline" (also when still packing) |
| Start riding | Shift 06 "Starting…", then Before you start (10–12): tick every item |
| Go to hub | Shift 52 map (sample turn, rider 1.2 km away); you arrive after 8 s |
| arrive while packing (Not today, then ask after the shift starts) | Shift 53 "Your stock at Hub 2" until the hub finishes |
| back from the map | Shift 07 "Collect your stock"; **Go online** → Shift 51 "Load stock at the hub" |
| at the hub with the stock packed | Refill 03: **Scan stock** → Stock 01 |
| Shift 09 Go online | Shift 19 (see below); without signal it stays on Home, with no message |

Stock scan (Section 8). The emulator has no labels to scan, so in demo mode **each tap on the viewfinder "scans" the next sample code**, and two amber demo pills (only in demo mode) switch the **Signal** and the **Camera**. A real QR code in front of the camera also works, but reads as "not on list" unless it says `NZ1|smash-burger|A-1100|1`.

| Tap / action | What you see |
|---|---|
| tap 1 | "Checking item…" (Stock 12), then "Smash Burger added · 1 of 6" (02); a few seconds later no toast (01) |
| tap 2 | Stock 07 Expired lot; **Scan another item** → 01 |
| tap 3 | added · 2 of 6 |
| tap 4 | Stock 10 Already scanned; **Scan again** |
| tap 5 | Stock 11 More than today's load; **Scan again** |
| tap 6 | Stock 04 Not on list; **Scan again** |
| tap 7 | Stock 08 Temperature alert; **Move to quarantine** → 01 |
| taps 8–10 | added · 3, 4, 5 of 6 |
| tap 11 | the last one: Stock 15 **Confirm stock** → 06 **Go online** → Shift 19; back from 06 → Shift 09 |
| **View list** on the scanner | Stock 03; **Scan next item** / **Scan** → 01; back → Shift 08 **Continue scanning** |
| **Manual** on the scanner | Stock 05; **Save counts** → 06 when every count is complete (reduce one with − to go to the list instead) |
| **Camera** pill off (or refuse the camera prompt) | Stock 09; **Enter counts instead** → 05; tap the viewfinder to turn it on |
| **Signal** pill off, then a tap that adds | Stock 13 Scans saved; **Keep scanning** → 01 (later scans just toast), **View list** → 03 |
| still off, last portion | Stock 14 All items scanned; **View list** → Stock 16; back → 14 |
| **Signal** on, on Stock 16 | Stock 15 |
| **Signal** on, on Stock 14 | Stock 06 |
| **Signal** on, on Stock 13 | back to the scanner |

Go online at spot (Section 9). The demo rider's position is simulated, about 1.2 km from the spot; the real distance rules run on it (at the spot within 100 m, "almost there" within 300 m, away beyond 150 m).

| Action | What you see |
|---|---|
| **Go online** on Stock 06 or Shift 09 | Shift 19 "Head to Yelahanka Node" |
| tap **Items on scooter** | Shift 20, the list open; tap again to close |
| **Navigate to spot** | Shift 21 "Heading to…"; the ride starts |
| 6 s later (240 m away) | Shift 22 "Almost at…" |
| 6 s later (30 m away) | Shift 23 "Are you at…?" |
| **Not yet, still on the way** | back on the route; asks again after 20 s |
| amber **Demo: Move 240 m away**, then **Yes, I'm at the spot** | Shift 24, then the location check says too far: Shift 22, and the ride goes on to 23 |
| **Yes, I'm at the spot** | Shift 24 "Checking your location…" for about a second, then Shift 25 "Online · at spot" |
| 5 s later | Shift 26 "Waiting for orders", the main map; the Online stat counts real minutes |

Online states (Section 10). The amber **Demo: …** pill on the main map plays the backend; it names the state it shows next, and each tap starts again from a rider waiting at the spot:

| Pill | What you see |
|---|---|
| Quiet spell | Shift 27 |
| Order assigned | Shift 28, 5 orders; **Start order #A2931** → Order 01, see below |
| Low stock | Shift 29; **Request hub to prepare** → Refill 03, see below |
| 1 item left | Refill 01, see below |
| Restock suggestion | Restock 01, see below |
| Relocation nudge | Shift 36, see below |
| Nudge covered | Shift 39; **Got it** → 26 |
| Away from spot | Shift 30, 180 m away; **Navigate to spot** → Shift 22 or 21, on to 23 |
| Battery low | Shift 31 |
| Shift ending | Shift 32, 15 min left; **Keep riding** → Shift 33; pick a time, **Keep riding · 30 min** → Shift 34 → Shift 35 for 6 s (tap its chip to close) → 26. **Let my shift end** → the map, no more banner; 15 minutes later Shift 46 opens |
| Connection lost | Shift 40; the next tap brings the signal back |
| Location off | Shift 41; **Open settings** → the map; **Go offline** → Shift 48 |
| Phone time wrong | Shift 42; **Check again** stays until **Open date settings** was tapped, then → the map |
| Shift limit | Shift 46, see below |
| Earnings | Earnings 01; back or **Back to waiting** → the map |
| Sync status | Sync 01; back → the map; **Try again now** → the map, signal back |
| Waiting | Shift 26 |

**Take a break** opens Shift 43, see below. **Go offline** opens Shift 48, see below. **View stock** opens the stock list without its actions; back returns to the map.

Refill, restock, move to a new spot, break (Sections 16–19), from the main map:

| Do this | What you see |
|---|---|
| Pill **Demo: 1 item left** | Refill 01; **Stay online** → the map until you run out; **Go refill** → Refill 03 |
| On Refill 01, amber **Demo: Out of stock** | Refill 02 "Paused"; **Navigate to hub** → Refill 03 |
| Refill 03 **Scan stock**, tap the viewfinder 6 times, **Confirm stock** | Stock 01 onwards, then Refill 04; **Go online** → Shift 26, with the refill's items on the scooter. Back on Refill 03 returns to the map (or Refill 02) |
| Pill **Demo: Restock suggestion** | Restock 01; **Edit quantity** → 02 (**Cancel** → 01); **Not now** → the map |
| On Restock 01, amber **Demo: Suggestion expired** | Restock 04; **Back to waiting** → the map; **Ask for a restock** does nothing yet (no flow-map arrow) |
| **Confirm restock** | Restock 03; **Head to Hub 2** → Refill 03 with what was asked; **Cancel restock** → the map |
| On Restock 03, amber **Demo: Hub is short** | Restock 05; **Take 2 from Hub 2** or **Try Hub 4** → Restock 03 |
| Pill **Demo: Relocation nudge** | Shift 36; **Not now** → the map; **Navigate to spot** → Shift 37 (the paid time counts) |
| Shift 37 **Navigate to spot** | Shift 38; about 6 s later Shift 23 at the new spot; **Yes, I'm at the spot** → online at Jakkur Node |
| **Take a break** | Shift 43; pick a time, **Start break** → Shift 44, counting; **+15 min** adds to it; **Cancel** → the map |
| On Shift 44, amber **Demo: Time up** | Shift 45, counting over; **Back online** → Shift 26; **End shift** → Shift 48 |

Connection, end shift, earnings and sync (Sections 20–22):

| Do this | What you see |
|---|---|
| **Go offline** on the map, or **End shift** on a break | Shift 48; **Stay online** goes back |
| Shift 48 **End shift** | Shift 49 for about a second, then Shift 50 (Orders, Earned and items as they stand); **Done** → Shift 05 |
| On Shift 48, amber **Demo: Order comes**, then **End shift** | Shift 47; **View order** → Order 02; **Close** → Shift 28 |
| Pill **Demo: Shift limit** | Shift 46; **End shift** → Shift 48; **Keep riding** → the map |
| On Home before Start riding, amber **Demo: No internet**, then **Start riding** | Shift 55; amber **Demo: Signal on**, **Try again** → Shift 05 |
| On Home, amber **Demo: Shift open on another phone**, then **Start riding** | Shift 54; **Cancel** → Shift 05; **Continue on this phone** → Shift 06 → Shift 10. The third tap, **Demo: Normal start**, clears both |

Earnings 01 and Sync 01 are reached only by the pill: the flow map has no arrow into them, from Profile or anywhere else.

Choose a spot (Section 24), reached only by the pill: the flow map has no arrow into it, and outside demo the backend assigns the spot. Get to Shift 09 first (stock loaded).

| Do this | What you see |
|---|---|
| On Shift 09, amber **Demo: Choose a spot** | Shift 13 "Finding spots…" for 3 s, then Shift 14; back → Shift 09 |
| Tap Jakkur Node or Yelahanka Node | Shift 15; Hebbal Node is full and can't be picked |
| **Go to Yelahanka Node** | Shift 16 for 2 s, then Shift 19 for the spot you chose |
| On Shift 14 or 15, amber **Demo: Spot is full** | Shift 17 |
| On Shift 16, amber **Demo: Spot is full** | when the confirm ends, Shift 17 |
| Shift 17 **Go to Jakkur Node** | Shift 16, then Shift 19; **Refresh** → Shift 13, with the spot still full |
| On Shift 13, amber **Demo: No spot available** | Shift 18; **Check again** → Shift 13 → Shift 18 |
| On Shift 18, amber **Demo: Spot opens**, then **Check again** | Shift 13, then Shift 14 |

Profile and other pushes (Sections 25, 26). Tap the avatar on Home (Shift 01–09, 51):

| Do this | What you see |
|---|---|
| Avatar | Profile 01; back returns to where it was opened from |
| **Your profile**, **My spot**, **Notifications**, **My shifts**, **Documents** | Profile 07, 04, 05, 06, 08 (Figma's sample values, dated from today) |
| **Help centre**, then **Contact us** | Profile 02, 09 |
| Profile 09 **Report a problem** | Problem 01 (no order on it unless one is under way); **Send report** → Problem 03; **Back to order** → Profile 09 |
| **Call hub manager** | the phone's dialler with the demo's placeholder number |
| **Log out** | Profile 03; **Stay logged in** → Profile 01; **Log out** → Welcome (the app's sign-out flow) |
| Amber **Demo: Push …** on Profile 01, four taps | the phone's real Notification 01, 02, 03, 04. Tap one in the shade: 01 → Profile 04; 02, 04 → the phase's own screen (the map when online: Shift 32, 30 if the state holds); 03 → Home |
| On the map, pill until **Demo: Profile**, then **Log out** | Profile 03 with the Online chip, as the frame has it |

The map's pills also fire the real pushes: **Relocation nudge** (03), **Away from spot** (04), **Shift ending** (02).

These do nothing, because the flow map has no arrow or frame for them: Privacy policy, FAQ questions, Hub manager, Send feedback, **Navigate to spot**, **Earlier** on My shifts.

Order, gate arrival, navigate (Sections 11–13). From Online, tap the amber pill until **Demo: Order assigned**, then **Start order #A2931**. The 90 s clock is real, from the moment the pill assigned the order; the simulated rider rides from 0.6 km to 0.3 km on **Navigate**, and 0.1 km 20 seconds later.

| Do this | What you see |
|---|---|
| Start order | Order 01, ticking |
| **Skip this order** | Order 04; **Keep this order** → 01; **Submit** → Order 05; **Back to your spot** → Shift 28 with the next order, or Shift 26 when none is left |
| **Navigate to Gate 3** | Order 02; **Turn right (0.3 km)** opens directions outside the app, **Call customer (masked)** the dialer |
| wait out the 90 s, or the amber **Demo: Running late** | Order 03 |
| amber route pill on the map: **Demo: Weak signal**, **Road closed**, **Off route**, **Back on route**, **Running late** | Navigate 01, 02, 03, Order 02, Order 03 |
| amber **Demo: Customer cancels (UPI ₹60)** | Navigate 04; the next time it plays cash ₹149 (Navigate 05), then UPI ₹16 (Navigate 06). **Back to your spot** → the next order on Shift 28 (Earned counts the trip pay, items stay) |
| **I've reached the gate** | Arrival 01 |
| tap the viewfinder (no real gate to point at) | first another gate's QR: Arrival 02, **Scan QR again** → 01; then this gate's: Arrival 03. A real QR saying `NZG\|gate-3` also works |
| amber **Demo: Camera on** on the viewfinder | Arrival 04; tap the viewfinder to turn it back on |
| **Enter gate code instead** | the code sheet (no Figma frame): **4821** → Arrival 03; anything else → Arrival 02 |
| Arrival 03 **Hand over order** | Handover 01; tap items and **Bag sealed**; with an item unticked **Something missing? Check the items** → Handover 08 |
| **Packed – go** on a UPI order (the first, A2931) | Handover 02; type: 03 |
| **4821** (any wrong code), **Confirm delivery** | Handover 04; it never locks. **Code not working? Check order details** → Handover 13: **Details match, hand over** delivers, **Details don't match** → Problem 01 |
| **4829** (the demo customer's code), **Confirm delivery** | Handover 05 for about a second, then 11 (or 06 with no order left) |
| leave the code empty for 15 s, **Customer not at the gate?** | Handover 07, counting; **Can't reach customer** → Problem 02 with Customer absent chosen |
| Handover 08, tap **−** | Handover 09; **Reset quantities** → 08 |
| amber **Demo: Signal on** (top right on every handover screen), then **Continue to code** on 09, or **Confirm delivery**, **I've collected**, **Details match** | Handover 10. Tap the pill again (signal back): on to the code (or what was saved goes through). **Back to waiting** instead: the map; the demo's signal returns there and it syncs (Orders, Earned and items update) |
| the second order, A2934 | **Packed – go** → Handover 12 (cash, no code); **I've collected ₹149** → delivered |
| Handover 11 | **Start next order** → Order 02 of the next order; amber **Demo: No more orders** → Handover 06 |
| Handover 06 **Back to waiting** | Shift 26, with Orders, Earned and items updated |
| flag button on the map once on the way (Order 02) | Problem 01; choose: 02; **Send report** → 03; **Back to order** |

Notifications need the permission from Onboard 04 (Android 13+).

## Known limits

These need a backend (Cloud Functions) and are not in the app yet:

- Stock lots: the backend must write `stock.list` and `stock.lots` on the shift, print labels as `NZ1|item|lot|portion`, and handle `quarantine` and `scans` (a portion that was refused or quarantined still counts in the load until the backend changes `stock.list`).
- Shift end's other side: `today.orderPay`, `incentives`, `repositionMinutes`, `repositionPay`, `averageDeliverySeconds`, signing out the other phone when `openOn` changes (Shift 54), taking back stock, and a next shift the same day.
- Push notifications from the backend (FCM). The stock-request pushes are scheduled on the phone from the shift times, and "Stock ready" shows only when the app sees the change.
- Assigning orders to `queue` at the spot, quiet spells, stats, battery and the "away from spot" and "shift ending" pushes.
- The order flow's other side: creating `orders/{id}` with `private/gate`, reassigning skipped orders, cancelling and paying the trip (`cancellationPayOf`), taking a finished order out of `queue` and stamping the next one's `assignedAt`, telling the customer the rider is nearly there.
- The handover's other side: on delivery updating `today` and `stock.sold` from `handedOver`, taking the order out of `queue`, reviewing handovers without a checked code (`details`, `offline`), limiting wrong-code tries per order, telling the customer the rider is waiting (`customerWaitingAt`), answering `problemReports`.
- Turn-by-turn routing: the hub map and the order map show the straight-line distance only (the turn card is left out and the button shows just the distance), and road closed / off route never show (the demo shows the design's sample turns and plays them).
- Payouts and cash deposit: the app shows cash in hand but doesn't settle it.
- Location is shared only while the app is open (no background tracking).
- The public OpenStreetMap tile server is rate-limited; use a paid tile provider before launch.
