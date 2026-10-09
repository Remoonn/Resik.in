# Matriks Kemajuan Project: Aplikasi Resik.in
## Prototipe Layanan Jasa Kebersihan On-Demand Berbasis Mobile

**Nama Aplikasi:** Resik.in  
**Pengembang:** Agil Seno Adjie  
**Tech Stack:**  
- **Frontend Mobile:** Flutter (Dart) — Android & iOS (`mobile/`)
- **Backend API:** Node.js (Express ES Module) (`backend/`)
- **Database & Storage:** Supabase Cloud (PostgreSQL 15, Supabase Auth, Storage Buckets `quality-reports` & `cleaners`)
**Dokumen Acuan:** [PRD-Resik.in.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/PRD-Resik.in.md) & [BUSINESS-RULES.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/BUSINESS-RULES.md)

---

## 📊 Ringkasan Status Keseluruhan

| Modul / Komponen | Status | Persentase | Tanggal Penyelesaian |
| :--- | :---: | :---: | :---: |
| **0. Fondasi, Arsitektur & Skema Basis Data** | Selesai | 100% | 25 September 2026 |
| **1. Autentikasi, Profil & Otorisasi RBAC** | Selesai | 100% | 28 September 2026 |
| **2. Katalog Layanan & Smart Matching Engine** | Selesai | 100% | 27 September 2026 |
| **3. Siklus Pesanan 7 Status & Anti-Double Booking** | Selesai | 100% | 28 September 2026 |
| **4. Akuntabilitas Mutu (Digital Quality Report Gate)** | Selesai | 100% | 29 September 2026 |
| **5. Sistem Rating & Ulasan Pelanggan Terverifikasi** | Selesai | 100% | 30 September 2026 |
| **6. Integrasi Cloud BaaS (Supabase PostgreSQL & Storage)**| Selesai | 100% | 1 Oktober 2026 |
| **7. Dasbor Multi-Peran (Customer, Cleaner, Admin)** | Selesai | 100% | 10 Oktober 2026 |
| **8. Pengujian Sistem (Unit, Integration & Widget Test)** | Selesai | 100% | 10 Oktober 2026 |

---

## 🛠️ Rincian Status Fitur per Modul

### 0. Fondasi, Arsitektur & Skema Basis Data (100% Selesai)
- [x] Inisialisasi struktur repositori modular: `mobile/`, `backend/`, `database/`, `docs/`.
- [x] Skrip DDL PostgreSQL di [database/schema.sql](file:///c:/Users/62859/Documents/Skripsi/Resik.in/database/schema.sql):
  - [x] Tabel `users`: Identitas akun (`id`, `email`, `role`, `nama`, `no_hp`).
  - [x] Tabel `cleaners`: Profil petugas (`rating`, `total_reviews`, `completed_tasks`, `skills`, `is_active`).
  - [x] Tabel `orders`: Transaksi pesanan (`customer_id`, `cleaner_id`, `service_category`, `status`, `status_pembayaran`, `start_time`, `duration`).
  - [x] Tabel `order_status_logs`: Jejak audit transisi 7 tahapan status pesanan.
  - [x] Tabel `quality_reports`: Laporan mutu digital (`order_id`, `checklist_verified`, `before_photos`, `after_photos`, `durasi_menit`).
  - [x] Tabel `reviews`: Ulasan dan rating pelanggan terverifikasi (`order_id`, `rating`, `review_text`).
- [x] Dokumentasi arsitektur sistem di [docs/ARCHITECTURE.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/ARCHITECTURE.md) dan kamus data di [docs/DATA-DICTIONARY.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/DATA-DICTIONARY.md).

### 1. Autentikasi, Profil & Otorisasi RBAC (100% Selesai)
- [x] Registrasi dan Login akun pelanggan via Google Sign-In terintegrasi dengan Supabase Auth.
- [x] Login akun internal Petugas dan Admin menggunakan `signInWithPassword`.
- [x] Penegakan isolasi rute antarmuka berbasis peran (`AuthGate` deklaratif):
  - [x] Role `customer` diarahkan ke Dasbor Pelanggan & Katalog Pemesanan.
  - [x] Role `cleaner` diarahkan ke `CleanerDashboardScreen`.
  - [x] Role `admin` diarahkan ke `AdminDashboardScreen`.
- [x] Otorisasi server-side: Pencegahan akses silang data pesanan pada endpoint `GET /api/orders`.

### 2. Katalog Layanan & Smart Matching Engine (100% Selesai)
- [x] Katalog pemesanan 4 jenis properti: Pembersihan Rumah, Kos, Kantor, Pasca Renovasi (`BookingScreen`).
- [x] Perhitungan estimasi durasi dan formula harga flat deterministik (`Rp 50.000 / jam` flat).
- [x] Mesin pencocokan petugas cerdas (*Smart Matching Engine* di `backend/lib/matching.js`):
  - [x] *Hard Filter:* Validasi kesesuaian kategori layanan dan jadwal bebas bentrok.
  - [x] *Scoring Formula:* Pembobotan skor keahlian, rating kepuasan, dan total tugas selesai.
  - [x] *Provisional Rating:* Petugas baru tanpa ulasan diberi rating awal adil sebesar 4.5.
- [x] Profil detail petugas kebersihan (`CleanerDetailScreen`): Portofolio keahlian, rating bintang, jumlah pesanan sukses, dan riwayat ulasan pelanggan.

### 3. Siklus Pesanan 7 Status & Anti-Double Booking (100% Selesai)
- [x] 7 Tahapan Siklus Status Pesanan:
  1. `Menunggu Konfirmasi` (Setelah checkout berhasil dibuat).
  2. `Dikonfirmasi` (Admin memverifikasi pesanan setelah status pembayaran `Sudah Bayar`).
  3. `Menuju Lokasi` (Petugas dalam perjalanan menuju lokasi pelanggan).
  4. `Tiba di Lokasi` (Petugas sampai di properti pelanggan).
  5. `Sedang Dikerjakan` (Pengerjaan pembersihan berlangsung).
  6. `Menunggu Review` (Petugas berhasil mengirimkan laporan mutu pekerjaan).
  7. `Selesai` (Pelanggan meninjau laporan mutu / memberikan rating).
- [x] Validasi pencegahan jadwal bentrok (*Anti-Double Booking*):
  - Memperhitungkan `start_time`, `duration`, dan buffer operasional 30 menit.
- [x] Antarmuka Pelacakan Pesanan: Stepper progres 7 tahapan dinamis pada `OrderTrackingScreen`.

### 4. Akuntabilitas Mutu: Digital Quality Report Gate (100% Selesai)
- [x] Template checklist verifikasi dinamis per kategori layanan di `backend/lib/checklist-templates.js`.
- [x] Endpoint pengiriman laporan mutu `POST /api/quality-reports` dengan validasi 9 tahap.
- [x] Penegakan *Mandatory Gate Lockout:* Status pesanan tidak dapat diubah menjadi `Selesai` tanpa adanya laporan mutu yang tervalidasi lengkap.
- [x] Lembar pengisian laporan mutu mobile (`QualityReportFormSheet`):
  - [x] Checklist interaktif seluruh area kerja yang wajib dicentang petugas.
  - [x] Pengambilan foto Before dan After langsung dari kamera/galeri via `image_picker`.
  - [x] Catatan hasil pengerjaan dari petugas.
- [x] Layar peninjauan laporan mutu bagi pelanggan (`QualityReportScreen`): Komparasi visual foto Before & After serta transparansi rincian durasi kerja.

### 5. Sistem Rating & Ulasan Pelanggan Terverifikasi (100% Selesai)
- [x] Endpoint pengiriman review `POST /api/orders/:id/reviews` dengan 5 tahap validasi integritas.
- [x] Pencegahan review palsu: Hanya pelanggan yang memiliki pesanan tuntas (`Selesai`) yang berhak memberikan ulasan.
- [x] Lembar ulasan interaktif `ReviewBottomSheet` dengan bintang dinamis (skala 1–5) dan label emosional responsif.
- [x] Sinkronisasi reputasi otomatis: Rating rata-rata dan total ulasan petugas dihitung ulang secara real-time pada tabel `cleaners`.

### 6. Integrasi Cloud BaaS (Supabase Live & Dual-Mode) (100% Selesai)
- [x] Arsitektur dual-mode backend (`IN_MEMORY` untuk automated tests, `SUPABASE_CLOUD` untuk server live).
- [x] Modul pemetaan data dua arah (`backend/lib/mapper.js`) untuk keselarasan skema database snake_case dan respons camelCase.
- [x] Modul sanitasi UUID (`backend/lib/uuid-sanitizer.js`) untuk menjamin kepatuhan tipe data `UUID` PostgreSQL.
- [x] Supabase Storage: Penyimpanan berkas foto Before/After pada bucket privat `quality-reports` dengan keamanan generasi signed URL bertenggang waktu.

### 7. Dasbor Multi-Peran Terintegrasi (100% Selesai)
- [x] **Dasbor Pelanggan:** Menampilkan riwayat pesanan, banner status aktif, dan akses cepat pemesanan ulang.
- [x] **Dasbor Petugas (`CleanerDashboardScreen`):** Menampilkan tugas aktif, kartu rincian alamat/jadwal, dan tombol aksi transisi status lapangan.
- [x] **Dasbor Admin (`AdminDashboardScreen`):**
  - [x] Pipeline counter bar terorganisir dengan chip interaktif (*🟡 Konfirmasi*, *🔵 Perlu Petugas*, *🟢 Berjalan*, *⚪ Tuntas*, *🔴 Batal*).
  - [x] Lembar penugasan cerdas (`SmartAssignmentSheet`) dengan rekomendasi kecocokan petugas dan peringatan konflik jadwal.
  - [x] Jalur Cepat Penugasan 1-Klik untuk petugas pilihan preferensi pelanggan.
  - [x] Gerbang pembayaran (*Payment Guard*): Tombol konfirmasi terkunci jika `status_pembayaran != 'Sudah Bayar'`.
  - [x] Manajemen status operasional petugas (`Aktif`, `Cuti`, `Nonaktif`) dengan dialog konfirmasi & validasi backend pencegahan bentrok pekerjaan aktif.
  - [x] Registrasi petugas baru dengan foto profil (upload Supabase Storage) dan pembuatan akun Supabase Auth + Profiles otomatis.
  - [x] Tab Monitoring tersegmentasi (*Sedang Berjalan*, *Tuntas / Selesai*, *Dibatalkan*) dengan inspeksi Laporan Mutu Digital (*Quality Report Screen*).
- [x] Pembersihan total seluruh elemen dummy/simulasi untuk memastikan sistem beroperasi secara riil.

### 8. Pengujian Sistem & Verifikasi Kualitas (100% Selesai)
- [x] **Backend Test Suite (`npm test`):**
  - [x] `test/cleaners.test.js` & `test/matching.test.js`: Algoritma Smart Matching & validasi filter.
  - [x] `test/orders.test.js` & `test/orders_lifecycle.test.js`: Siklus 7 status & anti-double booking.
  - [x] `test/quality-reports.test.js`: Validasi 9 tahap laporan mutu & gate lockout status Selesai.
  - [x] `test/reviews.test.js`: Validasi review & agregasi reputasi.
  - [x] `test/cleaner_status.test.js`: Validasi siklus status operasional petugas & pencegahan mutasi saat bertugas.
  - [x] `test/cleaner_create.test.js`: Validasi pendaftaran petugas baru & otomasi akun Auth.
  - [x] `test/database.test.js` & `test/supabase_client.test.js`: Arsitektur dual-mode & integrasi Supabase.
  - Status: **99/99 tests PASS (100% Lulus di 19 Test Suites)**.
- [x] **Mobile Flutter Test Suite (`flutter test`):**
  - [x] Analisis statis Dart: `flutter analyze` menghasilkan **0 issues found**.
  - [x] Unit test model: `cleaner_model_test.dart`, `order_model_test.dart`, `quality_report_model_test.dart`, `review_model_test.dart`.
  - [x] Widget test antarmuka & otorisasi: `auth_gate_role_test.dart`, `admin_dashboard_screen_test.dart`, `admin_cleaner_status_test.dart`, `admin_cleaner_create_test.dart`, `admin_quality_report_test.dart`, `cleaner_dashboard_screen_test.dart`, `quality_report_screen_test.dart`.
  - Status: **65/65 tests PASS (100% Lulus)**.
