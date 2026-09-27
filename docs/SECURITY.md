# SPESIFIKASI KEAMANAN & PRINSIP PRIVASI (SECURITY INVARIANTS)
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

> **Status Dokumen:** Active Security Policy & Access Invariants  
> **Versi Dokumen:** 1.2 (Hardened)  
> **Tanggal Pembaruan:** 26 September 2026  
> **Dokumen Induk:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/ARCHITECTURE.md`  

---

## 1. Prinsip Utama Keamanan Resik.in

Sistem Resik.in menerapkan standar keamanan berbasis pertahanan berlapis (*defense-in-depth*):

1. **Supabase Auth sebagai Otoritas Tunggal:**
   - Seluruh kredensial kata sandi, verifikasi sesi, token JWT, dan hashing akun ditangani langsung oleh infrastruktur Supabase Auth (`auth.users`).
   - Basis data aplikasi lokal **TIDAK PERNAH** menyimpan password mentah maupun kolom `password_hash`.
2. **Server-Side Authorization (No UI Trust):**
   - Batasan otorisasi antarmuka peramban (misal menyembunyikan tombol) tidak dianggap sebagai perlindungan keamanan.
   - Seluruh mutasi data dan endpoint API wajib memverifikasi identitas pengguna dan peran (*role*) di sisi server Node.js.
3. **Isolasi Data Antar-Pengguna (*Strict Tenant Isolation & Anti-IDOR*):**
   - Pelanggan $A$ tidak boleh dapat membaca, menebak, ataupun memanipulasi data pesanan milik Pelanggan $B$.
   - Backend membatasi query pesanan pelanggan berdasarkan ID terautentikasi: `customer_id = req.user.id`. Percobaan akses ke order milik pengguna lain wajib mengembalikan `403 Forbidden`.

---

## 2. Matriks Otorisasi Akses Penyimpanan Berkas (*Storage Access Matrix*)

Foto area tempat tinggal pelanggan merupakan data privat berisiko tinggi. Karena itu, bucket Supabase Storage `quality-reports` **WAJIB bersifat Privat (`public = false`)**.

| Peran Pengguna | Hak Unggah (*Upload*) | Hak Baca (*Read / View*) | Mekanisme Otorisasi |
| :--- | :---: | :---: | :--- |
| **Cleaner (Petugas yang Ditugaskan)** | ✅ Diizinkan (hanya saat pesanan berstatus `Sedang Dikerjakan`) | ✅ Diizinkan | Upload langsung via signed upload / RLS restricted token ke folder `orders/{order_id}/`. Akses baca via Signed URL temporer. |
| **Cleaner Lain** | ❌ Ditolak (`403 Forbidden`) | ❌ Ditolak (`403 Forbidden`) | RLS Storage & Backend Authorization memblokir cleaner yang tidak terdaftar pada `order_id`. |
| **Customer Pemilik Pesanan** | ❌ Ditolak | ✅ Diizinkan | Meminta akses via API `GET /api/quality-reports/:order_id`. Backend menerbitkan Signed URL temporer (30 menit). |
| **Customer Lain** | ❌ Ditolak | ❌ Ditolak (`403 Forbidden`) | Server memvalidasi `orders.customer_id = auth.uid()`. Jika tidak cocok, request ditolak langsung. |
| **Admin** | ❌ Ditolak (hanya Cleaner) | ✅ Diizinkan | Admin memiliki wewenang pengawasan mutu seluruh pesanan via Signed URL. |
| **Publik / Unauthenticated** | ❌ Ditolak (`401`) | ❌ Ditolak (`401`) | Tidak ada berkas yang memiliki URL publik statis tanpa token. |

---

## 3. Pencegahan Manipulasi Data & Serangan Kritis

### 3.1 Pencegahan Manipulasi Status Pembayaran & Urutan Siklus (*Lifecycle Integrity*)
- Klien dilarang mengirimkan `status_pembayaran` saat membuat pesanan (`POST /api/orders`).
- Nilai status bayar hanya dapat diubah dari `Belum Bayar` menjadi `Sudah Bayar` melalui endpoint `POST /api/orders/:id/pay`.
- Nilai `payment_timestamp` dicatat dari clock server, bukan waktu perangkat klien.
- **Invarian Konfirmasi:** Backend secara mutlak melarang Admin mengubah status pekerjaan dari `Menunggu Konfirmasi` menjadi `Dikonfirmasi` apabila `status_pembayaran != 'Sudah Bayar'`.
- **Invarian Penugasan:** Backend melarang penugasan (`POST /api/orders/:id/assign`) jika pesanan masih berada pada status `Menunggu Konfirmasi`. Status wajib sudah `Dikonfirmasi`.
- **Invarian Otoritas Transisi:**
  - Admin dilarang memanipulasi status operasional lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`) via endpoint generic.
  - Cleaner hanya berwenang memajukan status pesanan miliknya hingga `Sedang Dikerjakan`.
  - Perubahan status ke `Selesai` hanya dapat dipicu melalui formulir Quality Report terverifikasi (`POST /api/quality-reports`).
- **Invarian Pembatalan (*Cancellation Guardrails*):**
  - Pelanggan hanya diizinkan membatalkan mandiri pada status `Menunggu Konfirmasi`, `Dikonfirmasi`, dan `Petugas Ditugaskan`. Pelanggan diblokir membatalkan saat `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`, atau `Selesai` (`403 Forbidden`).
  - Admin diizinkan melakukan pembatalan darurat operasional kapan saja sebelum `Selesai` (termasuk saat `Sedang Dikerjakan`). Pembatalan wajib mencatat alasan, diaudit di `status_logs`, dan memulihkan status cleaner ke `Aktif`.
- **Invarian Timestamp Quality Report:**
  - Backend memvalidasi integritas kronologis: `started_at <= completed_at <= submitted_at` dan `completed_at <= NOW()`. Manipulasi timestamp di luar urutan atau waktu masa depan ditolak dengan status HTTP `400 Bad Request` (`INVALID_TIMESTAMPS`).

### 3.2 Pencegahan Injeksi Berkas Arbitrer (*Storage Path Tampering*)
- Saat cleaner mengirimkan Quality Report, klien mengirimkan `foto_before_path` dan `foto_after_path`.
- Backend memvalidasi secara ketat:
  1. String path wajib berawalan `orders/{order_id}/`. Klien dilarang menyuntikkan path berkas milik pesanan lain (mencegah pencurian foto antar-order).
  2. Server melakukan pengecekan eksistensi berkas fisik ke Supabase Storage via `storage.from('quality-reports').list(...)`. Jika berkas tidak ada, request ditolak dengan `404 Not Found`.
  3. Seluruh checklist area pembersihan template layanan wajib diverifikasi tuntas (`completed: true`). Validasi parsial ditolak.

### 3.3 Pencegahan Bentrok Jadwal (*Anti-Double Booking Invariant*)
- Validasi ketersediaan jadwal wajib dieksekusi di dalam transaksi database sebelum menyimpan penetapan `cleaner_id`.
- Formula: $\max(start_N, start_E) < \min(end_N + 30', end_E + 30')$.
- Jika terjadi bentrok jadwal saat konfirmasi/penugasan oleh Admin, server mengembalikan status HTTP `409 Conflict`.

---

## 4. Pengelolaan Kunci Rahasia (*Secrets Management*)

| Kunci / Variabel | Lingkungan yang Diizinkan | Kebijakan & Batasan Keras |
| :--- | :--- | :--- |
| `SUPABASE_SERVICE_ROLE_KEY` | **Backend Server Saja (`.env`)** | **DILARANG KERAS** dibocorkan ke frontend, file statis di `public/`, atau response JSON `/api/config`. Pelanggaran terhadap aturan ini merupakan insiden keamanan fatal. |
| `SUPABASE_URL` | Frontend & Backend | Informasi publik alamat server Supabase. |
| `SUPABASE_ANON_KEY` | Frontend & Backend | Kunci publik aman dengan hak akses terbatas yang dikontrol oleh Row Level Security (RLS). |

---

## 5. Validasi & Sanitasi Berkas Unggahan (*File Upload Hardening*)

1. **Validasi Tipe MIME:** Hanya berkas dengan tipe `image/jpeg`, `image/png`, dan `image/webp` yang diizinkan untuk diproses.
2. **Kompresi Wajib di Sisi Klien:** Foto wajib melewati pipeline kompresi Canvas di browser sebelum diunggah untuk menekan ukuran berkas ke kisaran aman **1–2 MB**.
3. **Masa Kedaluwarsa Signed URL:** Tautan unduh yang diterbitkan oleh API dibatasi maksimal **30 menit (1800 detik)**. Setelah waktu tersebut, akses ditutup kembali secara otomatis.
