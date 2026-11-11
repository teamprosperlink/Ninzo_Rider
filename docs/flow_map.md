# Flow map: which screen opens after which

From the Figma page "Rider App - 🧭 Flow Map · Tap map (NEW)" (`SJCZJDDoZBP2Skwvu7zdvs`, node `129294:2`), 2026-11-11.
Each row: on this screen, this tap or event opens that screen. `→ X` means the flow continues in another section.
The app follows every row; the few that differ say so in the last column. Screen-to-page links are in
`lib/routing/app_router.dart`.

## 1 · Onboarding

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Onboard – 01 Splash | Get started | Onboard – 02 Welcome | Same |
| Onboard – 02 Welcome | Continue | Onboard – 03 Location permission | Same |
| Onboard – 03 Location permission | Allow | Onboard – 04 Notifications permission | Same |
| Onboard – 04 Notifications permission | Allow | Onboard – 05 Camera permission | Same |
| Onboard – 05 Camera permission | Allow | → Login 01 · Phone | Same |
| Onboard – 03 Location permission | Deny | Onboard – 06 Location off | Same |
| Onboard – 07 Signed out | Sign in | → Login 01 · Phone ‹2› | Same |

## 2 · Login

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Login – 01 Phone (empty) | Enter number | Login – 02 Phone valid | Same |
| Login – 02 Phone valid | Send code | Login – 15 Sending code | Same |
| Login – 15 Sending code | Code sent | Login – 04 Code empty | Same |
| Login – 04 Code empty | Type code | Login – 05 Code typing | Same |
| Login – 05 Code typing | Verify | Login – 07 Verifying | Same |
| Login – 07 Verifying | Correct | Login – 09 Verified | Same |
| Login – 09 Verified | Open app | → Shift 05 · Home | The button says "Start shift", as drawn on Login 09. |
| Login – 02 Phone valid | Not registered | Login – 03 Not registered | Same |
| Login – 03 Not registered | Register | → Register 01 · Details | Same |
| Login – 07 Verifying | Wrong code | Login – 06 Wrong code | Same |

## 3 · Register

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Register – 01 Details (empty) | Fill details | Register – 02 Details filled | Same |
| Register – 02 Details filled | Next | Register – 04 Documents (none added) | Same |
| Register – 04 Documents (none added) | Add document | Register – 05 Take photo | Same |
| Register – 05 Take photo | Capture | Register – 06 Photo review | Same |
| Register – 06 Photo review | Use photo | Register – 07 Documents complete | Same |
| Register – 07 Documents complete | Submit | Register – 08 Under review | Same |
| Register – 08 Under review | Approved | Register – 09 Approved | Same |
| Register – 09 Approved | Continue | Register – 10 Spot assigned | Same |
| Register – 10 Spot assigned | Got it | → Shift 05 · Home | Same |
| Register – 02 Details filled | Number already registered | Register – 03 Number already registered | Same |
| Register – 08 Under review | Retake | Register – 11 Needs a retake | Same |
| Register – 08 Under review | Failed | Register – 12 Verification failed | Same |

## 4 · Morning stock request (1 hr before shift)

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Notification – 05 Prepare your stock (push) | I’m coming | Shift – 03 Home · Hub preparing | Same |
| Shift – 03 Home · Hub preparing | Hub packs it | Notification – 07 Stock ready (push) | Same |
| Notification – 07 Stock ready (push) | Tap | Shift – 04 Home · Stock ready | Same |
| Shift – 04 Home · Stock ready | Start riding | → Shift 10 · Before you start | Same |
| Notification – 05 Prepare your stock (push) | Not today | Shift – 02 Home · Not working today | Same |
| Notification – 05 Prepare your stock (push) | No reply in 30 min | Notification – 06 Reminder · tell the hub (push) | Same |
| Shift – 02 Home · Not working today | Ask hub to prepare | → Shift 03 · Hub preparing | Same |
| Notification – 06 Reminder · tell the hub (push) | Still no reply | Shift – 01 Home · No stock requested | Same |
| Notification – 06 Reminder · tell the hub (push) | I’m coming | → Shift 03 · Hub preparing ‹2› | Same |
| Shift – 01 Home · No stock requested | Ask hub to prepare | → Shift 03 · Hub preparing ‹3› | Same |

## 5 · Start riding, go to hub, collect stock

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 05 Home · Start riding | Start riding | Shift – 10 Pre-shift checklist – none checked | Same |
| Shift – 10 Pre-shift checklist – none checked | Tick all | Shift – 12 Pre-shift checklist – all checked | Same |
| Shift – 12 Pre-shift checklist – all checked | Go to hub | Shift – 52 Heading to hub | Same |
| Shift – 52 Heading to hub | Reached hub | Refill – 03 At hub | Same |
| Refill – 03 At hub | Scan stock | Stock – 01 Scan item | Same |
| Stock – 01 Scan item | Scan | → See 8 · Scan, confirm, Go online | Same |
| Shift – 05 Home · Start riding | Menu | → Profile 01 · Menu | Same |
| Refill – 03 At hub | Hub still packing | Shift – 53 At hub · Hub is packing | Same |
| Shift – 53 At hub · Hub is packing | Hub finishes | → Refill 03 · At hub ‹2› | Same |

## 6 · Go online is locked

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 07 Home · Collect stock at hub | Go to hub | Shift – 52 Heading to hub | Same |
| Shift – 52 Heading to hub | Reached hub | → Refill 03 · At hub | Same |
| Shift – 07 Home · Collect stock at hub | Go online, no stock | Shift – 51 Stock empty (offline) | Same |
| Shift – 51 Stock empty (offline) | Navigate to hub | → Shift 52 · Heading to hub | Same |
| Shift – 51 Stock empty (offline) | Request hub to prepare | → Shift 03 · Hub preparing | Same |

## 7 · Stock scanned, Go online unlocks

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Stock – 06 Stock confirmed | Back to Home | Shift – 09 Home · Stock loaded | Same |
| Shift – 09 Home · Stock loaded | Go online | Shift – 19 Go online at spot | Same |
| Shift – 19 Go online at spot | Go online | Shift – 21 Heading to spot | Same |
| Stock – 03 Stock list | Back to Home | Shift – 08 Home · Finish scanning | Same |
| Shift – 08 Home · Finish scanning | Continue scanning | → Stock 01 · Scan item | Same |

## 8 · Stock scan

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Stock – 01 Scan item | Scan | Stock – 12 Checking item | Same |
| Stock – 12 Checking item | Item added | Stock – 02 Item scanned | Same |
| Stock – 02 Item scanned | View list | Stock – 03 Stock list | Same |
| Stock – 03 Stock list | All loaded | Stock – 06 Stock confirmed | Same |
| Stock – 06 Stock confirmed | Go online | → Shift 19 · Go online | Same |
| Stock – 01 Scan item | Camera off | Stock – 09 Camera off | Same |
| Stock – 09 Camera off | Enter counts | Stock – 05 Manual count | Same |
| Stock – 05 Manual count | Save counts | → Stock 06 · Confirmed | Same |
| Stock – 12 Checking item | Not on list | Stock – 04 Not on list | Same |
| Stock – 12 Checking item | Duplicate | Stock – 10 Already scanned | Same |
| Stock – 12 Checking item | Too many | Stock – 11 More than today’s load | Same |
| Stock – 12 Checking item | No signal | Stock – 13 Scans saved offline | Same |
| Stock – 12 Checking item | Expired lot | Stock – 07 Expired lot | Same |
| Stock – 12 Checking item | Too warm | Stock – 08 Temperature alert | Same |
| Stock – 13 Scans saved offline | Last item scanned | Stock – 14 All scanned · saved offline | Same |
| Stock – 14 All scanned · saved offline | Signal back | → Stock 06 · Confirmed ‹2› | Same |

## 8b · Stock list, and the way to the main map

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Stock – 14 All scanned · saved offline | View list | Stock – 16 Stock list · all scanned · offline | Same |
| Stock – 16 Stock list · all scanned · offline | Back | → Stock 14 · All scanned | Same |
| Stock – 16 Stock list · all scanned · offline | Signal back | Stock – 15 Stock list · all scanned | Same |
| Stock – 03 Stock list | Last item scanned | Stock – 15 Stock list · all scanned | Same |
| Stock – 15 Stock list · all scanned | Confirm stock | Stock – 06 Stock confirmed | Same |
| Stock – 06 Stock confirmed | Go online | → See 9 · Go online, then Online waiting (main map) | Same |
| Stock – 03 Stock list | Scan next item | → Stock 01 · Scan item | Same |

## 9 · Go online

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 19 Go online at spot | Go online | Shift – 21 Heading to spot | Same |
| Shift – 21 Heading to spot | Reached spot | Shift – 23 Confirm you’re at the spot | Same |
| Shift – 23 Confirm you’re at the spot | Confirm | Shift – 24 Confirm at spot – checking location | Same |
| Shift – 24 Confirm at spot – checking location | Located | Shift – 25 Spot confirmed by rider | Same |
| Shift – 25 Spot confirmed by rider | Continue | Shift – 26 Online waiting | Same |
| Shift – 21 Heading to spot | Too far | Shift – 22 Too far from spot | Same |
| Shift – 22 Too far from spot | Walk to spot | → Shift 23 · Confirm at spot | Same |

## 10 · Online waiting

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 26 Online waiting | Order comes | Shift – 28 Online · Order assigned | Same |
| Shift – 28 Online · Order assigned | Start order | → Order 01 · Assigned | Same |
| Shift – 26 Online waiting | Low stock | Shift – 29 Online · Low stock (5 left) | Same |
| Shift – 26 Online waiting | Shift ending | Shift – 32 Online · Shift ending soon | Same |
| Shift – 26 Online waiting | Nudge | Shift – 36 Relocation nudge | Same |
| Shift – 26 Online waiting | Away | Shift – 30 Online · Away from spot | Same |
| Shift – 26 Online waiting | Take a break | Shift – 43 Take a break | Same |
| Shift – 29 Online · Low stock (5 left) | Go to hub | → Refill 03 · At hub | Same |
| Shift – 32 Online · Shift ending soon | Open | → See 11 · Shift ending | Same |
| Shift – 36 Relocation nudge | Open | → See 12 · Relocation | Same |
| Shift – 30 Online · Away from spot | Go back | → Shift 21 · Heading to spot | Same |
| Shift – 43 Take a break | Open | → See 13 · Break | Same |

## 11 · Shift ending, add time, end shift

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 32 Online · Shift ending soon | Keep riding | Shift – 33 Add time | Same |
| Shift – 33 Add time | Add time | Shift – 34 Add time – adding | Same |
| Shift – 34 Add time – adding | Added | Shift – 35 Online · Time added | Same |
| Shift – 35 Online · Time added | Continue | → Shift 26 · Online | Same |
| Shift – 32 Online · Shift ending soon | Go offline | Shift – 48 End shift confirm | Same |
| Shift – 48 End shift confirm | End shift | Shift – 49 End shift – ending | Same |
| Shift – 49 End shift – ending | Ended | Shift – 50 Shift summary | Same |
| Shift – 50 Shift summary | Done | → Shift 05 · Home | Same |

## 12 · Relocation

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 36 Relocation nudge | Accept | Shift – 37 Moving to a new spot | Same |
| Shift – 37 Moving to a new spot | Navigate | Shift – 38 Moving to a new spot – on the way | Same |
| Shift – 38 Moving to a new spot – on the way | Arrived | → Shift 23 · Confirm at spot | Same |
| Shift – 36 Relocation nudge | Covered | Shift – 39 Nudge covered (RARE CASE) | Same |

## 13 · Break

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 43 Take a break | Start break | Shift – 44 On a break | Same |
| Shift – 44 On a break | Time up | Shift – 45 Break over | Same |
| Shift – 45 Break over | Back online | → Shift 26 · Online | Same |

## 14 · Order and gate arrival

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Order – 01 Order assigned | Navigate | Order – 02 On the way | Same |
| Order – 02 On the way | Reached gate | Arrival – 01 Scan gate QR | Same |
| Arrival – 01 Scan gate QR | Gate OK | Arrival – 03 Gate confirmed | Same |
| Arrival – 03 Gate confirmed | Start handover | → Handover 01 · Pack | Same |
| Order – 01 Order assigned | Can’t take | Order – 04 Can’t take order | Same |
| Order – 04 Can’t take order | Skip | Order – 05 Order skipped | Same |
| Order – 05 Order skipped | Back to waiting | → Shift 26 · Online | Same |
| Order – 02 On the way | Running late | Order – 03 Running late | Same |
| Arrival – 01 Scan gate QR | Not confirmed | Arrival – 02 Not confirmed | Same |
| Arrival – 01 Scan gate QR | Camera off | Arrival – 04 Camera off | Same |

## 15 · Problems and cancels (from On the way)

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Order – 02 On the way | Report | Problem – 01 What’s happening | Not in the app: Order 02 has no Report button in Figma. Report opens from Handover 07, the delivered pages and Profile → Help. |
| Order – 02 On the way | Weak signal | Navigate – 01 Weak signal | Same |
| Order – 02 On the way | Road closed | Navigate – 02 Road closed | Same |
| Order – 02 On the way | Off route | Navigate – 03 Off route | Same |
| Order – 02 On the way | Cancelled UPI | Navigate – 04 Order cancelled (UPI, ₹20 or more) | Same |
| Order – 02 On the way | Cancelled cash | Navigate – 05 Order cancelled (cash) | Same |
| Order – 02 On the way | Cancelled small | Navigate – 06 Order cancelled (UPI, under ₹20) | Same |
| Problem – 01 What’s happening | Choose | Problem – 02 Option chosen | Same |
| Problem – 02 Option chosen | Send | Problem – 03 Report sent | Same |
| Navigate – 04 Order cancelled (UPI, ₹20 or more) | Back to waiting | → Shift 26 · Online | Same |

## 16 · Handover

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Handover – 01 Pack order | Packed | Handover – 02 Enter code | Same |
| Handover – 02 Enter code | Type code | Handover – 03 Code typing | Same |
| Handover – 03 Code typing | Submit | Handover – 05 Confirming | Same |
| Handover – 05 Confirming | More orders | Handover – 11 Delivered · next order ready | Same |
| Handover – 11 Delivered · next order ready | Start next | → Order 02 · On the way | Same |
| Handover – 05 Confirming | No more | Handover – 06 Delivered · no more orders | Same |
| Handover – 03 Code typing | Wrong code | Handover – 06 Delivered · no more orders | The map points at Handover 06; the app opens Handover 04 Wrong code, as the map's note for Handover 04 says. |
| Handover – 06 Delivered · no more orders | Back to waiting | → Shift 26 · Online | Same |

## 17 · Handover extras

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Handover – 01 Pack order | Packed | Handover – 02 Enter code | Same |
| Handover – 01 Pack order | Cash order | Handover – 12 Collect cash | Same |
| Handover – 02 Enter code | Code fails | Handover – 13 Code not working · verify details | Same |
| Handover – 02 Enter code | Not at gate | Handover – 07 Customer not at gate | Same |

## 18 · Refill

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Refill – 01 Low stock | Out of stock | Refill – 02 Out of stock | Same |
| Refill – 02 Out of stock | Go to hub | Refill – 03 At hub | Same |
| Refill – 03 At hub | Scan stock | → Stock 01 · Scan stock | Same |
| Refill – 03 At hub | Refilled | Refill – 04 Refilled | Same |
| Refill – 04 Refilled | Go online | → Shift 26 · Online | Same |

## 19 · Profile

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Profile – 01 Menu | Help | Profile – 02 Help centre | Same |
| Profile – 01 Menu | My spot | Profile – 04 My spot | Same |
| Profile – 01 Menu | Alerts | Profile – 05 Notifications | Same |
| Profile – 01 Menu | My shifts | Profile – 06 My shifts | Same |
| Profile – 01 Menu | Profile | Profile – 07 Your profile | Same |
| Profile – 01 Menu | Documents | Profile – 08 Documents | Same |
| Profile – 01 Menu | Log out | Profile – 03 Log out confirm | Same |
| Profile – 02 Help centre | Contact us | Profile – 09 Help centre · Contact us | Same |
| Profile – 03 Log out confirm | Confirm | → Onboard 07 · Signed out | Same |

## 20 · Push notifications

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Notification – 01 Spot assigned (push) | Tap | → Profile 04 · My spot | Same |
| Notification – 02 Shift ending soon (push) | Tap | → Shift 32 · Shift ending | Same |
| Notification – 03 Orders waiting (push) | Tap | → Shift 05 · Home | Same |
| Notification – 04 Away from spot (push) | Tap | → Shift 30 · Away from spot | Same |

## 21 · Login errors (number)

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Login – 01 Phone (empty) | Type number | Login – 13 Typing number | Same |
| Login – 13 Typing number | Valid number | Login – 02 Phone valid | Same |
| Login – 13 Typing number | Invalid number | Login – 14 Invalid number | Same |
| Login – 02 Phone valid | No internet | Login – 12 No internet | Same |
| Login – 12 No internet | Try again | → Login 15 · Sending code | Same |
| Login – 14 Invalid number | Fix number | → Login 13 · Typing number | Same |

## 22 · Login errors (code)

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Login – 04 Code empty | Timer ends | Login – 08 Resend available | Same |
| Login – 08 Resend available | Resend code | → Login 15 · Sending code | Same |
| Login – 04 Code empty | Type code | Login – 05 Code typing | Same |
| Login – 05 Code typing | Too many attempts | Login – 10 Too many attempts | Same |
| Login – 05 Code typing | Code expired | Login – 11 Code expired | Same |
| Login – 10 Too many attempts | Back to login | → Login 01 · Phone | Same |
| Login – 11 Code expired | Resend code | → Login 15 · Sending code ‹2› | Same |

## 23 · Register · verification expired

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Register – 08 Under review | Verification expired | Register – 13 Verification expired | Same |
| Register – 13 Verification expired | Update driving licence | → Register 04 · Documents | Same |

## 24 · Restock

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Restock – 01 Suggested | Confirm restock | Restock – 03 Hub progress | Same |
| Restock – 03 Hub progress | Head to Hub 2 | → Refill 03 · At hub | Same |
| Restock – 01 Suggested | Edit quantity | Restock – 02 Edit quantity | Same |
| Restock – 03 Hub progress | Hub is short | Restock – 05 Hub is short | Same |
| Restock – 01 Suggested | Suggestion expired | Restock – 04 Suggestion expired | Same |
| Restock – 02 Edit quantity | Confirm restock | → Restock 03 · Hub progress | Same |
| Restock – 05 Hub is short | Take 2 / Try Hub 4 | → Restock 03 · Hub progress ‹2› | Same |
| Restock – 04 Suggestion expired | Back to waiting | → Shift 26 · Online waiting | Same |

## 25 · Earnings and sync

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Earnings – 01 Today | Back to waiting | → Shift 26 · Online waiting | Same |
| Sync – 01 Events waiting | Try again now | → Shift 26 · Online waiting ‹2› | Same |

## 26 · Start riding · starting and errors

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 05 Home · Start riding | Start riding | Shift – 06 Home · Starting | Same |
| Shift – 06 Home · Starting | Done loading | → Shift 10 · Before you start | Same |
| Shift – 05 Home · Start riding | Shift already open | Shift – 54 Shift already open | Same |
| Shift – 05 Home · Start riding | No internet | Shift – 55 No internet at start | Same |
| Shift – 54 Shift already open | Continue on this phone | → Shift 06 · Starting | Same |
| Shift – 55 No internet at start | Try again | → Shift 05 · Home | Same |

## 27 · Before you start · ticking

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 10 Pre-shift checklist – none checked | Tick items | Shift – 11 Pre-shift checklist | Same |
| Shift – 11 Pre-shift checklist | Tick all | Shift – 12 Pre-shift checklist – all checked | Same |
| Shift – 12 Pre-shift checklist – all checked | Go to hub | → Shift 52 · Heading to hub | Same |

## 28 · Choose a spot (pending: backend assigns)

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 13 Choose a spot – finding spots | Spots found | Shift – 14 Choose a spot – nothing selected | Same |
| Shift – 14 Choose a spot – nothing selected | Pick a spot | Shift – 15 Choose a spot | Same |
| Shift – 15 Choose a spot | Confirm | Shift – 16 Choose a spot – confirming | Same |
| Shift – 16 Choose a spot – confirming | Spot confirmed | → Shift 19 · Go online at spot | Same |
| Shift – 13 Choose a spot – finding spots | No spot available | Shift – 18 No spot available | Same |
| Shift – 14 Choose a spot – nothing selected | Spot is full | Shift – 17 Spot is full | Same |

## 29 · Go online · items list

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 19 Go online at spot | Items on scooter | Shift – 20 Items list open | Same |
| Shift – 20 Items list open | Close | → Shift 19 · Go online at spot | Same |

## 30 · Online · quiet spell, battery and interrupts

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 26 Online waiting | Quiet spell | Shift – 27 Online · Quiet spell | Same |
| Shift – 26 Online waiting | Scooter battery low | Shift – 31 Online · Scooter battery low | Same |
| Shift – 26 Online waiting | Connection lost | Shift – 40 Connection lost | Same |
| Shift – 26 Online waiting | Location off | Shift – 41 Location is off | Same |
| Shift – 26 Online waiting | Phone time wrong | Shift – 42 Phone time is wrong | Same |
| Shift – 27 Online · Quiet spell | Order comes | → Shift 28 · Order assigned | Same |
| Shift – 31 Online · Scooter battery low | Take a break | → Shift 43 · Take a break | Same |
| Shift – 40 Connection lost | Back online | → Shift 26 · Online waiting | Same |
| Shift – 41 Location is off | Open settings | → Shift 26 · Online waiting ‹2› | Same |
| Shift – 42 Phone time is wrong | Check again | → Shift 26 · Online waiting ‹3› | Same |

## 31 · Shift limit and end shift edge cases

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Shift – 46 Shift limit reached | End shift | Shift – 48 End shift confirm | Same |
| Shift – 46 Shift limit reached | Keep riding | → Shift 26 · Online waiting | Same |
| Shift – 48 End shift confirm | Order in progress | Shift – 47 Can’t end shift yet | Same |
| Shift – 47 Can’t end shift yet | View order | → Order 02 · On the way | Same |

## 32 · Handover · quantity check

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Handover – 01 Pack order | Check quantity | Handover – 08 Check quantity | Same |
| Handover – 08 Check quantity | Not all items | Handover – 09 Partial quantity | Same |
| Handover – 09 Partial quantity | No signal | Handover – 10 Saved offline | Same |
| Handover – 10 Saved offline | Back online | → Handover 02 · Enter code | Same |

## 33 · Register · choose your area

| Screen | Tap or event | Opens | In the app |
|---|---|---|---|
| Register – 01 Details (empty) | Tap area field | Register – 14 Search your area | Same |
| Register – 14 Search your area | Type in search | Register – 15 Search · results | Same |
| Register – 15 Search · results | Pick an area | Register – 02 Details filled | Same |
| Register – 14 Search your area | Pick or use location | → Register 02 · Details filled | Same |
| Register – 15 Search · results | No match | Register – 16 Search · no results | Same |
| Register – 16 Search · no results | Try again | → Register 14 · Search your area | Same |


## Added in the app (no arrow on the Figma tap map)

Buttons the frames draw but the map leaves without a target, linked only to screens Figma already has (or to Google Maps). Nothing new is drawn: no extra screen, sheet or toast.

| Screen | Tap | Opens | In the app |
|---|---|---|---|
| Restock – 04 Suggestion ran out | Ask for a restock | Refill 03 · at the hub | Asks the hub again (`POST /restock` on the rider API) |
| Register – 08 Under review | Done | Register 08, checked again | Looks for the review result now |
| Profile – 04 My spot | Navigate to spot | Google Maps directions | To the spot of today's shift |
| Shift – 02 Off today | Avatar | Profile – 01 | Profile and its pages work on a day off |

Still without a target, as no frame exists for where they would lead: "Enter gate code" (Arrival 01, 02), "Ask hub to prepare" on Shift 02 (no shift yet), and failures no frame covers (the screen stays as it was).
