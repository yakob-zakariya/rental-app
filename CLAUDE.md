# CLAUDE.md — rental-app

Read this file fully at the start of every session.

## What this project is

The mobile app for a broker-free house rental platform in Ethiopia. Landlords list homes directly;
tenants find them without paying a broker. Trust comes from **verified identities**.

The backend lives in a separate repo, `rental-api` (NestJS). This app only talks to it over HTTP.

- The API contract: `docs/api-for-mobile.md` (copied from `rental-api`; that repo is the source of truth)
- What we are building now: `docs/app-phase-1-spec.md`
- Task breakdown: `docs/app-phase-1-tasks.md`

## The developer is new to Flutter

This is the developer's **first Flutter app**. He knows NestJS, Laravel and Next.js well.

- Explain Flutter and Dart concepts the first time they appear (widgets, `BuildContext`,
  `StatelessWidget` vs `StatefulWidget`, `async`/`await` in Dart, providers, routing), briefly,
  relating them to concepts he knows (e.g. "a provider is like an injectable service in NestJS").
- Keep tasks small. After each task, explain what was built, which files matter, and how to run
  and see it.
- Prefer plain, readable code over clever abstractions. No code generation (`build_runner`,
  `freezed`, `riverpod_generator`) in Phase 1, so there is no generated code to puzzle over.

## Current phase: App Phase 1 — sign-in and identity verification

Only build what `docs/app-phase-1-spec.md` describes. Listings, search, maps, chat, payments and
push notifications are **out of scope**. If a task seems to need them, stop and ask.

## Stack

- **Flutter** (stable channel), **Dart 3.11+** (required by the Didit SDK)
- **Target:** Android first (the developer uses Ubuntu; iOS builds need a Mac, later)
- **State management:** Riverpod (`flutter_riverpod`), hand-written providers, no code generation
- **HTTP:** `dio`
- **Secure storage:** `flutter_secure_storage`
- **Navigation:** `go_router`
- **Translations:** Flutter's built-in `gen-l10n` with ARB files (English now; Amharic and Afaan Oromo later)
- **Identity verification:** `didit_sdk` (Didit's Flutter SDK), started with a `sessionToken` from our backend
- **Tests:** `flutter_test`, `mocktail`

## Folder layout

```
lib/
  main.dart
  app/                 # app widget, router, theme
  core/
    config/            # API base URL from --dart-define
    api/               # dio client, ApiError, refresh interceptor
    storage/           # token storage (secure storage only)
  features/
    auth/              # phone entry, OTP, sign-in state
    profile/           # /me, language preference, logout
    verification/      # status, start session, Didit SDK, result screens
  l10n/                # ARB translation files
test/
docs/
```

Each feature has `data/` (API calls, models) and `presentation/` (screens, widgets, providers).

## Commands

Fill these in as the project grows, and keep them accurate.

```
flutter doctor                      # check the toolchain
flutter pub get                     # install packages
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000     # Android emulator
flutter run --dart-define=API_BASE_URL=https://<tunnel-domain>  # real phone via ngrok
flutter test                        # all tests
flutter analyze                     # lints
dart format .                       # formatting
```

## Hard rules — never break these

1. **Tokens live only in `flutter_secure_storage`.** Never in `SharedPreferences`, files, or memory
   that outlives the session.
2. **Never log tokens, OTP codes, or any identity data** (names, dates of birth, document data).
   Not with `print`, not with `debugPrint`, not in dio's log interceptor (if used, it must redact
   `Authorization` headers and token bodies).
3. **Switch on the API's error `code`, never on its message text.** Every code the app handles is
   listed in `docs/api-for-mobile.md`.
4. **Refresh the access token only on `ACCESS_TOKEN_EXPIRED`,** and only one refresh at a time:
   parallel requests wait for the single in-flight refresh, then retry. Always store both new tokens.
5. **The Didit SDK's result is never the final answer.** After the SDK closes, poll
   `GET /verification/status`. The backend applies its own rules (bans, duplicates, age).
6. **No Didit API key in the app, ever.** The app only receives a `sessionToken` from our backend.
7. **Don't duplicate backend rules in the app.** Whether the user can retry, request manual review,
   etc. comes from the API (`canRetry`, `canRequestManualReview`), not from app logic.
8. **Blocked users see only a neutral "contact support" message.** Never a reason.
9. **Every user-facing string comes from the ARB translation files.** No hard-coded UI text.
10. **The API base URL comes from `--dart-define=API_BASE_URL`.** Never hard-code a URL.

## Conventions

- One screen per file. Keep widgets small; extract a widget when a `build` method grows past ~80 lines.
- API calls live in repository classes under `data/`; screens never call `dio` directly.
- Models are plain Dart classes with hand-written `fromJson`. Dates of birth stay `YYYY-MM-DD`
  strings; timestamps are parsed as UTC and shown in Africa/Addis_Ababa time.
- Every API failure becomes an `ApiError(code, statusCode, retryAfterSeconds?)`; network failures
  become a distinct `NETWORK_ERROR` the UI can show as "check your connection".
- Show loading states on every button that calls the API, and disable it while loading.

## How to work in this repo

1. **Plan before coding.** For each task, propose a short plan (files, packages, what the screen
   does) and wait for approval.
2. **One task at a time** from `docs/app-phase-1-tasks.md`. Don't start the next one unprompted.
3. **Tests come with the code** for logic (API client, error mapping, refresh, providers). Screens
   get widget tests for their main states.
4. **Check real package docs** before using a package API (especially `didit_sdk`, `go_router`,
   `flutter_riverpod`). Don't guess method names.
5. **After each task:** explain what you did in plain language (teaching tone), how to run and see
   it, anything uncertain, and suggest a commit message.
6. If the spec or the API contract is unclear, **ask** — don't invent behaviour. If the API seems
   wrong, say so: the fix belongs in `rental-api`, not in an app workaround.
