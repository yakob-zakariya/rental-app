# App Phase 1 tasks

Work through these **in order, one task per Claude Code session** (`/clear` between tasks). For each:
plan → approve → implement with tests → **run it yourself** → read the explanation → commit → push.

Tasks use the prefix **A** so they don't get confused with the backend's T-numbers.
If `docs/app-phase-1-spec.md` and `docs/api-for-mobile.md` disagree, `api-for-mobile.md` wins.

---

## Setup (you do this, with Claude Code's help if stuck)

- [ ] **A0 Toolchain.** Install Flutter (stable) and Android Studio on Ubuntu; enable USB debugging
      on your Android phone. (No emulator: it crashes the dev PC. All testing is on the phone.)
      *Done when:* `flutter doctor` shows no errors for Flutter, Android toolchain and Android Studio,
      `flutter --version` shows Dart 3.11+, and the default counter app runs on your phone over USB.

## Foundation

- [ ] **A1 Project + structure.** `flutter create --org com.yakobzakariya --project-name rental_app .`
      (in this repo), folder layout from `CLAUDE.md`, strict lints (`flutter_lints` + a few extra
      rules), `API_BASE_URL` config via `--dart-define` with a clear error if missing, a
      **debug-only** Android network security config allowing cleartext to `localhost` only
      (release stays HTTPS-only), `.gitignore`.
      *Done when:* the app starts showing "Hello" with the configured base URL in debug, and
      `flutter analyze` is clean.
- [ ] **A2 App shell.** Material 3 light + dark themes (Design section in `CLAUDE.md`: seed
      `#0B6E69`, bundled Noto Sans + Noto Sans Ethiopic with their OFL licences, 16 px cards,
      48/52 px tap targets), `gen-l10n` with `app_en.arb`, `go_router` with placeholder sign-in and
      home screens, Riverpod `ProviderScope`.
      *Done when:* you can navigate between the two placeholders, all text comes from the ARB file,
      the app follows the phone's light/dark setting, and the shell's widget tests pass in both
      themes (contrast and tap-target checks included).

## API layer

- [ ] **A3 API client + errors.** `dio` instance, `ApiError` model, mapping of every error code in
      the contract (including `retryAfterSeconds` and `NETWORK_ERROR`), unknown codes handled
      without crashing, the ngrok header sent only when the base URL's host ends in
      `.ngrok-free.dev` or `.ngrok-free.app`. Unit tests with a mocked adapter.
      *Done when:* tests cover success, an error body with a code, an unknown code, a 429 with
      Retry-After, a timeout, and the ngrok host rule.
- [ ] **A4 Token storage.** Secure-storage wrapper (read, write both tokens, clear). Unit tests.
- [ ] **A5 Auth interceptor + refresh.** Bearer header on protected routes only, single-flight
      refresh on `ACCESS_TOKEN_EXPIRED`, retry once, sign-out **only** on `INVALID_REFRESH_TOKEN`
      or a non-expiry 401, `ACCOUNT_UNAVAILABLE` → unavailable state. A network error or timeout
      during refresh **never** signs out: tokens are kept and the requests fail with `NETWORK_ERROR`.
      *Done when:* a test proves 3 parallel requests that all get `ACCESS_TOKEN_EXPIRED` trigger
      exactly one refresh and all three succeed afterwards, and a test proves a refresh that times
      out leaves both tokens in storage and the user signed in.

## Sign-in

- [ ] **A6 Phone entry screen.** Field, loading state, error messages per code. Widget tests.
- [ ] **A7 OTP screen + sign-in.** 6-digit input, countdown, resend, verify with `deviceName` from
      `device_info_plus` (phone model), store tokens, go home. Widget tests.
      *Done when:* you sign in on your phone over USB against your local backend
      (`adb reverse tcp:3000 tcp:3000`, `API_BASE_URL=http://localhost:3000`; code from the
      backend console).
- [ ] **A8 Startup routing + sign-out.** Auth states `checking` / `signedOut` / `signedIn` /
      `accountUnavailable`, splash logic from spec 3.1 (including the "Can't connect — Retry" state,
      which never signs out), router redirect, account-unavailable screen with "Back to sign in",
      sign-out in the home screen's app-bar menu.
      *Done when:* closing and reopening the app keeps you signed in; starting it with the backend
      stopped shows "Can't connect — Retry" and, after starting the backend, Retry gets you home
      still signed in; signing out returns to phone entry; a banned account (ban it via Postman)
      lands on the neutral screen.

## Verification

- [ ] **A9 Home + status cards.** `GET /verification/status` + `GET /me`, one card per status
      (declined: "Try again" and "Request manual review" shown independently from `canRetry` /
      `canRequestManualReview`; when `canRetry` is false, "You can try again after HH:mm" (or "…tomorrow
      after HH:mm") from `retryAvailableAt` in Africa/Addis_Ababa time, or "Try again later" if it is `null`; re-fetch
      the status once that time passes),
      fallback text for unknown status / `reasonCode`, pull-to-refresh, refresh on app foreground.
      Widget tests for every status, the unknown values, and the declined-card combinations.
- [ ] **A10 Didit SDK + verification flow.** Add `didit_sdk` (`diditSdkAndroidVariant=autodetection`:
      no NFC; confirm the API against the installed version; report the release APK size), consent screen (before new sessions only, exact text from spec 3.5),
      start session (all errors), launch the SDK, handle each result (completed → "Checking…",
      cancelled → home, failed → home with message), "Checking…" polling screen (5 s for the first
      minute, then 30 s, while open, plus on foreground), manual-review request (all four errors;
      response is the full status object).
      *Done when:* on your phone over USB with the **sandbox** backend, you complete a flow and the
      home screen shows the result. Keep the ngrok tunnel running: Didit's webhooks reach the
      backend through it (without it, only the 5-minute polling job delivers the decision).
- [ ] **A11 Profile / settings.** Phone, status, verified name/DOB (read-only, DOB exactly as
      received), language choice via `PATCH /me`, sign-out.

## Real world

- [ ] **A12 Phone through the tunnel, wireless (sandbox).** Unplug the USB cable and run with
      `--dart-define=API_BASE_URL=https://<tunnel-domain>` (HTTPS, the ngrok header, a real mobile
      network). Full flow with the sandbox.
      Note anything awkward on a real phone (keyboard covering fields, slow network, small screen).
- [ ] **A13 Live Didit test with your real Fayda card** (the backend's T2.9). Set up the live Didit
      app first in `rental-api` (workflow restricted like the sandbox, webhook destination, live keys
      in the backend's `.env`, `DIDIT_ENVIRONMENT=live`). Use a fresh phone number. Record the
      findings from spec §6 in `rental-api/docs/didit-integration.md`, then verify a second account
      with the same card ends up blocked.

---

## Later (not Phase 1) — see spec §7

- Ethiopian-clock times when Amharic is added.
- Browser fallback via `verificationUrl`.
- Record consent server-side (backend).
- Legal review of the consent text before launch.

## App Phase 1 is done when

- Every box above is ticked.
- You verified yourself on your own phone with your real Fayda card through the live Didit app.
- You can explain every screen and the token refresh flow out loud, as in a job interview.
