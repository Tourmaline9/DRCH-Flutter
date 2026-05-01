# DRCH — Disaster Response & Community Help

A Flutter-based mobile application that enables communities, NGOs, and government authorities to report, verify, and coordinate responses to disasters in real time. The app integrates AI-powered verification (Google Gemini), live natural-disaster feeds (USGS & NASA EONET), interactive maps (OpenStreetMap), and push notifications (Firebase Cloud Messaging) into a single unified platform.

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Authentication](#authentication)
5. [Screens & Features](#screens--features)
   - [Home Screen](#home-screen)
   - [Nearby Screen](#nearby-screen)
   - [Report Screen](#report-screen)
   - [Verify Screen](#verify-screen)
   - [Incident Details Screen](#incident-details-screen)
   - [Natural Disaster Screen](#natural-disaster-screen)
   - [Map Screen](#map-screen)
   - [Natural Map Screen](#natural-map-screen)
   - [Profile Screen](#profile-screen)
6. [Services](#services)
   - [AuthService](#authservice)
   - [ReportService](#reportservice)
   - [AiVerificationService](#aiverificationservice)
   - [NaturalDisasterService](#naturaldisasterservice)
   - [CommentService](#commentservice)
   - [NotificationService](#notificationservice)
7. [Verification System](#verification-system)
8. [State Management](#state-management)
9. [External APIs](#external-apis)
10. [Getting Started](#getting-started)

---

## Overview

DRCH (Disaster Response & Community Help) is a community-driven disaster-reporting platform designed for India. It allows three types of users — **Community / Volunteers**, **NGOs**, and **Government Authorities** — to:

- Submit photo-backed incident reports with GPS coordinates
- Have those reports automatically analyzed by an AI model (Google Gemini)
- Verify reports through proximity-based community voting
- Browse live natural disasters sourced from USGS and NASA
- Navigate to disaster locations via Google Maps
- Coordinate on-the-ground requirements (water, food, shelter) and contributions
- Receive real-time push notifications for disaster alerts

---

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend / DB | Firebase (Firestore, Firebase Auth, FCM) |
| AI Analysis | Google Gemini 2.5 Flash (`google_generative_ai`) |
| Maps | Flutter Map (OpenStreetMap tiles) |
| State Management | Riverpod (`flutter_riverpod`) |
| Location | Geolocator |
| Notifications | Firebase Cloud Messaging + flutter_local_notifications |
| Image handling | image_picker, flutter_image_compress |
| HTTP | `http` package |
| Navigation | Google Maps external deep-link via `url_launcher` |
| Weather | Open-Meteo API |
| Reverse Geocoding | Nominatim (OpenStreetMap) |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, Firebase init, theme
├── auth_gate.dart               # Routes between LoginScreen and MainWrapper
├── firebase_options.dart        # Generated Firebase config
│
├── models/
│   └── disaster_model.dart      # Disaster data class (USGS / EONET)
│
├── data/
│   └── report_store.dart        # Local report cache utilities
│
├── services/
│   ├── auth_services.dart       # Sign-up, login, logout, FCM token save
│   ├── report_service.dart      # Create reports, AI background job, vote
│   ├── ai_verification_service.dart  # Gemini image + text analysis
│   ├── natural_disaster_service.dart # USGS + NASA EONET fetcher
│   ├── comment_service.dart     # Add / stream comments on reports
│   └── notification_service.dart    # FCM init, foreground notification display
│
├── screens/
│   ├── main_wrapper.dart        # Auth state listener → MainScaffold
│   ├── main_scaffold.dart       # Bottom nav (Home, Nearby, Report, Verify)
│   ├── login_screen.dart        # Sign-in / sign-up form
│   ├── home_screen.dart         # Reported + Natural disasters tabs, weather
│   ├── nearby_screen.dart       # Map of all verified reports
│   ├── report_screen.dart       # Incident submission form
│   ├── verify_screen.dart       # Unverified reports + AI analysis panel
│   ├── incident_details_screen.dart # Presence, requirements, contributions
│   ├── map_screen.dart          # Single incident map with status overlay
│   ├── natural_disaster_screen.dart # List of natural disasters (India)
│   ├── natural_map_screen.dart  # Map of India earthquakes
│   └── profile_screen.dart      # User profile + Aadhar upload
│
└── widgets/
    ├── disaster_card.dart       # Reusable disaster list tile
    ├── report_post_card.dart    # Report feed card
    ├── severity_chip.dart       # Colour-coded severity badge
    ├── screen_header.dart       # Shared page header
    ├── loading_state.dart       # Centered loading indicator with message
    └── empty_state.dart         # Centered icon + message for empty lists
```

---

## Authentication

**Screen:** `LoginScreen`

- Email/password authentication via Firebase Auth.
- Toggle between **Sign In** and **Create Account** modes with a single button.
- On sign-up, users select a **role**:
  - `community` — Community member or volunteer (default)
  - `ngo` — Non-governmental organisation
  - `govt_authority` — Government / municipal authority
- On successful sign-up the user document is created in Firestore (`users/{uid}`) with name, email, role, and Aadhar verification status fields initialised.
- On login the user's FCM device token is refreshed in Firestore for push notifications.
- An `AuthGate` widget listens to Firebase `authStateChanges` and routes the user to either the login form or the main app without any manual redirect logic.

---

## Screens & Features

### Home Screen

The main feed screen, implemented as a **two-tab layout**:

**Tab 1 — Reported Disasters**

- Real-time stream from Firestore showing all *verified* man-made incidents (Fire, Flood, Accident, Riot, Explosion, Road).
- Each card shows:
  - Incident type and timestamp
  - A colour-coded severity badge (green/orange/red for S1–S5)
  - The first attached photo (decoded from base64)
  - Description text
  - Action row: **Location** (opens MapScreen), **Navigate** (opens Google Maps turn-by-turn), **Details** (opens IncidentDetailsScreen)
- **Weather bar** at the top: fetches the user's current temperature and weather condition from the Open-Meteo API using GPS. Shows a localised weather icon and description.
- **Navigate** button performs a same-city check using reverse-geocoding (Nominatim) before launching Google Maps, ensuring volunteers aren't routed across cities accidentally.

**Tab 2 — Natural (India)**

- Fetches the past week of USGS earthquakes filtered to India's geographic bounding box.
- Displays magnitude, location name, and timestamp for each event.
- **View on Map** button opens the `NaturalMapScreen` showing all earthquakes plotted on an India-wide map.

---

### Nearby Screen

- Displays a full-screen OpenStreetMap map (via `flutter_map`).
- Fetches all *verified* reports from Firestore and places red pin markers at their GPS coordinates.
- Useful for quickly visualising which areas near the user have active verified incidents.

---

### Report Screen

The incident submission form, accessible via the bottom navigation "Report" tab.

**Fields & Steps:**

1. **Incident Type** — tap-to-select grid: Fire, Flood, Accident, Other (with icons).
2. **Photo** — camera capture via `image_picker`. Multiple photos can be added. Thumbnails preview at the bottom of the form.
3. **Any Injured?** — Yes / No choice chip.
4. **Description** — free-text field (required).
5. **Location** — tapping "Use my location" fetches GPS coordinates via `geolocator`.
6. **Severity** — a slider from 1 (low) to 5 (critical).

**Submission flow:**

1. All fields are validated (type, description, location, at least one photo).
2. Each photo is compressed with `flutter_image_compress` (max 800 px, quality 60) and base64-encoded before saving to Firestore, keeping document sizes manageable.
3. The report document is saved immediately to `reports/` with `verified: false` and `aiAnalysis: null`.
4. AI analysis runs **asynchronously in the background** — the user is not blocked waiting for it.
5. After submission the user is navigated to the Verify tab.

---

### Verify Screen

Shows all **unverified** reports so community members, NGOs, and authorities can review and vote on them.

**Per-report card shows:**

- Incident type, timestamp, severity badge
- Photo (base64-decoded)
- Description
- **AI Analysis Panel** — once Gemini has processed the image:
  - `is_disaster` flag
  - Confidence score (0–1)
  - Match score (0–10) between image and selected type
  - Detected alert type
  - AI-generated summary and explanation
  - `is_flagged` / `possible_screenshot` warnings with flag reason
  - List of mismatch points (e.g. "image appears to be a news screenshot")
  - While AI is processing, a spinner with "AI analysis in progress…" is shown.
- **Verify button** — triggers the proximity-based voting flow.
- **View Map** button — opens `MapScreen` for the report.

**Voting rules (enforced server-side in a Firestore transaction):**

- Reporter cannot verify their own report.
- Each user can vote once per report.
- User must be **within 200 metres** of the report's GPS coordinates.
- Required votes to auto-verify: **3** by default; reduced to **2** if AI confidence > 90 % and match score > 8; raised to **5** if the report is flagged or detected as a screenshot.
- NGO and Government Authority users **instantly verify** a report with a single vote, regardless of vote count.

---

### Incident Details Screen

Deep-dive view for a specific incident, opened from the home feed.

**Presence tracking:**
- Shows how many users are physically present at the scene.
- "I'm here" button marks the current user as present — only works if they are **within 200 metres** of the incident location.

**Requirements & Updates (only visible to users who are present):**
- Text field to add a requirement (e.g. "Water bottles", "Medical team").
- Requirements are stored in a `requirements` sub-collection under the report.
- Each requirement can be marked as **Fulfilled** by any present user.

**Contributions:**
- Any user can offer to contribute to an open requirement via a dialog.
- Contributions are stored in a nested `contributions` sub-collection.
- Other users can **upvote / un-upvote** contributions using Firestore array operations.

---

### Natural Disaster Screen

A scrollable list of current natural disasters in India, powered by two external APIs:

- **USGS** — Recent earthquakes inside India's geographic bounding box. Displays magnitude (shown in the avatar circle) and location name.
- **NASA EONET** — Broader natural events (wildfires, storms, floods) from the past 20 days, filtered to India.

Colour coding by type:
- 🔴 Earthquakes
- 🔵 Floods
- 🟠 Wildfires
- 🟣 Storms
- 🟢 Others

Each item has a **map icon** button that opens the `MapScreen` at that event's coordinates.

---

### Map Screen

A detailed map view for a single incident (reported or natural).

- Renders on OpenStreetMap tiles via `flutter_map`.
- Shows a **coloured circle** (200 m radius) around the incident location:
  - 🔴 Red — Authority verified or community verified + AI score > 8
  - 🟡 Yellow — Community verified + AI score < 8
  - 🟣 Purple — AI-suspicious report (awaiting NGO/authority)
  - 🟠 Orange — Pending verification
- Shows the user's own location as a blue person-pin.
- Draws a **polyline** from the user to the incident.
- Floating **distance chip** shows distance in kilometres.
- Status label banner at the top describes the verification state in plain language.

---

### Natural Map Screen

A full India map view (centred on 22.97°N, 78.66°E, zoom 4.5) plotting all fetched USGS earthquake events as coloured circles:

- 🔴 Red — Magnitude ≥ 5
- 🟠 Orange — Magnitude ≥ 4
- 🟡 Yellow — Magnitude < 4

Circle size scales with magnitude (clamped between 12 and 40 px).

---

### Profile Screen

- Displays the logged-in user's name, email, and role.
- Shows Aadhar identity verification status:
  - **Not submitted** (red) — prompts to upload
  - **Pending** (orange) — waiting for admin approval
  - **Approved** (green) — identity verified
- Upload Aadhar button opens the photo gallery, compresses the image (quality 50), base64-encodes it, and stores it in the `users/{uid}` document in Firestore with status `pending`.
- Logout button in the top app bar signs the user out via Firebase Auth.

---

## Services

### AuthService

Wraps Firebase Authentication:
- `signUp(email, password)` — creates a new user account.
- `login(email, password)` — signs in and saves the FCM token to Firestore.
- `logout()` — signs the user out.
- `authStateChanges` stream — used by `AuthGate` and `MainWrapper`.

### ReportService

Handles the full lifecycle of a community-submitted report:
- `addReport(...)` — compresses images, saves report to Firestore, then triggers AI verification asynchronously.
- `_runAiInBackground(...)` — calls `AiVerificationService`, then updates `aiAnalysis` and adjusts `requiredVotes` based on AI result.
- `getVerifiedReports()` — real-time stream of verified reports.
- `getUnverifiedReports()` — real-time stream of unverified reports.
- `vote(reportId)` — location-checked, transactional vote that auto-verifies when the threshold is met.

### AiVerificationService

Uses **Google Gemini 2.5 Flash** (`gemini-2.5-flash`) to analyse incident images:

Sends the first report photo plus a structured prompt asking Gemini to return JSON with:
- `is_disaster` — whether the image shows a real disaster
- `confidence` — float 0–1
- `ai_summary` — short visual description
- `match_score` — 0–10 match between image and reported type
- `alert_type` — detected disaster type
- `is_flagged` — whether the report looks fake/misleading
- `flag_reason` — reason for flagging
- `explanation` — 2–3 sentence decision rationale
- `possible_screenshot` — whether the image is a screenshot of news/social media
- `mismatch_points` — list of specific inconsistencies found

The `requiredVotes` threshold is dynamically adjusted based on this analysis.

### NaturalDisasterService

Fetches India-filtered natural disaster data from two public APIs:
- **USGS Earthquake Feed** (`all_day.geojson`) — daily earthquakes filtered to the India bounding box (6–37.5°N, 68–97.5°E).
- **NASA EONET v3** — broader natural events (last 20 days) similarly filtered; handles both `Point` and `Polygon` geometry types.

Results are sorted by date (newest first) and returned as a `List<Disaster>`.

### CommentService

Simple Firestore wrapper for the comments sub-collection on each report:
- `getComments(reportId)` — real-time stream ordered oldest → newest.
- `addComment(reportId, text)` — appends a new comment with the user's UID and email.

### NotificationService

Initialises Firebase Cloud Messaging and local notification display:
- Requests notification permission (Android 13+).
- Listens for foreground FCM messages and renders them as Android local notifications via the `drch_channel` channel (high importance).
- `getToken()` — retrieves the device's FCM token (saved to Firestore on login for server-side pushes).

---

## Verification System

DRCH uses a **multi-layer trust model** to reduce fake/misleading reports:

| Layer | Mechanism |
|---|---|
| **AI Pre-screening** | Gemini analyses image + description before anyone can vote |
| **Proximity voting** | Community users must be ≤ 200 m from the incident to vote |
| **Dynamic vote threshold** | 2 votes (high AI confidence) / 3 votes (default) / 5 votes (flagged) |
| **Authority fast-track** | NGO or Govt Authority instantly verifies with one vote |
| **Map colour coding** | Verification state is visually surfaced on every map |

---

## State Management

The app uses **Riverpod** (`flutter_riverpod`) throughout:

| Provider | Purpose |
|---|---|
| `mainTabIndexProvider` | Bottom navigation selected index |
| `loginLoadingProvider` | Login/signup loading spinner |
| `loginSignupProvider` | Toggle sign-in vs create-account mode |
| `loginRoleProvider` | Selected role during sign-up |
| `reportFormProvider` | Full state of the report submission form |
| `nearbyMarkersProvider` | Async fetching of map markers for NearbyScreen |
| `profileUploadingProvider` | Aadhar upload loading spinner |

---

## External APIs

| API | Purpose | Endpoint |
|---|---|---|
| USGS Earthquake Feed | Daily earthquake data | `earthquake.usgs.gov/…/all_day.geojson` |
| USGS (Home tab) | Weekly earthquakes for India | `earthquake.usgs.gov/…/all_week.geojson` |
| NASA EONET v3 | Broader natural events | `eonet.gsfc.nasa.gov/api/v3/events?days=20` |
| Open-Meteo | Current weather at user location | `api.open-meteo.com/v1/forecast` |
| Nominatim (OSM) | Reverse geocoding for city-check | `nominatim.openstreetmap.org/reverse` |
| OpenStreetMap Tiles | Map background tiles | `tile.openstreetmap.org/{z}/{x}/{y}.png` |
| Google Gemini 2.5 Flash | AI image + text analysis | via `google_generative_ai` SDK |
| Firebase FCM | Push notifications | via `firebase_messaging` SDK |

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.10.7
- A Firebase project with **Firestore**, **Firebase Auth**, and **Cloud Messaging** enabled
- `google-services.json` (Android) placed in `android/app/`
- A Google Generative AI API key (replace the placeholder in `ai_verification_service.dart` — move to a secure server/env variable before production)

### Setup

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Firestore Collections

| Collection | Purpose |
|---|---|
| `users/{uid}` | User profile, role, FCM token, Aadhar status |
| `reports/{id}` | Incident reports with AI analysis, votes, images |
| `reports/{id}/comments` | Threaded comments |
| `reports/{id}/requirements` | On-scene resource requirements |
| `reports/{id}/requirements/{id}/contributions` | Volunteer contribution offers with upvotes |

### Firestore Security Rules

Basic rules are defined in `firestore.rules` at the root of the repository.

---

> **Note:** The Google Gemini API key is currently embedded in source code for development purposes. Before any production release, move it to a server-side environment variable or Firebase Remote Config to prevent unauthorised usage.
