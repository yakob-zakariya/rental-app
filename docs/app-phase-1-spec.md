# App Phase 1 spec — sign-in and identity verification

**Goal:** on a real Android phone, a user signs in with their phone number, verifies their identity
with their Fayda card (or passport) and a selfie, and sees the result.

**Done when:** on your own phone, through the tunnel, you sign in, verify with your real Fayda card
against the **live** Didit app, and see `approved` — and a second account verified with the same
card ends up on the neutral "contact support" screen.

**Out of scope:** listings, search, maps, contact requests, chat, payments, push notifications,
iOS builds, Amharic/Afaan Oromo translations (the structure is ready; the text comes later).

The API contract for everything below is `docs/api-for-mobile.md`.

---

## 1. App structure

- **Config:** `API_BASE_URL` from `--dart-define`. The app refuses to start (clear error screen in
  debug) if it's missing.
- **Router (`go_router`)** with a redirect based on the auth state:
  - not signed in → `/sign-in`
  - signed in → `/home`
- **Theme:** one simple Material 3 theme. Large touch targets and readable text; many users have
  small or older phones.
- **Translations:** `gen-l10n` with `app_en.arb`. All strings, including error messages, come from it.

## 2. API layer

- One `dio` instance with the base URL, JSON headers and a 20-second timeout (mobile networks are slow).
- In development through ngrok, add the header `ngrok-skip-browser-warning: true`, so ngrok never
  answers with its browser warning page.
- **Errors:** every non-2xx response is converted into `ApiError(code, statusCode, retryAfterSeconds?)`
  using the body's `code` (and `retryAfterSeconds` or the `Retry-After` header when present).
  Connection failures and timeouts become `ApiError('NETWORK_ERROR')`.
- **Auth interceptor:**
  - adds `Authorization: Bearer <accessToken>` to protected requests;
  - on `401 ACCESS_TOKEN_EXPIRED`: runs **one** refresh (`POST /auth/refresh`); other requests that
    fail meanwhile wait for it; on success, stores both new tokens and retries the original request once;
  - on any other 401, or if the refresh fails with `INVALID_REFRESH_TOKEN`: clears tokens and signs
    the user out;
  - on `403 ACCOUNT_UNAVAILABLE`: clears tokens and shows the neutral account-unavailable screen.

## 3. Screens and flows

### 3.1 Startup
- Read tokens from secure storage. None → sign-in. Present → call `GET /me`:
  - success → home;
  - `ACCOUNT_UNAVAILABLE` → account-unavailable screen;
  - expired/invalid tokens → sign-in.

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
- `POST /auth/otp/verify` with `deviceName` (e.g. the phone model). Store both tokens, go to home.
- Errors: `OTP_INVALID` (show `attemptsRemaining` if present), `OTP_EXPIRED`,
  `OTP_ATTEMPTS_EXCEEDED` (offer a new code), `ACCOUNT_UNAVAILABLE`, `NETWORK_ERROR`.

### 3.4 Home (`/home`)
- Shows the verification state from `GET /verification/status`, refreshed when the screen opens
  and on pull-to-refresh.
- One card per status:
  - `not_verified` → explanation of why we verify + "Verify my identity" button;
  - `pending` → "Checking your verification…" + a "Continue verification" button if `canRetry`
    (resumes the same session);
  - `approved` → verified badge with the verified name (from `GET /me`);
  - `declined` → message for `reasonCode` + "Try again" if `canRetry`, else
    "Request manual review" if `canRequestManualReview`, else "Try again later" with
    `retriesLeftToday`;
  - `manual_review` → "Our team is reviewing your verification";
  - `blocked` → neutral "Please contact support". No reason, no buttons.
- A settings button (profile screen).

### 3.5 Verification
1. "Verify my identity" → a short **consent screen**: what is checked (ID + selfie), that the ID
   and selfie images are processed by our verification provider and **not stored by us**, and a
   "Continue" button.
2. `POST /verification/sessions` → `{ verificationUrl, sessionToken }`.
   Errors: `ALREADY_VERIFIED`, `VERIFICATION_IN_REVIEW`, `VERIFICATION_UNAVAILABLE` (neutral),
   `VERIFICATION_RETRY_LIMIT` (show when they can retry from `retryAfterSeconds`; offer manual
   review if `manualReviewAvailable`), `VERIFICATION_PROVIDER_UNAVAILABLE` ("try again shortly").
3. `DiditSdk.startVerification(sessionToken)`.
4. Whatever the SDK returns (completed, cancelled, failed), go to a **"Checking…" screen** that
   polls `GET /verification/status` every 3 seconds for up to 2 minutes, then shows the matching
   result card. If it's still `pending` after 2 minutes: "We're still checking — we'll update this
   screen when you come back."
5. Cancelled by the user → back to home (the session can be resumed via "Continue verification").

### 3.6 Manual review request
- Button shown only when `canRequestManualReview` is true. Confirmation dialog, then
  `POST /verification/manual-review-request`. Errors: `MANUAL_REVIEW_NOT_AVAILABLE`,
  `VERIFICATION_IN_REVIEW`.

### 3.7 Profile / settings
- Shows phone, verification status, and verified name/date of birth once approved (read-only).
- Language: Amharic / Afaan Oromo / English → `PATCH /me { preferredLanguage }`. In Phase 1 the
  app's own text stays English; the choice is saved for later.
- "Sign out" → `POST /auth/logout` with the refresh token (ignore failures), clear tokens, go to sign-in.

### 3.8 Account unavailable
- Shown on `ACCOUNT_UNAVAILABLE` anywhere. Neutral text: "This account is unavailable. Please
  contact support." Sign-out only.

## 4. Didit SDK setup (Android)

- `flutter pub add didit_sdk`. Confirm the exact API in its docs before coding.
- Minimum Android API 23, Java 17.
- **Disable NFC**: `diditSdkAndroidNfcEnabled=false` in `android/gradle.properties`. Our workflow
  doesn't read ID chips.
- The SDK requests camera permission itself at runtime.
- iOS (later, needs a Mac): camera, microphone and photo-library usage descriptions in
  `Info.plist`, or the app crashes when the camera opens.

## 5. Testing

- **Unit:** error mapping (every code in the contract), token storage, the refresh interceptor
  (single refresh for parallel 401s, retry once, sign-out on refresh failure), repositories with a
  mocked dio.
- **Widget:** each home status card, phone entry errors, OTP states, the "Checking…" screen timing out.
- **Manual (see tasks A11–A12):** emulator against local backend; real phone through the tunnel;
  finally the live Didit test with a real Fayda card.

## 6. Real-phone and live-Didit test (from the backend's T2.9)

- Use a **fresh phone number** for each real test account (codes appear in the backend console).
- Backend switched to the live Didit app: `DIDIT_ENVIRONMENT=live`, live API key, live workflow ID,
  live webhook secret; the live webhook destination points at the same tunnel URL.
- Record, without ever pasting a real ID number anywhere: whether the physical Fayda card is
  accepted as an ID card; which number fields come back and their lengths (FIN 12 digits /
  FAN 16 digits?); the date-of-birth format and calendar; whether the paper and digital Fayda work.
  The backend repo has (or will have) a script that prints only the *shape* of the decision.
- A second account verified with the same card must end up `blocked` (neutral screen).
