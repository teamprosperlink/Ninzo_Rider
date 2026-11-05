# Remaining Figma sections: handover

Handed over 2026-11-05, and taken back the same day: session ninzorider-04 owns these sections. Only one session works on them at a time. Read [figma_build_guide.md](figma_build_guide.md) and [figma_audit.md](figma_audit.md) first. Frame node ids are in [figma_screens.md](figma_screens.md). All of Figma stays read-only.

## Status
All 168 frames are built, the 162 before plus Section 24's 6: Sections 8, 9 and 10 are done, and Section 24 is reachable in demo only (below). Settled on Sections 8–10: Figma's greens changed on 2026-11-05 (brand #028902, pale fills solid); the user decided the app keeps yesterday's colours, #009600 and the pale fills. Compare colours against docs/figma_baseline_2026-11-05.png, the last render before the change. See the README for reaching each state in demo.

| Build order | Figma sections | Frames |
|---|---|---|
| 8 | 16 Refill, 17 Restock, 18 Move to a new spot (Shift 36–39), 19 Break (Shift 43–45) | 16 |
| 9 | 20 Connection and device issues (Shift 40–42, 54, 55), 21 End shift (Shift 46–50), 22 Earnings and sync | 12 |
| 10 | 25 Profile, 26 Other push notifications | 13 |

Not built, by decision: 23 Offer (on hold).

Section 24 Choose a spot (Shift 13–18) is built in `lib/features/online/` as one screen, `ChooseSpotPage` and `ChooseSpotViewModel`, reached only by the amber **Demo: Choose a spot** pill. The backend still assigns the spot in the real flow: the flow map has no arrow into Shift 13, and its title still says "pending: backend assigns". Outside demo the repository is `NoSpotChoices`, with no backend behind it.

## User's rules
- Everything as in Figma: colour, size, spacing, radius, shadow, copy. Figma wins.
- Nothing added on our own: no UI, copy, button or state that isn't in a frame. If a frame is missing, leave it out and ask the user.
- Material icons stay; no image or SVG icon assets.
- Letter spacing stays at token values. Don't tighten it to hold line breaks; report breaks that differ.

## How each section was built
- Use the Flow Map (`128717:2188`) to group frames into real screens and to find where buttons lead. Each real screen is one View and ViewModel; every frame still gets its own screenshot.
- Clean Architecture + MVVM: `domain` (entities, use cases with the rules, repository interfaces), `data` (Firestore and demo repositories, models), `di`, `presentation`. Only `di` imports `data`.
- Demo mode (`kDemoMode`): every state reachable on the phone, with short timers and amber "Demo: …" pills hidden outside demo. Keep the pills out of test screenshots. Document states in the README.
- Add an on-device suite under `integration_test/figma/` driving all frames with fakes, named from the Figma titles, keyboard down. Compare each with its frame using side-by-side images.
- Measure rendered colours from the Figma screenshot, because `get_design_context` drops opacity. Shadow blur: see the note in `rider_tokens.dart`. Use opaque fills over a BoxShadow.
- Before calling a section done: `flutter analyze` clean, `flutter test` green, all device suites one at a time on final code, and a walk of the real demo app, reading its results. Leave no background scripts; leave the demo build on Welcome.

## Where the new sections plug in
- A rider with no shift sees Shift 02 (`NoShiftHomePage`, `home_page.dart`), with Spot and Scooter blank; its button and avatar do nothing until a shift arrives.
- Section 9 is in `lib/features/shift_end/`. Earnings 01 and Sync 01 have no flow-map arrow into them, and Profile has none either.
- `lib/features/online/`: low-stock "Request hub to prepare", Take a break, Go offline.
- `lib/features/stock/`: reuse the scan flow for refills.
- Section 10 is in `lib/features/profile/`. The avatar on Home opens Profile 01; `AppDrawer` and `profile_view` are gone. Profile 09 "Report a problem" opens `ProblemReportPage`, but a rider on the way still can't reach it: no frame of an order draws an avatar, and an active order takes over the screen. Designer to decide.

## Open for the user
User's decision on 2026-11-05: whatever isn't in Figma comes out of the app. Done the same day: no snackbars, error screens, full-screen spinners or fallback text remain. A failed action leaves the screen as it was, with no message; a load with nothing to go back to shows blank and retries by itself (`SilentRetry`). `AppException` is never shown. Designer to draw frames where the rider now gets no answer: Go online or stock confirm without signal, checklist items that won't tick, a failed save or send anywhere. Still waiting for the user's answer: demo-only pills, the Shift 44 progress bar, invented routing behind drawn buttons.

Decisions the user or team still owes (reported section by section):
- Designer or product, Section 24: where does Shift 13 open from, and does choosing replace assignment? No arrow leads in. The map draws "Spot is full" from Shift 14, while the banner's copy reads like a refused confirm on Shift 16; the app does both. No arrows for Back, Go to Jakkur Node, Refresh, Check again, or Shift 18's avatar. No frame for a spot with 2 of 3 taken (tag left blank) or for Go to Jakkur Node's confirming state (the app uses Shift 16).
- Designer: Section 10 buttons with no arrow or frame, which do nothing: Privacy policy, FAQ answers, Hub manager row, Send feedback, Navigate to spot, My shifts "Earlier". Confirm → Onboard 07 on the map against the sign-out flow's Welcome; Problem 03's "Back to order" with no order.
- Backend: `spot.assignedAt`, `hub.managerPhone`, `riders/{uid}/notifications`, and FCM for Notification 01–04.
- Designer: frames or buttons for gate code entry (a rider whose QR won't scan can't confirm the gate), Check the items (Handover 08, 09), Customer not at gate (Handover 07).
- Designer: "Almost" overflows the ring on the running-late state; Order 01 says "turn left" under a right arrow; Handover 01 "90 sec starts when you move" vs the clock starting at assignment; Shift 53's bottom bar; Navigate 05, 06 "To confirm" notes; Shift 31 battery is "On hold" in Figma.
- Product: queued order's 90 s starts when it reaches the front; Start riding rule; low-stock count on portions; distance limits 100/150/300 m; manual counts pre-filled; quarantined portions still counted; QR format `NZ1|item|lot|portion`.
- Security: Register has no SMS check (anonymous sign-in, the user's choice), so the backend must verify numbers. Handover "details" and offline methods mark UPI orders delivered without a checked code, and wrong codes have no limit: the backend must review and limit these. Problem reports need signal, including for accidents.

## Not exercised anywhere yet
Real Firestore and the rules (not deployed); reading a real QR code; real GPS; loss of real signal; a real phone. One unexplained hang on a Stock walk (taps ignored, empty accessibility tree), not reproduced. Stray taps on the emulator earlier, source never found. Backend work (order assignment, hub stock, FCM pushes, payouts) is separate.

Pre-Figma backups: the original ride-hailing code and first delivery version were in the old session scratchpad and may be gone. The project isn't a git repo; suggest `git init` so there's a restore point.
