<USER_REQUEST>
# EV Identity & Security Platform — Product Requirements Document

**Codename:** VaultRide (placeholder — rename before build)
**Platform:** Android (native target via Flutter)
**Backend:** Supabase (Postgres, Auth, Realtime, Edge Functions, Storage)
**Document Type:** Full Product Requirements Document (PRD)
**Version:** 1.0
**Status:** Draft for Build Planning

---

## How to Read This Document

This PRD is written so an engineering team, a designer, and a founder can all work from the same source of truth. It is organized into eleven parts:

- **Part A — Overview & Strategy**: what we're building, why, for whom
- **Part B — Feasibility Foundations**: the Android + Supabase reality check, restated in build terms
- **Part C — System Architecture**: how the client, backend, BLE layer, and third parties fit together
- **Part D — Full User Flows**: every screen-by-screen journey in the product
- **Part E — Roles & Permissions**: who can do what, and how it's enforced
- **Part F — Non-Functional Requirements**: performance, security, compliance, battery, reliability
- **Part G — Screen Inventory**: a full list of every screen with purpose and contents
- **Part H — Edge Cases & Error Handling**: what happens when things go wrong
- **Part I — Analytics**: what we track and why
- **Part J — Roadmap**: V1 → V2 → V3
- **Part K — Appendix**: glossary, assumptions, open questions, risks

No code is included anywhere in this document by design. This is a concept and requirements document only — implementation is a separate exercise.

---

## Table of Contents

**Part A — Overview & Strategy**
1. Executive Summary
2. Problem Statement
3. Product Vision
4. Goals & Non-Goals
5. Why Android-Only (Strategic Rationale)
6. Target Users & Personas
7. Competitive Landscape
8. Success Metrics

**Part B — Feasibility Foundations**
9. Flutter on Android — What It Buys Us
10. Supabase as the Entire Backend
11. The Firmware Boundary (What We Can and Cannot Enforce)

**Part C — System Architecture**
12. High-Level Architecture
13. Client Architecture (Flutter/Android)
14. Backend Architecture (Supabase)
15. BLE Communication Layer
16. Push Notification Pipeline
17. KYC Verification Pipeline
18. Command Signing & Security Protocol
19. Data Model
20. Edge Function Catalog

**Part D — Full User Flows**
21. Onboarding & Account Creation
22. KYC Verification
23. Vehicle Pairing
24. Dashboard / Home
25. Authorized Devices Management
26. Login Alerts / New Device Requests
27. Temporary Access Grants
28. Theft Protection
29. Battery Protection
30. Service History
31. Insurance Data View
32. AI Anomaly Detection
33. Emergency Mode
34. Family Sharing
35. Digital Vehicle Passport & Ownership Transfer
36. Settings & Profile
37. Notification Center

**Part E — Roles & Permissions**
38. Role Matrix
39. Row Level Security Policy Design

**Part F — Non-Functional Requirements**
40. Performance
41. Security & Privacy
42. Compliance
43. Reliability & Offline Handling
44. Battery & Background Execution (Android Specifics)
45. Scalability

**Part G — Screen Inventory**
46. Full Screen List

**Part H — Edge Cases & Error Handling**
47. Edge Case Catalog by Module

**Part I — Analytics**
48. Event Tracking Plan

**Part J — Roadmap**
49. V1 / V2 / V3 Roadmap

**Part K — Appendix**
50. Glossary
51. Assumptions
52. Open Questions
53. Risks

---

# PART A — OVERVIEW & STRATEGY

## 1. Executive Summary

VaultRide is an identity and security layer for electric vehicles, starting with electric scooters and bikes in India. It does not replace the vehicle's Battery Management System (BMS) — it sits above it as an ownership, access-control, and monitoring layer, similar to how a Google Account sits above a phone without being the phone's operating system.

The core idea: a vehicle should not simply respond to "any app that knows how to talk to it." A vehicle should belong to a **verified identity**, and every device that wants to interact with it — the owner's phone, a family member's phone, a mechanic's diagnostic tool — must be explicitly authorized by that identity, for a defined scope and a defined time.

VaultRide is built as an Android-only Flutter application backed entirely by Supabase, with two external integrations: Firebase Cloud Messaging for push notifications, and a licensed KYC vendor for identity verification. It is explicitly **not** a claim to remotely disable or lock a vehicle at the firmware level in V1 — that capability requires manufacturer/BMS cooperation and is scoped into V2/V3 of the roadmap. V1 is an honest, fully-deliverable product: identity, ownership records, access permissions, monitoring, alerts, and history — all real, all useful, all shippable without needing a single manufacturer's cooperation.

## 2. Problem Statement

Most electric two-wheelers sold today — particularly from smaller or newer manufacturers — ship with a Bluetooth Low Energy (BLE) enabled BMS that accepts connections from any app that knows the correct service and characteristic UUIDs. This is convenient for manufacturers (any app can be built against it) but insecure for owners:

- Any third-party "universal BMS app" can connect to and read/write vehicle data
- There is no concept of "who is allowed to connect" — only "what protocol does the BMS speak"
- There is no audit trail of who changed what, when
- There is no way to temporarily and safely hand access to a mechanic without full access
- There is no unified record of a vehicle's ownership, service, or battery history that survives a resale
- Owners have no visibility into anomalous usage (e.g., vehicle moving at 2 AM, far from home)

This is structurally the same problem email had before centralized identity providers, and the same problem home Wi-Fi networks had before router-level device management became mainstream. The fix is not a better BMS — it's an identity layer that sits above any BMS.

## 3. Product Vision

**"One identity for every EV — the way a Google Account is one identity for every device you own."**

Long-term, VaultRide aims to be a cross-manufacturer identity and security standard: whether someone owns a scooter from one manufacturer or a bike from another, they manage both from the same account, the same dashboard, and the same security model. Manufacturers who integrate VaultRide's SDK get firmware-level enforcement (V2/V3); manufacturers who don't still allow their owners to get identity, ownership records, and monitoring, because that layer lives in the cloud and on the owner's phone, not in the vehicle.

## 4. Goals & Non-Goals

### Goals (V1)
- Let an owner create a verified identity and link it to one or more vehicles
- Let an owner manage which devices/people can interact with the vehicle's data, with explicit expiry and scope
- Let an owner see real-time and historical vehicle data (battery, location, charging state) where the BMS exposes it over BLE
- Detect and alert on anomalous parameter changes and anomalous movement patterns
- Maintain a permanent, portable service and ownership history per vehicle
- Support secure, time-boxed access grants (e.g., to a mechanic) without sharing credentials
- Support ownership transfer on resale with full history intact

### Non-Goals (V1 — explicitly out of scope)
- Remotely disabling, locking, or immobilizing a vehicle (requires firmware support — V2/V3)
- Blocking a rival app from connecting to the BMS over BLE at the protocol level (requires firmware support — V2/V3)
- iOS support (Android-only by decision — see Section 5)
- Building or operating the KYC verification engine ourselves (we integrate a licensed vendor)
- Deep ML-based behavioral modeling (V1 uses rule-based anomaly detection; ML is a V3 consideration)

## 5. Why Android-Only (Strategic Rationale)

This product was originally scoped as cross-platform, but Android-only is the right call for V1, for reasons that are genuinely technical, not just cost-saving:

- **Background BLE is far more permissive on Android.** iOS aggressively suspends background BLE scanning and restricts what a backgrounded app can do with Core Bluetooth unless very specific (and still limited) entitlements are used. Android's foreground service model lets VaultRide run a persistent, user-visible background service that can maintain a BLE connection, monitor for anomalies, and react in near real-time. A theft-detection or unauthorized-access feature that only half-works in the background is worse than not shipping it — Android-only lets us ship it properly.
- **Android's target market overlap is very high for this use case.** Electric two-wheeler buyers in India — the initial target market — are overwhelmingly Android users. Building for iOS first would mean building for the platform with weaker BLE background support **and** a smaller share of the actual target buyers.
- **Faster iteration, smaller surface area.** One platform means the team validates the hardest technical bet (reliable background BLE monitoring) without splitting effort across two very different background-execution models.
- **iOS is not abandoned — it's sequenced.** Once the BLE monitoring and anomaly detection logic is proven and the "does this actually catch unauthorized activity in practice" question is answered on Android, an iOS client can be built against the same Supabase backend with adjusted expectations for background behavior (e.g., leaning more on server-side triggers and push rather than continuous on-device scanning).

## 6. Target Users & Personas

**Persona 1 — Siva, the Primary Owner (25–40)**
Owns one electric scooter, uses it daily for commuting. Wants peace of mind that nobody else can mess with battery settings and wants to know immediately if the vehicle moves without him. Comfortable with apps, moderately technical.

**Persona 2 — Family Member (Spouse/Parent/Sibling)**
Shares the vehicle occasionally. Needs simple, frictionless access — not a full owner account, just "can ride" permission granted by the primary owner.

**Persona 3 — The Mechanic**
Needs temporary, scoped access to read diagnostics and possibly update firmware or battery settings, for a bounded time window, without ever seeing the owner's full account or being able to reconnect later.

**Persona 4 — The Used-EV Buyer**
Evaluating a second-hand electric scooter. Wants to verify the vehicle's real service and battery history before buying — currently has no reliable way to do this.

**Persona 5 — The Insurance Assessor (indirect user, V2+)**
Wants objective data on how a vehicle has been used and maintained to inform premiums or claims decisions.

## 7. Competitive Landscape

Most competitors fall into two buckets:

- **Manufacturer-native apps** (e.g., bundled with a specific scooter brand): these manage one brand's vehicles only, typically have basic pairing and battery-read features, and generally do not offer granular, time-boxed access control, cross-brand identity, or anomaly detection.
- **Generic third-party BMS apps**: these are exactly the problem VaultRide addresses — they connect to any compatible BMS with no ownership verification at all, which is how unauthorized access happens in the first place.

VaultRide's differentiation is the identity-and-permission layer itself, not vehicle telemetry, which is the easy part. No dominant cross-brand "identity provider for EVs" currently exists in this market — this is the gap being targeted.

## 8. Success Metrics

**Adoption**
- Number of verified owner accounts created
- Number of vehicles successfully paired per account
- KYC completion rate (started vs. completed)

**Engagement**
- Weekly active dashboard opens per owner
- Number of temporary access grants issued per month (proxy for real-world utility with mechanics/family)
- Alert response rate (percentage of security alerts actioned within 5 minutes)

**Trust & Retention**
- 30/60/90-day retention of owner accounts
- Ownership transfer completions (proxy for the "digital passport" value proposition working)
- Support tickets related to "unauthorized access" false positives/negatives (should trend down over time)

**Technical Health**
- BLE connection success rate on first attempt
- Background monitoring uptime (percentage of time the foreground service stays alive as expected)
- Push notification delivery latency (alert generated → device notified)


---

# PART B — FEASIBILITY FOUNDATIONS

## 9. Flutter on Android — What It Buys Us

Since this is Android-only, Flutter is being used less for "write once run anywhere" and more for its mature widget system, strong BLE plugin ecosystem, and fast iteration speed. What Android-only Flutter gives this specific product:

- **Full BLE access via `flutter_reactive_ble` or `flutter_blue_plus`**, including reading characteristics (battery %, voltage, current, cell data), writing characteristics (sending commands within whatever the BMS already permits), and subscribing to notifications for real-time updates.
- **A true Android Foreground Service** (accessed via platform channels or a plugin like `flutter_foreground_task`) that can keep a BLE connection alive and keep monitoring running even when the app is not in the foreground, with a persistent notification as required by Android's OS-level transparency rules for foreground services.
- **Native Android permission handling** for Bluetooth (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` on Android 12+), location (required for BLE scanning pre-Android 12 and still relevant for geofencing/theft alerts), and notifications (`POST_NOTIFICATIONS` on Android 13+).
- **Biometric app-lock** via `local_auth`, using the device's fingerprint/face unlock to gate the app itself — this protects the VaultRide account even if the phone is unlocked and handed to someone else temporarily.
- **Full camera and file access** for the KYC flow (capturing ID documents and a live selfie for face verification), and for uploading service photos.
- **Google Maps integration** via `google_maps_flutter` for live tracking and geofence visualization.
- **WorkManager-backed background jobs** for periodic checks that don't need a persistent connection (e.g., periodic "is the vehicle where it should be" reconciliation), which survive Doze mode better than raw background threads.

What Flutter/Android does **not** solve on its own: the BMS accepting connections from other apps. That remains a firmware-side question regardless of platform, and is addressed in Section 11.

## 10. Supabase as the Entire Backend

Supabase is used for effectively 100% of backend infrastructure:

- **Auth**: phone number + OTP as the primary sign-in method (matches how most EV owners already authenticate for other apps in this market), with email as a secondary/recovery method. Supabase Auth issues JWTs used for all subsequent requests, including Realtime subscriptions and Storage access.
- **Postgres Database**: the relational structure of this product — owners, vehicles, devices, permission grants, alerts, service records — is inherently relational, which is exactly what Postgres is built for. No NoSQL layer is needed.
- **Row Level Security (RLS)**: this is the single most important Supabase feature for this product. Every table (vehicles, permissions, alerts, service history) has RLS policies that enforce, at the database level, that a user can only see and modify data they're actually authorized for — not just "the app chooses not to show it," but "the database physically will not return it." This is what makes the family-sharing and mechanic-access model safe even if a client is compromised or reverse-engineered.
- **Realtime**: Postgres change streams power live updates — when a new device requests access, the owner's dashboard shows the prompt within seconds via a Realtime subscription, not a polling loop.
- **Storage**: KYC document images, selfie captures, and service-history photos are stored in Supabase Storage buckets with RLS-equivalent storage policies, so only the owner (and, for KYC docs, backend verification processes) can access them.
- **Edge Functions (Deno-based)**: all business logic that must not live on the client — generating and validating time-boxed access tokens, verifying command signatures, expiring grants on schedule, calling the KYC vendor's API, triggering FCM pushes when relevant rows change — lives here.
- **pg_cron**: scheduled jobs inside Postgres itself handle recurring tasks like auto-expiring temporary access grants the moment their time window ends, and running the rule-based anomaly-detection sweep periodically.

## 11. The Firmware Boundary (What We Can and Cannot Enforce)

This section exists so nobody building or pitching this product overstates what V1 does. It is restated here deliberately because it is the single most important constraint in the entire PRD.

**What VaultRide V1 CAN do, fully, without any manufacturer cooperation:**
- Verify who the owner is
- Record which vehicle belongs to which owner
- Let the owner grant, scope, and expire access for other people/devices, tracked entirely in VaultRide's own database
- Read whatever telemetry the BMS already exposes over its open BLE interface
- Send whatever commands the BMS already accepts over its open BLE interface, signed and logged by VaultRide
- Detect when BMS parameters change and alert the owner, using its own connection to compare before/after state
- Detect anomalous location/movement patterns and alert the owner
- Maintain a permanent, tamper-evident record of ownership and service history

**What VaultRide V1 CANNOT do, because no app can do it without firmware cooperation:**
- Prevent a different app from also connecting to the same open BLE interface
- Remotely and forcibly disable, lock, or immobilize the vehicle
- Guarantee that a command sent by VaultRide is the *only* command the BMS will accept

**The bridge (V2/V3):** once a manufacturer integrates VaultRide's signing SDK into their BMS firmware, the BMS itself starts rejecting any command that isn't signed by a key tied to a verified VaultRide identity. At that point, "blocking other apps" becomes literally true, because the vehicle itself is enforcing it — not the phone app. Until that integration exists for a given vehicle model, VaultRide is a monitoring-and-identity layer, not an enforcement layer, and the product's own UI must communicate this honestly (see Section 24 and Section 28 for how this is surfaced to the user).


---

# PART C — SYSTEM ARCHITECTURE

## 12. High-Level Architecture

The system has five logical layers:

```
[ Vehicle BMS (BLE Peripheral) ]
            │  BLE (GATT)
            ▼
[ Flutter Android App ]
   - BLE Manager
   - Foreground Service (background monitoring)
   - Local biometric app-lock
   - UI (Dashboard, Onboarding, Permissions, Alerts)
            │  HTTPS / WSS (JWT-authenticated)
            ▼
[ Supabase Backend ]
   - Auth (Phone OTP / Email)
   - Postgres (with RLS)
   - Realtime (change streams)
   - Storage (documents, photos)
   - Edge Functions (business logic)
   - pg_cron (scheduled jobs)
            │
   ┌────────┴────────┐
   ▼                  ▼
[ Firebase Cloud   [ KYC Vendor API ]
  Messaging ]        (Aadhaar/DL/Face
  (push delivery)     verification)
```

The vehicle never talks to Supabase directly — it only ever talks to the paired phone over BLE. The phone is the bridge between the vehicle and the cloud. This matters for the theft-detection flow (Section 28): if the phone isn't near the vehicle, VaultRide loses its BLE link and falls back to last-known-state plus owner-reported "vehicle should not be moving" logic, rather than a live feed.

## 13. Client Architecture (Flutter/Android)

The app is organized into the following functional modules, each with a clear boundary:

- **Auth Module**: phone OTP sign-in/sign-up, session persistence, biometric app-lock gate
- **KYC Module**: document capture, selfie capture, submission to Edge Function, status polling/Realtime subscription for verification result
- **Vehicle Pairing Module**: BLE scanning, device selection, GATT service discovery, characteristic mapping, serial/VIN/BMS ID capture, linking the discovered vehicle to the owner's account in Supabase
- **BLE Session Module**: manages the live connection to a paired vehicle when in range — reads telemetry, writes commands, maintains the foreground service and its persistent notification
- **Dashboard Module**: renders live and cached vehicle state, battery, location, charging status, quick actions
- **Permissions Module**: authorized devices list, grant/revoke UI, temporary access creation with duration and scope selection
- **Alerts Module**: renders login-alert prompts, unauthorized movement alerts, battery-parameter-change alerts; handles Allow/Deny actions and routes them to the correct Edge Function
- **History Module**: service history timeline, ownership timeline, insurance-relevant summary view
- **Family Sharing Module**: role assignment UI (Administrator, Can Ride, Weekends Only, etc.)
- **Emergency Module**: emergency lock trigger, emergency contact configuration, last-known-location broadcast
- **Settings Module**: profile management, notification preferences, linked devices, account security (change PIN, manage biometric lock)

## 14. Backend Architecture (Supabase)

**Auth**: Phone OTP as primary. Every authenticated request carries a Supabase JWT identifying the user. Session refresh is handled by the Supabase Flutter SDK automatically.

**Database schema groups** (detailed table list in Section 19):
- Identity tables: `owners`, `kyc_records`
- Vehicle tables: `vehicles`, `vehicle_bms_snapshots`
- Access tables: `authorized_devices`, `access_grants`, `access_grant_permissions`
- Event tables: `alerts`, `command_log`, `service_history`
- Sharing tables: `family_roles`
- Ownership tables: `ownership_transfers`

**RLS strategy**: every table is scoped by `owner_id` at minimum. Tables involving shared/delegated access (e.g., `access_grants`) additionally check whether the requesting user's ID appears as a `grantee_id` with a currently-valid (non-expired) grant before allowing reads, and check role/permission flags before allowing writes. This means even if the Flutter app were fully decompiled and someone tried to query Supabase directly with a stolen JWT belonging to a mechanic's temporary grant, the database itself would refuse to return anything outside that grant's scope and time window.

**Edge Functions** (full catalog in Section 20) handle: grant creation/expiry, command signature verification, KYC vendor calls, FCM push triggering, anomaly-detection sweeps, ownership transfer finalization.

**Realtime**: the Dashboard, Alerts module, and Authorized Devices screen all hold live Realtime subscriptions so state changes (a new alert, a grant expiring, a device being added) appear without the user refreshing anything.

## 15. BLE Communication Layer

Since VaultRide is not modifying BMS firmware in V1, it communicates using whatever GATT services and characteristics the target BMS already exposes. The BLE layer is responsible for:

- **Discovery**: scanning for nearby BLE peripherals matching known service UUID patterns for supported BMS types, presented to the user during pairing
- **Connection**: establishing a GATT connection, with retry/backoff logic since BLE connections on Android can be flaky, especially across different chipset vendors
- **Characteristic mapping**: a configuration layer (stored server-side, fetched per vehicle "make/model" at pairing time) maps generic concepts (battery %, voltage, current, charging state) to the specific characteristic UUIDs used by that BMS model — this is what allows VaultRide to support multiple BMS types without hardcoding per-brand logic into the app itself
- **Read loop**: while in range and the foreground service is active, telemetry is read/subscribed on an interval balanced against battery drain (default: active read every 30 seconds while charging or riding is detected, dropping to every 5 minutes while idle)
- **Write path**: any command sent to the BMS (e.g., a parameter change initiated by the owner, or relayed during a mechanic's temporary session) is first signed with a key tied to the authenticated session (see Section 18), logged in `command_log`, then sent over BLE
- **Change detection**: every successful read is diffed against the last known value; a meaningful change (e.g., charging current, cell voltage limits) that wasn't the result of a command VaultRide itself just sent triggers the battery-protection alert flow (Section 29)

## 16. Push Notification Pipeline

Supabase does not send push notifications natively, so this is one of the two required external integrations:

1. A relevant database event occurs (new row in `alerts`, a new row in `access_grants` requiring owner approval, a `command_log` entry outside an expected session)
2. A Postgres trigger or an Edge Function subscribed to that table's changes fires
3. The Edge Function looks up the target device's FCM token (stored at login/app-open time in a `device_tokens` table) and calls the Firebase Cloud Messaging API
4. FCM delivers the push to the Android device, even if VaultRide is fully closed
5. Tapping the notification deep-links into the relevant screen (e.g., the Login Alert screen with Allow/Deny buttons)

## 17. KYC Verification Pipeline

The second required external integration. VaultRide does not build identity verification itself — it integrates a licensed KYC-as-a-service vendor (selection is a business decision outside this PRD's scope, but the integration pattern is fixed):

1. User captures ID document (Aadhaar/Driving License) and a live selfie inside the Flutter app
2. Images are uploaded to Supabase Storage in a private bucket scoped to that user only
3. An Edge Function calls the KYC vendor's API, passing the document and selfie (or references to them, per vendor's integration model)
4. The vendor returns a verification result (pass/fail/manual-review) which the Edge Function writes to `kyc_records`
5. A Realtime subscription on the client updates the KYC status screen the moment the result lands, without polling
6. Vehicles cannot be paired to an account until `kyc_records.status = 'verified'` — this is enforced both in the UI and via an RLS check on the `vehicles` insert policy, so it cannot be bypassed by calling Supabase directly

## 18. Command Signing & Security Protocol

Every command VaultRide sends to a vehicle — whether initiated by the owner or relayed on behalf of a temporarily-authorized mechanic — follows this protocol:

1. The client requests a short-lived signed command token from an Edge Function, passing the intended command and target vehicle ID
2. The Edge Function verifies the requester currently holds valid permission for that specific action on that specific vehicle (checking `access_grants` and `access_grant_permissions` for non-owners, or ownership directly for the owner)
3. If authorized, the Edge Function signs the command payload with a server-held key and returns it to the client, along with a short expiry (e.g., 60 seconds)
4. The client sends this signed payload to the vehicle over BLE
5. The client also logs the attempt (success/failure) to `command_log` immediately, independent of whether the BMS itself has any way to verify the signature (V1 BMS hardware generally does not — this logging exists so VaultRide's own audit trail is complete and tamper-evident even before firmware-level enforcement exists)

This design means that when a manufacturer eventually integrates firmware-side signature checking (V2/V3), **no change is needed to this protocol** — the BMS simply starts actually validating the signature it was already being sent, rather than ignoring it. This is a deliberate "build the real protocol now, get real enforcement later" design choice.

## 19. Data Model

Core tables and their purpose (field-level schema is an implementation task, not enumerated here in full, but structure and relationships are defined):

- **`owners`**: one row per verified identity; links to Supabase Auth user ID; holds display name, phone, email, KYC status summary
- **`kyc_records`**: one row per KYC attempt; links to `owners`; holds document type, verification status, vendor reference ID, timestamps
- **`vehicles`**: one row per registered vehicle; links to current `owner_id`; holds serial number, VIN (if available), battery serial, BMS identifier, BLE device identifier, make/model (used to select the correct characteristic-mapping config), registration date
- **`vehicle_bms_snapshots`**: time-series table of periodic telemetry reads (battery %, voltage, current, charging state, timestamp, source device)
- **`authorized_devices`**: devices/accounts with standing (non-expiring, but revocable) access to a vehicle — e.g., a spouse's account
- **`access_grants`**: time-boxed access records (e.g., mechanic access), with `granted_by`, `grantee_id`, `vehicle_id`, `starts_at`, `expires_at`, `status`
- **`access_grant_permissions`**: fine-grained permission flags per grant (read-only, diagnostics, firmware, battery-write) — a many-to-one child of `access_grants`
- **`alerts`**: every generated alert (login request, unauthorized movement, battery parameter change), with type, severity, related vehicle, resolution status, owner action taken
- **`command_log`**: every signed command attempt, success/failure, initiating identity, timestamp
- **`service_history`**: manually or automatically logged service events (battery opened, firmware updated, cell replaced), with date, description, optional photo reference
- **`family_roles`**: maps additional people to a vehicle with a named role (Administrator, Can Ride, Weekends Only) and derived permission set
- **`ownership_transfers`**: records of a vehicle changing owner, preserving all prior `service_history` and `vehicle_bms_snapshots` rows under the vehicle's permanent record rather than the old owner's account

## 20. Edge Function Catalog

- `create-access-grant`: validates requester is the owner, creates a time-boxed grant + permissions
- `expire-access-grants`: scheduled via pg_cron, flips expired grants to `expired` status
- `sign-command`: validates permission, returns a signed, short-lived command payload
- `submit-kyc`: receives document/selfie references, calls KYC vendor, writes result
- `detect-anomalies`: scheduled sweep comparing recent `vehicle_bms_snapshots` and location data against the owner's learned normal-usage pattern; writes `alerts` rows for outliers
- `send-push`: triggered by relevant table inserts, resolves device tokens, calls FCM
- `transfer-ownership`: validates both parties, re-points `vehicles.owner_id`, writes an `ownership_transfers` row, revokes all prior `authorized_devices` and `access_grants` for that vehicle
- `revoke-device`: immediately invalidates a standing authorized device's access


---

# PART D — FULL USER FLOWS

Each flow below follows the same structure: **Goal**, **Entry Points**, **Step-by-Step Screens**, **Data Touched**, and **Edge Cases** (cross-referenced to Part H where the case is complex enough to warrant its own entry).

## 21. Onboarding & Account Creation

**Goal**: turn a new user into a verified-identity-in-progress owner account.

**Entry Points**: app first launch; "Create Account" from a referral/share link.

**Step-by-Step**
1. **Splash Screen** — brief brand moment, checks for existing session, routes accordingly.
2. **Welcome Screen** — explains the value proposition in one line ("Your vehicle, verified to you") with a single primary CTA: "Get Started."
3. **Phone Number Entry** — user enters mobile number; app requests OTP via Supabase Auth.
4. **OTP Verification Screen** — 6-digit input, auto-read via SMS retriever where possible, resend timer, error state for wrong/expired OTP.
5. **Basic Profile Screen** — name, optional email (used for account recovery and receipts), profile photo optional.
6. **Biometric Lock Setup Screen** — prompts the user to enable fingerprint/face unlock for the app itself, explaining this protects the account even if the phone is unlocked. Skippable but re-prompted once later.
7. **Home / Empty Dashboard State** — since no vehicle is paired yet and KYC isn't done, the dashboard shows a clear next-step card: "Verify your identity to add a vehicle" → routes into the KYC flow (Section 22).

**Data Touched**: `owners` row created on successful OTP verification; `device_tokens` row created/updated for push.

**Edge Cases**: OTP delivery failure/delay (offer resend + alternate channel messaging); duplicate phone number already registered (route to sign-in instead of sign-up); user backgrounds app mid-OTP (session state must survive this cleanly).

## 22. KYC Verification

**Goal**: convert a basic account into a verified identity, which is a hard prerequisite for pairing any vehicle.

**Entry Points**: prompted from empty dashboard; accessible any time from Settings.

**Step-by-Step**
1. **KYC Intro Screen** — explains why verification is required (vehicle security depends on knowing who really owns it), what's needed (ID document + selfie), and estimated time (2–3 minutes).
2. **Document Type Selection** — Aadhaar or Driving License (configurable based on which the deployed KYC vendor supports).
3. **Document Capture Screen** — camera view with an overlay guide frame; auto-capture when the document is detected in-frame and in focus, with a manual capture fallback.
4. **Document Review Screen** — shows the captured image, "Retake" or "Confirm" actions.
5. **Selfie Capture Screen** — front camera, liveness-guidance overlay (e.g., "blink" or "turn head" prompt if the vendor's SDK requires a liveness check).
6. **Submitting Screen** — a determinate or indeterminate progress state while the Edge Function calls the KYC vendor; this call is asynchronous, so this screen can safely be dismissed and the result delivered via notification/Realtime update if it takes longer than expected.
7. **KYC Result Screen** — three possible states:
   - **Verified**: green confirmation, CTA "Add Your Vehicle" → routes to Vehicle Pairing (Section 23)
   - **Manual Review**: amber state, explains a human review is in progress (typical for edge cases like blurry documents), gives an expected timeframe, and the user is notified via push when resolved
   - **Failed**: red state with a specific, honest reason where the vendor provides one (e.g., "document unreadable," "face mismatch"), with a "Try Again" CTA

**Data Touched**: `kyc_records` row created at submission, updated on result; document/selfie images written to a private Storage bucket scoped to that user only.

**Edge Cases**: poor lighting/blurry capture (client-side quality check before upload where feasible); vendor API timeout (retry with backoff, do not silently fail — show a clear "we'll notify you" state); user attempts to pair a vehicle before KYC completes (blocked both in UI and via RLS on the `vehicles` table).

## 23. Vehicle Pairing

**Goal**: link a physical vehicle's BMS to the verified owner's account for the first time.

**Entry Points**: "Add Your Vehicle" CTA post-KYC; "+" button on the vehicle list for owners adding a second vehicle.

**Step-by-Step**
1. **Pre-Pairing Checklist Screen** — reminds the user to turn on the vehicle/BMS and keep the phone within range, and that Bluetooth + Location permissions will be requested next.
2. **Permission Request Screens** — Android runtime permission dialogs for `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, and location (with plain-language rationale shown before the OS dialog, per Android best practice).
3. **Scanning Screen** — active BLE scan with a live list of nearby compatible devices, filtered to known supported BMS signal patterns; a signal-strength indicator helps the user identify their own vehicle among nearby ones.
4. **Device Selection** — user taps their vehicle from the list.
5. **Connecting Screen** — GATT connection established, service/characteristic discovery runs, with a progress indicator; on failure, a clear retry action and troubleshooting tip (move closer, restart Bluetooth).
6. **Vehicle Details Confirmation Screen** — once connected, the app reads (where available) serial number, VIN, battery serial, and BMS identifier directly from the vehicle, pre-filling a confirmation form; the user can add a nickname ("My Ather") and vehicle photo.
7. **Ownership Claim Screen** — a final confirmation step: "This vehicle will now be linked to your verified identity." This is the moment the `vehicles` row is written.
8. **Pairing Success Screen** — routes into the main Dashboard (Section 24) with the new vehicle now shown.

**Data Touched**: `vehicles` row created with `owner_id`, BLE identifier, serials, make/model; `vehicle_bms_snapshots` first row written from the initial read; `authorized_devices` row created for the owner's own phone.

**Edge Cases**: vehicle already claimed by another VaultRide identity (must be explicitly handled — see Section 47); BMS exposes no readable serial (allow manual entry with a "self-reported, unverified" flag); connection drops mid-pairing (resumable flow, doesn't lose entered nickname/photo).

## 24. Dashboard / Home

**Goal**: the single-glance home screen showing the state of the owner's vehicle(s) and surfacing anything requiring attention.

**Entry Points**: default screen after login/app open for an owner with at least one paired vehicle.

**Layout & Contents**
- **Vehicle Switcher** (if more than one vehicle) — horizontal selector at the top.
- **Hero Status Card** — battery percentage (large, primary), charging state icon, connection state ("Connected" / "Last seen 12 min ago" if out of BLE range), current or last-known location on a small embedded map.
- **Quick Actions Row** — Locate, Grant Temporary Access, View History, Report Issue.
- **Security Status Card** — a plain-language summary: "No unusual activity in the last 7 days" or, if relevant, a highlighted alert card at the top of the whole dashboard when an unresolved alert exists (this always takes visual priority over the status card).
- **Enforcement Honesty Banner** (shown once, dismissible, and always available from Settings) — a short, plain-language note: "VaultRide monitors and alerts on this vehicle. Full remote lock/block requires manufacturer support, which isn't yet available for this vehicle model." This directly reflects the Section 11 boundary and prevents the product from ever implying capabilities it doesn't have.
- **Recent Activity Feed** — condensed log: last charge, last ride, last device authorized, last service entry.

**Data Touched**: reads from `vehicles`, latest `vehicle_bms_snapshots`, unresolved `alerts`, via a mix of an initial fetch and a live Realtime subscription for anything that changes while the screen is open.

**Edge Cases**: vehicle never connected since app install (show a "Waiting for first connection" state rather than blank/zero values, which could be misread as "battery 0%"); stale data beyond a threshold (e.g., >24h) visually flagged as stale rather than presented as current.


## 25. Authorized Devices Management

**Goal**: give the owner full visibility and control over every device/identity with any level of access to their vehicle.

**Entry Points**: Dashboard → Security → Authorized Devices; also reachable from a vehicle's detail screen.

**Step-by-Step**
1. **Authorized Devices List Screen** — grouped into three sections: **Standing Access** (owner's own phone, family members), **Temporary Access** (active grants, with a live countdown to expiry), and **Recently Removed** (audit trail of past revocations, kept for history).
2. Each row shows: name/label, device type, access level (Full / Ride Only / Diagnostics Only / Read Only), and status (Active / Expires in Xh / Expired / Blocked).
3. **Device Detail Screen** (tap any row) — shows full grant history for that device/person, exact permissions granted, and a **Revoke Access** button (with confirmation dialog).
4. **Add Authorized Device Screen** — for standing (non-expiring) access, e.g., adding a spouse: enter their registered VaultRide phone number, select role (see Section 34's Family Sharing roles), confirm.
5. **Blocked Devices Sub-View** — any device that attempted to connect and was denied appears here automatically, so the owner has a record even of failed attempts, not just successful ones.

**Data Touched**: reads/writes `authorized_devices`, `access_grants`, `family_roles`; revocation writes an `alerts`-adjacent audit entry so removal itself is logged, not just silently applied.

**Edge Cases**: revoking access to a device that's mid-session with the vehicle (must immediately invalidate any outstanding signed command tokens for that identity — handled via the `sign-command` Edge Function checking grant status on every call, not just at grant time); owner tries to revoke their own only device (blocked with a clear explanation, since it would lock the owner out).

## 26. Login Alerts / New Device Requests

**Goal**: replicate the "Is this you signing in?" pattern — no device gets standing or temporary access silently.

**Entry Points**: triggered automatically whenever a device not already in `authorized_devices` or a valid `access_grants` row attempts to connect to a paired vehicle through VaultRide, or whenever a new device attempts to sign into the owner's account itself.

**Step-by-Step**
1. **Push Notification** — "Someone is requesting access to [Vehicle Nickname]" with location context (approximate, based on the requesting device's reported location where available) and device type.
2. **In-App Alert Screen** (opened via notification tap, or visible in the Notification Center — Section 37, if not actioned immediately) — shows requester context: approximate location, device type/OS, timestamp, and two clear actions: **Allow** and **Deny**.
3. **Allow Path** — prompts the owner to immediately define scope (jumps into the Temporary Access flow, Section 27, pre-filled with this requester) rather than granting blanket access by default.
4. **Deny Path** — request is logged to Blocked Devices (Section 25), requester (if it's another VaultRide-integrated context) receives a generic "access not granted" response with no detail on why, to avoid giving useful information to a bad-faith requester.
5. **No-Response Path** — if the owner doesn't respond within a configurable window (default 10 minutes), the request auto-expires to Denied, and the owner is informed after the fact that this happened, so nothing is left in limbo.

**Data Touched**: creates an `alerts` row of type `access_request`; on Allow, creates an `access_grants` row; on Deny/timeout, updates the alert's resolution status.

**Edge Cases**: repeated rapid requests from the same unauthorized device (rate-limited and escalated to a higher-severity alert after N attempts, since this pattern suggests probing rather than an accidental connection attempt); owner has notifications disabled (in-app badge + Notification Center still reflect it, and Settings nudges the owner that critical security alerts should not have push disabled).

## 27. Temporary Access Grants

**Goal**: let an owner hand scoped, time-boxed access to someone (classically a mechanic) without ever sharing account credentials.

**Entry Points**: Dashboard Quick Action "Grant Temporary Access"; pre-filled entry from an Allow action in the Login Alert flow (Section 26).

**Step-by-Step**
1. **Grant Setup Screen** — recipient selection (existing contact from Authorized Devices history, or a fresh phone number entry / QR code the recipient scans on their own device if they're not a VaultRide user yet).
2. **Duration Selector** — presets (15 min / 30 min / 1 hour / 1 day / custom), shown as a simple picker.
3. **Permission Scope Selector** — explicit checkboxes: **Read Only** (telemetry visibility), **Diagnostics** (read BMS diagnostic codes), **Firmware** (allow firmware update commands), **Battery Settings** (allow write access to charging current/voltage/cell limits). Each permission has a one-line plain-language explanation of what it allows, since this is the highest-risk screen in the app.
4. **Review & Confirm Screen** — full summary: who, what vehicle, what permissions, for how long, with a final "Grant Access" button.
5. **Active Grant Card** — appears on the Dashboard and Authorized Devices screen with a live countdown; the owner can tap **Revoke Now** at any point before natural expiry.
6. **Expiry** — handled automatically by the `expire-access-grants` scheduled Edge Function; the grantee's access silently and immediately stops working (any subsequent `sign-command` call for that identity is rejected), and the owner receives a low-priority notification confirming the grant ended as scheduled.

**Data Touched**: `access_grants` and `access_grant_permissions` rows created; `command_log` rows generated for anything the grantee actually does during the window; grant status transitions tracked (`active` → `expired`/`revoked`).

**Edge Cases**: recipient isn't a VaultRide user (QR-code-based one-time link flow that creates a minimal, scoped identity for them without full onboarding); owner grants Battery Settings permission (extra confirmation step given this is the highest-risk permission, echoing the Section 11 honesty principle — "changes will be sent to the vehicle if the vehicle's BMS accepts them").

## 28. Theft Protection

**Goal**: alert the owner promptly when the vehicle appears to move without an authorized, present device — while being explicit that this is detection, not prevention.

**Entry Points**: fully automatic, driven by the background foreground service and/or periodic WorkManager checks.

**Step-by-Step (system-driven)**
1. Foreground service detects vehicle movement (via BLE-reported speed/motion data where the BMS exposes it, or via correlated GPS movement of the paired phone assumed to be with the vehicle) **while** the owner's phone is not the device currently connected, or is reporting a significantly different location than the vehicle's last known BLE-linked position.
2. `detect-anomalies` Edge Function (or an on-device pre-check that reports up) classifies this as "Possible Unauthorized Movement" and writes an `alerts` row.
3. **Push Notification** — "Possible unauthorized movement — [Vehicle Nickname]" fires immediately, marked high priority/full-screen-intent style so it's hard to miss.
4. **Alert Detail Screen** — shows a live (or last-known, clearly labeled) location on a map, a timestamp of when movement started, and actions: **Open Live Tracking**, **This Was Me** (dismiss, and optionally teach the anomaly model this is normal), **Trigger Emergency Mode** (routes to Section 33).
5. **Live Tracking Screen** — map view with position updates as they arrive; explicitly labeled with connection state ("Live" vs "Last known, Xm ago") so the owner is never misled about data freshness.

**Data Touched**: `alerts` row (type `unauthorized_movement`); location points logged against the vehicle for the duration of the tracked event.

**Edge Cases**: false positive from the owner simply not having their phone on them while a family member with standing access rides the vehicle (the "This Was Me" / known-authorized-rider dismissal path should reduce recurrence — see anomaly learning in Section 32); no connectivity to relay the alert immediately (queued and delivered once the phone regains signal, with the original event timestamp preserved so the owner isn't misled about *when* it happened).

## 29. Battery Protection

**Goal**: alert the owner when BMS-level parameters change, since this is one of the more damaging and hard-to-notice forms of unauthorized tampering.

**Entry Points**: automatic, driven by the BLE read-loop's change-detection logic (Section 15).

**Step-by-Step**
1. Read-loop detects a change in a protected parameter (charging current, voltage limit, cell balancing limits) that does not correspond to a command VaultRide itself just issued on the owner's behalf.
2. An `alerts` row is created (type `ba
<truncated 37062 bytes>

NOTE: The output was truncated because it was too long. Use a more targeted query or a smaller range to get the information you need.