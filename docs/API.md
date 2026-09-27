# SPESIFIKASI KONTRAK REST API
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

> **Status Dokumen:** Active REST API Contract Specification  
> **Versi Dokumen:** 1.2 (Hardened & Specification-Complete)  
> **Tanggal Pembaruan:** 26 September 2026  
> **Dokumen Induk:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/SECURITY.md`  

---

## 1. Konvensi Komunikasi & Standard Response Envelope

Seluruh endpoint backend Resik.in menggunakan protokol HTTP/HTTPS dengan format payload JSON.

### 1.1 Format Respons Sukses (HTTP 200, 201)
```json
{
  "success": true,
  "message": "Deskripsi singkat keberhasilan aksi",
  "data": { ... }
}
```

### 1.2 Format Respons Galat (HTTP 400, 401, 403, 404, 409, 500)
```json
{
  "success": false,
  "message": "Pesan galat yang informatif dan ramah pengguna",
  "error": "Kode atau rincian teknis galat"
}
```

---

## 2. Rincian Endpoint Lengkap

### 2.1 Modul Layanan (`/api/services`)

#### `GET /api/services`
- **Method:** `GET`
- **Endpoint:** `/api/services`
- **Authorization:** Publik (Semua role / unauthenticated).
- **Request Params:** `?all=true` (Opsional, khusus Admin untuk melihat layanan non-aktif).
- **Validation:** None.
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Katalog layanan berhasil diambil",
    "data": [
      {
        "id": "uuid",
        "nama_layanan": "Pembersihan Rumah",
        "kategori": "rumah",
        "deskripsi": "Layanan pembersihan menyeluruh...",
        "durasi_estimasi": 2,
        "tarif_dasar": 120000.00,
        "icon_name": "home",
        "is_active": true
      }
    ]
  }
  ```
- **Error Response (HTTP 500):** Server database error.
- **Business Rule:** BR-FIN-002 (menampilkan `tarif_dasar` sebagai harga master service).

#### `PUT /api/services/:id/toggle`
- **Method:** `PUT`
- **Endpoint:** `/api/services/:id/toggle`
- **Authorization:** Wajib Bearer Token Admin (`role = 'admin'`).
- **Validation:** `:id` harus berupa valid UUID dan layanan ada.
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Status penawaran layanan berhasil diubah",
    "data": { "id": "uuid", "is_active": false }
  }
  ```
- **Error Response:** `401 Unauthorized`, `403 Forbidden`, `404 Not Found`.

---

### 2.2 Modul Petugas & Rekomendasi (`/api/cleaners`)

#### `GET /api/cleaners`
- **Method:** `GET`
- **Endpoint:** `/api/cleaners`
- **Authorization:** Wajib Admin (`role = 'admin'`).
- **Success Response (HTTP 200):** Mengembalikan seluruh profil petugas (termasuk `foto_url`, status operasional, keahlian).

#### `GET /api/cleaners/recommendations`
- **Method:** `GET`
- **Endpoint:** `/api/cleaners/recommendations`
- **Authorization:** Wajib Pengguna Terautentikasi (`customer`).
- **Request Query:** `tanggal` (YYYY-MM-DD), `start_time` (HH:MM), `service_id` (UUID).
- **Validation:**
  - `tanggal` $\ge H+0$ (tidak boleh masa lampau).
  - `start_time` berada di antara `08:00` s.d. `17:00`.
  - `service_id` valid.
- **Business Rule:** BR-SCH (interval + buffer 30 menit), BR-MTG (Hard Filter & Scoring 40/30/20/10).
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Rekomendasi petugas berhasil dihitung",
    "data": {
      "kandidat": [
        {
          "id": "uuid-candra",
          "nama": "Candra Pratama",
          "foto_url": "https://storage.supabase.co/.../candra.webp",
          "keahlian": ["pasca_renovasi", "general_cleaning"],
          "pengalaman_tahun": 4,
          "rating_rata_rata": 4.9,
          "total_pekerjaan": 127,
          "is_provisional_rating": false,
          "total_score": 98.0,
          "match_badge": "Sangat Sesuai"
        },
        {
          "id": "uuid-petugas-baru",
          "nama": "Joko Widodo",
          "foto_url": "https://storage.supabase.co/.../joko.webp",
          "keahlian": ["general_cleaning"],
          "pengalaman_tahun": 1,
          "rating_rata_rata": 4.5,
          "total_pekerjaan": 0,
          "is_provisional_rating": true,
          "total_score": 85.0,
          "match_badge": "Petugas Baru (Rating Awal 4.5)"
        }
      ],
      "total_kandidat": 2
    }
  }
  ```
- **Error Response:** `400 Bad Request` jika tanggal lampau atau parameter tidak lengkap.

---

### 2.3 Modul Pesanan (`/api/orders`)

#### `POST /api/orders` (Pembuatan Pesanan / Booking)
- **Method:** `POST`
- **Endpoint:** `/api/orders`
- **Authorization:** Wajib Pelanggan Terautentikasi (`role = 'customer'`).
- **Request Body:**
  ```json
  {
    "service_id": "uuid",
    "alamat_lengkap": "Jl. Kaliurang KM 14.5 No. 20, Sleman",
    "patokan_lokasi": "Depan Warung Madura cat biru",
    "luas_area": "Tipe 36",
    "catatan_khusus": "Tolong bersihkan sarang laba-laba di langit-langit",
    "tanggal_layanan": "2026-09-28",
    "start_time": "08:00",
    "preferensi_petugas_id": "uuid-cleaner-optional"
  }
  ```
  *(Catatan: Klien **DILARANG** mengirimkan `status_pembayaran`)*.
- **Validation:**
  - `tanggal_layanan` $\ge H+0$.
  - `start_time` di antara `08:00` s.d. `17:00`.
  - Jika `preferensi_petugas_id` disertakan, petugas harus aktif dan tidak bentrok.
- **Server Actions:**
  - Mengambil tarif dasar paket: $\text{harga\_saat\_booking} = \text{services.tarif\_dasar}$.
  - Mengunci total biaya: $\text{total\_biaya} = \text{harga\_saat\_booking}$.
  - Menghitung $\text{end\_time} = \text{start\_time} + \text{service.durasi\_estimasi}$.
  - Mengeset: `status_pembayaran = 'Belum Bayar'`, `payment_timestamp = NULL`, `status_pekerjaan = 'Menunggu Konfirmasi'`.
- **Success Response (HTTP 201 Created):**
  ```json
  {
    "success": true,
    "message": "Pesanan berhasil dibuat, silakan selesaikan pembayaran",
    "data": {
      "id": "uuid-order",
      "order_code": "RSK-20260928-001",
      "harga_saat_booking": 120000.00,
      "total_biaya": 120000.00,
      "status_pembayaran": "Belum Bayar",
      "status_pekerjaan": "Menunggu Konfirmasi"
    }
  }
  ```
- **Error Response:** `400 Bad Request`, `401 Unauthorized`.

#### `POST /api/orders/:id/pay` (Simulasi Pembayaran Server-Authoritative)
- **Method:** `POST`
- **Endpoint:** `/api/orders/:id/pay`
- **Authorization:** Wajib Pemilik Pesanan (`customer_id = auth.uid()`).
- **Validation:** Pesanan ada dan saat ini berstatus `status_pembayaran = 'Belum Bayar'`.
- **Server Actions:**
  - Mengubah `status_pembayaran` menjadi `'Sudah Bayar'`.
  - Menetapkan `payment_timestamp = NOW()` (waktu server).
  - Mencatat aksi pembayaran ke tabel `status_logs`.
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Simulasi pembayaran berhasil diverifikasi",
    "data": {
      "id": "uuid-order",
      "status_pembayaran": "Sudah Bayar",
      "payment_timestamp": "2026-09-28T08:05:00.000Z"
    }
  }
  ```
- **Error Response:** `400 Bad Request` (jika sudah bayar), `403 Forbidden` (bukan pemilik), `404 Not Found`.

#### `GET /api/orders`
- **Method:** `GET`
- **Endpoint:** `/api/orders`
- **Authorization:** Terautentikasi (Multi-role).
- **Isolasi RBAC:**
  - `customer`: Otomatis difilter `customer_id = auth.uid()`.
  - `cleaner`: Otomatis difilter `cleaner_id = cleaner_profile.id`.
  - `admin`: Menampilkan seluruh pesanan, mendukung filter `?status=...` dan search `?q=...`.
- **Success Response (HTTP 200):** Array pesanan (tiap objek memuat `id`, `order_code`, `service`, `tanggal_layanan`, `status_pembayaran`, `status_pekerjaan`).

#### `GET /api/orders/:id` (Detail Lengkap Pesanan)
- **Method:** `GET`
- **Endpoint:** `/api/orders/:id`
- **Authorization:** Terautentikasi (Multi-role).
- **Isolasi RBAC:**
  - `customer`: Hanya dapat mengakses jika `customer_id = auth.uid()`.
  - `cleaner`: Hanya dapat mengakses jika ditugaskan pada pesanan tersebut (`cleaner_id = cleaner_profile.id`).
  - `admin`: Dapat mengakses seluruh detail pesanan.
- **Validation:** Pesanan ditemukan dan user memiliki hak otorisasi.
- **Success Response (HTTP 200 OK):**
  ```json
  {
    "success": true,
    "message": "Detail pesanan berhasil diambil",
    "data": {
      "id": "uuid-order",
      "order_code": "RSK-20260928-001",
      "service": {
        "id": "uuid-service",
        "nama_layanan": "Pembersihan Rumah",
        "kategori": "rumah",
        "durasi_estimasi": 2
      },
      "customer": {
        "id": "uuid-customer",
        "nama": "Ahmad Dani",
        "nomor_wa": "081234567890"
      },
      "jadwal": {
        "tanggal_layanan": "2026-09-28",
        "start_time": "08:00",
        "end_time": "10:00",
        "duration": 2
      },
      "lokasi": {
        "alamat_lengkap": "Jl. Kaliurang KM 14.5 No. 20, Sleman",
        "patokan_lokasi": "Depan Warung Madura cat biru",
        "luas_area": "Tipe 36"
      },
      "catatan_khusus": "Tolong bersihkan sarang laba-laba di langit-langit",
      "keuangan": {
        "harga_saat_booking": 120000.00,
        "total_biaya": 120000.00,
        "status_pembayaran": "Sudah Bayar",
        "payment_timestamp": "2026-09-28T08:05:00.000Z"
      },
      "status_pekerjaan": "Petugas Ditugaskan",
      "cleaner": {
        "id": "uuid-cleaner",
        "nama": "Candra Pratama",
        "nomor_kontak": "081987654321",
        "foto_url": "https://example.com/cleaners/candra.jpg"
      },
      "preferensi_cleaner": {
        "id": "uuid-cleaner",
        "nama": "Candra Pratama"
      },
      "quality_report": null,
      "created_at": "2026-09-28T08:00:00.000Z"
    }
  }
  ```
- **Error Response:** `401 Unauthorized`, `403 Forbidden` (bukan pemilik/petugas terkait), `404 Not Found`.

#### `POST /api/orders/:id/assign` (Penugasan Hibrida oleh Admin)
- **Method:** `POST`
- **Endpoint:** `/api/orders/:id/assign`
- **Authorization:** Admin Saja (`role = 'admin'`).
- **Request Body:** `{ "cleaner_id": "uuid" }` (Konfirmasi preferensi pelanggan atau alokasi mandiri).
- **Validation:**
  - Status pesanan **WAJIB** berada pada status `Dikonfirmasi` (tidak boleh langsung dari `Menunggu Konfirmasi`).
  - Jika pesanan masih `Menunggu Konfirmasi`, request ditolak dengan `400 Bad Request` (`ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT`).
  - Petugas berstatus administratif `Aktif`.
  - Petugas bebas bentrok jadwal pada tanggal & interval (+ buffer 30 menit).
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Petugas berhasil ditugaskan ke pesanan",
    "data": {
      "id": "uuid-order",
      "cleaner_id": "uuid-cleaner",
      "status_pekerjaan": "Petugas Ditugaskan"
    }
  }
  ```
- **Error Response:** `400 Bad Request` (`ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT` / invalid payload), `409 Conflict` (`SCHEDULE_CONFLICT_DETECTED`).

#### `POST /api/orders/:id/reassign` (Penggantian Petugas Ber-Audit)
- **Method:** `POST`
- **Endpoint:** `/api/orders/:id/reassign`
- **Authorization:** Admin Saja (`role = 'admin'`).
- **Request Body:** `{ "new_cleaner_id": "uuid", "alasan": "Petugas lama sakit darurat" }`
- **Validation:**
  - Status pesanan wajib `Petugas Ditugaskan`.
  - Petugas pengganti berstatus `Aktif` dan bebas bentrok jadwal.
- **Server Actions:**
  - Memperbarui `cleaner_id = new_cleaner_id`.
  - Mencatat audit log di `status_logs`: `catatan = 'REASSIGN_CLEANER: dari {old} ke {new} - Alasan: {alasan}'`.
- **Success Response (HTTP 200):** Status 200 OK.
- **Error Response:** `400 Bad Request` (jika status pesanan sudah Menuju Lokasi ke atas), `409 Conflict` (jika pengganti bentrok).

#### `PATCH /api/orders/:id/status` (Transisi Status Sekuensial & Wewenang Peran)
- **Method:** `PATCH`
- **Endpoint:** `/api/orders/:id/status`
- **Authorization & Rules:**
  - **Admin:** Hanya berwenang melakukan transisi `Menunggu Konfirmasi` $\rightarrow$ `Dikonfirmasi`.
    - *Syarat Mutlak:* `status_pembayaran` wajib `'Sudah Bayar'`. Jika belum bayar, ditolak dengan `400 Bad Request` (`ORDER_NOT_PAID_YET`).
  - **Cleaner:** Hanya berwenang memajukan status operasional pesanan yang ditugaskan kepadanya:
    - `Petugas Ditugaskan` $\rightarrow$ `Menuju Lokasi`
    - `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi`
    - `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan` (mencatat `started_at = NOW()`).
  - **Dilarang untuk Keduanya:** Status `Selesai` **DILARANG** diubah melalui endpoint ini (wajib melalui `POST /api/quality-reports`).
- **Request Body:** `{ "status_baru": "Dikonfirmasi" }` (atau `"Menuju Lokasi"`, `"Tiba di Lokasi"`, `"Sedang Dikerjakan"`).
- **Validation:** Mengikuti matriks transisi sekuensial mutlak (BR-STS). Lompatan status ditolak.
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Status pekerjaan berhasil diperbarui",
    "data": {
      "id": "uuid-order",
      "status_pekerjaan": "Dikonfirmasi"
    }
  }
  ```
- **Error Response:** `400 Bad Request` (urutan salah / `ORDER_NOT_PAID_YET`), `403 Forbidden` (bukan aktor yang berwenang).

#### `POST /api/orders/:id/cancel` (Pembatalan Pesanan)
- **Method:** `POST`
- **Endpoint:** `/api/orders/:id/cancel`
- **Authorization:** Customer Pemilik atau Admin.
- **Request Body:** `{ "cancellation_reason": "Rencana mendadak berubah" }`
- **Validation:**
  - Alasan wajib diisi (minimal 5 karakter).
  - Jika Customer: status pekerjaan wajib `Menunggu Konfirmasi`, `Dikonfirmasi`, atau `Petugas Ditugaskan`. Ditolak jika `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`, atau `Selesai`.
  - Jika Admin: diizinkan membatalkan kapan saja sebelum status mencapai `Selesai` (termasuk tindakan darurat operasional saat `Menuju Lokasi`, `Tiba di Lokasi`, atau `Sedang Dikerjakan`).
- **Server Actions:**
  - Mengubah status pekerjaan menjadi `Dibatalkan`.
  - Mengisi `cancellation_reason`, `cancelled_by`, dan `cancelled_at = NOW()`.
  - Memulihkan status petugas bersangkutan (jika ada) kembali menjadi `Aktif`.
  - Mencatat aksi pembatalan ke `status_logs`.
- **Success Response (HTTP 200):** Pesanan berhasil dibatalkan.
- **Error Response:** `400 Bad Request`, `403 Forbidden`.

---

### 2.4 Modul Quality Report (`/api/quality-reports`)

#### `POST /api/quality-reports` (Submit Laporan Mutu & Selesaikan Order)
- **Method:** `POST`
- **Endpoint:** `/api/quality-reports`
- **Authorization:** Cleaner resmi yang ditugaskan (`auth.uid() = cleaner.user_id`).
- **Request Body:**
  ```json
  {
    "order_id": "uuid",
    "checklist_area": [
      { "area": "Ruang Tamu", "done": true },
      { "area": "Kamar Mandi", "done": true }
    ],
    "foto_before_path": "orders/uuid-order/before_1727376000.webp",
    "foto_after_path": "orders/uuid-order/after_1727379600.webp",
    "catatan_petugas": "Pembersihan tuntas, noda lantai berhasil diangkat.",
    "completed_at": "2026-09-26T10:00:00.000Z"
  }
  ```
- **Validation Pipeline (9 Tahap):**
  1. Verifikasi token: User terautentikasi adalah cleaner yang ditugaskan pada `order_id`.
  2. Verifikasi status: Pesanan wajib sedang berada pada status `Sedang Dikerjakan`.
  3. Verifikasi checklist template penuh: Seluruh area yang termasuk cakupan layanan sesuai template paket (Rumah, Kos, Kantor, Pasca Renovasi) wajib memiliki status `completed: true`. Validasi parsial ditolak.
  4. Verifikasi invarian timestamp server: Server memvalidasi urutan mutlak `started_at <= completed_at <= submitted_at` dan `completed_at <= NOW()`. Jika melanggar, ditolak dengan status HTTP `400 Bad Request` (`INVALID_TIMESTAMPS`).
  5. Verifikasi path: String `foto_before_path` dan `foto_after_path` wajib diawali dengan prefix `orders/{order_id}/`.
  6. Verifikasi berkas storage: Server memvalidasi bahwa berkas fisik benar-benar ada di private bucket `quality-reports` Supabase Storage.
  7. Simpan rekaman di `quality_reports` dengan `submitted_at = NOW()`.
  8. Ubah status pesanan menjadi `Selesai`.
  9. Pulihkan status cleaner ke `Aktif` dan tambahkan `total_pekerjaan` +1.
- **Success Response (HTTP 201 Created):**
  ```json
  {
    "success": true,
    "message": "Quality Report berhasil disimpan dan pesanan dinyatakan Selesai",
    "data": {
      "order_id": "uuid",
      "status_pekerjaan": "Selesai",
      "submitted_at": "2026-09-26T10:02:15.000Z"
    }
  }
  ```
- **Error Response:** `400 Bad Request` (payload/path salah / `CHECKLIST_AREAS_INCOMPLETE` / `INVALID_TIMESTAMPS`), `403 Forbidden` (bukan cleaner penanggung jawab), `404 Not Found` (berkas storage tidak ditemukan).

#### `GET /api/quality-reports/:order_id` (Inspeksi via Temporary Signed URL)
- **Method:** `GET`
- **Endpoint:** `/api/quality-reports/:order_id`
- **Authorization:** Customer Pemilik Pesanan, Cleaner Terkait, atau Admin.
- **Validation:** User memiliki hak akses terhadap order bersangkutan.
- **Server Action:** Server memanggil Supabase Storage `createSignedUrl` dengan masa berlaku 30 menit (1800 detik).
- **Success Response (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Quality report berhasil diambil",
    "data": {
      "order_id": "uuid",
      "cleaner_nama": "Candra Pratama",
      "checklist_area": [ ... ],
      "catatan_petugas": "Pembersihan tuntas...",
      "foto_before_signed_url": "https://storage.supabase.co/storage/v1/object/sign/quality-reports/orders/uuid/before.webp?token=...",
      "foto_after_signed_url": "https://storage.supabase.co/storage/v1/object/sign/quality-reports/orders/uuid/after.webp?token=...",
      "signed_url_expires_in": 1800,
      "started_at": "2026-09-26T08:00:00.000Z",
      "completed_at": "2026-09-26T10:00:00.000Z",
      "submitted_at": "2026-09-26T10:02:15.000Z"
    }
  }
  ```
- **Error Response:** `401 Unauthorized`, `403 Forbidden` (akses ditolak jika user lain), `404 Not Found`.

---

### 2.5 Modul Rating & Review (`/api/reviews` — Fase V1.1)

#### `POST /api/reviews`
- **Method:** `POST`
- **Endpoint:** `/api/reviews`
- **Authorization:** Wajib Pelanggan Pemilik Pesanan (`customer_id = auth.uid()`).
- **Request Body:**
  ```json
  {
    "order_id": "uuid",
    "rating": 5,
    "catatan_ulasan": "Petugas sangat rapi dan teliti."
  }
  ```
- **Validation:**
  - Status pesanan wajib `Selesai`.
  - `rating` bernilai integer antara 1 hingga 5.
  - Pesanan belum pernah diberi review sebelumnya.
- **Success Response (HTTP 201 Created):**
  ```json
  {
    "success": true,
    "message": "Rating dan ulasan berhasil dikirim",
    "data": { "id": "uuid", "rating": 5 }
  }
  ```
- **Error Response:** `400 Bad Request`, `403 Forbidden`, `409 Conflict` (jika order sudah pernah di-review).
