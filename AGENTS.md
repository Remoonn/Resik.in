# AGENTS.md — Onboarding & Operating Guide AI Coding Assistant (Resik.in)

> **Status:** Active Operational & Behavioral Guide for AI Coding Assistants  
> **Repository:** Resik.in — Prototipe Aplikasi Jasa Kebersihan On-Demand  
> **Target Pengguna AI:** Claude Code, Codex, Antigravity, Cursor, dan AI Agents lainnya.

---

## 1. Ringkasan Proyek & Struktur Dokumentasi

**Resik.in** adalah prototipe aplikasi mobile jasa kebersihan *on-demand* (Rumah, Kos, Kantor, Pasca Renovasi) berbasis Flutter (Android & iOS) yang mendigitalisasi alur pemesanan manual menjadi sistem terstruktur dengan rekomendasi petugas deterministik, pelacakan status bertahap, dan pelaporan mutu digital (*Quality Report*).

### Struktur Dokumentasi Resmi (Repository Directory):
Seluruh spesifikasi, aturan bisnis, dan kontrak teknis dipisahkan secara modular pada direktori `docs/`:

```text
AGENTS.md               # Panduan perilaku, coding principles, dan workflow AI agent
CLAUDE.md               # Instruksi operasional spesifik Claude / Claude Code

docs/
├── PRD-Resik.in.md     # Source of Truth (SOT) Fungsional, Scope, dan Requirement Produk
├── BUSINESS-RULES.md   # Aturan bisnis detail, formula kalkulasi, dan validasi operasional
├── ARCHITECTURE.md     # Arsitektur sistem, tech stack, dan alur perakitan dashboard
├── DATA-DICTIONARY.md  # Definisi entitas, kamus data, tipe, dan batasan skema database
├── API.md              # Kontrak endpoint REST API dan format respons JSON standar
├── SECURITY.md         # Invarian keamanan, hak akses RBAC, dan penanganan file upload
├── TESTING.md          # Strategi pengujian otomatis dan skenario uji aturan kritis
└── ROADMAP.md          # Milestone rilis fitur: V1 (Prototype), V1.1 (Phase 2), V2 (Phase 3)
```

---

## 2. Source of Truth & Integritas Requirement

- **Dokumen Acuan Tunggal:** [docs/PRD-Resik.in.md](docs/PRD-Resik.in.md) bersama [docs/BUSINESS-RULES.md](docs/BUSINESS-RULES.md) adalah **Source of Truth (SOT) mutlak** untuk seluruh spesifikasi fungsional, batasan sistem, alur bisnis, dan skema data.
- **Larangan Modifikasi Scope Sepihak:** AI **DILARANG KERAS** menambah, mengubah, mengurangi, atau memodifikasi requirement secara diam-diam tanpa instruksi eksplisit dari Tech Lead / User.
- **Prosedur Resolusi Konflik:** Jika ditemukan kontradiksi antara dokumen di `docs/`, skema database (`database/schema.sql`), dan kode berjalan:
  1. **JANGAN MENEBAK** atau mengambil keputusan sepihak.
  2. **STOP** dan paparkan titik konflik secara objektif.
  3. Minta arahan dan keputusan dari Tech Lead sebelum melanjutkan implementasi kode.

---

## 3. Tech Stack & Arsitektur Sistem

| Komponen | Teknologi | Keterangan & Catatan Arsitektur |
| :--- | :--- | :--- |
| **Frontend UI (Mobile)** | Flutter (Dart) | Aplikasi mobile lintas platform (Android & iOS) di direktori `mobile/`. Mencakup antarmuka Pelanggan, Petugas Lapangan, dan Admin. |
| **Backend REST API** | Node.js + Express.js | Arsitektur ES Module (`"type": "module"`) di direktori `backend/`. Router modular berada di `backend/routes/` (`services.js`, `cleaners.js`, `orders.js`, `auth.js`, `quality-reports.js`). |
| **Database** | Supabase PostgreSQL | Penyimpanan relasional utama (Kawasan Singapore). Skema di `database/schema.sql`. Memiliki *fallback* in-memory store (`lib/supabase.js`) saat offline/demo. |
| **Autentikasi & Sesi** | Supabase Auth + JWT Session | **Single source of truth:** Dikelola sepenuhnya oleh Supabase Auth (`auth.users`). Tidak ada penyimpanan password lokal atau `password_hash` di tabel aplikasi. |
| **Penyimpanan Berkas** | Supabase Storage (`quality-reports`) | Bucket khusus untuk menyimpan berkas dokumentasi foto *Before* dan *After*. |
| **Hosting Backend** | Vercel / Cloud | REST API backend server platform. |

---

## 4. Konvensi Coding & Prinsip Rekayasa Perangkat Lunak

- **Prinsip Perubahan Minimal (*Minimal Diff Principle*):**
  - Lakukan perubahan dengan bedah kode presisi hanya pada baris atau fungsi yang relevan.
  - **DILARANG** melakukan refactoring massal, restrukturisasi file yang tidak diminta, atau menghapus komentar yang ada tanpa instruksi eksplisit.
- **Arsitektur Pemisahan Tanggung Jawab (Separation of Concerns):**
  - Kode backend berada di `backend/` dan mematuhi kontrak REST API pada `docs/API.md`.
  - Kode mobile Flutter berada di `mobile/` dengan struktur modular (`models`, `services`, `screens`, `widgets`).
- **Backend Style & Format Respons:**
  - Gunakan sintaks ES Module modern (`import` / `export`).
  - Respons API wajib konsisten menggunakan amplop JSON standar:
    - Sukses: `{ "success": true, "message": "...", "data": { ... } }`
    - Galat: `{ "success": false, "message": "...", "error": "..." }`
- **Error Handling Komprehensif:**
  - Setiap endpoint Express wajib membungkus logika asinkron dalam blok `try / catch` dan meneruskan galat ke central JSON error handler.
  - Jangan pernah membiarkan error Express membocorkan HTML trace stack ke klien.
- **Immutability Data:**
  - Selalu buat objek/array baru saat transformasi data; jangan memutasi variabel state global secara sembarangan.

---

## 5. Keamanan, Otorisasi, & Validasi Backend

1. **Otorisasi Server-Side (RBAC Wajib):**
   - **JANGAN PERNAH** hanya mengandalkan pengecekan antarmuka pengguna untuk membatasi akses peran. Seluruh endpoint mutasi dan query data wajib divalidasi di backend (Express middleware / RLS Supabase).
   - Endpoint `GET /api/orders` wajib menerapkan isolasi peran:
     - `customer`: hanya dapat membaca pesanannya sendiri (`customer_id = auth.uid()`).
     - `cleaner`: hanya dapat membaca pesanan yang ditugaskan ke dirinya (`cleaner_id`).
     - `admin`: memiliki hak membaca seluruh pesanan.
2. **Pengelolaan Secrets & API Keys:**
   - Kunci sensitif `SUPABASE_SERVICE_ROLE_KEY` **HANYA BOLEH DIGUNAKAN DI SISI BACKEND** (`.env`).
   - **DILARANG KERAS** membocorkan service-role key ke frontend, file statis di `public/`, atau response JSON `/api/config`.
   - Frontend hanya boleh menerima `SUPABASE_URL` dan `SUPABASE_ANON_KEY`.
3. **Pencegahan Double Booking (Bentrok Jadwal):**
   - Backend wajib memvalidasi jadwal sebelum menyimpan pesanan atau penugasan (`cleaner_id`).
   - Validasi: Memperhitungkan `start_time`, `end_time = start_time + duration`, dan buffer operasional 30 menit sesuai [docs/BUSINESS-RULES.md](docs/BUSINESS-RULES.md).
4. **Validasi & Penanganan Upload File:**
   - Periksa tipe MIME file gambar (`image/jpeg`, `image/png`, `image/webp`).
   - Foto wajib dikompresi di sisi browser (1–2 MB) sebelum diunggah ke Supabase Storage bucket `quality-reports`.
5. **Integritas Lifecycle & Gerbang Pembayaran:**
   - Admin dilarang mengonfirmasi pesanan (`Menunggu Konfirmasi` → `Dikonfirmasi`) jika `status_pembayaran != 'Sudah Bayar'`.
   - Penugasan petugas (`POST /api/orders/:id/assign`) hanya diizinkan pada pesanan berstatus `Dikonfirmasi`.
   - Transisi status lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`) adalah hak eksklusif Cleaner; transisi ke `Selesai` wajib melalui pengiriman Quality Report via `POST /api/quality-reports`. Admin dilarang mengubah status lapangan secara sembarangan.

---

## 6. Cara Menjalankan Test & Build (Aturan Tanpa Mengarang Perintah)

**ATURAN UTAMA:** Selalu periksa `package.json` di `backend/` dan `pubspec.yaml` di `mobile/` terlebih dahulu. **JANGAN PERNAH MENGARANG COMMAND**.

Script dan perintah resmi di repository:
- **Backend REST API (`backend/`):**
  - Menjalankan Test Suite Backend: `cd backend && npm test`
  - Menjalankan Server Mode Dev: `cd backend && npm run dev`
  - Menjalankan Server Mode Produksi: `cd backend && npm start`
- **Mobile Flutter App (`mobile/`):**
  - Menganalisis Kode Dart: `cd mobile && flutter analyze`
  - Menjalankan Unit/Widget Test: `cd mobile && flutter test`
  - Menjalankan Aplikasi di Emulator/Device: `cd mobile && flutter run`

---

## 7. Batasan & Larangan Keras (*Out-of-Scope & Anti-Patterns*)

Untuk menjaga fokus skripsi dan stabilitas sistem, AI dilarang keras melakukan hal-hal berikut:

- ❌ **JANGAN mengintegrasikan Payment Gateway live** (seperti Midtrans, Xendit, Stripe, atau bank API riil). Sistem prototipe ini hanya menggunakan simulasi checkout dummy (`Belum Bayar` $\rightarrow$ `Sudah Bayar`).
- ❌ **JANGAN membuat chatbot AI interaktif** untuk konsultasi kebutuhan (fitur ini resmi ditunda dari scope prototipe).
- ❌ **JANGAN membuat pelacakan koordinat GPS live** di peta digital. Cukup gunakan representasi stepper progres 7 tahapan status.
- ❌ **JANGAN membuat modul payroll**, bagi hasil, atau transfer gaji petugas kebersihan.
- ❌ **JANGAN membuat formulir registrasi mandiri untuk petugas kebersihan** (akun petugas didaftarkan secara internal oleh Admin).
- ❌ **JANGAN membuat sistem manajemen inventaris stok bahan pembersih** atau pembukuan akuntansi laba-rugi perusahaan.
- ❌ **JANGAN menerapkan algoritma Machine Learning yang rumit** yang memerlukan pelatihan dataset besar. Rekomendasi wajib murni rule-based deterministik.
- ❌ **JANGAN mengganti tech stack utama** (Frontend: Flutter / Dart, Backend: Node.js / Express, Database: Supabase) dengan stack lain tanpa instruksi eksplisit tertulis dari Tech Lead.
- ❌ **JANGAN mengekspos credential rahasia** (`SUPABASE_SERVICE_ROLE_KEY`) ke frontend mobile atau commit file rahasia ke repository.
- ❌ **JANGAN melakukan refactor besar-besaran** jika tiket tugas hanya meminta perbaikan atau penyesuaian minor.

---

## 8. Workflow AI Coding Assistant

Setiap kali AI menerima instruksi atau tugas baru pada proyek Resik.in, jalankan siklus 5 tahap berikut:

```
[ 1. INSPECT ] ──> [ 2. PLAN ] ──> [ 3. IMPLEMENT ] ──> [ 4. VERIFY ] ──> [ 5. REPORT ]
```

1. **INSPECT (Pemeriksaan Awal):**
   - Pahami kebutuhan tugas dan rujuk ke dokumen `docs/PRD-Resik.in.md` dan `docs/BUSINESS-RULES.md`.
   - Telusuri file dan komponen yang terlibat. Cek apakah ada script build terkait.
   - Periksa `package.json` untuk mengetahui perintah yang valid.
2. **PLAN (Perencanaan Terukur):**
   - Rancang langkah perubahan dengan cakupan diff terkecil (*minimal diff*).
   - Pastikan rencana menghormati isolasi hak akses (RBAC), siklus 7 status, dan aturan anti-double booking.
   - Jika terdapat pertentangan spesifikasi atau dependensi ambigu: **STOP dan tanyakan kepada pengguna**.
3. **IMPLEMENT (Eksekusi Kode):**
   - Tulis kode yang bersih, modular, dan mengikuti konvensi proyek (ES Module, Vanilla JS).
   - Terapkan validasi server-side dan error handling di backend.
   - Jika menyentuh dashboard pelanggan, lakukan perubahan di `public/components/` atau `public/js/modules/`, lalu jalankan `npm run build`.
4. **VERIFY (Verifikasi & Pengujian Mandiri):**
   - Jalankan `npm test` untuk membuktikan tidak ada regresi pada seluruh test suite.
   - Pastikan perubahan lulus uji fungsional dan tidak memicu warning atau error di console/server.
5. **REPORT (Pelaporan Ringkas & Terbukti):**
   - Sajikan laporan perubahan yang ringkas, transparan, dan langsung pada pokok masalah.
   - Sertakan bukti hasil verifikasi (status kelulusan test) tanpa narasi bertele-tele.
