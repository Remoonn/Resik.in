# Spesifikasi Desain: Fase 2 (V1.1) — Rating & Ulasan Pelanggan (Customer Rating & Review)

> **Dokumen:** `docs/superpowers/specs/2026-09-30-phase-2-customer-review-design.md`  
> **Status:** Draft Disetujui  
> **Tanggal:** 30 September 2026  
> **Target Rilis:** Fase 2 / V1.1 (FR-11 — Penyempurnaan Pasca-Evaluasi)  
> **Referensi SOT:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `docs/DATA-DICTIONARY.md`, `docs/API.md`, `database/schema.sql`

---

## 1. Latar Belakang & Nilai Strategis

Pada Milestone V1 Prototype (Sprint 0 s.d. Sprint 4), sistem Resik.in telah menyelesaikan seluruh alur transaksi utama:
1. Katalog 4 Layanan Multi-Kategori (`FR-01`).
2. Penjadwalan Berbasis Interval & Buffer 30 Menit (`FR-02`).
3. Pemesanan Layanan & Simulasi Pembayaran Server-Authoritative (`FR-03`).
4. Direktori Master Data Petugas (`FR-04`).
5. Penugasan Petugas Hibrida Bebas Bentrok Jadwal (`FR-05`).
6. Manajemen Pesanan & Dasbor Admin (`FR-06`).
7. Pelacakan 7 Status Pekerjaan & Pembatalan Terstruktur (`FR-07`).
8. Autentikasi Tunggal Supabase Auth & Google Sign-In (`FR-08`).
9. Rekomendasi Petugas Cerdas Deterministik (*Smart Matching*) (`FR-09`).
10. Laporan Mutu Digital Berbukti Foto Before/After (*Digital Quality Report*) (`FR-10`).

### Problem Statement
Pada algoritma **Smart Matching (FR-09)**, komponen bobot terbesar adalah **Rating Petugas ($40\%$)**:
$$\text{Total Skor} = 40\% \times S_{\text{rating}} + 30\% \times S_{\text{pengalaman}} + 20\% \times S_{\text{kepuasan}} + 10\% \times S_{\text{ketepatan\_waktu}}$$
Hingga V1 Prototype selesai, semua petugas baru mengandalkan **Rating Provisional $4.5$** ($S_{\text{rating}} = 90.0$). Tanpa modul ulasan pelanggan, algoritma rekomendasi tidak memiliki siklus umpan balik tertutup (*closed feedback loop*).

### Tujuan Fase 2 (FR-11)
1. **Menutup Feedback Loop:** Menggantikan nilai provisional $4.5$ dengan nilai reputasi riil hasil penilaian pelanggan yang terakumulasi otomatis.
2. **Akuntabilitas & Apresiasi Mutu:** Memberikan kanal formal bagi pelanggan untuk mengapresiasi kinerja petugas setelah memeriksa Laporan Mutu digital.
3. **Transparansi Profil:** Menampilkan ulasan dan testimoni riil pelanggan pada profil publik petugas untuk meningkatkan kepercayaan calon pemesan.

---

## 2. Ruang Lingkup Fitur (Scope: FR-11)

| Kode Fitur | Deskripsi | Aktor Utama | Kriteria Keberhasilan |
| :--- | :--- | :--- | :--- |
| **FR-11** | Rating & Ulasan Pelanggan (*Customer Rating & Review*) | Pelanggan, Sistem | • Formulir modal bintang 1–5 + catatan teks opsional.<br>• Hanya dapat diisi untuk pesanan berstatus `Selesai` yang memiliki Quality Report.<br>• Validasi hak akses RBAC: hanya pelanggan pemilik pesanan (`customer_id`).<br>• Integritas *One Review per Order*: duplikasi ditolak `409 Conflict`.<br>• Agregasi otomatis reputasi petugas (`rating_rata_rata`) secara sinkron.<br>• Profil petugas menampilkan ulasan riil & banner provisional otomatis hilang saat $N > 0$. |

### Invarian Bisnis Kritis (Non-Negotiable Business Rules):
1. **BR-REV-001 (Kelayakan):** Ulasan hanya dapat dikirim jika pesanan berstatus `Selesai`. Pesanan dalam proses lapangan atau yang dibatalkan (`Dibatalkan`) ditolak server.
2. **BR-REV-002 (Otoritas & Duplikasi):** Hanya pelanggan pemilik pesanan (`customer_id = auth.uid()`) yang dapat mengisi. Satu pesanan hanya dapat menerima 1 ulasan. Pengiriman ulang ditolak HTTP `409 Conflict`.
3. **BR-REV-003 (Skala Bintang):** Bintang berupa bilangan bulat integer $1 \le \text{rating} \le 5$. Catatan ulasan teks opsional dengan batas maksimum 300 karakter.
4. **BR-REV-004 (Formula Agregasi Reputasi):**
   $$\text{cleaners.rating\_rata\_rata} = \text{ROUND}\left(\frac{\sum_{i=1}^{N} \text{rating}_i}{N}, 1\right)$$
   Nilai dibulatkan 1 angka di belakang koma (contoh: 4.8). `cleaners.total_pekerjaan` / `total_ulasan` diperbarui.
5. **BR-REV-005 (Immutability):** Ulasan yang telah tersimpan bersifat permanen (*read-only lock*) dan tidak dapat disunting ulang oleh pelanggan.

---

## 3. Skema Data & Basis Data Relasional

### 3.1 Skema Tabel `public.reviews`
Sesuai rancangan [database/schema.sql](file:///C:/Users/62859/Documents/Skripsi/Resik.in/database/schema.sql) dan [docs/DATA-DICTIONARY.md](file:///C:/Users/62859/Documents/Skripsi/Resik.in/docs/DATA-DICTIONARY.md):

```sql
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    cleaner_id UUID NOT NULL REFERENCES public.cleaners(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    catatan_ulasan TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeks performa pencarian ulasan per petugas dan per pesanan
CREATE INDEX IF NOT EXISTS idx_reviews_cleaner_id ON public.reviews (cleaner_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_order_id ON public.reviews (order_id);
```

### 3.2 Sinkronisasi Agregasi Database
- **PostgreSQL Trigger (Supabase):**
  Fungsi `update_cleaner_rating()` yang terpasang pada trigger `on_review_created` mengeksekusi kalkulasi ulang `rating_rata_rata` setiap kali baris baru masuk ke `public.reviews`.
- **Runtime Fallback (In-Memory / Backend API):**
  Untuk memastikan pengujian otomatis (`npm test`) dan mode offline tetap konsisten 100%, backend secara sinkron menghitung rata-rata ulasan di memori/database saat menangani request `POST /api/reviews`.

---

## 4. Kontrak Antarmuka REST API (`backend/routes/reviews.js`)

Semua respons menggunakan format standar amplop JSON Resik.in.

### 4.1 `POST /api/reviews` — Pengiriman Ulasan Baru
- **Method:** `POST`
- **Path:** `/api/reviews`
- **Header:** `Content-Type: application/json`, `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "order_id": "ord-12345",
    "rating": 5,
    "catatan_ulasan": "Petugas sangat teliti dan ramah, kamar mandi jadi kinclong!",
    "user_id": "usr-cust-001"
  }
  ```
- **Alur Validasi Server (5 Langkah):**
  1. Periksa keberadaan `order_id`. Jika tidak ditemukan $\rightarrow$ `404 Not Found` (`ORDER_NOT_FOUND`).
  2. Periksa otorisasi pemohon: `user_id` wajib sama dengan `order.customer_id`. Jika tidak cocok $\rightarrow$ `403 Forbidden` (`FORBIDDEN_NOT_ORDER_OWNER`).
  3. Periksa status pesanan: wajib berstatus `selesai`. Jika belum $\rightarrow$ `400 Bad Request` (`ORDER_NOT_COMPLETED`).
  4. Periksa validitas rating: wajib integer $1 \le \text{rating} \le 5$. Jika di luar rentang $\rightarrow$ `400 Bad Request` (`INVALID_RATING`).
  5. Periksa duplikasi ulasan: jika order sudah memiliki review $\rightarrow$ `409 Conflict` (`REVIEW_ALREADY_EXISTS`).
- **Response Sukses (`201 Created`):**
  ```json
  {
    "success": true,
    "message": "Rating dan ulasan berhasil dikirim",
    "data": {
      "id": "rev-98765",
      "order_id": "ord-12345",
      "customer_id": "usr-cust-001",
      "cleaner_id": "cln-001",
      "rating": 5,
      "catatan_ulasan": "Petugas sangat teliti dan ramah, kamar mandi jadi kinclong!",
      "created_at": "2026-09-30T13:30:00.000Z",
      "cleaner_summary": {
        "id": "cln-001",
        "rating_rata_rata": 4.9,
        "total_ulasan": 13
      }
    }
  }
  ```

### 4.2 `GET /api/reviews/order/:order_id` — Status Ulasan Pesanan Tertentu
- **Method:** `GET`
- **Tujuan:** Digunakan oleh aplikasi mobile untuk mengecek apakah pesanan tertentu sudah pernah diberi ulasan.
- **Response Sukses (`200 OK` jika sudah diulas):**
  ```json
  {
    "success": true,
    "data": {
      "id": "rev-98765",
      "order_id": "ord-12345",
      "rating": 5,
      "catatan_ulasan": "Petugas sangat teliti dan ramah, kamar mandi jadi kinclong!",
      "created_at": "2026-09-30T13:30:00.000Z"
    }
  }
  ```
- **Response Belum Diulas (`404 Not Found`):**
  ```json
  {
    "success": false,
    "message": "Pesanan belum memiliki ulasan",
    "error": "REVIEW_NOT_FOUND"
  }
  ```

### 4.3 `GET /api/reviews/cleaner/:cleaner_id` — Riwayat Ulasan Publik Petugas
- **Method:** `GET`
- **Query Params:** `limit` (default: 10)
- **Tujuan:** Mengambil ulasan riil untuk ditampilkan pada layar profil petugas.
- **Penyensoran Privasi:** Nama pelanggan ditampilkan dalam bentuk nama depan + inisial (misal: *"Ahmad F."* atau *"Pelanggan Resik.in"* jika anonim).
- **Response Sukses (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "cleaner_id": "cln-001",
      "rating_rata_rata": 4.9,
      "total_ulasan": 13,
      "reviews": [
        {
          "id": "rev-98765",
          "customer_name": "Ahmad F.",
          "rating": 5,
          "catatan_ulasan": "Petugas sangat teliti dan ramah, kamar mandi jadi kinclong!",
          "created_at": "2026-09-30T13:30:00.000Z"
        }
      ]
    }
  }
  ```

---

## 5. Arsitektur Komponen Mobile Flutter

```
mobile/lib/
├── models/
│   └── review_model.dart             # Model data ReviewModel (serialisasi JSON & entity)
├── services/
│   └── review_service.dart           # HTTP Service: submitReview, getReviewByOrderId, getCleanerReviews
├── widgets/
│   └── review_bottom_sheet.dart      # Modal Bottom Sheet rating 1-5 bintang interaktif & input catatan
├── screens/
│   ├── order_tracking_screen.dart    # Tombol "Beri Ulasan" & kartu ringkasan saat pesanan 'Selesai'
│   ├── quality_report_screen.dart    # Tombol "Beri Ulasan Petugas" di akhir laporan mutu
│   └── cleaner_detail_screen.dart    # Seksi baru daftar ulasan pelanggan riil
```

### 5.1 `ReviewModel` (`mobile/lib/models/review_model.dart`)
- Kolom: `id`, `orderId`, `customerId`, `customerName`, `cleanerId`, `rating`, `catatanUlasan`, `createdAt`.
- Factory constructor `fromJson(Map<String, dynamic> json)` dan method `toJson()`.

### 5.2 `ReviewService` (`mobile/lib/services/review_service.dart`)
- `Future<ReviewModel?> submitReview({required String orderId, required int rating, String? catatanUlasan})`: Mengirim ulasan ke `POST /api/reviews`.
- `Future<ReviewModel?> getReviewByOrderId(String orderId)`: Mengecek status ulasan pesanan.
- `Future<List<ReviewModel>> getCleanerReviews(String cleanerId)`: Mengambil daftar ulasan riil untuk profil petugas.

### 5.3 `ReviewBottomSheet` (`mobile/lib/widgets/review_bottom_sheet.dart`)
- **Interaksi Bintang:** Deretan 5 icon bintang `Icons.star_rounded` (warna amber `Color(0xFFF59E0B)` saat aktif, abu-abu saat nonaktif).
- **Label Emosional Dinamis:**
  - 1 Bintang: 🔴 *Sangat Kurang*
  - 2 Bintang: 🟠 *Kurang Memuaskan*
  - 3 Bintang: 🟡 *Cukup*
  - 4 Bintang: 🟢 *Memuaskan*
  - 5 Bintang: 🌟 *Sangat Puas & Bersih*
- **Formulir Catatan:** `TextFormField` 3 baris dengan validasi panjang maksimal 300 karakter.
- **Button State:** Tombol *"Kirim Ulasan"* berstatus disabled hingga pelanggan memilih minimal 1 bintang. Menampilkan `CircularProgressIndicator` saat pengiriman berlangsung.

### 5.4 Integrasi Layar Antarmuka
1. **Layar Pelacakan Pesanan (`OrderTrackingScreen`):**
   - Saat status `Selesai`: sistem secara otomatis memuat status ulasan via `reviewService.getReviewByOrderId`.
   - Jika **belum diulas**: Tampil tombol aksi sekunder di bawah banner Quality Report:
     `[⭐ Beri Rating & Ulasan Petugas]` yang membuka `ReviewBottomSheet`.
   - Jika **sudah diulas**: Tampil kartu ringkasan ulasan berwarna krem/amber dengan ikon centang terverifikasi:
     `Ulasan Anda: ⭐ 5/5 — "Petugas sangat teliti..." (Terkunci)`.
2. **Layar Laporan Mutu (`QualityReportScreen`):**
   - Di bagian footer layar setelah checklist dan foto Before/After, tersedia tombol CTA yang sama untuk memudahkan pelanggan memberi ulasan langsung setelah inspeksi mutu.
3. **Layar Profil Petugas (`CleanerDetailScreen`):**
   - Jika `cleaner.total_ulasan > 0`:
     - Banner *"Petugas Baru (Rating Awal 4.5)"* secara otomatis **tidak ditampilkan**.
     - Tampil kartu metrik rating rata-rata aktual: `⭐ 4.9 (13 ulasan)`.
     - Seksi baru: **"Ulasan Pelanggan"** dengan `ListView` kartu ulasan yang memuat inisial nama, bintang, tanggal, dan komentar pelanggan.

---

## 6. Strategi Pengujian Otomatis (TDD & Quality Gates)

### 6.1 Pengujian Backend REST API (`backend/test/reviews.test.js`)
1. **Validasi Skala Rating:** Pengiriman rating bernilai 0, 6, -1, atau string ditolak dengan `400 Bad Request`.
2. **Validasi Status Pesanan:** Pengiriman ulasan pada pesanan yang masih `sedang_dikerjakan` atau `dibatalkan` ditolak dengan `400 Bad Request`.
3. **Validasi Hak Akses (RBAC):** Upaya pengguna lain (bukan pemesan) mengirimkan ulasan ditolak dengan `403 Forbidden`.
4. **Validasi Anti-Duplikasi:** Pengiriman ulasan kedua pada pesanan yang sama ditolak dengan `409 Conflict`.
5. **Akurasi Agregasi Reputasi:**
   - Cleaner awal memiliki ulasan rating 5 dan rating 4.
   - Server memverifikasi bahwa `cleaners.rating_rata_rata` menjadi `4.5` dan `total_ulasan` bertambah menjadi 2.
6. **GET Status Ulasan Pesanan:** Mengembalikan `200 OK` jika sudah diulas, dan `404 Not Found` jika belum diulas.
7. **GET Riwayat Ulasan Petugas:** Mengembalikan daftar ulasan dengan penyensoran nama pelanggan untuk privasi.

### 6.2 Pengujian Mobile Flutter
1. **Unit Test Serialisasi (`mobile/test/review_model_test.dart`):** Pengujian mapping JSON model `ReviewModel`.
2. **Service Test (`mobile/test/review_service_test.dart`):** Pengujian mock API request untuk submit dan fetch ulasan.
3. **Widget Test (`mobile/test/review_bottom_sheet_test.dart`):**
   - Memastikan tombol submit dalam kondisi dinonaktifkan saat belum ada bintang yang dipilih.
   - Memastikan label emosional berubah saat bintang ditekan (misal: bintang 5 memunculkan teks "Sangat Puas & Bersih").
   - Memastikan tombol submit aktif dan callback terpanggil saat bintang dipilih.
4. **Widget Test Integrasi Pelacakan (`mobile/test/order_tracking_review_test.dart`):**
   - Menampilkan tombol ulasan pada status `Selesai` saat belum diulas.
   - Menampilkan kartu ulasan tersimpan saat pesanan telah diulas.
5. **Widget Test Profil Petugas (`mobile/test/cleaner_detail_review_test.dart`):**
   - Memastikan daftar ulasan muncul saat petugas memiliki ulasan riil.

---

## 7. Penanganan Kasus Tepi (Edge Cases & Resilience)

1. **Jaringan Terputus saat Submit:**
   Jika koneksi internet putus saat menekan tombol kirim ulasan, aplikasi menampilkan *SnackBar* notifikasi kesalahan ramah pengguna dan tidak menutup sheet, sehingga pelanggan tidak perlu mengetik ulang catatannya.
2. **Double-Click pada Tombol Kirim:**
   Tombol submit memiliki state guard `_isSubmitting` yang langsung mengunci tombol begitu ditekan sekali untuk mencegah pengiriman request ganda dari sisi klien.
3. **Pembersihan Fixture Pengujian:**
   Semua data ulasan pengujian otomatis menggunakan format ID khusus `rev-test-*` sehingga secara otomatis terisolasi dan tidak mengotori data demo pada `.in_memory_state.json`.

---

## 8. Checklist Verifikasi & Kriteria Penerimaan

- [ ] Route `POST /api/reviews` dan `GET /api/reviews/...` terpasang di `backend/server.js`.
- [ ] 100% test suite backend `npm test` lulus tanpa kegagalan (target: 65+ total tests).
- [ ] Model `ReviewModel` dan service `ReviewService` terimplementasi di Flutter.
- [ ] `ReviewBottomSheet` interaktif berfungsi mulus dengan animasi sentuh bintang.
- [ ] Layar `OrderTrackingScreen` dan `QualityReportScreen` terintegrasi dengan alur review.
- [ ] Layar `CleanerDetailScreen` menampilkan riwayat ulasan riil dan menghapus banner rating awal jika $N > 0$.
- [ ] `flutter analyze` menghasilkan **0 issues found**.
- [ ] `flutter test` lulus **100% tanpa regresi** (target: 40+ tests).
