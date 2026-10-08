# Logbook Harian Kemajuan Project & Skripsi
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

**Nama Mahasiswa:** Agil Seno Adjie  
**Program Studi:** Informatika / FTI UII  
**Repositori:** `Resik.in`  

Dokumen ini mencatat secara kronologis seluruh capaian nyata (*deliverables*) harian terhitung sejak hari pertama proyek diinisiasi (25 September 2026) hingga tahap pengujian akhir. Setiap entri memuat bukti fisik kode, skrip basis data, hasil pengujian, dan penambahan naskah skripsi.

---

## 📅 Jumat, 25 September 2026 (Inisialisasi Proyek, PRD v1.2 & Fondasi Basis Data)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Penyusunan dokumen Source of Truth mutlak: **Product Requirements Document (PRD v1.2)** ([docs/PRD-Resik.in.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/PRD-Resik.in.md)) yang menetapkan 3 pilar operasional: *Smart Matching*, *Sequential Status Tracking (7 Tahapan)*, dan *Quality Report Gate*.
  * Penyusunan aturan bisnis dan validasi operasional ([docs/BUSINESS-RULES.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/BUSINESS-RULES.md)), kamus data lengkap ([docs/DATA-DICTIONARY.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/DATA-DICTIONARY.md)), serta kontrak REST API ([docs/API.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/API.md)).
  * Perancangan skema relasional PostgreSQL Supabase di [database/schema.sql](file:///c:/Users/62859/Documents/Skripsi/Resik.in/database/schema.sql) untuk tabel utama: `users`, `cleaners`, `orders`, `order_status_logs`, `reviews`, dan `quality_reports`.
* **Bukti/Artefak:**
  * Dokumen resmi: `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/DATA-DICTIONARY.md`.
  * Skrip DDL: `database/schema.sql`.
  * Commit GitHub: `c9249e6 - feat: initial setup with PRD, architecture guidelines, and Supabase schema`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penyusunan Bab 1 (Pendahuluan): Perumusan 5 masalah mendasar pemesanan manual jasa kebersihan (ketidakpastian progres, ketiadaan bukti hasil kerja, risiko jadwal bentrok, ketiadaan transparansi keahlian petugas).
  * Pemetaan Kebutuhan Fungsional (FR) dan Non-Fungsional (NFR) untuk persiapan Bab 3.
* **Bukti/Artefak:**
  * Draf Bab 1 & Matriks Kebutuhan Sistem.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Membangun mesin pencocokan petugas cerdas (*Smart Matching Engine*) di backend Node.js dan layar pemesanan Flutter.
* **Skripsi:** Penulisan Bab 3 Subbab 3.2 (Analisis Kebutuhan) dan Subbab 3.3 (Perancangan Algoritma Smart Matching).

---

## 📅 Minggu, 27 September 2026 (Smart Matching Engine & Katalog Pemesanan Mobile)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Implementasi *Deterministic Smart Matching Engine* pada backend Node.js (`backend/lib/matching.js`):
    * Hard filter: kesesuaian kategori layanan (`skills`), ketersediaan jadwal waktu, dan status aktif.
    * Formula scoring deterministik: pembobotan rating kepuasan (dengan rating provisional 4.5 bagi petugas baru), riwayat penyelesaian tugas, dan kedekatan lokasi.
  * Pembuatan rute REST API cleaners dan endpoint rekomendasi: `GET /api/cleaners` dan `POST /api/cleaners/recommendations`.
  * Pengembangan antarmuka Flutter:
    * `CleanerModel` dan integrasi API client.
    * `CleanerDetailScreen`: Layar profil detail petugas sesuai standar visual modern (foto, rating, jumlah tugas selesai, spesialisasi, dan ulasan).
    * `BookingScreen`: Integrasi kartu rekomendasi petugas pintar berbasis skor kecocokan tertinggi.
* **Bukti/Artefak:**
  * Backend: `backend/routes/cleaners.js`, `backend/lib/matching.js`, unit test matching.
  * Mobile: `mobile/lib/screens/cleaner_detail_screen.dart`, `mobile/lib/screens/booking_screen.dart`, `mobile/lib/models/cleaner_model.dart`.
  * Commit GitHub: `27 September 2026 (Multiple commits: matching engine, routes, detail screen, booking integration)`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 3 Subbab 3.3: Perumusan formula matematis *Smart Matching Engine* dan aturan *provisional rating*.
  * Pembuatan Activity Diagram untuk alur penentuan rekomendasi petugas.
* **Bukti/Artefak:**
  * Dokumentasi formula pembobotan dan diagram alir algoritma pencocokan.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Integrasi modul otentikasi pengguna (Supabase Auth & Google OAuth) dan siklus 7 status pesanan (*Sprint 3*).
* **Skripsi:** Perancangan State Machine Diagram untuk 7 siklus status pesanan di Bab 3.

---

## 📅 Senin, 28 September 2026 (Autentikasi Supabase & Sprint 3: 7 Siklus Status Pesanan)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Modul Autentikasi Pengguna:
    * Backend: API otentikasi login dan register (`backend/routes/auth.js`).
    * Mobile: `AuthService`, `UserModel`, penegakan `AuthGate`, serta integrasi Google Sign-In dengan Supabase Auth.
    * UI Mobile: Halaman `WelcomeScreen`, `LoginScreen`, dan `RegisterScreen`.
  * Sprint 3 (Siklus Pesanan & Pelacakan Progres):
    * Backend: Progresi sekuensial 7 tahapan status pesanan (`Menunggu Konfirmasi` $\rightarrow$ `Dikonfirmasi` $\rightarrow$ `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan` $\rightarrow$ `Menunggu Review` $\rightarrow$ `Selesai`).
    * Validasi pencegahan jadwal bentrok (*Anti-Double Booking*) dengan perhitungan buffer operasional 30 menit.
    * Mobile: `OrderTrackingScreen` dengan representasi stepper visual 7 tahapan interaktif.
* **Bukti/Artefak:**
  * Dokumen Sprint: `docs/superpowers/specs/2026-09-28-sprint-3-order-lifecycle-tracking.md`.
  * Kode Backend: `backend/routes/orders.js`, `backend/lib/database.js`.
  * Kode Mobile: `mobile/lib/screens/order_tracking_screen.dart`, `mobile/lib/screens/auth/`.
  * Commit GitHub: `28 September 2026 (auth integration, order lifecycle specs & progression, tracking stepper)`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 3 Subbab 3.4 (Diagram UML): Pembuatan Use Case Diagram (Aktor: Pelanggan, Petugas, Admin) dan State Machine Diagram untuk siklus 7 status pesanan.
* **Bukti/Artefak:**
  * Diagram Use Case dan State Machine tersimpan di naskah Bab 3.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Sprint 4 (Implementasi Quality Report Gate: checklist interaktif, unggah foto Before/After, penguncian status Selesai).
* **Skripsi:** Penulisan Bab 3 Subbab Perancangan Basis Data tabel `quality_reports` dan aturan integritas penyelesaian kerja.

---

## 📅 Selasa, 29 September 2026 (Sprint 4: Laporan Mutu Digital & Quality Report Gate)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Backend Quality Report:
    * Template checklist dinamis per kategori layanan (Pembersihan Rumah, Kos, Kantor, Pasca Renovasi) di `backend/lib/checklist-templates.js`.
    * Endpoint `POST /api/quality-reports` dengan pipa validasi ketat 9 tahap (verifikasi pesanan, hak kepemilikan petugas, kelengkapan foto Before & After, verifikasi seluruh item checklist, serta pencatatan timestamp presisi).
    * Endpoint `GET /api/quality-reports/:order_id` dilengkapi otorisasi RBAC dan generasi signed URL Supabase Storage.
    * **Mandatory Gate Lockout:** Memblokir transisi status pesanan ke `Selesai` apabila laporan mutu belum disubmit dan diverifikasi.
  * Mobile Quality Report:
    * Penambahan dependensi `image_picker` dan kompresi foto kamera.
    * Pembuatan `QualityReportFormSheet` untuk petugas mengisi checklist dinamis dan mengambil foto Before & After.
    * Pembuatan `QualityReportScreen` bagi pelanggan untuk meninjau bukti dokumentasi mutu pekerjaan secara transparan.
* **Bukti/Artefak:**
  * Dokumen Sprint: `docs/superpowers/specs/2026-09-29-sprint-4-quality-report.md`.
  * Kode: `backend/routes/quality-reports.js`, `mobile/lib/screens/quality_report_screen.dart`, `mobile/lib/widgets/quality_report_form_sheet.dart`.
  * Pengujian: Unit test `quality_reports.test.js` dan model test Flutter.
  * Commit GitHub: `29 September 2026 (checklist templates, 9-stage validation, signed URLs, quality report viewer & form sheet)`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 3 Subbab 3.5: Perancangan subsistem akuntabilitas mutu digital (*Quality Report Gate Architecture*) dan skema penyimpanan berkas berbasis Private Bucket.
* **Bukti/Artefak:**
  * Diagram alur validasi pelaporan mutu dan komparasi foto Before/After.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Fase 2 (Sistem Rating & Ulasan Pelanggan Terverifikasi serta agregasi reputasi petugas).
* **Skripsi:** Penulisan Bab 3 Subbab Perancangan Antarmuka Pengguna ulasan bintang dan umpan balik pelanggan.

---

## 📅 Rabu, 30 September 2026 (Fase 2: Rating & Ulasan Pelanggan Terverifikasi)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Spesifikasi & Rencana Desain Fase 2: Dokumen perancangan modul rating dan review pelanggan ([docs/superpowers/specs/2026-09-30-phase-2-customer-review-design.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-09-30-phase-2-customer-review-design.md)).
  * Backend Rating & Review:
    * Endpoint `POST /api/orders/:id/reviews` dengan validasi 5 tahap (hanya pesanan berstatus Selesai, hanya pelanggan pemesan, proteksi review duplikat, batas skor 1–5, dan panjang ulasan).
    * Algoritma agregasi otomatis reputasi petugas (`rating` rata-rata dan `total_reviews`) di tabel `cleaners`.
  * Mobile Flutter:
    * `ReviewModel`, `ReviewService`, dan widget interaktif `ReviewBottomSheet` dengan bintang dinamis dan label emosional (Kecewa, Kurang, Cukup, Bagus, Luar Biasa!).
    * Integrasi lembar ulasan pada `OrderTrackingScreen` dan `QualityReportScreen`.
    * Penampilan daftar ulasan terverifikasi dan reputasi dinamis pada `CleanerDetailScreen`.
* **Bukti/Artefak:**
  * Dokumen: `docs/superpowers/specs/2026-09-30-phase-2-customer-review-design.md`.
  * Kode: `backend/routes/reviews.js`, `mobile/lib/widgets/review_bottom_sheet.dart`, `mobile/lib/services/review_service.dart`.
  * Commit GitHub: `30 September 2026 (review store, 5-stage validation, ReviewBottomSheet, verified reviews on profile)`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 3 Subbab 3.6: Pemodelan Sequence Diagram untuk alur pengiriman review dan pembaruan reputasi agregat petugas.
* **Bukti/Artefak:**
  * Sequence Diagram alur verifikasi review dan kalkulasi rating rata-rata.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Integrasi penuh ke Supabase Cloud (PostgreSQL Live, Auth JWT, dan Supabase Storage Bucket).
* **Skripsi:** Penulisan Bab 4 Subbab 4.1 (Lingkungan Implementasi) dan 4.2 (Implementasi Basis Data Cloud).

---

## 📅 Kamis, 1 Oktober 2026 (Integrasi Supabase Cloud & Sanitasi Data)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Dokumen Desain & Rencana Migrasi Supabase Cloud ([docs/superpowers/specs/2026-10-01-supabase-cloud-integration.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/superpowers/specs/2026-10-01-supabase-cloud-integration.md)).
  * Arsitektur Dual-Mode Backend:
    * Dukungan transparan antara memori lokal (pengujian otomatis terisolasi) dan Supabase Cloud PostgreSQL riil.
    * Pembuatan modul data mapper dua arah (`backend/lib/mapper.js`) dan modul sanitasi UUID (`backend/lib/uuid-sanitizer.js`).
    * Implementasi repositori database: `cleaners-repo.js`, `orders-repo.js`, `quality-reports-repo.js`, dan `reviews-repo.js`.
    * Integrasi upload foto biner langsung ke Supabase Storage Bucket `quality-reports` dengan pembuatan Signed URL privat.
* **Bukti/Artefak:**
  * Dokumen: `docs/superpowers/specs/2026-10-01-supabase-cloud-integration.md`.
  * Backend: `backend/lib/database.js`, `backend/lib/mapper.js`, `backend/lib/supabase-client.js`.
  * Pengujian: 32/32 test backend lulus (`npm test`).
  * Commit GitHub: `01 October 2026 (supabaseAdmin, bi-directional mapper, repository migrations, signed URLs)`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 4 Subbab 4.2: Dokumentasi arsitektur integrasi Cloud BaaS (Supabase), konfigurasi Row Level Security (RLS), dan mekanisme keamanan Private Bucket Storage.
* **Bukti/Artefak:**
  * Tabel kamus data fisik live dan dokumentasi policy RLS Supabase.

### 3. Komitmen Output Selanjutnya:
* **Project:** Implementasi Multi-Role Dashboard (Admin & Cleaner) pada aplikasi mobile Flutter dan pembersihan lembar simulasi dummy.
* **Skripsi:** Penulisan Bab 4 Subbab 4.3 (Implementasi Antarmuka Multi-Peran).

---

## 📅 Minggu, 4 Oktober – Senin, 5 Oktober 2026 (Multi-Role Dashboards & Keamanan RBAC)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Penghapusan Lembar Simulasi Dummy (`SimulationSheet`): Mengganti tombol simulasi demo dengan alur operasional lapangan yang nyata.
  * Dasbor Petugas Kebersihan (`CleanerDashboardScreen`):
    * Menampilkan tugas aktif yang ditugaskan ke petugas terkait.
    * Tombol aksi progresi status lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Mulai Bekerja`, `Kirim Laporan Mutu`).
  * Dasbor Admin (`AdminDashboardScreen`):
    * Pipeline counter interaktif (Semua, Menunggu Konfirmasi, Dikonfirmasi, Sedang Berjalan, Selesai, Dibatalkan).
    * Gerbang validasi pembayaran (Admin dilarang mengonfirmasi pesanan sebelum status pembayaran `Sudah Bayar`).
    * Lembar penugasan cerdas (`SmartAssignmentSheet`) lengkap dengan skor kecocokan rekomendasi dan lencana peringatan jadwal bentrok (*conflict badge*).
  * Pemisahan Peran Deklaratif: `AuthGate` mengarahkan pengguna secara otomatis ke dasbor yang sesuai (`customer`, `cleaner`, `admin`).
  * Integrasi Supabase Auth `signInWithPassword` untuk login akun internal Admin dan Petugas.
* **Bukti/Artefak:**
  * Dokumen: `docs/superpowers/specs/2026-10-04-multi-role-dashboard-simulation-removal-design.md`.
  * Kode Mobile: `CleanerDashboardScreen`, `AdminDashboardScreen`, `SmartAssignmentSheet`, `AuthGate`.
  * Commit GitHub: `04-05 October 2026 (CleanerDashboard, SmartAssignmentSheet, AdminDashboard, AuthGate declarative routing, Supabase admin login)`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 4 Subbab 4.3: Dokumentasi antarmuka Dasbor Pelanggan, Dasbor Petugas, dan Dasbor Admin.
  * Dokumentasi tabel matriks hak akses Role-Based Access Control (RBAC) pada sistem.
* **Bukti/Artefak:**
  * Tangkapan layar antarmuka ketiga peran pengguna dan tabel pengujian RBAC.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Stabilisasi akhir sistem, perbaikan bug layout, dan verifikasi test suite penuh sebelum pengujian dosen.
* **Skripsi:** Penulisan Bab 4 Subbab 4.4 (Pengujian Black-Box Testing & Ketercapaian Hasil).

---

## 📅 Rabu, 7 Oktober 2026 (Bug Fixes, Stabilisasi Sistem & Pembersihan Role Switcher Demo)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * Perbaikan Bug Kritis Admin Dashboard: Memperbaiki filter query `fetchOrders` di backend agar Admin dapat membaca seluruh pesanan dari semua pelanggan tanpa terpotong filter ID pengguna admin.
  * Perbaikan Antarmuka Pengguna: Menghilangkan error visual `TabBar overflowed by 2.0 pixels` pada dasbor admin serta membersihkan tombol demonstrasi switch-role manual demi kepatuhan RBAC murni.
  * Verifikasi Test Suite: Seluruh pengujian backend dan mobile lulus 100%.
  * Pembentukan sistem pelacakan dokumen skripsi di folder `laporan-skripsi-resikin/`.
* **Bukti/Artefak:**
  * Kode: `backend/routes/orders.js`, `mobile/lib/screens/admin_dashboard_screen.dart`, `mobile/lib/main.dart`.
  * Commit GitHub: `826358b - fix(ui): eliminate TabBar overflow and remove demonstration role switcher buttons`.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 4 Subbab 4.4: Dokumentasi skenario pengujian fungsional sistem menggunakan metode Black-Box Testing (mencakup 8 skenario pengujian utama sesuai PRD).
* **Bukti/Artefak:**
  * Tabel matriks pengujian Black-Box di naskah Bab 4.

### 3. Komitmen Output Hari Berikutnya:
* **Project:** Pengujian alur penugasan petugas pada skenario nyata menggunakan akun pelanggan riil dan akun admin.
* **Skripsi:** Penulisan Bab 5 (Kesimpulan & Saran) dan finalisasi draf lengkap.

---

## 📅 Kamis, 8 Oktober 2026 (Jalur Cepat 1-Klik Penugasan Preferensi Pelanggan & Pinning Smart Matching)

### 1. Kemajuan Project (Resik.in)
* **Capaian:**
  * **Jalur Cepat Penugasan Pilihan Pelanggan (Direct 1-Click Assignment - SOT BR-ASN-002):**
    * Mengatasi kendala alur penugasan di mana Admin sebelumnya harus memilih ulang petugas secara manual pada modal sheet meskipun pelanggan sudah memilih petugas tertentu saat pemesanan (Smart Matching).
    * Kartu Pesanan Dasbor Admin (`AdminDashboardScreen`):
      * Menampilkan badge informasi visual: `⭐ Pilihan Pelanggan: [Nama Petugas]` (jika ada preferensi) atau `Alokasi Petugas: Pilih Otomatis oleh Admin`.
      * Menyediakan tombol aksi utama 1-klik: `[ Tugaskan [Nama Petugas] (Pilihan Pelanggan) ]` yang langsung menetapkan petugas dan memperbarui status pesanan tanpa perlu membuka lembar seleksi manual.
      * Menyediakan tombol sekunder: `[ Ganti / Pilih Petugas Lain ]` jika admin memerlukan penyesuaian operasional.
    * Lembar Penugasan Petugas Cerdas (`SmartAssignmentSheet`):
      * Menyematkan petugas pilihan pelanggan (*Pinning to Top*) ke posisi paling atas (indeks 0) terlepas dari skor match matematis.
      * Menampilkan banner khusus preferensi pelanggan dan tombol aksi khusus `Tugaskan Pilihan Pelanggan`.
  * **Verifikasi & Pengujian Otomatis:**
    * Penambahan unit & widget test untuk memverifikasi lencana preferensi dan tombol penugasan 1-klik di `admin_dashboard_screen_test.dart` dan `smart_assignment_sheet_test.dart`.
    * Analisis Dart: `flutter analyze` $\rightarrow$ **No issues found!**
    * Mobile Test Suite: `flutter test` $\rightarrow$ **59/59 tests PASS (100% Lulus)**.
    * Backend Test Suite: `npm test` $\rightarrow$ **86/86 tests PASS (100% Lulus)**.
* **Bukti/Artefak:**
  * Mobile: `mobile/lib/screens/admin_dashboard_screen.dart`, `mobile/lib/widgets/smart_assignment_sheet.dart`, `mobile/test/admin_dashboard_screen_test.dart`, `mobile/test/smart_assignment_sheet_test.dart`.
  * Hasil Eksekusi Uji: 59 mobile tests pass & 86 backend tests pass.

### 2. Kemajuan Naskah Skripsi
* **Capaian:**
  * Penulisan Bab 4 Subbab 4.3 (Evaluasi Alur Hibrida Penugasan Petugas): Mendokumentasikan mekanisme keseimbangan antara preferensi pelanggan hasil Smart Matching dan hak verifikasi akhir Admin.
  * Penulisan Bab 5 (Kesimpulan & Saran): Merumuskan kesimpulan efektivitas kombinasi otomasi algoritma dan keputusan admin dalam operasional jasa kebersihan.
* **Bukti/Artefak:**
  * Naskah Bab 4 & Bab 5 terbarui.

### 3. Komitmen Output Selanjutnya:
* Persiapan demonstrasi prototipe aplikasi dan penyerahan naskah lengkap Bab 1–5 kepada Dosen Pembimbing untuk agenda pra-sidang / seminar hasil skripsi.

