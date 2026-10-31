# App Phase 1 spec — sign-in and identity verification

**Goal:** on a real Android phone, a user signs in with their phone number, verifies their identity
with their Fayda card (or passport) and a selfie, and sees the result.

**Done when:** on your own phone, through the tunnel, you sign in, verify with your real Fayda card
against the **live** Didit app, and see `approved` — and a second account verified with the same
card ends up on the neutral "contact support" screen.

**Out of scope:** listings, search, maps, contact requests, chat, payments, push notifications,
iOS builds, Amharic/Afaan Oromo translations (the structure is ready; the text comes later),
opening `verificationUrl` in a browser (see §7).

The API contract for everything below is `docs/api-for-mobile.md`. **If this spec and
`api-for-mobile.md` disagree, `api-for-mobile.md` wins** (it is generated from the real code) —
report the mismatch so this spec gets fixed.

---

## 1. App structure

- **Project:** created with `flutter create --org com.yakobzakariya --project-name rental_app .`
  (Android application ID `com.yakobzakariya.rental_app`). Requires Dart 3.11+.
- **Config:** `API_BASE_URL` from `--dart-define`. The app refuses to start (clear error screen in
  debug) if it's missing.
- **Network security (Android):** release builds are HTTPS-only. A **debug-only** network security
  config allows cleartext HTTP to `localhost` only (the phone over USB, reaching the local backend
  through `adb reverse tcp:3000 tcp:3000`). It must never apply to release builds.
- **Devices:** all testing is on a physical Android phone (no emulator). Daily: adb (wireless
  debugging, or USB) with `adb reverse` and `API_BASE_URL=http://localhost:3000`. Wireless: the ngrok tunnel URL. Didit
  webhooks always reach the backend through the ngrok tunnel.
- **Router (`go_router`)** with a redirect based on the auth state, which has four values:
  - `checking` → splash (startup, while tokens are read and `GET /me` runs);
  - `signedOut` → `/sign-in`;
  - `signedIn` → `/home`;
  - `accountUnavailable` → the neutral account-unavailable screen.
- **Theme:** Material 3, light and dark from one seed (`#0B6E69`), following the phone's
  setting; bundled Noto Sans + Noto Sans Ethiopic; 48 px tap targets (52 px main buttons); WCAG AA
  contrast in both themes. Calm and readable: many users have small or older phones. Full rules:
  the Design section in `CLAUDE.md`.
- **Translations:** `gen-l10n` with `app_en.arb`. All strings, including error messages and
  fallback texts, come from it.

## 2. API layer

- One `dio` instance with the base URL, JSON headers and a 20-second timeout (mobile networks are slow).
- **ngrok header:** add `ngrok-skip-browser-warning: true` only when the base URL's host ends in
  `.ngrok-free.dev` or `.ngrok-free.app`, so ngrok never answers with its browser warning page.
  No extra flag.
- **Errors:** every non-2xx response is converted into `ApiError(code, statusCode, retryAfterSeconds?)`
  using the body's `code` (and `retryAfterSeconds` or the `Retry-After` header when present).
  `attemptsRemaining` and `manualReviewAvailable` are read too when present.
  Connection failures and timeouts become `ApiError('NETWORK_ERROR')`; a response without a
  readable `code` (e.g. an ngrok or proxy error page) becomes `ApiError('UNKNOWN_ERROR')`.
  `VALIDATION_FAILED` carries the code only; nothing is logged (if logging is added later: field
  names only, debug builds only).
- **Unknown values never crash the app.** An unknown error `code`, verification `status` or
  `reasonCode` is shown with generic fallback text from the ARB file.
- **Auth interceptor:**
  - adds `Authorization: Bearer <accessToken>` to protected requests (not to `/auth/otp/*`,
    `/auth/refresh` or `/auth/logout`, which are public);
  - on `401 ACCESS_TOKEN_EXPIRED`: runs **one** refresh (`POST /auth/refresh`); other requests that
    fail meanwhile wait for it; on success, stores both new tokens and retries the original request once;
  - if the refresh fails with `INVALID_REFRESH_TOKEN`, or a request gets any other 401
    (`UNAUTHENTICATED`): clears tokens and signs the user out;
  - if the refresh fails with **`NETWORK_ERROR` (connection failure or timeout): never sign out.**
    Keep both tokens; the waiting requests fail with `NETWORK_ERROR` and the UI shows a connection
    error;
  - on `403 ACCOUNT_UNAVAILABLE` (from refresh or any protected route): clears tokens and moves to
    the `accountUnavailable` state.

## 3. Screens and flows

### 3.1 Startup (splash, state `checking`)
- Read tokens from secure storage. None → `signedOut`. Present → call `GET /me` (an expired access
  token is simply refreshed by the interceptor first):
  - success → `signedIn` (home);
  - `ACCOUNT_UNAVAILABLE` → `accountUnavailable`;
  - refresh failed with `INVALID_REFRESH_TOKEN`, or `UNAUTHENTICATED` → `signedOut`;
  - `NETWORK_ERROR` → a **"Can't connect — Retry"** state on the splash screen. Tokens are kept;
    never sign out for this. "Retry" runs the startup check again.

### 3.2 Phone entry (`/sign-in`)
- One field; accept what people naturally type (`0911…`, `911…`, `+251…`). The **API** normalises
  and validates; the app only checks it's not empty.
- `POST /auth/otp/request`. On success go to the OTP screen with the phone and `expiresInSeconds`.
- Errors: `INVALID_PHONE` ("Enter an Ethiopian mobile number"), `OTP_RATE_LIMITED` and
  `RATE_LIMITED` ("Too many attempts, try again in N minutes" using `retryAfterSeconds`),
  `SMS_SEND_FAILED`, `NETWORK_ERROR`.

### 3.3 OTP (`/sign-in/code`)
- 6-digit field with auto-submit when complete. Countdown from `expiresInSeconds`; a "Send a new
  code" button after it ends (calls OTP request again).
- `POST /auth/otp/verify` with `deviceName` = the phone model (from `device_info_plus`).
  Store both tokens, go to home.
- Errors: `OTP_INVALID` (show `attemptsRemaining` if present), `OTP_EXPIRED`,
  `OTP_ATTEMPTS_EXCEEDED` (offer a new code), `ACCOUNT_UNAVAILABLE`, `NETWORK_ERROR`.

### 3.4 Home (`/home`)
- Shows the verification state from `GET /verification/status` (and `GET /me` for the verified
  name), refreshed when the screen opens, on pull-to-refresh, and **when the app returns to the
  foreground**.
- One card per status:
  - `not_verified` → explanation of why we verify + "Verify my identity" button;
  - `pending` → "Checking your verification…" + a "Continue verification" button if `canRetry`
    (resumes the same session);
  - `approved` → verified badge with the verified name (from `GET /me`);
  - `declined` → message for `reasonCode`, then — independently, both can appear:
    - "Try again" if `canRetry`. If `canRetry` is false: "You can try again after HH:mm" when
      `retryAvailableAt` is set (the timestamp shown in Africa/Addis_Ababa time, 24-hour), or
      "Try again later" when it is `null`. When that moment passes, re-fetch the status — never
      assume `canRetry` changed (hard rule 7);
    - "Request manual review" if `canRequestManualReview`.

    The app never decides between these itself (hard rule 7);
  - `manual_review` → "Our team is reviewing your verification";
  - `blocked` → neutral "Please contact support". No reason, no buttons;
  - unknown `status` → generic fallback text, no buttons.
- Unknown `reasonCode` → generic "We couldn't verify your identity" fallback text.
- App-bar menu with **"Settings"** (profile screen) and **"Sign out"** (§3.7).

### 3.5 Verification
1. **Consent screen**, shown before every **new** session ("Verify my identity", "Try again"),
   and **skipped when resuming** ("Continue verification"). It explains what is checked (ID + selfie)
   with exactly this text:

   > Your ID and selfie are checked by our verification partner, Didit. We don't store the photos.
   > We keep your verified name, date of birth and a protected one-way reference to your ID number,
   > used only to prevent duplicate and banned accounts.

   …and a "Continue" button.
2. `POST /verification/sessions` → `{ verificationUrl, sessionToken }`.
   Errors: `ALREADY_VERIFIED`, `VERIFICATION_IN_REVIEW`, `VERIFICATION_UNAVAILABLE` (neutral),
   `VERIFICATION_RETRY_LIMIT` (show when they can retry from `retryAfterSeconds`; offer manual
   review if `manualReviewAvailable`), `VERIFICATION_PROVIDER_UNAVAILABLE` ("try again shortly").
   The `sessionToken` is never logged.
3. `DiditSdk.startVerification(sessionToken)` returns a sealed `VerificationResult`:
   - `VerificationCompleted` → the **"Checking…" screen** (step 4). Its `session.status` is
     ignored — the backend decides (hard rule 5);
   - `VerificationCancelled` → back to home (the session can be resumed via "Continue verification");
   - `VerificationFailed` → back to home with the message "Verification couldn't continue. Please
     try again." (`error.type` / `error.message` are neither shown nor logged).

   Home always re-reads the status when it is shown.
4. The **"Checking…" screen** polls `GET /verification/status` every **5 seconds for the first
   minute, then every 30 seconds**, for as long as the screen is open, and also immediately when
   the app returns to the foreground. As soon as the status is no longer `pending`, it shows the
   matching result card (same cards as home). After the first minute it also shows "This can take
   a few minutes — you can leave this screen; home will update when you come back."
   A `NETWORK_ERROR` while polling shows a connection hint but keeps polling.

### 3.6 Manual review request
- Button shown only when `canRequestManualReview` is true (home card, and after
  `VERIFICATION_RETRY_LIMIT` when `manualReviewAvailable`). Confirmation dialog, then
  `POST /verification/manual-review-request`.
- Response: the full status object (same shape as `GET /verification/status`); the screen shows it.
- Errors: `MANUAL_REVIEW_NOT_AVAILABLE` (refresh the status), `VERIFICATION_IN_REVIEW` (show "in
  review"), `ALREADY_VERIFIED` (show approved), `VERIFICATION_UNAVAILABLE` (neutral "contact support").

### 3.7 Profile / settings
- Shows phone, verification status, and — once approved — the verified name and date of birth
  (read-only). The date of birth is shown **exactly as received** (`YYYY-MM-DD` string) until A13
  confirms which calendar Didit returns.
- Language: Amharic / Afaan Oromo / English → `PATCH /me { preferredLanguage }`. In Phase 1 the
  app's own text stays English; the choice is saved for later.
- "Sign out" (also in the home app-bar menu) → `POST /auth/logout` with the refresh token (public
  route, always `204`; ignore network failures), clear tokens, go to sign-in.

### 3.8 Account unavailable
- Shown on `ACCOUNT_UNAVAILABLE` anywhere (state `accountUnavailable`). Neutral text: "This account
  is unavailable. Please contact support." One button, **"Back to sign in"** (the tokens are
  already cleared, so there is nothing to log out).

## 4. Didit SDK setup (Android)

Confirmed from docs.didit.me/integration/native-sdks/flutter-sdk — still re-check against the
package version actually installed.

- `flutter pub add didit_sdk`.
- `DiditSdk.startVerification(sessionToken)` → sealed `VerificationResult`:
  `VerificationCompleted` (`session.status`: approved / pending / declined),
  `VerificationCancelled`, `VerificationFailed` (`error.type`, `error.message`).
- Minimum Android API 23, Java 17.
- **Disable NFC**: `diditSdkAndroidNfcEnabled=false` in `android/gradle.properties`. Our workflow
  doesn't read ID chips. (The extra `pickFirsts` packaging rule is only needed with NFC on.)
- The SDK requests camera permission itself at runtime.
- iOS (later, needs a Mac): camera, microphone and photo-library usage descriptions in
  `Info.plist`, or the app crashes when the camera opens.

## 5. Testing

- **Unit:** error mapping (every code in the contract, plus an unknown code → fallback), token
  storage, the refresh interceptor (single refresh for parallel `ACCESS_TOKEN_EXPIRED`, retry once,
  sign-out **only** on `INVALID_REFRESH_TOKEN` / non-expiry 401, **tokens kept on a network error or
  timeout during refresh**, `ACCOUNT_UNAVAILABLE` → unavailable state), the ngrok-header host rule,
  status/`reasonCode` parsing including unknown values, repositories with a mocked dio.
- **Widget:** each home status card (including unknown status and unknown `reasonCode`, and the
  declined card with every `canRetry` × `canRequestManualReview` combination), phone entry errors,
  OTP states, startup "Can't connect — Retry", the "Checking…" screen's polling interval change
  (5 s → 30 s) and leaving it, each SDK result (completed / cancelled / failed).
- **Manual:** the phone over USB against the local backend (A7–A11); the phone wirelessly through
  the tunnel (A12); finally the live Didit test with a real Fayda card (A13).

## 6. Real-phone and live-Didit test (from the backend's T2.9)

- Use a **fresh phone number** for each real test account (codes appear in the backend console).
- Backend switched to the live Didit app: `DIDIT_ENVIRONMENT=live`, live API key, live workflow ID,
  live webhook secret; the live webhook destination points at the same tunnel URL. This work is
  done in `rental-api`.
- Record, without ever pasting a real ID number anywhere: whether the physical Fayda card is
  accepted as an ID card; which number fields come back and their lengths (FIN 12 digits /
  FAN 16 digits?); the date-of-birth format and calendar; whether the paper and digital Fayda work.
  The backend repo has (or will have) a script that prints only the *shape* of the decision.
- A second account verified with the same card must end up `blocked` (neutral screen).

## 7. Later (not Phase 1)

- **Ethiopian clock:** when Amharic is added, consider showing times (e.g. "try again after …")
  on the Ethiopian clock (12-hour, the day starting at 6:00 — 7:00 international is 1:00).
- **Browser fallback:** opening `verificationUrl` in the browser if the SDK can't be used.
- **Record consent server-side** (backend item): store that and when the user accepted the
  consent text.
- **Legal review of the consent text** before launch.
- **Afaan Oromo Material-localizations fallback:** Flutter's built-in `GlobalMaterialLocalizations`
  (texts like "OK", "Cancel", date pickers) cover Amharic (`am`) but not Afaan Oromo (`om`). When
  `app_om.arb` is added, add a small fallback delegate for `om` (e.g. reusing English or Amharic
  Material texts), or the app fails to load Material widgets in that locale.
