# A12 — real phone through the tunnel (sandbox)

**Date:** 2026-11-01
**Phone:** Samsung Galaxy M15 (SM-M156B, arm64), Android 12+
**Build:** release (`flutter run --release`), installed over USB, then **unplugged**
**Backend:** local `rental-api`, Didit **sandbox**, reached through ngrok
(`https://coach-mongoose-liable.ngrok-free.dev`); verifications reset first with
`npm run dev:reset-verifications`

## Result

The developer went through every check and reported that **everything worked**: the full flow over the real network (HTTPS,
the ngrok header, no cable), from sign-in to identity verification with the sandbox.

| # | Check | Result |
| --- | --- | --- |
| 1 | Sign in (code from the backend console) | ✓ |
| 2 | Close and reopen the app: still signed in | ✓ |
| 3 | Full Didit flow: consent → camera → Checking → result | ✓ |
| 4 | Pull to refresh, leave the app and come back | ✓ |
| 5 | Airplane mode on Home, then pull ("Couldn't refresh…") | ✓ |
| 6 | Airplane mode, then reopen ("Can't connect" + Retry) | ✓ |
| 7 | Settings: change language | ✓ |
| 8 | Largest font size, keyboard not covering fields | ✓ |
| 9 | Dark mode on/off | ✓ |
| 10 | Sign out | ✓ |
| 11 | A second account verified with the same sandbox identity → blocked as a duplicate (V6) | ✓ only "Please contact support.", no reason |

## Things learned

- **localhost vs. tunnel.** `API_BASE_URL=http://localhost:3000` only works while the cable is in:
  `adb reverse` carries the phone's `localhost` over USB. With the cable out the app reports
  "No connection". For a cable-free run use the tunnel URL (no `adb reverse` needed):
  `flutter run --release --dart-define=API_BASE_URL=https://<tunnel-domain>`, then unplug.
- **ngrok's free tier can be slow to answer the first request** (one 5-second timeout from the
  computer before the test). If the first "Send code" says "No connection", try again.
- **`didit_sdk` 4.9.1 still applies the Kotlin Gradle plugin.** The build warns that future Flutter
  versions will refuse such plugins. Today's build is fine; before upgrading Flutter, check that
  Didit has released a version with Built-in Kotlin support (spec §7).
- **APK size:** `flutter run --release` produced a 63.3 MB APK; what users download from the Play
  Store stays about the per-CPU size measured in A10 (42.4 MB for arm64).

## Nothing to fix

No awkward screens were reported (keyboard, slow network, small screen, large fonts).
