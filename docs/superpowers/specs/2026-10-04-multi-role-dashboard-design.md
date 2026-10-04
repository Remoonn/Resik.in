# Spesifikasi Desain: Multi-Role Dedicated Dashboards (Admin, Cleaner, Customer) & Penghapusan Simulasi Operasional

> **Dokumen:** `docs/superpowers/specs/2026-10-04-multi-role-dashboard-design.md`  
> **Status:** Approved Architecture Specification (Senior Software Engineer Hardened)  
> **Tanggal:** 04 Oktober 2026  
> **Target Rilis:** Sprint 6 — Production-Grade Multi-Role Architecture  
> **Referensi SOT:** `docs/PRD-Resik.in.md`, `docs/ARCHITECTURE.md`, `docs/BUSINESS-RULES.md`, `docs/API.md`, `docs/SECURITY.md`, `database/schema.sql`

---

## 1. Latar Belakang, Problem Statement, & Urgensi

### 1.1 Kondisi Saat Ini (Current State)
Pada Milestone V1 dan V1.1 (Sprint 0 s.d. Sprint 5), seluruh logika backend REST API dan aturan bisnis mutlak telah selesai diimplementasikan secara *server-authoritative* dan terhubung langsung ke **Supabase Cloud (PostgreSQL & Storage)**:
- **Backend REST API**: Endpoint konfirmasi admin (`PATCH /api/orders/:id/status`), penugasan petugas (`POST /api/orders/:id/assign`), pembaruan status lapangan sekuensial (`PATCH /api/orders/:id/status`), dan pengiriman pelaporan mutu digital (`POST /api/quality-reports`) sudah berstatus *real API* dan dilindungi aturan RBAC serta validasi status.
- **Frontend Mobile (Flutter)**: Gerbang navigasi (`AuthGate`) saat ini masih mengarahkan semua pengguna ke layar beranda Pelanggan (`HomeScreen`). Untuk memfasilitasi pengujian alur 7 tahapan siklus hidup pesanan, sebuah lembar bantuan sementara bernama **"Simulasi Operasional"** (`OperationalSimulationSheet`) disematkan mengambang di layar pelacakan pesanan pelanggan (`OrderTrackingScreen`).

### 1.2 Masalah yang Dipecahkan (Problem Statement)
1. **Ketidaksesuaian Pengalaman Pengguna (UX Inconsistency)**: Pelanggan tidak seharusnya memiliki wewenang atau tombol di antarmukanya untuk mengonfirmasi pesanan sendiri, memilih petugas sendiri secara bebas, atau mengubah status fisik lapangan menjadi "Tiba di Lokasi" dan mengirim foto mutu pengerjaan.
2. **Kebutuhan Bobot Pembahasan Skripsi (Production-Grade Architecture)**: Pada sidang skripsi rekayasa perangkat lunak, sistem aplikasi *on-demand* dinilai jauh lebih matang dan memenuhi standar industri (*production-ready*) apabila memiliki pembagian antarmuka berbasis peran (*Role-Based UI*) yang terpisah dan mencerminkan interaksi nyata antara 3 aktor utama:
   - **Pelanggan (Customer)**: Memesan, membayar, melacak status real-time, melihat laporan mutu, dan memberi ulasan.
   - **Petugas Lapangan (Cleaner)**: Menerima penugasan, navigasi ke lokasi hunian, memperbarui status kedatangan/pengerjaan, dan mengunggah bukti mutu (*Quality Report*).
   - **Administrator (Admin)**: Menara pengawas operasional (*Control Tower*), konfirmasi pesanan lunas, penugasan cerdas (*Smart Matching*) anti-double booking, *reassignment* ber-alasan audit, dan pembatalan darurat.

### 1.3 Tujuan Desain (Design Objectives)
1. **Declarative Role-Based Routing**: Mengarahkan pengguna secara otomatis ke dasbor yang sesuai dengan perannya (`customer`, `cleaner`, atau `admin`) saat membuka aplikasi atau berhasil login.
2. **Cleaner Dedicated Dashboard**: Menyediakan antarmuka lapangan ergonomis bagi petugas kebersihan untuk melihat tugas aktif hari ini, memicu transisi status fisik lapangan, dan mengisi dokumen *Quality Report* (foto Before/After & checklist verifikasi).
3. **Admin Operational Control Tower**: Menyediakan antarmuka monitoring komprehensif bagi admin untuk memverifikasi pesanan lunas, menugaskan petugas secara cerdas (*Smart Matching*) bebas bentrok jadwal, melakukan *reassignment* ber-audit, dan pembatalan darurat.
4. **Pembersihan Antarmuka Pelanggan**: Menghapus seluruh tombol simulasi dari antarmuka pelanggan sehingga pelanggan murni menerima pembaruan status nyata (*real-time/short-polling*) dan mengisi ulasan pasca-selesai.
5. **Fleksibilitas Pengujian Sidang Skripsi**: Menyediakan mekanisme *Role Switcher* terisolasi berlabel demo di tab Akun agar penguji dapat mengevaluasi 3 peran berbeda dengan mudah pada satu perangkat ponsel.

---

## 2. Arsitektur Peran & Navigasi Sistem (`AuthGate`) — Penyempurnaan Bagian 1

### 2.1 Alur Deteksi Peran & Pemetaan Identitas (*Identity Linking*)
Sesuai rancangan basis data Supabase:
- Tabel `public.profiles` menyimpan atribut `role VARCHAR(20)` (`'customer'`, `'cleaner'`, `'admin'`).
- Tabel `public.cleaners` menyimpan data profil operasional petugas lapangan dan memiliki relasi opsional `user_id UUID REFERENCES public.profiles(id)`.

```mermaid
graph TD
    User([Pengguna Login]) --> AuthGate{AuthGate: Cek user.role}
    AuthGate -->|role == 'admin'| AdminDash[AdminDashboardScreen]
    AuthGate -->|role == 'cleaner'| CleanerDash[CleanerDashboardScreen]
    AuthGate -->|role == 'customer'| CustHome[Customer HomeScreen]
    
    subgraph AdminActions["Aksi Admin"]
        AdminDash --> Conf[Konfirmasi Pesanan]
        AdminDash --> Assign[Tugaskan Petugas]
        AdminDash --> Reassign[Reassign Petugas]
        AdminDash --> Cancel[Emergency Cancel]
    end
    
    subgraph CleanerActions["Aksi Petugas"]
        CleanerDash --> OTW[Menuju Lokasi]
        CleanerDash --> Arrived[Tiba di Lokasi]
        CleanerDash --> Work[Mulai Pengerjaan]
        CleanerDash --> QR[Unggah Quality Report]
    end
    
    subgraph CustomerActions["Aksi Pelanggan"]
        CustHome --> Book[Pemesanan Layanan]
        CustHome --> Pay[Simulasi Bayar]
        CustHome --> Track[Lacak 7 Status Real-Time]
        CustHome --> ViewQR[Tinjau Laporan Mutu]
        CustHome --> Review[Beri Rating & Ulasan]
    end
```

### 2.2 Penanganan Khusus Petugas (*Cleaner Context*)
Saat pengguna dengan `role: 'cleaner'` login:
1. Model `UserModel` di Flutter diperluas dengan properti `final String? cleanerId`.
2. Saat aplikasi melakukan inisialisasi sesi (`AuthService`), jika `user.role == 'cleaner'`:
   - Frontend memanggil `GET /api/cleaners` atau memeriksa relasi `cleaners.user_id == user.id`.
   - Menautkan ID operasional cleaner (`cleanerId`) ke sesi aktif.
3. `CleanerDashboardScreen` memanfaatkan `cleanerId` ini untuk mengambil daftar tugas aktif:
   `GET /api/orders?cleaner_id={cleanerId}`.

### 2.3 Skema Database Linking (SQL Migration)
Untuk memastikan akun demo cleaner di `public.profiles` terhubung dengan data petugas di `public.cleaners`:
```sql
-- Memastikan kolom user_id tersedia di tabel cleaners
ALTER TABLE public.cleaners 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Menautkan cleaner Cecep ke profil cleaner aktif untuk keperluan pengujian
UPDATE public.cleaners 
SET user_id = 'c1eane11-0000-4000-a000-000000000001' 
WHERE nama = 'Cecep' AND user_id IS NULL;
```

### 2.4 Mekanisme Role Switcher (Khusus Demonstrasi Evaluasi Skripsi)
- Di tab **Akun** (baik di Customer, Cleaner, maupun Admin), sistem menyediakan menu ekspansi: **"Mode Evaluasi Skripsi (Role Switcher)"**.
- Pengguna/Penguji sidang dapat berpindah mode seketika tanpa harus memasukkan kredensial login berulang-ulang:
  - Mode Pelanggan (`Customer - Demo User`)
  - Mode Petugas Lapangan (`Cleaner - Cecep / Candra Pratama`)
  - Mode Administrator (`Admin Operasional`)
- **Senior Software Engineer Safeguard**:
  - Pergantian peran di UI akan memperbarui sesi `currentUser` di `AuthService` dan mengirimkan header identitas yang valid ke backend (`x-user-id`, `x-user-role`, dan `x-cleaner-id`).
  - Hal ini menjamin bahwa seluruh pembatasan akses server-side (RBAC Express.js & RLS Supabase) tetap berjalan sesuai hak akses sebenarnya tanpa ada celah bypass keamanan.

---

## 3. Spesifikasi Dasbor Petugas (*Cleaner Dashboard*) — Penyempurnaan Bagian 2

### 3.1 Komponen & Tata Letak Layar (`CleanerDashboardScreen`)
Layar didesain khusus untuk penggunaan operasional lapangan dengan satu tangan (*one-handed mobile operation*):
1. **Header Profil Petugas**:
   - Avatar / inisial nama petugas.
   - Nama petugas & badge status operasional (`Aktif` hijau atau `Sedang Bertugas` biru).
   - Rating rata-rata aktual (bintang) dan total pekerjaan selesai.
   - Chip kategori keahlian layanan (`Rumah`, `Kos`, `Kantor`, `Pasca Renovasi`).
2. **Kartu Metrik Harian Ringkas**:
   - Jumlah tugas aktif yang sedang berjalan.
   - Total pesanan yang tuntas dikerjakan.
3. **Tab Navigasi Pekerjaan**:
   - **Tab 1: Tugas Berjalan (*Active Task*)**:
     - Menampilkan kartu pesanan yang ditugaskan kepada dirinya (`Petugas Ditugaskan`, `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`).
     - Menyajikan informasi lapangan lengkap: Alamat hunian pelanggan, patokan lokasi, tombol cepat **"Buka Navigasi / Peta"** (membuka Google Maps intent via `url_launcher`), jadwal kedatangan, durasi layanan, luas area, dan catatan khusus hunian.
   - **Tab 2: Riwayat Pekerjaan (*Completed History*)**:
     - Daftar pesanan berstatus `Selesai` yang pernah dikerjakan oleh petugas ini.
     - Menampilkan rating bintang dan ulasan testimoni dari pelanggan serta tombol untuk melihat kembali arsip foto *Quality Report*.

### 3.2 Alur Aksi Bertahap Lapangan (*Sequential Field Progression*)
Tombol aksi lapangan di kartu tugas aktif berevolusi secara sekuensial mutlak sesuai *finite-state machine*:
1. **Saat status `Petugas Ditugaskan`**:
   - Tombol: **"Mulai Berangkat (Menuju Lokasi)"** $\rightarrow$ Request `PATCH /api/orders/:id/status` dengan `status_baru: 'Menuju Lokasi'`.
2. **Saat status `Menuju Lokasi`**:
   - Tombol: **"Saya Sudah Tiba di Lokasi"** $\rightarrow$ Request `PATCH /api/orders/:id/status` dengan `status_baru: 'Tiba di Lokasi'`.
3. **Saat status `Tiba di Lokasi`**:
   - Tombol: **"Mulai Pengerjaan"** $\rightarrow$ Request `PATCH /api/orders/:id/status` dengan `status_baru: 'Sedang Dikerjakan'`.
4. **Saat status `Sedang Dikerjakan`**:
   - Tombol Utama: **"Tuntaskan & Buat Laporan Mutu (Quality Report)"** $\rightarrow$ Membuka form `QualityReportScreen`.

### 3.3 Ketahanan Operasional Lapangan (*Resilience, Debouncing & Image Handling*)
1. **Pencegahan Mutasi Ganda (*Double-Tap Debouncing*)**:
   - Seluruh tombol aksi transisi status lapangan dinonaktifkan secara visual (*disabled state*) dan menampilkan *CircularProgressIndicator* mini saat panggilan jaringan sedang berlangsung.
2. **Kompresi Gambar Sisi Klien**:
   - Foto kamera/galeri otomatis dikompresi menjadi format JPEG/WebP dengan ukuran 1–2 MB sebelum diunggah ke Supabase Storage bucket `quality-reports`.
3. **Retensi Formulir (*Offline Resilience*)**:
   - Jika koneksi internet terputus saat proses pengiriman Quality Report, berkas foto yang telah dipilih dan centang checklist tidak akan hilang dari layar. Tombol otomatis berubah menjadi mode **"Coba Kirim Ulang (*Retry*)"**.

---

## 4. Spesifikasi Dasbor Administrator (*Admin Dashboard*) — Penyempurnaan Bagian 3

### 4.1 Komponen & Tata Letak Layar (`AdminDashboardScreen`)
Dasbor ini berfungsi sebagai **Menara Pengawas Operasional (*Operational Control Tower*)**:
1. **Header & Pipeline Counter Badges**:
   - Menampilkan rekapitulasi jumlah pesanan secara visual:
     - 🟡 **Perlu Konfirmasi** (Pesanan baru masuk, status bayar `Sudah Bayar`).
     - 🔵 **Perlu Petugas** (Pesanan berstatus `Dikonfirmasi`, belum ada petugas).
     - 🟢 **Sedang Berjalan** (Tahap lapangan: Menuju, Tiba, Dikerjakan).
     - ⚪ **Tuntas** (Status `Selesai`).
     - 🔴 **Dibatalkan** (Status `Dibatalkan`).
2. **Tab Navigasi Operasional**:
   - **Tab 1: Butuh Tindakan Segera (*Action Required*)**:
     - Khusus mengumpulkan pesanan yang memerlukan keputusan Admin:
       - Pesanan `Menunggu Konfirmasi`: Jika `status_pembayaran == 'Sudah Bayar'`, tombol **"Konfirmasi Pesanan"** aktif. Jika `Belum Bayar`, tombol terkunci dengan badge abu-abu *"Menunggu Pembayaran Pelanggan"* (*BR-FIN-001*).
       - Pesanan `Dikonfirmasi`: Tombol **"Tugaskan Petugas (Smart Matching)"** aktif.
   - **Tab 2: Monitoring Lapangan (*Live Monitoring*)**:
     - Mengawasi seluruh pesanan yang sedang berjalan di lapangan secara real-time.
     - Menyediakan tombol aksi mitigasi: **"Ganti Petugas (*Reassign*)"** jika petugas berhalangan, atau **"Batalkan Pesanan Darurat"** jika terjadi insiden di lapangan.
   - **Tab 3: Tim Petugas (*Cleaner Roster*)**:
     - Menampilkan daftar seluruh petugas kebersihan, status operasional saat ini (`Aktif`, `Sedang Bertugas`, `Cuti`), rating performa, dan keahlian kategori layanan.

### 4.2 Modal Cerdas Penugasan Petugas (`SmartAssignmentSheet`)
Saat Admin menekan tombol *"Tugaskan Petugas"*:
- Menampilkan modal pemilihan petugas yang diurutkan secara deterministik oleh **Algoritma Smart Matching (SOT Sprint 2)**:
  - Skor Total: 40% Ketersediaan Jadwal, 30% Keahlian, 20% Rating, 10% Pengalaman.
  - Pembedaan badge visual: Petugas preferensi awal pelanggan ditandai badge *"Pilihan Pelanggan"*.
  - **Pencegahan Double Booking Visual**: Petugas yang mengalami bentrok jadwal (irisan waktu pesanan lain + buffer 30 menit) otomatis diberi tanda merah **"Jadwal Bentrok"** dan tombol pemilihannya terkunci (*disabled*).
- Admin memilih petugas $\rightarrow$ memanggil `POST /api/orders/:id/assign`. Status pesanan berubah menjadi `Petugas Ditugaskan`.

### 4.3 Audit Integritas pada Reassign & Pembatalan Darurat
- Sesuai aturan *BR-ASN-003* dan *BR-STS-003*, form modal penggantian petugas (*Reassign*) dan pembatalan (*Cancel*) wajib menyertakan kolom input teks alasan (minimal 5 karakter, misal: *"Petugas sakit mendadak"*).
- Alasan pembatalan/penggantian disimpan permanen pada tabel `status_logs` untuk auditabilitas operasional.

### 4.4 Efisiensi Pengambilan Data Paralel (*Parallel Data Fetching*)
- Layar Admin menggunakan `Future.wait([orderService.getOrders(), cleanerService.getCleaners()])` untuk memangkas *network latency* hingga 50% dibandingkan pemanggilan berurutan (*sequential waterfall*).

---

## 5. Pembersihan Antarmuka Pelanggan (*Customer UI Cleanup*) — Penyempurnaan Bagian 4

### 5.1 Penghapusan Widget Bantuan Simulasi
1. Widget tombol mengambang `OperationalSimulationSheet` pada [`mobile/lib/screens/order_tracking_screen.dart`](file:///c:/Users/62859/Documents/Skripsi/Resik.in/mobile/lib/screens/order_tracking_screen.dart) **dihapus secara permanen**.
2. Seluruh dependensi simulasi operasional di sisi pelanggan dinonaktifkan, sehingga antarmuka pelanggan murni menjadi antarmuka konsumen (*pure consumer experience*).

### 5.2 Mekanisme Pembaruan Status Pelanggan (*Adaptive Polling & Pull-to-Refresh*)
Karena prototipe ini berjalan pada arsitektur HTTP REST API (tanpa WebSocket server yang membebani resource), pelacakan status pesanan di sisi pelanggan menggunakan strategi **Dual Synchronization**:
1. **Manual Pull-to-Refresh**:
   - Layar pelacakan dibungkus dengan `RefreshIndicator` dan tombol refresh di `AppBar` agar pengguna dapat memicu pembaruan status kapan saja.
2. **Adaptive Short-Polling with Lifecycle Awareness**:
   - Selama pesanan berstatus aktif (`Menunggu Konfirmasi`, `Dikonfirmasi`, `Petugas Ditugaskan`, `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`), sebuah timer ringan melakukan polling setiap **10 detik**.
   - **Senior Software Engineer Safeguard**:
     - Polling otomatis dihentikan (*cancel timer*) saat pesanan mencapai status terminal (`Selesai` atau `Dibatalkan`).
     - Polling otomatis dihentikan saat layar di-`dispose()` (pengguna keluar dari halaman pelacakan) atau saat aplikasi diminimalkan ke latar belakang (*AppLifecycleState.paused*) untuk menghemat baterai dan kuota data ponsel.
3. **Retensi Tampilan Optimistik (*Optimistic View Retention*)**:
   - Jika terjadi kegagalan jaringan saat polling berlangsung, UI tidak akan mengosongkan layar (*no blank screen*). State terakhir stepper 7 tahapan tetap ditampilkan, disertai pemberitahuan *SnackBar* halus di bagian bawah.

### 5.3 Pemicu Aksi Pasca-Selesai (*Seamless Post-Completion Trigger*)
Saat status pesanan terdeteksi telah berubah menjadi `Selesai`:
1. Stepper tahapan otomatis menandai seluruh 7 langkah dengan centang hijau tuntas.
2. Kartu kesimpulan menampilkan dua tombol aksi utama:
   - **"Lihat Laporan Mutu (Quality Report)"**: Membuka modal ringkasan laporan mutu (foto Before/After, checklist, dan catatan petugas).
   - **"Beri Rating & Ulasan"**: Membuka modal ulasan pelanggan bintang 1-5 dan testimoni (jika `has_reviewed == false`). Jika ulasan telah dikirim (`has_reviewed == true`), tombol berubah menjadi badge bintang ulasan yang telah diberikan.

---

## 6. Rencana Pengujian Otomatis & Verifikasi (*Testing Matrix*)

Pengujian otomatis wajib lulus 100% tanpa regresi:
1. **Unit & Widget Test Dashboard Baru**:
   - `cleaner_dashboard_test.dart`: Memastikan Cleaner Dashboard menampilkan tugas aktif, memicu transisi status sekuensial lapangan, dan menampilkan form Quality Report.
   - `admin_dashboard_test.dart`: Memastikan Admin Dashboard menampilkan counter ringkasan, mengunci konfirmasi jika belum bayar, membuka Smart Matching modal, dan menolak double booking.
   - `auth_gate_role_test.dart`: Memastikan `AuthGate` merender `AdminDashboardScreen` untuk admin, `CleanerDashboardScreen` untuk cleaner, dan `HomeScreen` untuk customer.
2. **Regression Check Backend (`npm test`)**: Memastikan seluruh 86 automated backend tests tetap lulus 100%.
3. **Regression Check Mobile (`flutter test` & `flutter analyze`)**: Memastikan seluruh unit & widget tests lulus dan 0 issues pada static analysis.
4. **Verifikasi Perangkat Fisik (Samsung Galaxy A52)**: Build APK terbaru dan pengujian alur lengkap 3 peran di ponsel nyata via Wireless ADB.

---

## 7. Rencana Struktur Berkas Proyek

```text
mobile/lib/
├── models/
│   └── user_model.dart                   # [DIUBAH] Menambahkan properti cleanerId
├── screens/
│   ├── admin_dashboard_screen.dart       # [BARU] Dasbor monitoring & penugasan Admin
│   ├── cleaner_dashboard_screen.dart     # [BARU] Dasbor operasional lapangan Petugas
│   ├── order_tracking_screen.dart        # [DIUBAH] Pembersihan simulasi & penambahan adaptive polling
│   └── ... (screens lainnya tetap)
├── widgets/
│   ├── smart_assignment_sheet.dart       # [BARU] Modal pemilihan petugas ber-algoritma
│   ├── role_switcher_drawer.dart         # [BARU/MODULAR] Modul pergantian peran untuk evaluasi sidang
│   ├── operational_simulation_sheet.dart # [DIHAPUS/DEPRECATED] Digantikan oleh dashboard asli
│   └── ... (widgets lainnya tetap)
└── main.dart                             # [DIUBAH] Role-based routing di AuthGate
```
