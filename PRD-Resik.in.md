# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Aplikasi Jasa Kebersihan On-Demand (Resik.in)
### Untuk Pemesanan Layanan, Penjadwalan Petugas, dan Status Pekerjaan

**UNIVERSITAS ISLAM INDONESIA**  
**FAKULTAS TEKNOLOGI INDUSTRI**  

- **Nama:** _[Nama Mahasiswa]_
- **NIM:** _[NIM Mahasiswa]_
- **Versi Dokumen:** 1.0
- **Tanggal:** 21 September 2026

---

### Metadata Dokumen

| Metadata | Keterangan |
| :--- | :--- |
| **Kode Dokumen** | PRD-RESIKIN-2026-V1 |
| **Versi Dokumen** | 1.0 — Prototipe Fungsional Layanan Inti, Smart Matching, dan Quality Report |
| **Tanggal Pembaruan**| 21 September 2026 |
| **Status Proyek** | Prototipe Fungsional — Dalam Pengembangan & Siap Uji |
| **Bidang Fokus** | Manajemen Operasional Layanan Jasa Kebersihan *On-Demand* |
| **Target Pembaca** | Dosen Pembimbing, Dosen Penguji Skripsi, Tim Pengembang (*Developer*) |
| **Arsitektur Sistem**| Frontend HTML/CSS/JS (Vanilla) — Backend Node.js (Express) — Data Layer Supabase (PostgreSQL + Auth + Storage) — Hosting Vercel |
| **Repositori** | `https://github.com/[username]/Resik.in` |
| **Live Demo** | `https://resik-in.vercel.app` |
| **Penyusun** | _[Nama Mahasiswa]_ |

---

## 1. Ringkasan Produk (*Executive Summary*)
Aplikasi Jasa Kebersihan (**Resik.in**) adalah prototipe sistem *on-demand cleaning service* yang mendigitalisasi proses pemesanan layanan kebersihan tempat tinggal dan komersial (Pembersihan Rumah, Kos, Kantor, dan Pasca Renovasi). Berbeda dari model pemesanan konvensional berbasis chat manual yang rentan miskomunikasi dan tanpa kepastian petugas, sistem ini mengintegrasikan mekanisme rekomendasi petugas terstruktur (*Smart Petugas Matching*), alur persetujuan penugasan hibrida, pelacakan progres 7 tahapan kerja secara transparan di sisi pelanggan, serta pelaporan hasil kerja digital (*Quality Report*) berbasis foto *before-after* dan checklist terverifikasi.

- **Nama Produk:** Aplikasi Jasa Kebersihan (nama kerja: Resik.in)
- **Jenis Produk:** Aplikasi web responsif (prototipe skripsi), dapat diakses melalui peramban desktop maupun ponsel pintar (*mobile browser*).
- **Pemilik Produk:** Mahasiswa penyusun skripsi, dengan dosen pembimbing sebagai *reviewer/approver requirement*.
- **Catatan Revisi:** Versi 1.0 mengonsolidasikan 7 fitur utama (Katalog, Jadwal, Form Pemesanan + Simulasi Bayar, Manajemen Petugas, Penugasan Hibrida, Status Pekerjaan, Riwayat) dan 2 fitur pembeda bernilai tambah prioritas tinggi (*Smart Petugas Matching* dan *Quality Report*). Modul *Chatbot Konsultasi* resmi ditunda dari prototipe agar implementasi terfokus pada keandalan transaksi operasional dan akuntabilitas hasil kerja.

---

## 2. Latar Belakang dan Rumusan Masalah
Proses pemesanan jasa kebersihan harian saat ini mayoritas masih bertumpu pada komunikasi informal (WhatsApp/telepon langsung), yang memicu serangkaian inefisiensi operasional dan ketidaknyamanan pelanggan:
1. **Pemesanan Tidak Terstruktur:** Ketiadaan formulir baku menyebabkan detail krusial seperti tipe ruangan, luas area, titik patokan lokasi, dan instruksi khusus sering tidak tercatat dengan baik, memicu salah paham saat petugas tiba di lapangan.
2. **Kesulitan Alokasi Petugas oleh Pengelola:** Admin kesulitan memetakan ketersediaan jadwal serta mencocokkan keahlian khusus petugas (misalnya spesialisasi kotoran semen pasca renovasi) dengan permintaan pelanggan pada jam sibuk.
3. **Ketidakpastian Progres Pengerjaan bagi Pelanggan:** Setelah memesan, pelanggan berada dalam kondisi pasif tanpa visibilitas apakah pesanan sudah diproses, petugas sudah berangkat, sudah tiba, atau sedang bekerja.
4. **Kekhawatiran terhadap Rasa Aman & Kredibilitas Petugas:** Pelanggan merasa ragu mempersilakan orang asing masuk ke area privat tempat tinggal mereka tanpa informasi awal mengenai identitas, pengalaman kerja, dan rekam jejak penilaian (*rating*).
5. **Ketiadaan Bukti Hasil Pengerjaan yang Akuntabel:** Pelanggan yang sedang bekerja di luar rumah sulit memastikan apakah seluruh area yang dipesan benar-benar telah dibersihkan sesuai ekspektasi tanpa adanya laporan dokumentasi yang terverifikasi.

---

## 3. Tujuan Produk
- Menyediakan platform pemesanan jasa kebersihan terpusat dengan katalog terstruktur untuk 4 jenis tempat (Rumah, Kos, Kantor, Pasca Renovasi).
- Memfasilitasi alur penugasan hibrida yang memberikan pelanggan kebebasan memilih rekomendasi petugas terbaik, dengan otorisasi pengawasan di tangan admin.
- Mengurangi ketidakpastian pelanggan melalui pembaruan status pengerjaan transparan secara sekuensial (7 tahapan kerja).
- Membangun rasa aman dan kepercayaan pelanggan melalui transparansi profil, rating bintang, dan riwayat pekerjaan petugas.
- Menyediakan instrumen akuntabilitas hasil kerja melalui modul *Quality Report* digital yang mengombinasikan checklist ruangan dan foto komparasi *before-after*.

---

## 4. Target Pengguna dan Persona

| Peran | Deskripsi | Kebutuhan Utama |
| :--- | :--- | :--- |
| **Pelanggan (*Customer*)** | Pengguna yang membutuhkan jasa pembersihan untuk rumah, kos, kantor, atau bangunan pasca renovasi. | Pemesanan praktis, kejelasan jadwal & tarif, transparansi profil petugas, pemantauan status pengerjaan, dan bukti foto hasil kerja. |
| **Petugas Kebersihan (*Cleaner*)**| Tenaga pelaksana kebersihan yang bertugas mengerjakan pesanan di lokasi pelanggan. | Kejelasan jadwal penugasan harian, kemudahan navigasi alamat pemesan, antarmuka pembaruan status kerja yang cepat, serta sarana unggah laporan hasil kerja. |
| **Pengelola (*Admin*)** | Pengelola operasional bisnis Resik.in yang mengatur ketersediaan layanan dan petugas. | Dasbor pemantauan pesanan terpusat, kemudahan mengonfirmasi atau menugaskan petugas secara manual, serta pengawasan mutu laporan kerja. |

---

## 5. Ruang Lingkup Sistem (*Scope Boundaries*)

### In Scope (Fokus Prototipe Skripsi)
- Pendaftaran akun mandiri untuk pelanggan dan login multi-peran (Pelanggan, Petugas, Admin).
- Katalog 4 layanan kebersihan: Pembersihan Rumah, Kos, Kantor, dan Pasca Renovasi beserta estimasi durasi dan tarif.
- Penjadwalan tanggal fleksibel (H+0 ke depan) dan pemilihan slot jam kedatangan.
- Formulir pemesanan terperinci (alamat, patokan lokasi, estimasi luas area, dan catatan instruksi).
- Simulasi pembayaran *dummy checkout* (`Belum Bayar` $\rightarrow$ `Sudah Bayar`) sebagai prasyarat pesanan diteruskan ke antrean admin.
- Manajemen master data petugas oleh admin (keahlian, pengalaman tahun, status operasional).
- Modul *Smart Petugas Matching* sederhana berbasis aturan (*rule-based*) di langkah pemesanan.
- Alur penugasan hibrida: Rekomendasi sistem disajikan $\rightarrow$ Pelanggan memilih $\rightarrow$ Admin mengonfirmasi; atau penugasan langsung oleh Admin jika pelanggan melewati opsi pilihan.
- Pelacakan 7 tahapan status pekerjaan (*Menunggu Konfirmasi* $\rightarrow$ *Dikonfirmasi* $\rightarrow$ *Petugas Ditugaskan* $\rightarrow$ *Menuju Lokasi* $\rightarrow$ *Tiba di Lokasi* $\rightarrow$ *Sedang Dikerjakan* $\rightarrow$ *Selesai*).
- Modul *Quality Report* digital: checklist area tuntas dibersihkan, unggahan foto asli *before-after*, dan catatan petugas.
- Riwayat pesanan komprehensif bagi pelanggan dan rekap data operasional bagi admin.
- Modul *Cleaning Plan* untuk paket jadwal pembersihan rutin berkala (Should Have / Fase 3).

### Out of Scope (Tidak Dikerjakan)
- Chatbot AI interaktif untuk konsultasi kebutuhan (ditunda dari prototipe skripsi).
- Integrasi gerbang pembayaran otomatis riil (*payment gateway* live seperti Midtrans/Xendit).
- Pelacakan koordinat GPS pergerakan petugas secara live di peta digital.
- Sistem penggajian bulanan, perhitungan bagi hasil, atau transfer komisi petugas (*payroll*).
- Pendaftaran petugas secara mandiri (akun petugas didaftarkan internal oleh Admin).
- Sistem manajemen inventaris stok bahan pembersih fisik dan akuntansi laba-rugi perusahaan.
- Algoritma *Machine Learning* kompleks yang membutuhkan pelatihan dataset besar.

---

## 6. Kebutuhan Fungsional (*Functional Requirements*)

### 6.1 Fitur Inti

#### FR-01 — Katalog Layanan Multi-Kategori
- **Aktor:** Pelanggan, Admin
- **User Story:** *Sebagai pelanggan, saya ingin melihat katalog layanan kebersihan yang tersedia beserta deskripsi cakupannya, sehingga saya dapat memilih jenis layanan yang sesuai dengan kebutuhan tempat saya.*
- **Kriteria Penerimaan:**
  - Sistem menyajikan 4 kartu layanan: Rumah, Kos, Kantor, dan Pasca Renovasi.
  - Setiap kartu memuat judul layanan, deskripsi cakupan pengerjaan, estimasi durasi standar, dan indikasi tarif dasar.
  - Admin dapat mengaktifkan atau menonaktifkan status penawaran layanan melalui dasbor admin.
- **Catatan:** Sesuai analisis produk Bab III, kategori layanan difokuskan pada 4 jenis properti utama dan tidak mencampuradukkan konsep kasir/F&B.

#### FR-02 — Penjadwalan Layanan Terstruktur
- **Aktor:** Pelanggan
- **User Story:** *Sebagai pelanggan, saya ingin memilih tanggal dan slot waktu kedatangan petugas, sehingga pekerjaan kebersihan dapat dilakukan saat tempat saya siap dan ada yang menerima.*
- **Kriteria Penerimaan:**
  - Sistem menyediakan kalender interaktif yang membatasi pemilihan tanggal hanya untuk hari ini (H+0) dan tanggal-tanggal di masa mendatang.
  - Sistem menyediakan pilihan slot jam mulai pengerjaan (misal: 08.00, 10.00, 13.00, 15.00 WIB).
  - Pilihan jadwal tersimpan sementara untuk digunakan pada proses pengecekan ketersediaan petugas.

#### FR-03 — Pemesanan Layanan dan Simulasi Pembayaran
- **Aktor:** Pelanggan
- **User Story:** *Sebagai pelanggan, saya ingin melengkapi alamat detail dan menyelesaikan simulasi pembayaran, sehingga pesanan saya dapat segera masuk ke antrean konfirmasi admin.*
- **Kriteria Penerimaan:**
  - Formulir mewajibkan pengisian field alamat lengkap, patokan titik lokasi, perkiraan luas area, dan catatan khusus.
  - Sistem menampilkan ringkasan rincian biaya layanan dengan status awal `Belum Bayar`.
  - Pelanggan menekan tombol "Bayar Sekarang (Simulasi)" $\rightarrow$ sistem memvalidasi dan mengubah status pembayaran menjadi `Sudah Bayar`.
  - Pesanan tersimpan ke basis data dengan status pekerjaan awal `Menunggu Konfirmasi`.

#### FR-04 — Manajemen Data Master Petugas
- **Aktor:** Admin
- **User Story:** *Sebagai admin, saya ingin mengelola data master petugas kebersihan (nama, kontak, keahlian, pengalaman, dan status), sehingga sistem memiliki basis data yang valid untuk alokasi pekerjaan.*
- **Kriteria Penerimaan:**
  - Admin dapat menambah petugas baru dengan mengisi nama lengkap, nomor kontak WhatsApp, spesialisasi keahlian, dan tahun pengalaman.
  - Admin dapat mengubah status operasional petugas (`Aktif`, `Sibuk`, `Cuti`, `Nonaktif`).
  - Sistem menghitung agregat rating bintang dan total pekerjaan selesai secara otomatis dari pesanan-pesanan lampau.

#### FR-05 — Penugasan Petugas Hibrida (*Hybrid Assignment*)
- **Aktor:** Pelanggan, Admin, Petugas
- **User Story:** *Sebagai admin, saya ingin mengonfirmasi petugas pilihan pelanggan atau menugaskan petugas secara manual, sehingga setiap pesanan memiliki penanggung jawab yang tepat di lapangan.*
- **Kriteria Penerimaan:**
  - **Skenario Pilihan Pelanggan:** Jika pelanggan memilih salah satu rekomendasi petugas saat pemesanan, pesanan masuk ke admin dengan tag "Pilihan Pelanggan: [Nama Petugas]". Admin menekan tombol "Konfirmasi Penugasan" $\rightarrow$ status pesanan berubah menjadi `Petugas Ditugaskan`.
  - **Skenario Fallback (Penugasan Langsung):** Jika pelanggan melewati opsi rekomendasi (opsi default), Admin memilih salah satu petugas aktif dari daftar dropdown dan menekan tombol "Tugaskan Langsung" $\rightarrow$ status pesanan berubah menjadi `Petugas Ditugaskan`.
  - Tugas yang telah ditetapkan otomatis muncul pada dasbor kerja akun petugas yang bersangkutan.
- **Catatan:** Fitur ini mengimplementasikan keputusan final: sistem merekomendasikan $\rightarrow$ pelanggan memilih $\rightarrow$ admin mengonfirmasi; jika tidak memilih, admin menugaskan langsung.

#### FR-06 — Pelacakan Progres Status Pekerjaan 7 Tahap
- **Aktor:** Petugas, Pelanggan, Admin
- **User Story:** *Sebagai pelanggan, saya ingin memantau perkembangan pekerjaan kebersihan secara bertahap, sehingga saya mengetahui kepastian kapan petugas tiba dan menyelesaikan pekerjaan.*
- **Kriteria Penerimaan:**
  - Sistem mendukung 7 siklus status berurutan:
    `Menunggu Konfirmasi` $\rightarrow$ `Dikonfirmasi` $\rightarrow$ `Petugas Ditugaskan` $\rightarrow$ `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan` $\rightarrow$ `Selesai`.
  - Petugas memiliki tombol aksi pada dasbor untuk memperbarui status lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Mulai Pengerjaan`).
  - Halaman pelacakan pada antarmuka pelanggan dan dasbor admin menampilkan indikator progres visual (*stepper*) yang ter-update secara *real-time*.

#### FR-07 — Manajemen Pengguna, Autentikasi, dan Riwayat Pesanan
- **Aktor:** Pelanggan, Petugas, Admin
- **User Story:** *Sebagai pengguna, saya ingin login ke akun saya dengan aman dan dapat melihat riwayat transaksi saya kapan saja.*
- **Kriteria Penerimaan:**
  - Mendukung autentikasi multi-peran dengan hak akses terisolasi (Pelanggan hanya dapat melihat pesanannya sendiri, Petugas hanya melihat tugasnya).
  - Kata sandi disimpan dalam format terenkripsi searah (*hashing* bcrypt/Supabase Auth).
  - Pelanggan dan Admin dapat membuka tab "Riwayat Pesanan" untuk melihat arsip pesanan lampau beserta tautan dokumen hasil kerjanya.

---

### 6.2 Fitur Bernilai Tambah (*Value-Added Features*)

#### FR-08 — Smart Petugas Matching (*Rule-Based Recommendation*)
- **Aktor:** Pelanggan, Sistem
- **User Story:** *Sebagai pelanggan, saya ingin sistem merekomendasikan petugas yang memiliki keahlian sesuai dengan layanan yang saya pilih dan jadwalnya luang, sehingga saya yakin dengan kualitas kerja petugas.*
- **Kriteria Penerimaan:**
  - Pada langkah formulir pemesanan, sistem secara otomatis mengeksekusi logika filter rekomendasi:
    1. Memilih petugas yang berstatus `Aktif` dan tidak memiliki jadwal bentrok pada tanggal & jam terpilih.
    2. Memprioritaskan petugas yang memiliki badge keahlian yang cocok dengan jenis layanan (misal: Keahlian *Pasca Renovasi* untuk pesanan Pasca Renovasi).
    3. Mengurutkan kandidat teratas berdasarkan kombinasi rating tertinggi dan total order sukses.
  - Kartu profil kandidat menampilkan foto, nama, rating bintang, tahun pengalaman, dan badge kecocokan ("Sangat Sesuai").
  - Pelanggan dapat memilih salah satu kandidat atau memilih opsi default "Pilihkan Otomatis oleh Admin".
- **Catatan:** Sesuai keputusan bimbingan, matching prototipe diimplementasikan secara *rule-based* tanpa machine learning rumit agar transparan dan reliabel.

#### FR-09 — Quality Report Digital (Checklist & Foto Before/After)
- **Aktor:** Petugas (pengisi), Pelanggan (penerima), Admin (pengawas)
- **User Story:** *Sebagai pelanggan, saya ingin melihat bukti foto sebelum dan sesudah serta checklist area yang dibersihkan, sehingga saya puas dan percaya terhadap hasil pengerjaan meskipun saya tidak berada di lokasi.*
- **Kriteria Penerimaan:**
  - Saat pesanan berstatus `Sedang Dikerjakan`, formulir Quality Report terbuka pada antarmuka Petugas.
  - Petugas mencentang checklist area yang selesai dibersihkan (misal: Ruang Tamu, Kamar Mandi, Dapur, Jendela/Balkon).
  - Petugas mengunggah minimal 1 foto *Before* (kondisi awal) dan 1 foto *After* (kondisi bersih), serta mengisi catatan hasil kerja.
  - Menekan tombol "Kirim Laporan & Selesaikan" mengunggah berkas ke penyimpanan cloud (*Supabase Storage*), mengunci laporan menjadi *read-only*, dan mengubah status pesanan menjadi `Selesai`.
  - Pelanggan dan Admin dapat membuka dan melihat dokumen Quality Report lengkap dari rincian pesanan.
- **Catatan:** Fitur ini merupakan inovasi utama pembeda Resik.in dari aplikasi jasa kebersihan biasa.

#### FR-10 — Cleaning Plan (Layanan Rutin Berkala)
- **Aktor:** Pelanggan, Sistem
- **User Story:** *Sebagai pelanggan kos atau kantor yang butuh pembersihan berkala, saya ingin berlangganan jadwal rutin, sehingga saya tidak perlu repot mengisi formulir pemesanan setiap minggu.*
- **Kriteria Penerimaan:**
  - Pelanggan dapat memilih opsi jadwal berulang: frekuensi (Mingguan / Dua Mingguan), hari tetap, jam kedatangan, dan preferensi petugas langganan.
  - Sistem menyimpan rencana pembersihan aktif dan secara otomatis menjadwalkan pembentukan draf pesanan baru sesuai siklus waktu.
- **Catatan:** Diklasifikasikan sebagai *Should Have* (Fase 3 lanjutan) setelah sistem transaksi inti dan Quality Report terverifikasi stabil.

---

## 7. Kebutuhan Non-Fungsional (*Non-Functional Requirements*)

| Kategori | Kebutuhan |
| :--- | :--- |
| **Kinerja (*Performance*)** | Halaman utama, formulir pemesanan, dan dasbor dapat dimuat dalam waktu wajar (< 3 detik) pada koneksi internet seluler standar. |
| **Keamanan (*Security*)** | Data pribadi (nomor kontak, alamat rumah) hanya dapat diakses oleh pemilik akun dan admin/petugas yang ditugaskan; kata sandi dienkripsi searah (*hash*); implementasi otorisasi berbasis sesi/token JWT. |
| **Ketersediaan (*Availability*)** | Sistem prototipe di-deploy pada platform *serverless cloud* (Vercel) yang dapat diakses 24/7 untuk keperluan evaluasi dan demonstrasi skripsi. |
| **Usabilitas (*Usability*)** | Alur pemesanan dirancang dalam format tahapan sederhana (*wizard-like*); elemen tombol dan formulir mudah dioperasikan pada layar ponsel (*touch-friendly*). |
| **Auditabilitas (*Auditability*)** | Setiap perubahan tahapan status pesanan dan pengunggahan laporan kualitas dicatat dengan waktu (*timestamp*) dan ID aktor pengubah. |
| **Konsistensi Data** | Sistem mencegah kondisi petugas dijadwalkan ganda (*double booking*) pada rentang waktu yang saling tumpang tindih. |
| **Optimalisasi Berkas** | Foto dokumentasi Quality Report dikompresi di sisi browser sebelum diunggah ke *Supabase Storage* untuk menghemat kuota penyimpanan dan mempercepat proses kirim. |

---

## 8. Alur Proses Bisnis

Alur berikut menggambarkan siklus hidup pesanan jasa kebersihan Resik.in dari awal hingga selesai:

| Tahap | Aktivitas | Aktor | Output |
| :---: | :--- | :--- | :--- |
| **1. Pilih Layanan** | Memilih salah satu dari 4 kategori layanan kebersihan. | Pelanggan | Kategori layanan terpilih |
| **2. Tentukan Jadwal & Lokasi** | Mengisi tanggal, slot jam mulai, alamat lengkap, dan patokan lokasi. | Pelanggan | Data jadwal & lokasi tersimpan |
| **3. Smart Matching (Opsional)** | Memilih petugas dari rekomendasi sistem atau memilih opsi penugasan oleh Admin. | Pelanggan / Sistem | Preferensi petugas tercatat |
| **4. Pembayaran Dummy** | Meninjau total biaya dan menekan tombol simulasi pembayaran. | Pelanggan | Status: `Sudah Bayar`, Pesanan: `Menunggu Konfirmasi` |
| **5. Konfirmasi Penugasan** | Menyetujui pilihan pelanggan atau menugaskan petugas secara langsung (*fallback*). | Admin | Status: `Petugas Ditugaskan`, Tugas masuk ke Petugas |
| **6. Perjalanan & Kedatangan** | Menekan tombol aksi saat berangkat dan tiba di lokasi pengerjaan. | Petugas | Status: `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi` |
| **7. Eksekusi Pekerjaan** | Memulai pembersihan dan memperbarui status kerja. | Petugas | Status: `Sedang Dikerjakan` |
| **8. Pelaporan Mutu (Quality Report)** | Mencentang checklist area, mengunggah foto *Before/After*, dan menulis catatan. | Petugas | Quality Report terunggah, Status: `Selesai` |
| **9. Peninjauan Hasil & Riwayat** | Melihat laporan hasil pembersihan dan mengarsipkan transaksi. | Pelanggan & Admin | Transparansi hasil kerja terpenuhi |

---

## 9. Model Data Utama (Entitas)

| Entitas | Deskripsi | Atribut Kunci |
| :--- | :--- | :--- |
| **`users`** | Akun pengguna sistem (pelanggan, petugas, dan admin). | `id`, `nama`, `email`, `nomor_wa`, `password_hash`, `role` (customer/cleaner/admin), `created_at` |
| **`services`** | Data katalog 4 layanan kebersihan yang ditawarkan. | `id`, `nama_layanan`, `kategori` (rumah/kos/kantor/pasca_renovasi), `deskripsi`, `durasi_estimasi`, `tarif_dasar`, `is_active` |
| **`cleaners`** | Data profil profesional petugas kebersihan. | `id`, `user_id`, `nama`, `nomor_kontak`, `keahlian` (array/text), `pengalaman_tahun`, `rating_rata_rata`, `total_pekerjaan`, `status_operasional` |
| **`orders`** | Entitas transaksi pemesanan layanan kebersihan. | `id`, `customer_id`, `cleaner_id`, `service_id`, `alamat_lengkap`, `patokan_lokasi`, `luas_area`, `catatan_khusus`, `tanggal_layanan`, `jam_mulai`, `status_pembayaran`, `status_pekerjaan`, `preferensi_petugas_id`, `created_at` |
| **`quality_reports`** | Laporan pertanggungjawaban mutu hasil pekerjaan. | `id`, `order_id`, `cleaner_id`, `checklist_area` (json), `foto_before_url`, `foto_after_url`, `catatan_petugas`, `waktu_submit` |
| **`cleaning_plans`** | Data paket langganan jadwal rutin berkala. | `id`, `customer_id`, `service_id`, `cleaner_id`, `frekuensi`, `hari_tetap`, `jam_mulai`, `status_plan` |
| **`status_logs`** | Catatan audit perubahan status pekerjaan secara kronologis. | `id`, `order_id`, `status_sebelumnya`, `status_baru`, `diubah_oleh`, `waktu_perubahan` |

---

### 9.1 Arsitektur Sistem (Prototipe Saat Ini)

| Lapisan | Teknologi | Fungsi |
| :--- | :--- | :--- |
| **Frontend** | HTML5, CSS3, JavaScript Vanilla (Responsif) | Menampilkan antarmuka pemesanan multi-langkah, pelacakan stepper status, dasbor petugas, dasbor admin, dan kartu profil rekomendasi. |
| **Backend / API** | Node.js dengan Express.js | Menyediakan endpoint RESTful API untuk autentikasi, kalkulasi jadwal, pemrosesan status pesanan, dan orkestrasi data. |
| **Mesin Rekomendasi (Matching)**| Modul JavaScript Terstruktur (`matching-engine.js`)| Memproses penyaringan petugas aktif tanpa jadwal bentrok, penghitungan bobot kesesuaian keahlian, dan pengurutan skor reputasi. |
| **Autentikasi & Sesi** | Supabase Auth & JWT Session Cookie | Mengelola login berbasis peran (*role-based guard*), validasi token sesi yang aman pada arsitektur hosting *serverless*. |
| **Penyimpanan Data Relasional** | Supabase (PostgreSQL, Kawasan Singapore) | Menyimpan seluruh tabel entitas terstruktur dan memastikan relasi referensial data tetap konsisten. |
| **Penyimpanan Berkas (Storage)** | Supabase Storage Bucket (`quality-reports`) | Menyimpan berkas foto asli *Before* dan *After* hasil pekerjaan yang diunggah oleh petugas lapangan. |
| **Hosting & Deployment** | Vercel Cloud Platform | Menghosting aplikasi web dengan *continuous deployment* otomatis terhubung ke repositori Git utama. |

---

## 10. Prioritas Fitur (MoSCoW Matrix)

| Fitur | Prioritas | Alasan Rasional |
| :--- | :---: | :--- |
| **FR-01 s.d. FR-07 (Fitur Inti)** | **Must Have** | Menjalankan proses bisnis fundamental: katalog, penentuan jadwal, pemesanan terstruktur, pelacakan tahapan kerja, dan arsip riwayat. |
| **FR-08 Smart Petugas Matching** | **Must Have** | Menjadi pembeda utama aplikasi agar alokasi petugas transparan, tepat keahlian, dan memberikan kontrol kepada pelanggan. |
| **FR-09 Quality Report Digital** | **Must Have** | Menjawab masalah hilangnya kepercayaan hasil kerja saat pelanggan tidak di lokasi melalui bukti foto dan checklist konkret. |
| **FR-10 Cleaning Plan (Layanan Rutin)**| **Should Have**| Bermanfaat meningkatkan retensi pelanggan rutin, namun sistem tetap dapat beroperasi penuh secara *on-demand* tanpanya. |
| **Chatbot Konsultasi Kebutuhan** | **Won't Have** (Out of Scope)| Ditunda dari prototipe agar implementasi terfokus pada kesempurnaan transaksi dan akuntabilitas operasional lapangan. |

---

## 11. Metrik Keberhasilan (*Success Metrics*)
- **Efisiensi Input Pemesanan:** Pelanggan dapat menyelesaikan formulir pemesanan lengkap beserta pemilihan jadwal dan preferensi petugas dalam waktu < 3 menit.
- **Akurasi Alokasi Petugas:** 100% pesanan yang dialokasikan tidak mengalami konflik jadwal ganda (*zero overlapping schedule*) pada petugas yang sama.
- **Tingkat Kelengkapan Laporan Mutu:** 100% pesanan yang mencapai status `Selesai` memiliki catatan checklist area dan lampiran foto komparasi *Before-After*.
- **Transparansi Progres:** Pelanggan dapat melihat perubahan status tahapan kerja secara *real-time* saat petugas memperbarui status di lapangan.
- **Tingkat Kepuasan Pengguna:** Skor kepuasan di atas 80% (diukur melalui instrumen kuesioner pengujian prototipe) terhadap kemudahan pemesanan dan kejelasan laporan hasil kerja.

---

## 12. Asumsi dan Batasan
- Pengguna diasumsikan memiliki perangkat yang terhubung ke jaringan internet aktif saat mengoperasikan aplikasi web.
- Wilayah operasional layanan pada prototipe skripsi diasumsikan mencakup satu area cakupan kota percontohan.
- Data pengujian menggunakan kombinasi data akun simulasi (daftar petugas contoh dengan berbagai variasi keahlian dan rating) untuk memvalidasi skenario *matching* dan penugasan.
- Tarif layanan yang dicantumkan pada prototipe bersifat estimasi dasar tetap (*fixed baseline estimate*) untuk keperluan demonstrasi fungsional.

---

## 13. Risiko dan Mitigasi

| Risiko | Dampak | Strategi Mitigasi |
| :--- | :--- | :--- |
| **Jadwal Petugas Bentrok (*Double Booking*)** | Dua pelanggan memesan petugas yang sama pada slot jam yang berdekatan. | Sistem menyaring secara otomatis: petugas yang sudah memiliki penugasan aktif pada slot jam tersebut dieliminasi dari daftar rekomendasi dan diberi tanda non-aktif di dropdown admin. |
| **Pembengkakan Ukuran Berkas Foto Laporan** | Pengunggahan foto resolusi tinggi dari kamera ponsel menghabiskan kuota Supabase Storage dan memperlambat koneksi. | Implementasi kompresi gambar otomatis berbasis Canvas di sisi klien (*client-side compression*) sebelum berkas dikirim ke server (maksimal ukuran berkas dibatasi 1–2 MB). |
| **Inkonsistensi Sesi pada Serverless Vercel** | Sesi pengguna hilang saat berpindah *instance serverless* jika sesi hanya disimpan di memori lokal. | Penyimpanan sesi menggunakan token terverifikasi (*Supabase Auth JWT*) yang dikirimkan via *secure cookie/headers* sehingga status login tetap konsisten di seluruh serverless node. |
| **Pelanggan Mengabaikan Rekomendasi Petugas** | Proses pemesanan terhambat jika sistem memaksa pelanggan memilih petugas. | Disediakan mekanisme *fallback*: pilihan petugas dibuat opsional; jika pelanggan melewati opsi tersebut, admin dapat menugaskan petugas yang tersedia secara langsung. |
| **Petugas Mengabaikan Pembaruan Status** | Pelanggan melihat status diam di satu tahap meskipun pekerjaan sudah berjalan. | Tombol pembaruan status dibuat menonjol di antarmuka petugas, dan formulir Quality Report hanya bisa disubmit jika tahapan pengerjaan telah dilalui. |

---

## 14. Value Proposition
> *"Resik.in bukan sekadar platform pencatatan pesanan kebersihan biasa, melainkan layanan jasa kebersihan modern yang memberikan pelanggan kendali dan transparansi penuh: mulai dari memilih petugas yang sesuai dengan kebutuhan, memantau perkembangan pekerjaan secara bertahap, hingga menerima bukti hasil pembersihan (Quality Report) yang nyata dan akuntabel."*

---

## 15. Referensi
Dokumen ini disusun mengadaptasi metodologi pemisahan fitur inti (*Core System*) dan fitur bernilai tambah (*Value-Added Features*) dari hasil studi eksplorasi aplikasi *Mibebi Kasir* pada tugas analisis produk. Konsep tersebut kemudian ditransformasikan ke dalam domain jasa kebersihan (*Resik.in*) dengan memprioritaskan penyelesaian masalah nyata di lapangan: transparansi alokasi petugas (*Smart Matching*) dan verifikasi mutu hasil kerja (*Quality Report*). Dokumen PRD ini menjadi acuan spesifikasi resmi untuk tahapan implementasi perangkat lunak dan pengujian prototipe skripsi selanjutnya.
