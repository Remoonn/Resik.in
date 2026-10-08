# Matriks Kemajuan Naskah Skripsi
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

**Nama Mahasiswa:** Agil Seno Adjie  
**Program Studi:** Informatika  
**Fakultas / Universitas:** Fakultas Teknologi Industri / Universitas Islam Indonesia  
**Judul Skripsi (Tentatif):**  
*Rancang Bangun Aplikasi Jasa Kebersihan On-Demand Berbasis Mobile dengan Algoritma Rekomendasi Petugas Deterministik dan Akuntabilitas Mutu Digital (Studi Kasus: Resik.in)*  
*(Catatan: Judul dapat disesuaikan dengan Surat Keputusan / pengesahan tugas akhir resmi Anda)*

---

## 📊 Ringkasan Status Naskah Skripsi

| Bagian / Bab | Status | Estimasi Halaman | Terakhir Diperbarui |
| :--- | :---: | :---: | :---: |
| **Halaman Depan (Judul, Abstrak, Lembar Pengesahan)** | In Progress | ~6 | 8 Oktober 2026 |
| **BAB 1: Pendahuluan** | Selesai | ~8 | 25 September 2026 |
| **BAB 2: Tinjauan Pustaka & Landasan Teori** | Selesai | ~16 | 28 September 2026 |
| **BAB 3: Analisis & Perancangan Sistem** | Selesai | ~28 | 30 September 2026 |
| **BAB 4: Implementasi & Pengujian Sistem** | Selesai | ~32 | 7 Oktober 2026 |
| **BAB 5: Kesimpulan & Saran** | Selesai | ~4 | 8 Oktober 2026 |
| **Daftar Pustaka & Lampiran** | In Progress | ~10 | 8 Oktober 2026 |

---

## 📝 Rincian Bab & Subbab Naskah Skripsi

### BAB 1: Pendahuluan (Selesai)
- [x] **1.1 Latar Belakang Masalah:**
  - Keterbatasan alur konvensional pemesanan jasa kebersihan berbasis chat manual.
  - Risiko jadwal bentrok (*double booking*) pada jam sibuk akibat ketiadaan validasi interval dan buffer waktu.
  - Ketidakpastian pelanggan terhadap status kehadiran dan pengerjaan petugas di lapangan.
  - Ketiadaan transparansi keahlian petugas dan ketiadaan sarana pembuktian mutu pekerjaan objektif saat pelanggan berada di luar properti.
- [x] **1.2 Rumusan Masalah:**
  - Bagaimana merancang sistem pemesanan kebersihan *on-demand* dengan katalog terstruktur dan formula tarif flat deterministik?
  - Bagaimana menerapkan algoritma *Smart Matching* rule-based dengan rating provisional untuk rekomendasi alokasi petugas bebas bentrok jadwal?
  - Bagaimana membangun sistem pelacakan progres 7 tahapan sekuensial yang transparan?
  - Bagaimana mengimplementasikan subsistem *Digital Quality Report Gate* berbasis komparasi foto Before/After dan checklist area kerja sebagai syarat penyelesaian pesanan?
- [x] **1.3 Batasan Masalah:**
  - Prototipe aplikasi mobile dibangun menggunakan Flutter (Android & iOS) dan backend REST API Node.js Express.
  - Basis data relasional dan penyimpanan berkas foto menggunakan Supabase Cloud (PostgreSQL & Storage).
  - Pembayaran menggunakan simulasi checkout internal (*Belum Bayar* $\rightarrow$ *Sudah Bayar*), tanpa payment gateway live pihak ketiga.
  - Pelacakan progres menggunakan representasi stepper 7 tahapan status, tanpa pelacakan koordinat GPS real-time pada peta.
- [x] **1.4 Tujuan Penelitian:**
  - Menghasilkan prototipe aplikasi mobile *on-demand* jasa kebersihan yang terstruktur.
  - Mengimplementasikan dan menguji kinerja algoritma rekomendasi petugas cerdas deterministik.
  - Menyediakan mekanisme verifikasi mutu kerja digital yang akuntabel sebelum pesanan diselesaikan.
- [x] **1.5 Manfaat Penelitian:**
  - Bagi Pelanggan: Kepastian durasi, tarif tetap, transparansi profil petugas, dan bukti foto hasil kerja yang terverifikasi.
  - Bagi Pengelola/Admin: Kemudahan manajemen penugasan, pencegahan *double booking*, dan monitoring operasional terpusat.
  - Bagi Petugas Kebersihan: Kejelasan daftar checklist area kerja dan transparansi perolehan ulasan pelanggan.
- [x] **1.6 Sistematika Penulisan Naskah.**

---

### BAB 2: Tinjauan Pustaka & Landasan Teori (Selesai)
- [x] **2.1 Studi Komparasi Penelitian Sejenis:** Kajian 5+ jurnal/literatur terkait sistem informasi manajemen jasa kebersihan, aplikasi *on-demand service*, dan arsitektur *cloud backend*.
- [x] **2.2 Landasan Teori:**
  - [x] Konsep Layanan *On-Demand Services* dan *Service Level Agreement (SLA)*.
  - [x] Sistem Pendukung Keputusan & Algoritma Rekomendasi Berbasis Aturan (*Rule-Based Matching*).
  - [x] Kerangka Kerja Lintas Platform Flutter (Dart) & Manajemen State Reaktif.
  - [x] Arsitektur Layanan REST API & Runtime Node.js (Express ES Module).
  - [x] Database Relasional PostgreSQL & Cloud Backend as a Service (BaaS) Supabase.
  - [x] Mekanisme Keamanan Otorisasi Berbasis Peran (*Role-Based Access Control / RBAC*).
  - [x] Pengujian Perangkat Lunak: Metode *Black-Box Testing*, Unit Testing, dan Integration Testing.

---

### BAB 3: Analisis & Perancangan Sistem (Selesai)
- [x] **3.1 Metodologi Pengembangan Sistem:** Penerapan model *Iterative Development / Sprint Lifecycle*.
- [x] **3.2 Analisis Kebutuhan Sistem:**
  - [x] Kebutuhan Fungsional (FR-01 s.d. FR-08 sesuai PRD v1.2).
  - [x] Kebutuhan Non-Fungsional (NFR: Keamanan RBAC, Integritas Data, Performa Waktu Respons < 2 detik).
- [x] **3.3 Perancangan Algoritma & Aturan Bisnis:**
  - [x] Formula matematis *Smart Matching Engine* (bobot rating 40%, tugas selesai 30%, kedekatan 30%, rating provisional 4.5).
  - [x] Logika validasi jadwal anti-double booking: interval `start_time` s.d. `end_time` + buffer operasional 30 menit.
- [x] **3.4 Pemodelan Sistem (Diagram UML):**
  - [x] *Use Case Diagram:* Interaksi Pelanggan, Petugas, dan Admin dengan seluruh modul sistem.
  - [x] *Activity Diagram:* Alur pemesanan jasa, alur penugasan petugas, dan alur pengiriman laporan mutu.
  - [x] *Sequence Diagram:* Alur otentikasi, transisi 7 status pesanan, dan verifikasi ulasan.
  - [x] *State Machine Diagram:* Siklus hidup 7 status pesanan dari `Menunggu Konfirmasi` hingga `Selesai`.
- [x] **3.5 Perancangan Basis Data:**
  - [x] *Entity Relationship Diagram (ERD):* Model konseptual dan fisik relasi 6 tabel.
  - [x] *Kamus Data:* Atribut tipe data, batasan *primary key*, *foreign key*, dan nilai enum pada tabel `users`, `cleaners`, `orders`, `order_status_logs`, `quality_reports`, dan `reviews`.
- [x] **3.6 Perancangan Antarmuka Pengguna (*UI Wireframe / Mockup*):**
  - [x] Antarmuka Pelanggan: Katalog properti, detail petugas, booking form, order tracking stepper, lembar ulasan bintang.
  - [x] Antarmuka Petugas: Dasbor tugas aktif, form checklist interaktif, pengunggah foto Before/After.
  - [x] Antarmuka Admin: Dasbor statistik pesanan, tab pipeline status, lembar penugasan cerdas dengan indikator konflik.
- [x] **3.7 Perancangan Arsitektur Keamanan & Penyimpanan:**
  - [x] Skema penyimpanan berkas foto Before/After pada Supabase Storage Bucket privat via Signed URL bertenggang waktu.
  - [x] Penegakan matriks hak akses Role-Based Access Control (RBAC).

---

### BAB 4: Implementasi & Pengujian Sistem (Selesai)
- [x] **4.1 Lingkungan Implementasi:**
  - Spesifikasi Perangkat Keras (*Hardware Environment*).
  - Perangkat Lunak & Versi Toolchain: Flutter SDK 3.x, Dart 3.x, Node.js 20+, Supabase PostgreSQL 15.
- [x] **4.2 Implementasi Basis Data & Backend REST API:**
  - Eksekusi DDL skema relasional di PostgreSQL Supabase Cloud.
  - Implementasi router modular Node.js: `auth.js`, `cleaners.js`, `orders.js`, `quality-reports.js`, `reviews.js`.
  - Implementasi arsitektur dual-mode (`mapper.js`, `uuid-sanitizer.js`, `database.js`).
- [x] **4.3 Implementasi Antarmuka Mobile Flutter:**
  - Implementasi halaman utama Pelanggan, Petugas (`CleanerDashboardScreen`), dan Admin (`AdminDashboardScreen`).
  - Implementasi widget reaktif: `OrderTrackingScreen`, `QualityReportFormSheet`, `QualityReportScreen`, `ReviewBottomSheet`.
  - Penegakan perutean otomatis berbasis peran pada `AuthGate`.
- [x] **4.4 Pengujian Perangkat Lunak:**
  - [x] **Pengujian Otomatis (*Automated Testing*):**
    - Backend: 32 unit & integration test case (`npm test`) berstatus 100% PASS.
    - Mobile: 0 issue pada `flutter analyze` dan seluruh test widget/model (`flutter test`) berstatus PASS.
  - [x] **Pengujian Fungsional (*Black-Box Testing*):**
    - TC-01: Alur pendaftaran dan login Google Sign-In & Email/Password.
    - TC-02: Pemesanan jasa dan rekomendasi petugas cerdas (*Smart Matching*).
    - TC-03: Validasi pencegahan jadwal bentrok (*Anti-Double Booking*).
    - TC-04: Transisi sekuensial 7 status pesanan oleh Admin dan Petugas.
    - TC-05: Penegakan *Payment Guard* (penguncian konfirmasi pesanan jika belum bayar).
    - TC-06: Validasi *Quality Report Gate* (kunci status Selesai sebelum foto & checklist tervalidasi).
    - TC-07: Pemberian rating bintang dan agregasi reputasi dinamis petugas.
    - TC-08: Pengujian isolasi hak akses (RBAC) pada data pesanan.
- [x] **4.5 Evaluasi Hasil Pengujian & Analisis Ketercapaian Tujuan:** Seluruh skenario uji memenuhi kriteria penerimaan PRD v1.2.

---

### BAB 5: Kesimpulan & Saran (Selesai)
- [x] **5.1 Kesimpulan:** Penarikan kesimpulan berdasarkan evaluasi fungsional dan ketercapaian 3 pilar operasional Resik.in.
- [x] **5.2 Saran Pengembangan Lanjutan:** Rekomendasi fitur V2 (modul jadwal langganan berkala/cleaning plan, integrasi payment gateway live, dan optimasi rute lapangan).

---

## 🎨 Inventaris Artefak & Diagram Skripsi

| Nama Artefak Diagram / Dokumen | Jenis Model | Status | Keterangan & Lokasi Berkas |
| :--- | :--- | :---: | :--- |
| **Arsitektur Sistem Resik.in** | Arsitektur | Siap | [docs/ARCHITECTURE.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/docs/ARCHITECTURE.md) |
| **Use Case Diagram Resik.in** | UML | Siap | Bahan Bab 3 (Interaksi 3 Aktor: Pelanggan, Petugas, Admin) |
| **Activity Diagram - Smart Matching** | UML | Siap | Bahan Bab 3 (Alur kalkulasi skor dan filter bentrok) |
| **Activity Diagram - Quality Report Gate**| UML | Siap | Bahan Bab 3 (Alur verifikasi checklist & foto Before/After) |
| **Sequence Diagram - Lifecycle Pesanan**| UML | Siap | Bahan Bab 3 (Interaksi Flutter $\leftrightarrow$ Express $\leftrightarrow$ Supabase) |
| **State Machine Diagram - 7 Status** | UML | Siap | Bahan Bab 3 (Siklus hidup transisi pesanan) |
| **ERD (Entity Relationship Diagram)** | Basis Data | Siap | Bahan Bab 3 (Relasi 6 tabel dari [database/schema.sql](file:///c:/Users/62859/Documents/Skripsi/Resik.in/database/schema.sql)) |
| **Tangkapan Layar UI Dasbor Multi-Peran** | Desain UI | Siap | Disimpan di folder `bukti-progres/` |
| **Hasil Rekap Uji Otomatis (Test Report)**| Pengujian | Siap | Disimpan di folder `bukti-progres/` (32 backend tests & flutter tests) |
