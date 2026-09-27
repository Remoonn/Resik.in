# CLAUDE.md — Operating Guidelines for Claude Code (Resik.in)

> **Status:** Active Guidance for Claude / Claude Code  
> **Repository:** Resik.in — Prototipe Aplikasi Jasa Kebersihan On-Demand  
> **Source of Truth Produk:** `docs/PRD-Resik.in.md` & `docs/BUSINESS-RULES.md`  

---

## 1. Panduan Cepat & Aturan Utama Claude

1. **Source of Truth (SOT) Spesifikasi:**
   - Seluruh requirement fungsional, batasan ruang lingkup, dan alur bisnis berada di [docs/PRD-Resik.in.md](docs/PRD-Resik.in.md).
   - Seluruh logika validasi, formula perhitungan ketersediaan, dan matriks transisi status berada di [docs/BUSINESS-RULES.md](docs/BUSINESS-RULES.md).
   - Dilarang membuat requirement baru atau mengubah scope yang telah ditentukan.
2. **Pedoman Perilaku Agent:**
   - Patuhi seluruh panduan rekayasa dan etika AI yang tercantum pada [AGENTS.md](AGENTS.md).
3. **Prinsip Perubahan Minimal (*Minimal Diff Principle*):**
   - Lakukan pengeditan terarah pada fungsi/baris yang relevan.
   - Hindari refactor besar-besaran yang tidak diminta. Pertahankan seluruh komentar dan struktur kode yang ada.
4. **Arsitektur Pemisahan Tanggung Jawab (*Separation of Concerns*):**
   - Layanan backend Express REST API berada di direktori `backend/` dan mematuhi kontrak API pada `docs/API.md`.
   - Antarmuka aplikasi mobile Flutter berada di direktori `mobile/`. Jaga keterpisahan antara models, services (API client), dan UI screens.

---

## 2. Perintah Resmi Repositori (*Valid CLI Commands*)

Jangan pernah mengarang perintah CLI baru. Gunakan perintah resmi:

```bash
# Backend REST API (Node.js + Express)
cd backend && npm test       # Menjalankan pengujian otomatis backend
cd backend && npm run dev    # Menjalankan server lokal mode pengembangan (hot-reload)
cd backend && npm start      # Menjalankan server lokal mode produksi

# Mobile Application (Flutter / Dart)
cd mobile && flutter analyze # Memeriksa kualitas & validitas kode Dart
cd mobile && flutter test    # Menjalankan pengujian widget/unit mobile
cd mobile && flutter run     # Menjalankan aplikasi mobile di emulator/device
```

---

## 3. Struktur Dokumentasi Proyek

Untuk memahami konteks arsitektur dan data secara lengkap, rujuk dokumen spesifik berikut:
- **Requirement Produk:** `docs/PRD-Resik.in.md`
- **Aturan Bisnis & Validasi:** `docs/BUSINESS-RULES.md`
- **Arsitektur Sistem & Build:** `docs/ARCHITECTURE.md`
- **Kamus Data & Skema Database:** `docs/DATA-DICTIONARY.md`
- **Kontrak REST API:** `docs/API.md`
- **Kebijakan Keamanan & RBAC:** `docs/SECURITY.md`
- **Rencana Pengujian:** `docs/TESTING.md`
- **Roadmap Pengembangan:** `docs/ROADMAP.md`

---

## 4. Invarian Kritis Sistem yang Wajib Dipertahankan

- **Gerbang Pembayaran Server-Authoritative:** Admin dilarang mengonfirmasi pesanan (`Menunggu Konfirmasi` → `Dikonfirmasi`) jika `status_pembayaran != 'Sudah Bayar'`. Simulasi pembayaran hanya sah melalui mutasi server `POST /api/orders/:id/pay`.
- **Sekuensial Penugasan Petugas:** Penugasan petugas (`POST /api/orders/:id/assign`) hanya dapat dilakukan jika pesanan telah berstatus `Dikonfirmasi`. Alur lifecycle dilarang melompati status konfirmasi.
- **Otoritas Peran Terisolasi:** Transisi status lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`) adalah hak eksklusif Petugas Lapangan (Cleaner); transisi ke `Selesai` eksklusif melalui pengiriman Quality Report. Admin dilarang mengubah status tahapan lapangan secara sembarangan.
- **Gerbang Quality Report:** Perubahan status pesanan dari `Sedang Dikerjakan` menjadi `Selesai` **WAJIB** melalui pengiriman Quality Report lengkap melalui endpoint resmi `POST /api/quality-reports` (seluruh checklist area template layanan, foto Before/After terkompresi, catatan, dan invarian 3 timestamp `started_at <= completed_at <= submitted_at`). Tidak ada bypass langsung.
- **Anti-Double Booking:** Backend wajib memvalidasi jadwal petugas menggunakan formula interval (`start_time`, `end_time = start_time + duration`) dan buffer operasional 30 menit. Evaluasi ketersediaan menggabungkan status administratif `Aktif` dan validasi jadwal riil.
- **Autentikasi Terpusat:** Supabase Auth (`auth.users`) adalah satu-satunya otoritas autentikasi. Tabel profil aplikasi `users` tidak boleh menyimpan kolom `password_hash`.
- **Snapshot Transaksi:** Setiap pesanan baru wajib mencatat snapshot tarif satuan (`harga_saat_booking`) dan total biaya (`total_biaya`). Nilai transaksi historis tidak boleh terpengaruh oleh perubahan harga master di masa depan.
- **Pembatalan Terstruktur:** Pelanggan hanya boleh membatalkan pesanan mandiri pada status `Menunggu Konfirmasi`, `Dikonfirmasi`, dan `Petugas Ditugaskan`. Pelanggan dilarang membatalkan jika status sudah `Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`, atau `Selesai`. Admin berhak membatalkan sebelum `Selesai` (termasuk tindakan darurat operasional saat `Sedang Dikerjakan`). Pembatalan wajib mencatat `cancellation_reason`, `cancelled_by`, `cancelled_at`, dan memulihkan status petugas ke `Aktif`.
- **Batas Scope Skripsi:** Tidak ada Payment Gateway live (hanya simulasi dummy), tidak ada GPS live map, tidak ada payroll/bagi hasil, tidak ada pendaftaran mandiri cleaner, dan tidak ada algoritma Machine Learning kompleks.
