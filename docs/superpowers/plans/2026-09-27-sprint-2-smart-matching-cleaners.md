# Sprint 2: Cleaner Master Data & Deterministic Smart Matching Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete end-to-end Cleaner Master Data, Deterministic Smart Matching Recommendation Engine (40/30/20/10 scoring formula with schedule buffer and provisional ratings), and Flutter Mobile Cleaner Recommendation & Profile Interfaces (matching Stitch Screens 2 & 3).

**Architecture:** Monorepo architecture where the Express.js REST API (`backend/routes/cleaners.js` and `backend/lib/matching.js`) evaluates candidate cleaners using strict hard filters (status `Aktif`, skill match, and 30-minute buffer anti-double booking) and deterministically ranks them using the 40/30/20/10 formula. The Flutter mobile app (`mobile/`) presents recommendations inside the booking flow (Stitch Screen 2) and provides an in-depth cleaner profile inspection screen (Stitch Screen 3) before locking in the customer's cleaner preference (`preferensi_petugas_id`).

**Tech Stack:**
- Backend: Node.js (ES Module), Express.js, Supabase PostgreSQL / in-memory dual-mode store, Node.js native test runner (`node:test`)
- Mobile: Flutter 3.x, Dart, `google_fonts` (Plus Jakarta Sans), `http`, `intl`
- Design System: Stitch "Pristine On-Demand" (`AppColors` Sky Blue, Emerald, Warm Amber, Slate 900)

**Spec References:**
- `docs/PRD-Resik.in.md` (FR-04, FR-05, FR-09)
- `docs/BUSINESS-RULES.md` (BR-SCH-005, BR-SCH-007, BR-MTG-001 s.d. BR-MTG-005, BR-ASN-002)
- `docs/API.md` (Section 2.2 `GET /api/cleaners`, `GET /api/cleaners/:id`, `GET /api/cleaners/recommendations`)
- Stitch MCP Project `5093522159329805546`: Screen 2 (`4124fcf43b544308ab5ba3fb25379716`) & Screen 3 (`6af3b2891f954043b26adf57a7e0cde2`)

---

## Global Constraints & Business Invariants

1. **Hard Filter Disqualification (BR-MTG-001):**
   - Cleaners with `status_operasional != 'Aktif'` are immediately disqualified.
   - Cleaners with schedule overlap on the requested date and interval (including the 30-minute operational buffer: `start_time - 30m` to `end_time + 30m`) are disqualified.
   - Cleaners lacking required skill for high-technical services (specifically `pasca_renovasi`) are disqualified.
2. **Deterministic Scoring Formula (BR-MTG-002):**
   $$\text{Total Score} = (0.40 \times S_{\text{skill}}) + (0.30 \times S_{\text{avail}}) + (0.20 \times S_{\text{rating}}) + (0.10 \times S_{\text{exp}})$$
   - $S_{\text{skill}}$: 100 for exact/primary match, 70 for acceptable secondary (`office_cleaning` using `general_cleaning`), 0 for no match.
   - $S_{\text{avail}}$: 100 if 0 other active orders that day, 80 if 1 safe order, 60 if $\ge 2$ safe orders.
   - $S_{\text{rating}}$: $(\text{rating} / 5.0) \times 100$. For new cleaners without reviews, provisional rating is $4.5$ ($S_{\text{rating}} = 90.0$).
   - $S_{\text{exp}}$: $\min(100, (\text{pengalaman\_tahun} / 5) \times 100)$.
3. **Deterministic Tie-Breaking (BR-MTG-004):**
   Tie sorted by: Prioritas 1: `rating_rata_rata` DESC $\rightarrow$ Prioritas 2: `total_pekerjaan` DESC $\rightarrow$ Prioritas 3: `id` ASC.
4. **UI Distinction (BR-MTG-003):**
   Provisional rating must never be disguised as customer reviews. UI displays "Petugas Baru (Rating Awal 4.5)" for provisional ratings vs "⭐ 4.9 (127 ulasan)" for verified reviews.
5. **Zero Candidates Fallback (BR-MTG-005):**
   If 0 candidates qualify, system provides options: change date, change time, or proceed with `preferensi_petugas_id = null` ("Pilihkan Otomatis oleh Admin").

---

### Task 1: Backend Smart Matching Engine (`backend/lib/matching.js` & `backend/test/matching.test.js`)

**Files:**
- Create: `backend/lib/matching.js`
- Create: `backend/test/matching.test.js`

**Interfaces:**
- Produces: `calculateMatchingScore(cleaner, service, date, startTime, duration, existingOrders)` and `getRecommendations({ cleaners, service, date, startTime, duration, existingOrders })`

- [ ] **Step 1: Write failing unit tests for the Smart Matching algorithm**
  Create `backend/test/matching.test.js` testing:
  1. Cleaner with status `Cuti` or `Nonaktif` is excluded by Hard Filter.
  2. Cleaner with schedule overlap within 30-minute buffer is excluded.
  3. Pasca renovasi service without `pasca_renovasi` skill is excluded.
  4. Scoring formula calculates exact score: 40% skill + 30% avail + 20% rating + 10% exp.
  5. Provisional rating 4.5 applied for cleaners with 0 reviews.
  6. Tie-breaking sorts higher rating, then total_pekerjaan, then id ASC.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm test` in `backend/`
  Expected: FAIL (module not found).

- [ ] **Step 3: Implement matching logic in `backend/lib/matching.js`**
  Implement:
  - `hasScheduleConflict(cleanerId, date, startTime, duration, existingOrders, bufferMinutes = 30)`
  - `calculateSkillScore(cleanerSkills, serviceKategori)`
  - `calculateAvailabilityScore(cleanerId, date, startTime, duration, existingOrders)`
  - `calculateRatingScore(rating, totalPekerjaan)`
  - `calculateExperienceScore(years)`
  - `getRecommendations(...)` sorting candidates with tie-breaking rules.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm test` in `backend/`
  Expected: PASS (all matching tests green).

- [ ] **Step 5: Commit**
  `git add backend/lib/matching.js backend/test/matching.test.js && git commit -m "feat(backend): implement deterministic smart matching engine with hard filters and scoring"`

---

### Task 2: Backend Cleaners REST API & Recommendations Endpoint (`backend/routes/cleaners.js` & `backend/routes/orders.js`)

**Files:**
- Modify: `backend/lib/supabase.js` (enrich seeded cleaner data with realistic profiles, skills, and photos)
- Modify: `backend/routes/cleaners.js` (implement full `GET /api/cleaners`, `GET /api/cleaners/:id`, `GET /api/cleaners/recommendations`)
- Modify: `backend/routes/orders.js` (accept and record `preferensi_petugas_id`)
- Create: `backend/test/cleaners.test.js`

**Interfaces:**
- `GET /api/cleaners`: Returns all active cleaners.
- `GET /api/cleaners/:id`: Returns cleaner profile detail by ID.
- `GET /api/cleaners/recommendations?service_id=...&tanggal=...&start_time=...&duration=...`: Returns ranked candidates.
- `POST /api/orders`: Stores `preferensi_petugas_id` in orders and status logs.

- [ ] **Step 1: Write failing API route tests in `backend/test/cleaners.test.js`**
  Assert:
  1. `GET /api/cleaners` returns 200 with list of cleaners.
  2. `GET /api/cleaners/:id` returns 200 with cleaner detail, or 404 if not found.
  3. `GET /api/cleaners/recommendations` without required query parameters returns 400.
  4. `GET /api/cleaners/recommendations` with past date returns 400.
  5. `GET /api/cleaners/recommendations` returns ranked candidate array with match badges.
  6. `POST /api/orders` saves `preferensi_petugas_id`.

- [ ] **Step 2: Run test to verify it fails**
  Run: `npm test` in `backend/`
  Expected: FAIL on recommendations query validation.

- [ ] **Step 3: Implement endpoints in `backend/routes/cleaners.js` and `backend/routes/orders.js`**
  - Integrate `matching.js` into `GET /api/cleaners/recommendations`.
  - Validate parameters (`service_id`, `tanggal >= today`, `start_time between 08:00 and 17:00`, `duration`).
  - Wire in-memory and Supabase data sources.
  - Handle `preferensi_petugas_id` in `orders.js`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `npm test` in `backend/`
  Expected: PASS (all backend tests green).

- [ ] **Step 5: Commit**
  `git add backend/lib/supabase.js backend/routes/cleaners.js backend/routes/orders.js backend/test/cleaners.test.js && git commit -m "feat(backend): implement cleaners API routes and recommendation endpoint"`

---

### Task 3: Flutter Cleaner Model and API Service Client

**Files:**
- Create: `mobile/lib/models/cleaner_model.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Create: `mobile/test/cleaner_model_test.dart`

**Interfaces:**
- Produces: `CleanerModel` Dart class with `fromJson` and `toJson`.
- Produces: `ApiService.fetchCleaners()`, `ApiService.fetchCleanerById(id)`, `ApiService.fetchRecommendations(...)`.

- [ ] **Step 1: Write failing unit test for CleanerModel**
  Create `mobile/test/cleaner_model_test.dart` verifying JSON parsing of full cleaner attributes (ratings, provisional flag, totalScore, matchBadge, skills).

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/cleaner_model_test.dart` in `mobile/`
  Expected: FAIL (file or class not found).

- [ ] **Step 3: Implement `CleanerModel` and `ApiService` methods**
  - Create `CleanerModel` in `mobile/lib/models/cleaner_model.dart`.
  - Add `fetchCleaners`, `fetchCleanerById`, and `fetchRecommendations` in `mobile/lib/services/api_service.dart`.

- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test` in `mobile/`
  Expected: PASS.

- [ ] **Step 5: Commit**
  `git add mobile/lib/models/cleaner_model.dart mobile/lib/services/api_service.dart mobile/test/cleaner_model_test.dart && git commit -m "feat(mobile): add cleaner model and api client methods"`

---

### Task 4: Flutter Cleaner Detail Profile Screen (Stitch Screen 3)

**Files:**
- Create: `mobile/lib/screens/cleaner_detail_screen.dart`
- Create: `mobile/test/cleaner_detail_screen_test.dart`

**Interfaces:**
- Produces: `CleanerDetailScreen` displaying:
  - Header with large avatar, verified badge, and experience tag.
  - Quick performance metrics (Pekerjaan Selesai, Kepuasan %, Ketepatan Waktu %).
  - Verified skills & specializations chips.
  - Certifications & guarantee section.
  - Customer review list (or provisional rating explanation).
  - Sticky bottom action button "Pilih Petugas Ini".

- [ ] **Step 1: Write failing widget test for `CleanerDetailScreen`**
  Create `mobile/test/cleaner_detail_screen_test.dart` asserting:
  1. Renders cleaner name, skills, and rating.
  2. Displays provisional rating badge if `isProvisionalRating == true`.
  3. Displays "Pilih Petugas Ini" button and returns selected cleaner on pop.

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/cleaner_detail_screen_test.dart` in `mobile/`
  Expected: FAIL.

- [ ] **Step 3: Implement `CleanerDetailScreen` in `mobile/lib/screens/cleaner_detail_screen.dart`**
  Build the UI matching Stitch Screen 3 using `AppColors` and Plus Jakarta Sans.

- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test` in `mobile/`
  Expected: PASS.

- [ ] **Step 5: Commit**
  `git add mobile/lib/screens/cleaner_detail_screen.dart mobile/test/cleaner_detail_screen_test.dart && git commit -m "feat(mobile): implement cleaner detail profile screen matching stitch design"`

---

### Task 5: Flutter Booking Screen Smart Matching Integration (Stitch Screen 2)

**Files:**
- Modify: `mobile/lib/screens/booking_screen.dart`
- Modify: `mobile/lib/screens/payment_screen.dart` (show selected cleaner info)
- Modify: `mobile/test/booking_screen_test.dart`

**Interfaces:**
- In `BookingScreen`:
  - When date/time changes, calls `ApiService.fetchRecommendations`.
  - Displays recommendation cards with match badge, photo, star rating / provisional badge.
  - Tapping card opens `CleanerDetailScreen`.
  - Radio/toggle allows selecting cleaner or "Pilihkan Otomatis oleh Admin".
  - Submits `preferensi_petugas_id` on booking creation.
- In `PaymentScreen`:
  - Displays assigned/preferred cleaner card if present.

- [ ] **Step 1: Write failing widget test in `mobile/test/booking_screen_test.dart`**
  Test recommendation cards render and selecting a cleaner updates booking state.

- [ ] **Step 2: Run test to verify it fails**
  Run: `flutter test test/booking_screen_test.dart` in `mobile/`
  Expected: FAIL.

- [ ] **Step 3: Update `BookingScreen` and `PaymentScreen`**
  - Integrate recommendation section with Stitch styling (rounded 16px cards, match score chip, provisional badge).
  - Handle zero candidates fallback.
  - Forward `preferensi_petugas_id` to order payload and payment summary.

- [ ] **Step 4: Run test to verify it passes**
  Run: `flutter test` in `mobile/`
  Expected: PASS.

- [ ] **Step 5: Commit**
  `git add mobile/lib/screens/booking_screen.dart mobile/lib/screens/payment_screen.dart mobile/test/booking_screen_test.dart && git commit -m "feat(mobile): integrate smart matching recommendations into booking screen"`

---

### Task 6: Full Suite Verification & Build Validation

**Files:**
- Test all: `backend/` and `mobile/`

- [ ] **Step 1: Run Backend Tests**
  Run: `cd backend && npm test`
  Expected: 100% PASS with all suites green.

- [ ] **Step 2: Run Flutter Static Analysis**
  Run: `cd mobile && flutter analyze`
  Expected: `No issues found!` (0 errors, 0 warnings).

- [ ] **Step 3: Run Flutter Widget Tests**
  Run: `cd mobile && flutter test`
  Expected: 100% PASS.

- [ ] **Step 4: Build Debug APK**
  Run: `cd mobile && flutter build apk --debug`
  Expected: `√ Built app-debug.apk` successfully.

- [ ] **Step 5: Final Release Commit for Sprint 2**
  `git commit -m "chore(release): complete sprint 2 cleaner master data and smart matching engine"`
