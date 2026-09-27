# STRATEGI & SKENARIO PENGUJIAN SISTEM (TESTING PLAN)
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

> **Status Dokumen:** Active Test Plan & Quality Assurance Guide  
> **Versi Dokumen:** 1.2 (Hardened & Specification-Complete)  
> **Tanggal Pembaruan:** 26 September 2026  
> **Dokumen Induk:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/API.md`, `docs/SECURITY.md`  

---

## 1. Ikhtisar Strategi Pengujian

Sistem Resik.in menggunakan suite pengujian otomatis berbasis native Node.js test runner (`node:test` dan `node:assert`).
Pengujian mencakup unit test, integration test, security invariant test (termasuk negative testing), dan verifikasi aturan bisnis kritis:
- **Perintah Resmi Pengujian:**
  ```bash
  npm test
  ```
  *(Mengeksekusi `node --test test/*.test.js`).*
- **Kriteria Lulus Mutlak:** 100% test assertions berstatus hijau (*green/passed*) tanpa error atau warning regresi.

---

## 2. Matriks Skenario Pengujian Menyeluruh (18 Domain Uji)

### 2.1 Autentikasi & Otorisasi RBAC (BR-SEC-001)
- **TC-AUTH-01:** Login berhasil dengan kredensial Supabase Auth yang valid dan mengembalikan JWT token.
- **TC-AUTH-02 (Negative):** Akses ke endpoint privat tanpa Bearer token ditolak dengan respon HTTP `401 Unauthorized`.
- **TC-RBAC-01:** Customer mengakses endpoint khusus admin (`GET /api/cleaners` atau `PUT /api/services/:id/toggle`) ditolak dengan HTTP `403 Forbidden`.
- **TC-RBAC-02:** Cleaner mencoba mengonfirmasi penugasan awal pesanan ditolak dengan HTTP `403 Forbidden`.

### 2.2 Pencegahan IDOR & Isolasi Data Pelanggan (BR-SEC-002)
- **TC-IDOR-01:** Customer A meminta `GET /api/orders` hanya menerima daftar pesanan miliknya sendiri (`customer_id = Customer A`).
- **TC-IDOR-02 (Negative):** Customer A mencoba mengakses detail pesanan milik Customer B (`GET /api/orders/{order_id_b}`) ditolak oleh backend dengan respon HTTP `403 Forbidden`.

### 2.3 Row Level Security (RLS Database Validation)
- **TC-RLS-01:** Query langsung via anon client ke tabel `orders` tanpa session header hanya mengembalikan row yang sesuai dengan `auth.uid()`.
- **TC-RLS-02:** Mutasi data pada tabel `status_logs` (UPDATE/DELETE) ditolak oleh kebijakan RLS database (bersifat *append-only*).

### 2.4 Manipulasi Pembayaran & Alur Server-Authoritative (BR-FIN-001)
- **TC-PAY-01 (Negative Payload):** Customer mengirimkan body `POST /api/orders` yang memuat `"status_pembayaran": "Sudah Bayar"`. Backend mengabaikan input tersebut dan tetap mengeset `status_pembayaran = 'Belum Bayar'` dan `payment_timestamp = NULL`.
- **TC-PAY-02:** Customer memanggil `POST /api/orders/:id/pay`. Server memverifikasi hak akses, mengupdate `status_pembayaran = 'Sudah Bayar'`, mencatat `payment_timestamp = NOW()` (waktu server), dan mencatat aksi ke `status_logs`.
- **TC-PAY-03 (Negative Duplicate):** Memanggil `POST /api/orders/:id/pay` untuk pesanan yang sudah berstatus `Sudah Bayar` ditolak dengan HTTP `400 Bad Request`.
- **TC-PAY-04 (Negative Unpaid Confirmation Gate):** Admin mencoba mengubah status pesanan dari `Menunggu Konfirmasi` menjadi `Dikonfirmasi` saat `status_pembayaran == 'Belum Bayar'`. Backend menolak mutasi dengan status HTTP `400 Bad Request` (`ORDER_NOT_PAID_YET`).

### 2.5 Snapshot Harga & Immutability Transaksi (BR-FIN-002)
- **TC-PRC-01:** Pembuatan pesanan mengunci nilai transaksi: `harga_saat_booking = services.tarif_dasar` dan `total_biaya = harga_saat_booking` (flat package baseline). Parameter `luas_area` tersimpan sebagai teks deskriptif.
- **TC-PRC-02:** Pembaruan tarif dasar pada master `services` (misal dinaikkan menjadi Rp 150.000) tidak mengubah nilai `harga_saat_booking` dan `total_biaya` pada pesanan lama yang sudah ada di basis data.
- **TC-PRC-03 (Optional Field):** Pembuatan pesanan dengan `catatan_khusus = null` berhasil diproses (HTTP 201 Created). Pembuatan pesanan tanpa atribut wajib (`alamat_lengkap`, `patokan_lokasi`, `luas_area`, `service_id`, `tanggal_layanan`) ditolak dengan HTTP `400 Bad Request`.

### 2.6 Penjadwalan & Pencegahan Double Booking Langsung (BR-SCH-005)
- **TC-DBL-01 (Negative):** Menolak alokasi petugas jika terdapat irisan waktu langsung pada tanggal yang sama (misal: Order A `08:00 - 10:00` vs Order B `09:00 - 11:00`). Backend mengembalikan status HTTP `409 Conflict`.
- **TC-DBL-02:** Penugasan diterima jika jadwal tidak bersinggungan dan memenuhi buffer 30 menit (misal: Order A `08:00 - 10:00`, Order B `10:30 - 12:30`).

### 2.7 Batasan Buffer Waktu Operasional 30 Menit (BR-SCH-004)
- **TC-BUF-01 (Negative Boundary):** Order A selesai pukul `10:00`. Order B dijadwalkan pukul `10:29` (jeda 29 menit, kurang dari buffer 30 menit). Alokasi ditolak dengan HTTP `409 Conflict`.
- **TC-BUF-02 (Positive Boundary):** Order A selesai pukul `10:00`. Order B dijadwalkan pukul `10:30` (jeda tepat 30 menit). Alokasi diterima dengan HTTP `200 OK`.

### 2.8 Smart Matching Deterministik, Skill Matrix, & Availability Score (BR-MTG)
- **TC-MTG-01 (Hard Filter):** Petugas berstatus administratif `'Cuti'` atau `'Nonaktif'` otomatis tereliminasi dari rekomendasi. Petugas berstatus `'Aktif'` yang mengalami bentrok jadwal juga otomatis gugur (Score = 0).
- **TC-MTG-02 (Skill Matrix Matching):**
  - Order Pembersihan Rumah: Petugas dengan keahlian `'general_cleaning'` memperoleh $S_{\text{skill}} = 100$.
  - Order Pembersihan Kantor: Petugas dengan keahlian `'office_cleaning'` memperoleh $S_{\text{skill}} = 100$, sedangkan keahlian `'general_cleaning'` memperoleh $S_{\text{skill}} = 70$.
  - Order Pasca Renovasi: Petugas tanpa keahlian `'pasca_renovasi'` langsung gugur pada Hard Filter. Petugas dengan keahlian `'pasca_renovasi'` memperoleh $S_{\text{skill}} = 100$.
- **TC-MTG-03 (Availability Score Rubric):**
  - Petugas dengan 0 tugas lain pada tanggal yang sama memperoleh $S_{\text{avail}} = 100$.
  - Petugas dengan 1 tugas lain pada tanggal yang sama (jadwal valid + buffer terpenuhi) memperoleh $S_{\text{avail}} = 80$.
  - Petugas dengan $\ge 2$ tugas lain pada tanggal yang sama (jadwal valid + buffer terpenuhi) memperoleh $S_{\text{avail}} = 60$.
- **TC-MTG-04 (Provisional Rating V1):** Petugas baru tanpa ulasan customer dihitung dengan rating awal $4.5$ ($S_{\text{rating}} = 90.0$ poin) dan ditandai badge *"Petugas Baru (Rating Awal 4.5)"*.
- **TC-MTG-05 (Actual Rating):** Petugas dengan ulasan customer menggunakan nilai `rating_rata_rata` aktual ($S_{\text{rating}} = (\text{rating} / 5.0) \times 100$).
- **TC-MTG-06 (Tie-Breaking):** Jika dua petugas memiliki Total Score sama persis, urutan ditentukan oleh: (1) Rating tertinggi, (2) Total order sukses terbanyak, (3) ID cleaner terkecil (`id` ASC).

### 2.9 Kondisi Tanpa Kandidat Rekomendasi (BR-MTG-005)
- **TC-ZER-01:** Ketika seluruh petugas mengalami bentrok jadwal pada slot yang diminta, endpoint rekomendasi mengembalikan `total_kandidat: 0` dan pesan transparan *"Tidak ada petugas tersedia pada jadwal ini."*
- **TC-ZER-02:** Pelanggan memilih opsi *"Lanjutkan dan Serahkan ke Admin"*, pesanan berhasil dibuat dengan `preferensi_petugas_id: null` dan flag kebutuhan alokasi manual admin.

### 2.10 Penugasan Hibrida & Sekuensialitas Mutlak (BR-ASN)
- **TC-ASN-01 (Negative Lifecycle Skipping):** Admin mencoba memanggil `POST /api/orders/:id/assign` untuk pesanan yang masih berstatus `Menunggu Konfirmasi`. Backend menolak dengan HTTP `400 Bad Request` (`ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT`).
- **TC-ASN-02:** Admin menugaskan petugas pada pesanan berstatus `Dikonfirmasi` (`POST /api/orders/:id/assign`). Status pesanan berhasil berubah menjadi `Petugas Ditugaskan`.
- **TC-ASN-03 (Negative Collision):** Admin mencoba menugaskan petugas yang jadwalnya telah terisi oleh pesanan lain. Backend menolak penugasan dengan HTTP `409 Conflict`.

### 2.11 Penggantian Petugas Ber-Audit (Reassignment - BR-ASN-003)
- **TC-REA-01:** Admin mengganti petugas pada pesanan berstatus `Petugas Ditugaskan` (`POST /api/orders/:id/reassign`). `cleaner_id` ter-update ke petugas baru.
- **TC-REA-02:** Aksi reassignment menghasilkan catatan permanen di `status_logs` dengan format audit: `catatan: 'REASSIGN_CLEANER: dari {old} ke {new} - Alasan: {alasan}'`.
- **TC-REA-03 (Negative):** Reassignment ditolak dengan HTTP `400 Bad Request` jika status pesanan sudah mencapai `Menuju Lokasi`, `Tiba di Lokasi`, atau `Sedang Dikerjakan`.

### 2.12 Siklus Pembatalan Terstruktur (BR-STS-003)
- **TC-CAN-01 (Customer Allowed Cancellation):** Pelanggan berhasil membatalkan pesanan pada status `Menunggu Konfirmasi`, `Dikonfirmasi`, dan `Petugas Ditugaskan`. Status berubah menjadi `Dibatalkan` dan alasan tersimpan.
- **TC-CAN-02 (Customer Blocked Cancellation):** Pelanggan mencoba membatalkan pesanan saat status telah mencapai `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`, atau `Selesai`. Backend menolak dengan HTTP `400 Bad Request` / `403 Forbidden`.
- **TC-CAN-03 (Admin Emergency Cancellation):** Admin membatalkan pesanan sebelum `Selesai` termasuk saat `Sedang Dikerjakan` sebagai tindakan darurat operasional. Alasan pembatalan tersimpan, audit tercatat di `status_logs`, dan status operasional petugas dipulihkan menjadi `Aktif`.

### 2.13 Gerbang Mutlak Quality Report & Template Checklist Penuh (BR-QRP)
- **TC-QRP-01 (Negative Bypass):** Upaya mengubah status pesanan dari `Sedang Dikerjakan` ke `Selesai` melalui endpoint generic `PATCH /api/orders/:id/status` ditolak dengan HTTP `400 Bad Request` / `403 Forbidden`.
- **TC-QRP-02 (Negative Partial Checklist):** Cleaner mengirimkan Quality Report dengan checklist yang tidak lengkap (melewatkan salah satu area template layanan). Backend menolak dengan status HTTP `400 Bad Request` (`CHECKLIST_AREAS_INCOMPLETE`).
- **TC-QRP-03 (Complete Submission):** Cleaner mengirimkan Quality Report melalui `POST /api/quality-reports` dengan verifikasi seluruh area template (`completed: true`), foto before/after terkompresi, dan catatan. Status pesanan berubah menjadi `Selesai`, laporan terkunci read-only, dan cleaner kembali ke status `Aktif`.
- **TC-QRP-04 (Timestamps Invariant Validation):** Backend memvalidasi integritas 3 timestamp. Jika `started_at <= completed_at <= submitted_at` dan `completed_at <= NOW()`, request diterima (201 Created). Jika `completed_at < started_at` atau `completed_at > NOW()`, backend menolak dengan HTTP `400 Bad Request` (`INVALID_TIMESTAMPS`).
- **TC-QRP-05 (Official Endpoint Enforcement):** Memastikan hanya endpoint resmi `POST /api/quality-reports` yang memproses pengiriman Quality Report dan mengubah status ke `Selesai`.

### 2.14 Otorisasi Penyimpanan Berkas & Anti-Tampering (BR-QRP-003)
- **TC-STO-01 (Path Sanitization):** Cleaner mengirimkan `foto_before_path` yang tidak diawali `orders/{order_id}/` (mencoba menyuntikkan file order lain). Backend menolak request dengan HTTP `400 Bad Request`.
- **TC-STO-02 (Negative File Missing):** Cleaner mengirimkan path yang valid secara format tetapi berkas fisiknya tidak ada di Supabase Storage. Backend menolak dengan HTTP `404 Not Found`.
- **TC-STO-03 (Negative Role):** Cleaner yang bukan penanggung jawab pesanan mencoba mengunggah/mengirimkan Quality Report untuk order tersebut. Ditolak dengan HTTP `403 Forbidden`.

### 2.15 Akses Berkas Private Storage via Temporary Signed URL (BR-QRP-004)
- **TC-SGN-01 (Authorized Readers):** Customer pemilik pesanan, Cleaner yang ditugaskan pada pesanan tersebut, atau Admin memanggil `GET /api/quality-reports/:order_id`. Backend mengembalikan objek laporan beserta `foto_before_signed_url` dan `foto_after_signed_url` dengan masa berlaku 30 menit (HTTP 200 OK).
- **TC-SGN-02 (Negative Unauthorized Readers):** Customer lain yang bukan pemilik pesanan, Cleaner lain yang tidak ditugaskan pada pesanan tersebut, atau user unauthenticated mencoba memanggil `GET /api/quality-reports/:order_id`. Backend menolak dengan status HTTP `403 Forbidden` / `401 Unauthorized`.
- **TC-SGN-03 (Public Access Blocked):** Mengakses berkas storage langsung tanpa query token signed URL mengembalikan respons `403 Forbidden` / `400 Invalid Token` dari Supabase Storage.

### 2.16 Detail Pesanan & Otorisasi Endpoint (GET /api/orders/:id)
- **TC-ORD-01 (Customer Detail Access):** Customer mengakses `GET /api/orders/:id` miliknya sendiri. Response mengembalikan HTTP 200 OK dengan detail lengkap mencakup `order_code`, snapshot harga, jadwal, preferensi cleaner, dan status.
- **TC-ORD-02 (IDOR Prevention):** Customer A mengakses `GET /api/orders/:id` milik Customer B. Backend mengembalikan status HTTP `403 Forbidden`.
- **TC-ORD-03 (Cleaner Detail Access):** Cleaner mengakses detail pesanan yang ditugaskan kepadanya. Backend mengembalikan status HTTP 200 OK. Cleaner mencoba mengakses order yang tidak ditugaskan kepadanya mengembalikan `403 Forbidden`.
- **TC-ORD-04 (Admin Detail Access):** Admin dapat mengakses seluruh detail pesanan dari seluruh pelanggan.

### 2.17 Otoritas Transisi Status Lapangan (PATCH /api/orders/:id/status)
- **TC-AUT-01 (Admin Status Restriction):** Admin mencoba mengubah status lapangan ke `Menuju Lokasi` atau `Sedang Dikerjakan` via endpoint `PATCH /status`. Backend menolak dengan status HTTP `403 Forbidden` (wewenang eksklusif cleaner).
- **TC-AUT-02 (Cleaner Sequential Advancement):** Cleaner yang ditugaskan memajukan status pesanan secara sekuensial: `Petugas Ditugaskan` $\rightarrow$ `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan`. Seluruh transisi berhasil dengan status HTTP 200 OK.

### 2.18 Rating & Ulasan Pelanggan V1.1 (BR-REV)
- **TC-REV-01:** Customer pemilik pesanan mengirimkan rating 1–5 untuk pesanan yang telah berstatus `Selesai`. Ulasan tersimpan dan rating rata-rata cleaner ter-update otomatis.
- **TC-REV-02 (Negative Duplicate):** Customer mencoba mengirimkan rating kedua kalinya untuk pesanan yang sama. Backend menolak dengan HTTP `409 Conflict`.
- **TC-REV-03 (Negative Not Finished):** Mengirimkan review untuk pesanan yang belum berstatus `Selesai` ditolak dengan HTTP `400 Bad Request`.

### 2.19 Sinkronisasi Real-Time (Primary WebSocket & Fallback Polling - BR-RT)
- **TC-RT-01 (Primary Realtime):** Mutasi status pesanan di database memicu event Supabase Realtime WebSocket ke channel `order-status-{id}` secara instan.
- **TC-RT-02 (Fallback Polling):** Saat koneksi WebSocket ditutup paksa, browser beralih mengeksekusi request short polling setiap 15 detik untuk memvalidasi perubahan status terakhir.

### 2.20 Foto Profil Petugas Kebersihan
- **TC-PRF-01:** Detail profil cleaner memuat atribut `foto_url` yang valid dan dirender pada kartu antarmuka rekomendasi Smart Matching.
