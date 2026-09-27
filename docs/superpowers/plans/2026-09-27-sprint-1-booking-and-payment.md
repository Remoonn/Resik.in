# Sprint 1: Core Booking & Payment Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete end-to-end Core Booking, Price Freezing, and Server-Authoritative Payment Simulation for Resik.in across the Node.js/Express backend and Flutter mobile client.

**Architecture:** Monorepo architecture where the Flutter mobile client (`mobile/`) sends structured booking requests to the Express.js REST API (`backend/routes/orders.js`). The backend freezes pricing from active catalog services, calculates the service end time based on estimated duration, initializes the order state to `Menunggu Konfirmasi` with payment state `Belum Bayar`, and validates payment simulation via `POST /api/orders/:id/pay` while logging status events.

**Tech Stack:**
- Backend: Node.js (ES Module), Express.js, Supabase PostgreSQL / in-memory dual-mode store, Node.js native test runner (`node:test`)
- Mobile: Flutter 3.x, Dart, `http` package, `intl` package

**Spec:**
- `docs/PRD-Resik.in.md` (FR-02, FR-03)
- `docs/BUSINESS-RULES.md` (BR-SCH-005, BR-SCH-007, BR-FIN-001, BR-FIN-002)
- `docs/API.md` (Section 2.3 `POST /api/orders`, `POST /api/orders/:id/pay`, `GET /api/orders/:id`)
- `docs/TESTING.md` (TC-PAY-01 s.d. TC-PAY-04, TC-PRC-01 s.d. TC-PRC-03)

## Global Constraints

- Backend response envelopes must always follow `{ "success": boolean, "message": string, "data": { ... } }` or `{ "success": false, "message": string, "error": string }`.
- Canonical HTTP status codes: 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict, 500 Internal Server Error. No 422.
- Pricing must be frozen deterministically: `harga_saat_booking = services.tarif_dasar`, `total_biaya = harga_saat_booking`.
- Client is strictly forbidden from supplying `status_pembayaran` on booking creation. Initial state is always `Belum Bayar`.
- Order creation requires: `service_id`, `tanggal_layanan` ($\ge H+0$), `start_time` (08:00–17:00), `duration` (1–4 hrs), `alamat_lengkap` ($\ge 10$ chars), `patokan_lokasi` ($\ge 3$ chars), `luas_area`.
- Simulated payment must set `status_pembayaran = 'Sudah Bayar'` with `payment_timestamp = NOW()` (server time).
- Flutter client must compile cleanly with `flutter analyze` (0 warnings/errors) and follow Flutter clean widget patterns.

---

### Task 1: Backend Booking Logic & Pricing Freeze (`POST /api/orders`)

**Files:**
- Modify: `backend/routes/orders.js`
- Modify: `backend/lib/supabase.js`
- Test: `backend/test/orders.test.js`

**Interfaces:**
- Consumes: `services` data from `backend/lib/supabase.js`
- Produces: `POST /api/orders` returning HTTP 201 Created with `{ success: true, message: "...", data: { id, order_code, harga_saat_booking, total_biaya, status_pembayaran, status_pekerjaan } }`

- [ ] **Step 1: Write the failing test for booking creation and price freezing**
Create `backend/test/orders.test.js` with tests asserting:
1. Missing required fields returns 400 with descriptive error.
2. Invalid operating hours (before 08:00 or after 17:00) returns 400.
3. Valid payload creates order with 201, price frozen from service, `status_pembayaran = 'Belum Bayar'`, `status_pekerjaan = 'Menunggu Konfirmasi'`.

- [ ] **Step 2: Run test to verify it fails**
Run: `npm test` in `backend/`
Expected: FAIL due to unimplemented `POST /api/orders`.

- [ ] **Step 3: Write minimal implementation in backend/routes/orders.js**
Implement input validation, operating hours check (08:00 to 17:00), duration interval calculation (`end_time = start_time + duration`), price freezing snapshot from service catalog, in-memory/Supabase order persistence, and status logs creation.

- [ ] **Step 4: Run test to verify it passes**
Run: `npm test` in `backend/`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add backend/routes/orders.js backend/lib/supabase.js backend/test/orders.test.js && git commit -m "feat(backend): implement order booking with price freezing"`

---

### Task 2: Backend Payment Simulation & Order Detail (`POST /api/orders/:id/pay` & `GET /api/orders/:id`)

**Files:**
- Modify: `backend/routes/orders.js`
- Modify: `backend/lib/supabase.js`
- Test: `backend/test/orders.test.js`

**Interfaces:**
- Consumes: Created orders from Task 1
- Produces:
  - `POST /api/orders/:id/pay` returning HTTP 200 with `{ success: true, message: "...", data: { id, status_pembayaran: "Sudah Bayar", payment_timestamp } }`
  - `GET /api/orders/:id` returning HTTP 200 with full order details.

- [ ] **Step 1: Write the failing tests for payment simulation and idempotency**
Add tests in `backend/test/orders.test.js`:
1. Paying a non-existent order returns 404.
2. Paying an unpaid order transitions payment to `Sudah Bayar` and sets `payment_timestamp`.
3. Paying an already paid order returns 400 Bad Request (`ORDER_ALREADY_PAID`).
4. `GET /api/orders/:id` returns the full order detail.

- [ ] **Step 2: Run test to verify it fails**
Run: `npm test` in `backend/`
Expected: FAIL because pay endpoint is not implemented.

- [ ] **Step 3: Write minimal implementation for pay and detail endpoints**
Implement `POST /api/orders/:id/pay` and `GET /api/orders/:id` in `backend/routes/orders.js`. Record payment log in `status_logs`.

- [ ] **Step 4: Run test to verify it passes**
Run: `npm test` in `backend/`
Expected: PASS with all tests passing.

- [ ] **Step 5: Commit**
`git add backend/routes/orders.js backend/test/orders.test.js && git commit -m "feat(backend): implement payment simulation and order detail endpoints"`

---

### Task 3: Flutter Order & Booking Models and API Client

**Files:**
- Create: `mobile/lib/models/order_model.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Create: `mobile/test/order_model_test.dart`

**Interfaces:**
- Consumes: Backend API responses (`POST /api/orders`, `POST /api/orders/:id/pay`, `GET /api/orders/:id`)
- Produces: `OrderModel` Dart class, `ApiService.createOrder(...)`, `ApiService.payOrder(...)`, `ApiService.getOrder(...)`

- [ ] **Step 1: Write failing Dart unit tests for OrderModel and ApiService methods**
Write tests in `mobile/test/order_model_test.dart` asserting JSON serialization/deserialization for `OrderModel` and mock contract structure.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/order_model_test.dart` in `mobile/`
Expected: FAIL (file or class not found).

- [ ] **Step 3: Write minimal implementation for OrderModel and ApiService**
Implement `mobile/lib/models/order_model.dart` with properties matching `docs/DATA-DICTIONARY.md` and `docs/API.md`. Update `mobile/lib/services/api_service.dart` with `createOrder`, `payOrder`, and `fetchOrderById`.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test` in `mobile/`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add mobile/lib/models/order_model.dart mobile/lib/services/api_service.dart mobile/test/order_model_test.dart && git commit -m "feat(mobile): add order model and api client methods"`

---

### Task 4: Flutter Service Detail & Booking Form Screen

**Files:**
- Create: `mobile/lib/screens/booking_screen.dart`
- Modify: `mobile/lib/main.dart`
- Create: `mobile/test/booking_screen_test.dart`

**Interfaces:**
- Consumes: `ServiceModel` from home screen
- Produces: `BookingScreen` widget that collects mandatory booking attributes, validates inputs, and triggers order creation.

- [ ] **Step 1: Write failing widget test for BookingScreen**
Create `mobile/test/booking_screen_test.dart` testing:
1. Renders service summary with frozen base price.
2. Validates mandatory fields (address $\ge 10$ chars, landmark $\ge 3$ chars, date, operating hour 08:00–17:00).

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/booking_screen_test.dart` in `mobile/`
Expected: FAIL.

- [ ] **Step 3: Implement BookingScreen in mobile/lib/screens/booking_screen.dart**
Design clean, professional mobile form with:
- Service header banner with frozen tariff.
- Date picker ($\ge H+0$) and operational time dropdown/picker (08:00–17:00).
- Text fields for `alamat_lengkap`, `patokan_lokasi`, `luas_area`, and optional `catatan_khusus`.
- Submission button calling `ApiService.createOrder`.
- Navigation to Payment Screen upon success.
- Link tapping service card on `main.dart` to open `BookingScreen`.

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test` in `mobile/`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add mobile/lib/screens/booking_screen.dart mobile/lib/main.dart mobile/test/booking_screen_test.dart && git commit -m "feat(mobile): implement booking form screen with validation"`

---

### Task 5: Flutter Payment & Order Confirmation Screen

**Files:**
- Create: `mobile/lib/screens/payment_screen.dart`
- Modify: `mobile/lib/screens/booking_screen.dart`
- Create: `mobile/test/payment_screen_test.dart`

**Interfaces:**
- Consumes: Created `OrderModel` from `BookingScreen`
- Produces: `PaymentScreen` displaying order summary, frozen price, and server-authoritative simulation button.

- [ ] **Step 1: Write failing widget test for PaymentScreen**
Create `mobile/test/payment_screen_test.dart` checking:
1. Renders order code, service name, and total cost formatted in Rupiah.
2. Displays "Belum Bayar" badge.
3. Contains "Bayar Sekarang (Simulasi)" button.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/payment_screen_test.dart` in `mobile/`
Expected: FAIL.

- [ ] **Step 3: Implement PaymentScreen in mobile/lib/screens/payment_screen.dart**
Implement the payment simulation interface:
- Displays Order Code, service details, frozen price breakdown.
- Status badge: Red/Orange for `Belum Bayar`, Green for `Sudah Bayar`.
- Action button "Bayar Sekarang (Simulasi)" calling `ApiService.payOrder`.
- Success dialog showing payment timestamp, transition confirmation, and next steps ("Menunggu Konfirmasi Admin").

- [ ] **Step 4: Run test to verify it passes**
Run: `flutter test` in `mobile/`
Expected: PASS.

- [ ] **Step 5: Commit**
`git add mobile/lib/screens/payment_screen.dart mobile/lib/screens/booking_screen.dart mobile/test/payment_screen_test.dart && git commit -m "feat(mobile): implement payment simulation screen"`

---

### Task 6: End-to-End Suite Verification & Static Analysis

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

- [ ] **Step 4: Final Sprint 1 Commit**
`git commit -m "chore(release): complete sprint 1 core booking and payment engine"`
