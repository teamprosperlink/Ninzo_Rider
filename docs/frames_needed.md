# Frames needed from design

The app now shows only what is in Figma. These cases have no frame, so the rider gets no message or no way forward. Each row needs a frame or a decision. Figma's green change on 2026-11-05 is not included here: the app keeps the colours from before it.

## Failures that now say nothing
| Case | What the rider sees now |
|---|---|
| Go online with no signal (Home, Stock 06, Shift 23) | Same screen, nothing happens |
| Checklist: location off or denied, low phone battery, scooter needs charging | Row stays unticked with no reason, and no route to Settings. "Go to hub" stays disabled |
| Location check fails on hub map, spot or order | Nothing |
| Stock fails to load or save, or confirm with no signal | Blank during load, then back on Home. Otherwise same screen |
| Gate scan with no signal | Stays on Arrival 01, scan does nothing |
| Wrong code or failed confirm at handover | Same screen, no reason |
| Problem report with no signal | Stays on Problem 02, nothing sent |
| Refill, restock, break, add time or end shift fails | Same screen, no reason |
| Login fails | Same step, no message |
| Register: invalid number, location, no area nearby, camera denied, no internet, failed save, upload or submit | Same screen, no message |
| App can't load session, shift or order | Splash or blank screen, retries every 5 s without saying so |
| Loading | Blank screen, no spinner |
| Value unknown (about 14 rows) | Blank value |
| No turn data on a real route | No turn card; button shows only the distance or arrow |

## Screens with content missing
- Selfie and bank photo: no instruction above the viewfinder, no caption. Register 08 Done does nothing.
- More than one document to retake: body blank, and the button reads "Retake <first document>".
- Rider with no shift: Shift 02 is shown, with Spot and Scooter blank. "Ask hub to prepare" and the avatar do nothing, so no Profile or Log out.
- No shifts in the last 7 days, no notifications: page with no card.

## Drawn buttons with no destination
Shift 18's avatar, Enter gate code, Ask for a restock, Privacy policy, FAQ questions, Hub manager, Send feedback, Navigate to spot (Profile 04), "Earlier" (My shifts), Start riding after Shift 50.

## Screens with no way in
- Earnings 01, Sync 01: reachable only in demo.
- Choose a spot (Shift 13–18): reachable only in demo; the backend assigns the spot in the real flow.
- Report a problem during an order: no order frame has a route to it.
- Check the items (Handover 08, 09), Customer not at gate (Handover 07).
- Refill 01: opens at 1 item left, which is an assumption. Restock 01: opens when the backend sends a suggestion.

## Copy that conflicts with the flow
- Log out: the arrow goes to Onboard 07, but its copy is "You signed in on another phone…". The app goes to Welcome.
- Refill 04 "head back to your spot" goes straight to the map, so a rider at the hub sees Away from spot.
- Shift 46 "add more time": Keep riding adds no time.
- Shift 55 "Try again": goes to Home and does not retry.
- Shift 44: the sample bar is 42% at 29:12 of 30 min. The app shows real time, 2.7%.
- Profile 05 shows both "Yesterday" and "Mon" on a Tuesday. Mobile mask shows 11 symbols for a 10-digit number.
