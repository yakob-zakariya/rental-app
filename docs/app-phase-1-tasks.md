# App Phase 1 tasks

Work through these **in order, one task per Claude Code session** (`/clear` between tasks). For each:
plan → approve → implement with tests → **run it yourself** → read the explanation → commit → push.

Tasks use the prefix **A** so they don't get confused with the backend's T-numbers.

---

## Setup (you do this, with Claude Code's help if stuck)

- [ ] **A0 Toolchain.** Install Flutter (stable) and Android Studio on Ubuntu; create an Android
      emulator; enable USB debugging on your Android phone.
      *Done when:* `flutter doctor` shows no errors for Flutter, Android toolchain and Android Studio,
      and the default counter app runs on both the emulator and your phone.

## Foundation

- [ ] **A1 Project + structure.** `flutter create rental_app`, folder layout from `CLAUDE.md`,
      strict lints (`flutter_lints` + a few extra rules), `API_BASE_URL` config via `--dart-define`
      with a clear error if missing, `.gitignore`.
      *Done when:* the app starts showing "Hello" with the configured base URL in debug, and
      `flutter analyze` is clean.
- [ ] **A2 App shell.** Material 3 theme, `gen-l10n` with `app_en.arb`, `go_router` with
      placeholder sign-in and home screens, Riverpod `ProviderScope`.
      *Done when:* you can navigate between the two placeholders, and all text comes from the ARB file.

## API layer

- [ ] **A3 API client + errors.** `dio` instance, `ApiError` model, mapping of every error code in
      the contract (including `retryAfterSeconds` and `NETWORK_ERROR`), the ngrok header in dev.
      Unit tests with a mocked adapter.
      *Done when:* tests cover success, an error body with a code, a 429 with Retry-After, and a timeout.
- [ ] **A4 Token storage.** Secure-storage wrapper (read, write both tokens, clear). Unit tests.
- [ ] **A5 Auth interceptor + refresh.** Bearer header, single-flight refresh on
      `ACCESS_TOKEN_EXPIRED`, retry once, sign-out on refresh failure, `ACCOUNT_UNAVAILABLE` handling.
      *Done when:* a test proves 3 parallel requests that all get `ACCESS_TOKEN_EXPIRED` trigger
      exactly one refresh and all three succeed afterwards.

## Sign-in

- [ ] **A6 Phone entry screen.** Field, loading state, error messages per code. Widget tests.
- [ ] **A7 OTP screen + sign-in.** 6-digit input, countdown, resend, verify, store tokens, go home.
      Widget tests. *Done when:* you sign in on the emulator against your local backend (code from
      the backend console).
- [ ] **A8 Startup routing + sign-out.** Splash logic from spec 3.1, router redirect, account-unavailable
      screen, sign-out. *Done when:* closing and reopening the app keeps you signed in; signing out
      returns to phone entry; a banned account (ban it via Postman) lands on the neutral screen.

## Verification

- [ ] **A9 Home + status cards.** `GET /verification/status` + `GET /me`, one card per status,
      pull-to-refresh. Widget tests for every status.
- [ ] **A10 Didit SDK + verification flow.** Add `didit_sdk` (NFC disabled), consent screen,
      start session (all errors), launch the SDK, "Checking…" polling screen, manual-review request.
      *Done when:* on the emulator with the **sandbox** backend, you complete a flow and the home
      screen shows the result.
- [ ] **A11 Profile / settings.** Phone, status, verified name/DOB (read-only), language choice via
      `PATCH /me`, sign-out.

## Real world

- [ ] **A12 Real phone through the tunnel (sandbox).** Run on your phone with
      `--dart-define=API_BASE_URL=https://<tunnel-domain>`. Full flow with the sandbox.
      Note anything awkward on a real phone (keyboard covering fields, slow network, small screen).
- [ ] **A13 Live Didit test with your real Fayda card** (the backend's T2.9). Set up the live Didit
      app first (workflow restricted like the sandbox, webhook destination, live keys in the
      backend's `.env`, `DIDIT_ENVIRONMENT=live`). Use a fresh phone number. Record the findings
      from spec §6 in `rental-api/docs/didit-integration.md`, then verify a second account with the
      same card ends up blocked.

---

## App Phase 1 is done when

- Every box above is ticked.
- You verified yourself on your own phone with your real Fayda card through the live Didit app.
- You can explain every screen and the token refresh flow out loud, as in a job interview.
