# DRCH Code Flow Overview

This document explains the current end-to-end behavior of the app.

## 1) App bootstrap
- `main.dart` initializes Firebase and launches `MyApp`.
- `MyApp` uses `AuthGate` as `home`.

## 2) Authentication routing
- `AuthGate` listens to `FirebaseAuth.instance.authStateChanges()`.
- If there is no user, it shows `LoginScreen`.
- If a user exists, it shows `MainWrapper`.
- `MainWrapper` also listens to auth state and then renders `MainScaffold`.

## 3) Main app shell
- `MainScaffold` is a 4-tab container with an `IndexedStack`:
    1. Home
    2. Nearby
    3. Report
    4. Verify
- Report submission callback switches tab index to Verify so users can immediately inspect verification state.

## 4) Report creation flow
- `ReportScreen` collects incident type, description, camera photo, and GPS location.
- It calls `ReportService.addReport(...)`.
- `ReportService`:
    - compresses images
    - stores report in Firestore with `verified=false`, `votes=[]`, `requiredVotes=3`
    - starts background AI analysis (`_runAiInBackground`)

## 5) AI verification flow
- `AiVerificationService` sends first image + prompt to Gemini.
- Parsed JSON response is stored in `aiAnalysis`.
- `requiredVotes` may be lowered from 3 to 2 for high-confidence/high-match reports.

## 6) Human verification flow
- `VerifyScreen` streams unverified reports.
- `ReportService.vote(reportId)`:
    - blocks self-verification
    - blocks duplicate votes
    - requires location services + permission
    - requires user to be within 200 meters of the report location
    - marks report `verified=true` once vote count reaches `requiredVotes`

## 7) Viewing reports
- `HomeScreen` streams verified reports and displays cards/details/maps.
- Images are handled in a dual-path way:
    - base64 string (Firestore)
    - local file path fallback

## Important current caveats
- `AiVerificationService` currently contains a hardcoded API key; this should be moved to a secure secret/config mechanism.
- `MainWrapper` duplicates auth listening behavior already present in `AuthGate`; this can be simplified in a future refactor.