# Spesifikasi Desain: Sprint 4 — Quality Report Digital (Laporan Mutu Hasil Kerja)

> **Dokumen:** `docs/superpowers/specs/2026-09-29-sprint-4-quality-report-design.md`  
> **Status:** Draft Disetujui  
> **Tanggal:** 29 September 2026  
> **Target Rilis:** Sprint 4 (FR-10 — Milestone Terakhir V1 Prototype)  
> **Referensi SOT:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/API.md`, `database/schema.sql`

---

## 1. Latar Belakang & Tujuan

Pada Sprint 1 hingga Sprint 3, sistem Resik.in telah menyelesaikan katalog 4 layanan, formulir pemesanan, snapshot harga flat deterministik, simulasi checkout pembayaran server-authoritative, manajemen master data petugas, mesin Smart Petugas Matching, autentikasi Supabase Auth & Google Sign-In, siklus hidup pesanan 7 status, penugasan hibrida bebas bentrok jadwal (+ buffer 30 menit), pembatalan berbasis peran, stepper pelacakan visual beranimasi, dan sheet kontrol simulasi operasional.

Satu-satunya subsistem yang tersisa untuk menuntaskan **V1 Prototype (100%)** adalah **Quality Report Digital (`FR-10`)**.

**Tujuan Sprint 4:**
1. Mengimplementasikan gerbang wajib status (*Mandatory Gate to Selesai*), di mana pesanan yang sedang berada pada status `Sedang Dikerjakan` **hanya bisa** bertransisi ke status `Selesai` jika petugas telah menyerahkan Quality Report yang valid.
2. Menerapkan verifikasi checklist area fisik 100% tuntas berdasarkan template kategori layanan (Rumah, Kos, Kantor, Pasca Renovasi).
3. Menerapkan alur unggah foto fisik *Before* dan *After* ke private storage bucket Supabase (`quality-reports`).
4. Menegakkan invarian konsistensi timestamp server ($\text{started\_at} \le \text{completed\_at} \le \text{submitted\_at}$ dan $\text{completed\_at} \le \text{NOW()}$).
5. Mengimplementasikan akses inspeksi laporan berbasis **temporary Signed URL** berdurasi 30 menit (1800 detik) untuk Pelanggan pemilik order, Petugas yang ditugaskan, dan Admin.
6. Membangun antarmuka mobile Flutter:
   - Formulir pengisian Quality Report (*dialog/form*) dengan pemilih foto (*image picker* kamera/galeri) dan checklist dinamis.
   - Layar penuh peninjauan hasil (*Dedicated Full-Screen: `QualityReportScreen`*) untuk Pelanggan dengan komparasi visual foto *Before* & *After*, status centang area, kartu audit trail waktu, dan badge penguncian *read-only*.

---

## 2. Ruang Lingkup Fitur (Scope: FR-10)

| Kode Fitur | Deskripsi | Aktor Utama | Kriteria Keberhasilan |
| :--- | :--- | :--- | :--- |
| **FR-10** | Quality Report Digital (*Mandatory Gate to Selesai with Private Storage & Signed URL*) | Petugas, Pelanggan, Admin | • Validasi 9 tahap di backend sebelum order berpindah ke `Selesai`.<br>• Template checklist wajib 100% tercentang sesuai kategori layanan.<br>• Verifikasi invarian timestamp server.<br>• Foto Before & After tersimpan privat dan hanya dapat dibuka via Signed URL 30 menit.<br>• Data laporan terkunci *read-only* setelah terbit.<br>• UI Customer Dedicated Full-Screen menampilkan komparasi foto dan audit waktu. |

---

## 3. Skema Data & Konfigurasi Supabase Storage

### 3.1 Skema Tabel `quality_reports`
Tabel relasional pada basis data Supabase PostgreSQL (sesuai `database/schema.sql`):
```sql
CREATE TABLE IF NOT EXISTS public.quality_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    cleaner_id UUID REFERENCES public.cleaners(id) ON DELETE SET NULL,
    checklist_area JSONB NOT NULL DEFAULT '[]'::jsonb, 
    -- Format JSON: [{"area": "Ruang Tamu", "completed": true}, ...]
    foto_before_url TEXT NOT NULL,     -- Path storage: orders/{order_id}/before_{timestamp}.webp
    foto_after_url TEXT NOT NULL,      -- Path storage: orders/{order_id}/after_{timestamp}.webp
    catatan_petugas TEXT,
    started_at TIMESTAMPTZ,            -- Waktu pesanan beralih ke 'Sedang Dikerjakan'
    completed_at TIMESTAMPTZ NOT NULL, -- Waktu fisik selesai diisi oleh petugas
    submitted_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3.2 Konfigurasi Private Storage Bucket (`quality-reports`)
- **Bucket ID:** `quality-reports` (Private / Non-Public).
- **Format Penamaan Path Berkas Standar:**
  - Foto Sebelum: `orders/{order_id}/before_{timestamp}.webp` (atau `.jpg`/`.png`)
  - Foto Sesudah: `orders/{order_id}/after_{timestamp}.webp` (atau `.jpg`/`.png`)
- **Kebijakan Akses Berkas:**
  - Unduhan langsung publik diblokir (*Access Denied*).
  - Akses baca hanya dimungkinkan via token otentikasi Supabase Storage atau *temporary Signed URL* yang diterbitkan oleh backend.

---

## 4. Kontrak REST API Backend (`backend/routes/quality-reports.js`)

### 4.1 Pembuatan & Finalisasi Laporan (`POST /api/quality-reports`)
- **Method:** `POST`
- **Header:** `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "order_id": "uuid-order",
    "checklist_area": [
      { "area": "Ruang Tamu", "completed": true },
      { "area": "Kamar Tidur", "completed": true },
      { "area": "Dapur", "completed": true },
      { "area": "Kamar Mandi", "completed": true },
      { "area": "Area Tambahan Sesuai Paket", "completed": true }
    ],
    "foto_before_path": "orders/uuid-order/before_1727376000.webp",
    "foto_after_path": "orders/uuid-order/after_1727379600.webp",
    "catatan_petugas": "Pembersihan tuntas sesuai standar kebersihan Resik.in.",
    "completed_at": "2026-09-29T10:00:00.000Z",
    "role": "cleaner"
  }
  ```

- **Pipeline Validasi 9 Tahap (Strict Enforcement):**
  1. **Verifikasi Hak Akses:** Pengirim adalah Petugas yang ditugaskan pada `order_id` (atau Admin dalam mode simulasi).
  2. **Verifikasi Status Pesanan:** Status pekerjaan pesanan saat ini **wajib** `'Sedang Dikerjakan'`. Jika belum atau sudah selesai, tolak dengan `400 Bad Request` (`ORDER_NOT_IN_PROGRESS`).
  3. **Verifikasi Template Checklist Penuh:** Seluruh area wajib sesuai kategori layanan pesanan (Rumah: 5 area, Kos: 3 area, Kantor: 4 area, Renovasi: 4 area) dan setiap item harus bernilai `completed: true`. Jika ada yang tertinggal/false, tolak dengan `400 Bad Request` (`CHECKLIST_AREAS_INCOMPLETE`).
  4. **Verifikasi Invarian Timestamp Server:** Server memvalidasi bahwa $\text{started\_at} \le \text{completed\_at} \le \text{submitted\_at}$ dan $\text{completed\_at} \le \text{NOW()}$. Jika melanggar urutan atau completed_at berada di masa depan, tolak dengan `400 Bad Request` (`INVALID_TIMESTAMPS`).
  5. **Verifikasi Path Berkas:** Parameter `foto_before_path` dan `foto_after_path` wajib berupa string dan diawali dengan prefix `orders/{order_id}/`. Jika tidak cocok, tolak dengan `400 Bad Request` (`INVALID_STORAGE_PATH`).
  6. **Verifikasi Keberadaan Berkas Fisik:** Server memverifikasi keberadaan berkas pada private bucket Supabase Storage (dengan mode fallback adaptif pada unit test / offline environment).
  7. **Penyimpanan Laporan Mutu:** Simpan data ke tabel `quality_reports` dengan `submitted_at = NOW()`.
  8. **Transisi Status Pesanan:** Mutasi status `orders.status_pekerjaan = 'Selesai'`, catat entri log audit ke `status_logs`.
  9. **Pemulihan Metrik Petugas:** Kembalikan `cleaners.status_operasional = 'Aktif'` dan tambahkan `cleaners.total_pekerjaan` +1.

- **Success Response (HTTP 201 Created):**
  ```json
  {
    "success": true,
    "message": "Quality Report berhasil disimpan dan pesanan dinyatakan Selesai",
    "data": {
      "report_id": "uuid-report",
      "order_id": "uuid-order",
      "status_pekerjaan": "Selesai",
      "submitted_at": "2026-09-29T10:02:15.000Z"
    }
  }
  ```

- **Error Responses:**
  - `400 Bad Request`: `ORDER_NOT_IN_PROGRESS`, `CHECKLIST_AREAS_INCOMPLETE`, `INVALID_TIMESTAMPS`, `INVALID_STORAGE_PATH`.
  - `403 Forbidden`: `UNAUTHORIZED_CLEANER`.
  - `404 Not Found`: `ORDER_NOT_FOUND`, `STORAGE_FILE_NOT_FOUND`.

---

### 4.2 Inspeksi Laporan via Temporary Signed URL (`GET /api/quality-reports/:order_id`)
- **Method:** `GET`
- **Header:** `Authorization: Bearer <token>`
- **Otorisasi RBAC:** Pelanggan pemilik pesanan (`customer_id`), Petugas yang ditugaskan (`cleaner_id`), atau Admin. Pihak ketiga ditolak dengan status `403 Forbidden`.
- **Aksi Server:** Menghasilkan token Signed URL untuk `foto_before_url` dan `foto_after_url` dengan masa kedaluwarsa **30 menit (1800 detik)**.
- **Success Response (HTTP 200 OK):**
  ```json
  {
    "success": true,
    "message": "Quality report berhasil diambil",
    "data": {
      "id": "uuid-report",
      "order_id": "uuid-order",
      "cleaner_nama": "Candra Pratama",
      "checklist_area": [
        { "area": "Ruang Tamu", "completed": true },
        { "area": "Kamar Tidur", "completed": true },
        { "area": "Dapur", "completed": true },
        { "area": "Kamar Mandi", "completed": true },
        { "area": "Area Tambahan Sesuai Paket", "completed": true }
      ],
      "catatan_petugas": "Pembersihan tuntas sesuai standar kebersihan Resik.in.",
      "foto_before_signed_url": "https://supabase.../sign/quality-reports/orders/uuid/before.webp?token=...",
      "foto_after_signed_url": "https://supabase.../sign/quality-reports/orders/uuid/after.webp?token=...",
      "signed_url_expires_in": 1800,
      "started_at": "2026-09-29T08:00:00.000Z",
      "completed_at": "2026-09-29T10:00:00.000Z",
      "submitted_at": "2026-09-29T10:02:15.000Z",
      "is_locked": true
    }
  }
  ```

---

### 4.3 Penguncian Gerbang Status di `backend/routes/orders.js`
- Modifikasi endpoint `PATCH /api/orders/:id/status`:
  - Jika klien mengirim `status_baru: 'Selesai'`, backend secara tegas menolak pembaruan dengan status HTTP `400 Bad Request` dan kode pesan `QUALITY_REPORT_REQUIRED: "Transisi ke status Selesai wajib melalui pengiriman Quality Report pada POST /api/quality-reports"`.

---

## 5. Template Area Checklist Spesifik Layanan

Setiap template area disusun sesuai karakteristik fisik properti:
```javascript
export const CHECKLIST_TEMPLATES = {
  rumah: [
    'Ruang Tamu',
    'Kamar Tidur',
    'Dapur',
    'Kamar Mandi',
    'Area Tambahan Sesuai Paket'
  ],
  kos: [
    'Kamar Tidur / Utama',
    'Kamar Mandi',
    'Area yang Termasuk Paket'
  ],
  kantor: [
    'Ruang Kerja',
    'Area Umum / Koridor',
    'Toilet Kantor',
    'Pantry / Dapur Bersih'
  ],
  renovasi: [
    'Area Utama Pekerjaan',
    'Pembersihan Lantai & Sudut Ruangan',
    'Pembersihan Debu & Sisa Material Semen/Cat',
    'Ruangan yang Termasuk Paket'
  ]
};
```

---

## 6. Arsitektur Mobile Flutter

### 6.1 Model Data (`mobile/lib/models/quality_report_model.dart`)
- `ChecklistItem`: `{ String area, bool completed }`.
- `QualityReportModel`: Menyimpan seluruh field respons laporan mutu, termasuk signed URLs, catatan, timestamps, dan status *isLocked*.

### 6.2 Layanan API (`mobile/lib/services/quality_report_service.dart`)
- `Future<QualityReportModel> submitQualityReport(...)`: Mengunggah foto ke Supabase Storage (atau path simulasi), lalu memanggil `POST /api/quality-reports`.
- `Future<QualityReportModel?> fetchQualityReport(String orderId)`: Memanggil `GET /api/quality-reports/:orderId`.

### 6.3 Form Pengisian Laporan Mutu (`mobile/lib/widgets/quality_report_form_sheet.dart`)
- **Pemicu:** Tombol *"Selesaikan Pekerjaan"* pada `OperationalSimulationSheet` saat order berstatus `Sedang Dikerjakan`.
- **Komponen Form:**
  - Header: Identitas Pesanan & Petugas.
  - Template Checklist Otomatis: Checkbox interaktif untuk tiap area sesuai kategori order.
  - Slot Pemilih Foto: Dua kartu pemilih berkas (*Before* & *After*) menggunakan `image_picker` (kamera atau galeri). Menampilkan thumbnail preview dan tombol hapus/ganti.
  - Input Catatan Petugas: Opsional.
  - Tombol Kirim: Tervalidasi dinamis (hanya aktif jika kedua foto telah dipilih dan seluruh checklist area tercentang `true`).

### 6.4 Layar Peninjauan Pelanggan (`mobile/lib/screens/quality_report_screen.dart`)
- **Akses:** Muncul tombol utama *"Lihat Laporan Mutu"* pada `OrderTrackingScreen` ketika pesanan telah berstatus `Selesai`.
- **Fitur Tampilan (Dedicated Full-Screen):**
  - **Status Card:** Menampilkan badge resmi *"Laporan Mutu Terverifikasi (Read-Only Lock)"*.
  - **Before & After Visual Comparison:** Widget kartu foto dengan tab toggle *"Sebelum"* dan *"Sesudah"* (atau perbandingan berdampingan) yang memuat foto resolusi tinggi dari signed URL.
  - **Daftar Checklist Area Terverifikasi:** Daftar area dengan ikon centang hijau tebal membuktikan seluruh area telah tuntas.
  - **Kartu Akuntabilitas Waktu (Timestamps):**
    - Waktu Pekerjaan Dimulai (`started_at`).
    - Waktu Fisik Lapangan Selesai (`completed_at`).
    - Waktu Laporan Diverifikasi Server (`submitted_at`).
  - **Catatan & Informasi Petugas:** Menampilkan foto profil, nama petugas, dan catatan kebersihan.

---

## 7. Strategi Pengujian & Kriteria Kelulusan

### 7.1 Backend Test Matrix (`backend/test/quality_reports.test.js`)
1. `POST /api/quality-reports` berhasil menyimpan laporan dan memutasi status ke `Selesai` saat seluruh checklist `true` dan timestamp valid.
2. `POST /api/quality-reports` menolak pengiriman dengan status `400 Bad Request` (`CHECKLIST_AREAS_INCOMPLETE`) jika ada checklist area yang tidak tercentang atau hilang dari template.
3. `POST /api/quality-reports` menolak pengiriman dengan `400 Bad Request` (`INVALID_TIMESTAMPS`) jika `started_at > completed_at` atau `completed_at` di masa depan.
4. `POST /api/quality-reports` menolak jika status pesanan bukan `Sedang Dikerjakan` (`ORDER_NOT_IN_PROGRESS`).
5. `PATCH /api/orders/:id/status` memblokir mutasi langsung ke `Selesai` tanpa Quality Report (`QUALITY_REPORT_REQUIRED`).
6. `GET /api/quality-reports/:order_id` mengembalikan data lengkap dan signed URLs valid bagi Customer pemilik, Petugas, atau Admin.
7. `GET /api/quality-reports/:order_id` mengembalikan `403 Forbidden` jika diakses oleh user yang tidak berhak.

### 7.2 Mobile Test Matrix
1. `quality_report_model_test.dart`: Validasi serialisasi dan deserialisasi JSON.
2. `quality_report_screen_test.dart`: Memastikan layar render dengan benar tanpa error (foto, checklist, timestamp card).
3. `order_tracking_screen_test.dart`: Memastikan tombol *"Lihat Laporan Mutu"* muncul saat order berstatus `Selesai`.

---

## 8. Rencana Implementasi Bertahap

- **Langkah 1:** Backend Test Suite & Implementasi Endpoint (`backend/routes/quality-reports.js` & `backend/routes/orders.js`).
- **Langkah 2:** Verifikasi Backend Test lulus 100% (`npm test`).
- **Langkah 3:** Mobile Quality Report Model & Service (`mobile/lib/models/`, `mobile/lib/services/`).
- **Langkah 4:** Mobile Quality Report Submission Form & Simulation Sheet Integration.
- **Langkah 5:** Mobile Quality Report Viewer Screen (`QualityReportScreen`) & Order Tracking Integration.
- **Langkah 6:** Verifikasi Mobile Test lulus 100% (`flutter test`) & `flutter analyze` 0 issues.
- **Langkah 7:** Laporan Hasil, Review, & Merge ke Branch Utama.
