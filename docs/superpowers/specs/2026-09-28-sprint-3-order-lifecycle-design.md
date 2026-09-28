# Spesifikasi Desain: Sprint 3 — Siklus Hidup Pesanan, Pelacakan Stepper 7 Status, & Dasbor Operasional

> **Dokumen:** `docs/superpowers/specs/2026-09-28-sprint-3-order-lifecycle-design.md`  
> **Status:** Draft Disetujui  
> **Tanggal:** 28 September 2026  
> **Target Rilis:** Sprint 3 (FR-05, FR-06, FR-07)  
> **Referensi SOT:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/API.md`, Screen 4 Stitch Project `5093522159329805546`

---

## 1. Latar Belakang & Tujuan

Pada Sprint 1 dan Sprint 2, sistem Resik.in telah menyelesaikan katalog 4 layanan, penjadwalan interval dengan buffer 30 menit, pemesanan dengan snapshot harga flat deterministik, simulasi pembayaran server-authoritative, manajemen master data petugas kebersihan, sistem rekomendasi deterministik (*Smart Petugas Matching*), serta integrasi autentikasi Google Sign-In dengan *AuthGate*.

**Tujuan Sprint 3:**
1. Mengimplementasikan siklus hidup pesanan 7 status sekuensial mutlak (*no status skipping*).
2. Menerapkan penugasan hibrida (*Hybrid Assignment*) dengan deteksi bentrok jadwal otomatis (*schedule conflict check*) memperhitungkan durasi layanan dan buffer operasional 30 menit.
3. Mendukung fitur penggantian petugas (*Reassignment*) ber-audit trail pada `status_logs`.
4. Menerapkan aturan pembatalan pesanan terstruktur berbasis peran (*RBAC Cancellation*).
5. Membangun antarmuka mobile Flutter untuk **Pelacakan Status Pekerjaan** (*Screen 4 dari Stitch*) dengan stepper 7 status visual, kartu profil petugas aktif, kontak telepon, dan kartu progres durasi kerja.
6. Menyediakan komponen modular **Simulasi Operasional** (*Operational Simulation Sheet*) terisolasi yang dapat dinyalakan/dimatikan melalui konfigurasi konstanta (`kEnableOperationalSimulation`), sehingga saat ini pengguna dapat menguji peran Admin & Petugas tanpa berganti akun, dan ketika dinonaktifkan nantinya, sistem tetap mematuhi otorisasi peran riil.

---

## 2. Ruang Lingkup Fitur (Scope)

| Kode Fitur | Deskripsi | Aktor Utama | Kriteria Keberhasilan |
| :--- | :--- | :--- | :--- |
| **FR-05** | Penugasan Petugas Hibrida (*Hybrid Assignment*) | Admin | Validasi prasyarat pesanan `Dikonfirmasi`. Deteksi bentrok jadwal (+ buffer 30 m) menghasilkan `409 Conflict`. Update status ke `Petugas Ditugaskan`. |
| **FR-06** | Dasbor Operasional Admin & Reassignment Ber-Audit | Admin | Pergantian petugas hanya saat `Petugas Ditugaskan`, pencatatan audit log `REASSIGN_CLEANER: dari {old} ke {new} - Alasan: {alasan}`. |
| **FR-07** | Pelacakan Progres 7 Status Pekerjaan & Pembatalan | Pelanggan, Petugas, Admin | 7 status sekuensial mutlak. Pelanggan hanya bisa membatalkan sebelum masuk tahap lapangan (`Menuju Lokasi`). Admin bisa membatalkan kapan saja sebelum `Selesai`. |

---

## 3. Arsitektur & Kontrak REST API Backend (`backend/routes/orders.js`)

### 3.1 Transisi Status Sekuensial (`PATCH /api/orders/:id/status`)
- **Method:** `PATCH`
- **Tujuan:** Memajukan status pengerjaan sesuai alur sekuensial mutlak:
  $$\text{Menunggu Konfirmasi} \overset{\text{Admin}}{\longrightarrow} \text{Dikonfirmasi} \overset{\text{Admin}}{\longrightarrow} \text{Petugas Ditugaskan} \overset{\text{Cleaner}}{\longrightarrow} \text{Menuju Lokasi} \overset{\text{Cleaner}}{\longrightarrow} \text{Tiba di Lokasi} \overset{\text{Cleaner}}{\longrightarrow} \text{Sedang Dikerjakan}$$
- **Request Body:**
  ```json
  {
    "status_baru": "Dikonfirmasi",
    "role": "admin"
  }
  ```
- **Validasi Bisnis:**
  1. Status saat ini wajib sesuai dengan tahapan sebelum `status_baru` (tidak boleh melompat).
  2. Transisi `Menunggu Konfirmasi` $\rightarrow$ `Dikonfirmasi` hanya diizinkan untuk Admin, dan **wajib** `status_pembayaran == 'Sudah Bayar'`. Jika belum bayar, tolak dengan `400 Bad Request` (`ORDER_NOT_PAID_YET`).
  3. Transisi `Petugas Ditugaskan` $\rightarrow$ `Menuju Lokasi`, `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi`, dan `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan` hanya diizinkan untuk Petugas (`role: 'cleaner'`).
  4. Transisi saat `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan` otomatis mencatat server timestamp `started_at = NOW()`.
  5. Transisi ke `Selesai` dilarang melalui endpoint ini (wajib melalui `POST /api/quality-reports` pada Sprint 4).
- **Log Audit:** Setiap perubahan status otomatis dicatat ke dalam `inMemoryStore.status_logs`.

### 3.2 Penugasan Petugas Hibrida (`POST /api/orders/:id/assign`)
- **Method:** `POST`
- **Request Body:** `{ "cleaner_id": "uuid-cleaner", "role": "admin" }`
- **Validasi Bisnis:**
  1. Status pesanan wajib `Dikonfirmasi`. Jika masih `Menunggu Konfirmasi`, tolak dengan `400 Bad Request` (`ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT`).
  2. Petugas target wajib berstatus `Aktif`.
  3. **Pemeriksaan Bentrok Jadwal (Anti-Double Booking):**
     - Cari seluruh pesanan lain pada tanggal yang sama (`tanggal_layanan`) yang ditugaskan kepada petugas tersebut dan statusnya bukan `Dibatalkan` atau `Selesai`.
     - Hitung interval sibuk: `[start_time, end_time + 30 menit]`.
     - Jika interval pesanan baru tumpang tindih dengan interval sibuk yang ada, tolak dengan `409 Conflict` (`SCHEDULE_CONFLICT_DETECTED`).
- **Server Action:**
  - Update `order.cleaner_id = cleaner_id`.
  - Update `order.status_pekerjaan = 'Petugas Ditugaskan'`.
  - Catat log audit ke `status_logs`.

### 3.3 Penggantian Petugas Ber-Audit (`POST /api/orders/:id/reassign`)
- **Method:** `POST`
- **Request Body:** `{ "new_cleaner_id": "uuid", "alasan": "Petugas sakit mendadak", "role": "admin" }`
- **Validasi Bisnis:**
  1. Status pesanan wajib `Petugas Ditugaskan`. Jika sudah masuk tahap lapangan (`Menuju Lokasi`, dll), tolak dengan `400 Bad Request` (`CANNOT_REASSIGN_AFTER_DISPATCH`).
  2. Alasan wajib diisi (minimal 5 karakter).
  3. Petugas baru bebas bentrok jadwal (+ buffer 30 m).
- **Server Action:**
  - Simpan `old_cleaner_id = order.cleaner_id`.
  - Update `order.cleaner_id = new_cleaner_id`.
  - Tambahkan entri ke `status_logs`:  
    `REASSIGN_CLEANER: dari ${old_cleaner_id} ke ${new_cleaner_id} - Alasan: ${alasan}`.

### 3.4 Pembatalan Pesanan Berbasis Peran (`POST /api/orders/:id/cancel`)
- **Method:** `POST`
- **Request Body:** `{ "cancellation_reason": "Perubahan rencana mendadak", "role": "customer" | "admin" }`
- **Validasi Bisnis:**
  1. `cancellation_reason` wajib diisi minimal 5 karakter.
  2. Jika pemohon adalah **Customer**:
     - Status pesanan hanya boleh `Menunggu Konfirmasi`, `Dikonfirmasi`, atau `Petugas Ditugaskan`.
     - Jika status sudah `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`, atau `Selesai`, tolak dengan `403 Forbidden` (`CUSTOMER_CANNOT_CANCEL_DISPATCHED_ORDER`).
  3. Jika pemohon adalah **Admin**:
     - Boleh membatalkan kapan saja sebelum `Selesai` (tindakan darurat operasional).
- **Server Action:**
  - `order.status_pekerjaan = 'Dibatalkan'` (*terminal state*).
  - `order.cancellation_reason = cancellation_reason`.
  - `order.cancelled_by = role`.
  - `order.cancelled_at = NOW()`.
  - Jika pesanan memiliki petugas yang ditugaskan, status petugas dipulihkan kembali ke `Aktif`.
  - Catat log ke `status_logs`.

---

## 4. Desain Antarmuka Mobile Flutter (`mobile/lib/screens/order_tracking_screen.dart`)

Mengadopsi spesifikasi desain **Screen 4 Stitch** (`Pelacakan Status Pekerjaan`):

1. **Struktur Header & AppBar:**
   - Tombol kembali (Back).
   - Judul layar "Pelacakan Cleaner".
   - Foto avatar user di pojok kanan.
2. **Badge Status & Info Pesanan:**
   - Pill badge status aktif dengan titik animasi berdenyut (*pulse dot*).
   - Kode pesanan `#RSK-XXXXX`.
   - Nama layanan (e.g. "Pembersihan Pasca Renovasi") dan rincian ruangan.
3. **Kartu Durasi & Progres Pengerjaan (Ambient Gradient Card):**
   - Latar belakang gradien `from-primary via-primary-container to-secondary`.
   - Durasi berjalan (*elapsed timer* atau status timeline).
   - Estimasi selesai (jam WIB).
   - Bar progres visual dengan gradien aksen.
4. **Kartu Profil Petugas Kebersihan Aktif:**
   - Foto avatar petugas dengan badge centang verifikasi (*Mitra Pro*).
   - Nama petugas, rating bintang (e.g. 4.9 ★), dan total pekerjaan selesai.
   - Tombol aksi cepat: Telepon langsung (`url_launcher` / `tel:`) dan Chat.
5. **Stepper Visual 7 Status Pekerjaan:**
   - Masing-masing status memiliki label, sub-deskripsi, dan timestamp log.
   - Indikator:
     - Hijau centang (`Icons.check_circle`): Tahapan yang telah terlewati.
     - Biru aktif berdenyut (`Icons.radio_button_checked` / pulse): Tahapan yang sedang berlangsung.
     - Abu-abu netral: Tahapan yang belum dicapai.
6. **Tombol Batalkan Pesanan:**
   - Tombol sekunder di bagian bawah layar.
   - Hanya muncul/aktif jika status pesanan masih memenuhi syarat pembatalan oleh pelanggan (`Menunggu Konfirmasi`, `Dikonfirmasi`, `Petugas Ditugaskan`).
   - Membuka modal dialog konfirmasi pembatalan dengan `TextFormField` alasan pembatalan.

---

## 5. Komponen Modular Simulasi Operasional (`OperationalSimulationSheet`)

Untuk mengakomodasi kebutuhan pengujian saat ini tanpa merusak arsitektur hak akses di masa depan:

1. **Konfigurasi Flag:**
   - `mobile/lib/constants.dart`: `static const bool kEnableOperationalSimulation = true;`
2. **Karakteristik Komponen:**
   - Saat `kEnableOperationalSimulation == true`, tombol melayang / aksi di AppBar menampilkan menu *"Simulasi Status Operasional"*.
   - Sheet ini menyajikan tombol aksi sesuai status pesanan saat ini:
     - Status `Menunggu Konfirmasi` $\rightarrow$ *"Konfirmasi Pesanan (Admin)"* (mengirim `role: 'admin'`)
     - Status `Dikonfirmasi` $\rightarrow$ *"Tugaskan Petugas (Admin)"* (mengirim `role: 'admin'`)
     - Status `Petugas Ditugaskan` $\rightarrow$ *"Menuju Lokasi (Petugas)"* (mengirim `role: 'cleaner'`)
     - Status `Menuju Lokasi` $\rightarrow$ *"Tiba di Lokasi (Petugas)"* (mengirim `role: 'cleaner'`)
     - Status `Tiba di Lokasi` $\rightarrow$ *"Mulai Dikerjakan (Petugas)"* (mengirim `role: 'cleaner'`)
     - Opsi darurat: *"Batalkan Pesanan (Admin)"* (mengirim `role: 'admin'`)
3. **Pemisahan Tegas & Degradasi Aman:**
   - Backend tetap memvalidasi aturan peran secara ketat.
   - Jika `kEnableOperationalSimulation` diset ke `false` (atau dihapus kelak), aplikasi mobile sepenuhnya menjadi murni antarmuka pelanggan, sedangkan aksi Admin dan Petugas wajib dilakukan oleh akun dengan peran masing-masing.

---

## 6. Integrasi Alur Pengguna

1. **Dari Booking & Pembayaran:**
   - Pelanggan membuat pesanan di `BookingScreen` $\rightarrow$ masuk ke `PaymentScreen`.
   - Setelah simulasi pembayaran berhasil diverifikasi di server, tombol aksi pada `PaymentScreen` langsung mengarahkan navigasi ke `OrderTrackingScreen(orderId: ...)`.
2. **Dari Beranda (`HomeScreen`):**
   - `HomeScreen` memeriksa apakah ada pesanan aktif milik pelanggan.
   - Jika ada, kartu pesanan aktif ditampilkan di bagian atas beranda dengan tombol *"Lacak Status"*, yang membuka `OrderTrackingScreen`.

---

## 7. Rencana Pengujian Otomatis

1. **Backend Tests (`backend/test/lifecycle.test.js`):**
   - Transisi status sekuensial (sukses dan penolakan lompat status).
   - Penolakan konfirmasi jika pesanan belum bayar.
   - Penugasan petugas dengan deteksi bentrok jadwal (+ buffer 30 m).
   - Reassignment petugas dan verifikasi pencatatan audit log di `status_logs`.
   - Aturan pembatalan: pelanggan ditolak setelah tahap lapangan; admin diizinkan membatalkan darurat.
2. **Mobile Widget Tests (`mobile/test/order_tracking_screen_test.dart`):**
   - Render stepper 7 status dengan styling status aktif/selesai.
   - Render kartu petugas aktif dengan nama dan nomor kontak.
   - Menampilkan/menyembunyikan tombol batalkan sesuai status.
   - Dialog konfirmasi pembatalan mengirim alasan pembatalan yang valid.
