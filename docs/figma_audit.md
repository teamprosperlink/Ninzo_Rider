# Figma audit: fix queue

**Status, 2026-11-05, fix pass 2 (121 built screens):** median pixel diff 0.43% (was 2.05%); 96 screens under 1%; 99.97% of flat pixels match the Figma render exactly; no strip shift on non-map screens; all 8 device suites and 131 unit tests pass.

Root causes fixed in this pass:
- Figma renders Inter 3.19. `assets/fonts` now holds 3.19, in place of 4.001. Letter-spacing overrides are gone; every text uses its token value.
- Figma sizes hugging text in whole pixels: `RiderHugText` (labels, pills, buttons, 20-radius card values).
- Flutter centres the spacing after the last letter: centred overlines get a left inset equal to their letter spacing.
- Flutter paints a blur number wider than Figma: see the note in `rider_tokens.dart`. Flutter paints a BoxShadow under translucent fills, so use opaque fills there.
- Chip and panel borders: see `RiderPhoneField`, `RiderPanel`.

Still different, and why:
- Icon shapes: Material icons, the user's decision (no image or SVG icons).
- Real map tiles against Figma's grey placeholder (Shift 19-35, 52, Order 01-03, Navigate 01-03). UI over tiles can't be pixel-compared.
- Text anti-aliasing: Figma's and Flutter's rasterisers differ, so text edges never reach 0.
- Under 1px: some text runs (e.g. Order 05, Stock 07, 08 labels); phone field digits 1/3px high; spinner 18 + 10 gap against 20 + 8 (same label position); Register 08 chip 1 colour level.
- Captures use sample timers, so Login 05-07 resend text differs by data.

Device note: flutter drive hung twice on 2026-11-05 (Stock, Home) with no assertion and passed on re-run. Cause unknown. Use a time limit.

From a read-only audit (1x Figma render vs `build/screens`, 121 of 168 screens). Screens saved at 16:21 predate the 16:48 token/widget edits, so re-check each item against fresh screenshots before fixing it. Colours are Figma render -> app render.

Section 24 (Shift 13–18, added 2026-11-05), against the pre-change crops, same measure as above (over 32 levels): 0.04%, 0.35%, 0.50%, 0.40%, 0.35%, 0.26%. Still different: Shift 18's pin (Material `pin_drop_outlined`: heavier stroke, a flat line for the ring base), the back arrow's stroke (`Icons.west`, thicker), Shift 16's spinner (animated ring against a drawn arc), text anti-aliasing.

## Layout
1. Login 04-08, 11: keypad key is about 112 wide, Figma 100. Pass `keyWidth: 100` in `login_view.dart` (Handover already does).
2. Login 04-09, 11: heading, code boxes and error text sit 2px low (Figma heading y=120).
3. Onboard 02: bottom bar 8px low (Figma y=616). Onboard 06, 07: bottom buttons 4px low.
4. Problem 01, 02: option card pitch 78, Figma 80 (68 high + 12 gap, first at y=160). Sent to the Section 7 agent.

## Colour
5. Input field fill: #efefef -> #f2f2f2 (Login, Register).
6. Register 06: photo preview #e2e2e2 -> #cdcdcd; tip #f9efdd -> #fae5c1. Handover 09 notice: #f9efdd -> #faeeda.
7. Tick halo: #dceedc/#c6e5c6 -> #e1f0e1/#cae7ca (Handover 06, 11). Home avatar tint: #dceedc -> #e1f1e1 (Shift 01-09).
8. Art tiles: #d3ecd3 -> #d0ead0 (Onboard 03, 04, 05, 07, Login 10, Shift 51). Register 09, 10: #e4f2e4 -> #ddefdd, #d3ecd3 -> #cbe8cb. Register 11-13: #f9e8e8 -> #fae5e5 (Register 12: #fde9e9), #f9dbdb -> #f9d8d8.
9. Register 14, 15: #d3d3d3 -> #d8d8d8. Stock 06: #d6d6d6 -> #dbdbdb. Onboard 02 ring: #20a320 -> #1da21d.

## Type and icons
10. `home_page.dart` sets letter spacing 0.1; Figma Body/Medium is 0.15. Note: the Home section chose 0.1 on purpose so Shift 02 wraps as in Figma. Check the wrap if this changes.
11. No Input/Large token (16/20/400); fields use bodyLarge 16/24.
12. Back icon is 22 in `rider_buttons.dart`; Figma is 24.

## Icons
- Keep Material icons; no image or SVG assets (user's decision, relayed by the audit session). Only the back icon size changes (item 12).

## Colour detail (second audit list)
Goal: every colour matches Figma. Values are Figma render -> app render at 360x800, so semi-transparent fills need their alpha set to reach the Figma value. Re-check against current output first; most captures predate the token edits.

Already exact, leave alone: #fbfbfb screen, #ffffff card and sheet, #009600, #54b954, #0c0c0c, #e3e3e3 keypad, #ef4444.

Field and chip fills:
- Input field #efefef -> #f2f2f2 (Login 01, Register 02, 03; Login 02, 03, 12-16 not measured, assumed the same widget).
- Empty code box #f1f1f1 -> #f2f2f2 (Login 04, 05, 08).
- Offline status chip #e9e9e9 -> #ebebeb (11 screens incl. Shift 01-03, 05, 06, 08, 51).
- Pill #ececec -> #efefef (Shift 21, 22, 52).

Warning:
- Tip #f9efdd -> #fae5c1 and icon tile #f8e2bc -> #f9d79d (Register 06).
- Notice #f9efdd -> #faeeda (Handover 09), -> #faf0de (Arrival 02, Register 08).
- Register 08: #fdf3e1 -> #fef3e2, #faeacd -> #fae9cd.

Error art tiles:
- #f9e8e8 -> #fae5e5 and #f9dbdb -> #f9d8d8 (Register 11-13), #fde8e8 -> #fde9e9 (Register 11-13).
- #f9e8e8 -> #fae9e9 and #f9dbdb -> #f9dcdc (Onboard 06).

Green tints:
- Art tile #e4f2e4 -> #e2f1e2 and #d3ecd3 -> #d0ead0 (Onboard 03, 04, 05, 07, Login 10, Shift 51); Shift 33, 34 #d3ecd3 -> #d2ebd2.
- Register 09, 10: #e4f2e4 -> #ddefdd, #d3ecd3 -> #cbe8cb.
- Avatar #dceedc -> #e1f1e1 (10 screens incl. Shift 01-03, 05, 06, 08, 51). Halo #dceedc -> #e1f0e1, #c6e5c6 -> #cae7ca (Handover 06, 11).
- Handover 01 #d8edd8 -> #ddefdd. Register 04 #e8f6e8 -> #e5f4e5. Register 14-16 #e1f0e1 -> #e2f1e2. Register 02, 03 #d7e6d7 -> #dae9da.
- Onboard 02 rings #3fb03f -> #3daf3d, #20a320 -> #1da21d.
- Login 09 illustration #e0f2e0 -> #d9efd9 (gradient, `verified_sheet.dart`).

Visual, not measured:
- Onboard 01 splash: Figma's logo border and tagline side lines are soft and translucent; the app draws them solid white.
- Login checkbox: Figma radius 8 on a 20 box (node 128584:125); the app's corners look tighter.

Text: no wrong text colour on the screens checked. Not grid-checked: the 14 screens with layout shifts, the 2 keyboard captures, and everything above the sheet on the map screens. Re-check these after the layout fixes.

## Test captures
- `login_13` and `register_01` are captured with the keyboard up, which shifts the layout, so they can't be compared with Figma. Capture them with the keyboard down.

## Not measured
- Reasons card shadow on Onboard 06, 07 looks heavier than Figma (visual only).
- UI over the map on the 22 map screens.
