# KAMUS DATA (DATA DICTIONARY)
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

> **Status Dokumen:** Active Data Definition Standard  
> **Versi Dokumen:** 1.2 (Hardened)  
> **Tanggal Pembaruan:** 26 September 2026  
> **Dokumen Induk:** `docs/PRD-Resik.in.md`, `docs/BUSINESS-RULES.md`, `database/schema.sql`  

---

## 1. Ikhtisar Skema Basis Data

Sistem Resik.in menggunakan PostgreSQL (Supabase) dengan relasi referensial penuh. Skema dirancang dengan prinsip:
- **Single Source of Authentication:** Autentikasi dikelola sepenuhnya oleh `auth.users`. Kolom `password_hash` **DITIADAKAN** dari tabel aplikasi.
- **Snapshot Integritas Transaksi:** Menyimpan snapshot harga flat deterministik (`harga_saat_booking`, `total_biaya`), deskripsi `luas_area`, dan waktu pembayaran server-authoritative.
- **Private Storage Integrity:** Menyimpan path relatif berkas (`foto_before_path`, `foto_after_path`) di private bucket, bukan URL publik statis.

---

## 2. Definisi Entitas & Kolom

### 2.1 Tabel `users` (Profil Aplikasi Pengguna)
Menyimpan profil aplikasi pengguna yang terikat 1-to-1 dengan akun Supabase Auth.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `REFERENCES auth.users(id)` | ID unik pengguna yang sinkron dengan identitas Supabase Auth. |
| `nama` | `VARCHAR(255)` | `NOT NULL` | Nama lengkap pengguna. |
| `email` | `VARCHAR(255)` | `NOT NULL`, `UNIQUE` | Alamat email aktif pengguna. |
| `nomor_wa` | `VARCHAR(50)` | `NOT NULL` | Nomor kontak WhatsApp untuk koordinasi layanan. |
| `role` | `VARCHAR(20)` | `NOT NULL`, `CHECK (role IN ('customer', 'cleaner', 'admin'))` | Peran pengguna dalam sistem. |
| `created_at`| `TIMESTAMPTZ` | `DEFAULT NOW()` | Waktu pembuatan akun profil. |

---

### 2.2 Tabel `services` (Katalog Layanan Master)
Menyimpan master katalog 4 kategori layanan kebersihan yang ditawarkan.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik layanan. |
| `nama_layanan`| `VARCHAR(255)`| `NOT NULL` | Nama tampilan layanan (misal: "Pembersihan Rumah"). |
| `kategori` | `VARCHAR(50)` | `NOT NULL`, `CHECK (kategori IN ('rumah', 'kos', 'kantor', 'pasca_renovasi'))` | Kategori spesifik properti. |
| `deskripsi` | `TEXT` | `NOT NULL` | Rincian cakupan pembersihan yang termasuk dalam paket. |
| `durasi_estimasi`| `INTEGER` | `NOT NULL` | Durasi standar pengerjaan dalam satuan jam (1 s.d. 4 jam). |
| `tarif_dasar` | `NUMERIC(12,2)`| `NOT NULL` | **Harga Master Service:** Tarif patokan paket layanan (IDR). |
| `icon_name` | `VARCHAR(100)`| `NULL` | Identifier icon untuk representasi visual UI. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | Status aktif penawaran layanan pada katalog. |

---

### 2.3 Tabel `cleaners` (Profil Profesional Petugas)
Menyimpan profil profesional, keahlian, foto profil, dan metrik performa petugas kebersihan.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik profil petugas. |
| `user_id` | `UUID` | `NOT NULL`, `REFERENCES users(id)`, `UNIQUE` | Relasi ke akun login pengguna petugas. |
| `nama` | `VARCHAR(255)` | `NOT NULL` | Nama lengkap petugas. |
| `nomor_kontak`| `VARCHAR(50)` | `NOT NULL` | Nomor WhatsApp aktif petugas untuk dihubungi. |
| `foto_url` | `TEXT` | `NULL` | URL foto profil petugas untuk ditampilkan pada kartu Smart Matching. |
| `keahlian` | `TEXT[]` | `NOT NULL` | Array keahlian canonical: `{'general_cleaning', 'office_cleaning', 'pasca_renovasi'}`. Contoh: `{'general_cleaning', 'pasca_renovasi'}`. |
| `pengalaman_tahun`| `INTEGER` | `NOT NULL`, `DEFAULT 0` | Jumlah tahun pengalaman kerja profesional. |
| `rating_rata_rata`| `NUMERIC(3,2)`| `DEFAULT 4.50` | Nilai rata-rata kepuasan bintang (skala 1.00 s.d. 5.00). Petugas baru bernilai default 4.50 (provisional). |
| `total_pekerjaan`| `INTEGER` | `DEFAULT 0` | Akumulasi total pesanan yang sukses diselesaikan. |
| `status_operasional`| `VARCHAR(20)`| `NOT NULL`, `CHECK (status_operasional IN ('Aktif', 'Cuti', 'Nonaktif'))` | Kesiapan administratif petugas (`Aktif`, `Cuti`, `Nonaktif`). Ketersediaan riil dievaluasi dinamis bersama jadwal penugasan aktif (bebas bentrok + buffer 30 menit). |

---

### 2.4 Tabel `orders` (Transaksi Pemesanan Layanan)
Entitas sentral pencatatan transaksi pemesanan layanan kebersihan.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik pesanan transaksi (UUID internal). |
| `order_code` | `VARCHAR(30)` | `NOT NULL`, `UNIQUE` | Kode bisnis pesanan yang ramah pengguna (format `RSK-YYYYMMDD-XXXX`) untuk referensi komunikasi & struk. |
| `customer_id` | `UUID` | `NOT NULL`, `REFERENCES users(id)` | ID pelanggan pemilik pesanan. |
| `cleaner_id` | `UUID` | `NULL`, `REFERENCES cleaners(id)` | ID petugas yang dialokasikan (terisi setelah penugasan). |
| `service_id` | `UUID` | `NOT NULL`, `REFERENCES services(id)` | ID layanan yang dipesan. |
| `alamat_lengkap`| `TEXT` | `NOT NULL` | Alamat jalan, nomor rumah/kantor lokasi pembersihan (wajib). |
| `patokan_lokasi`| `TEXT` | `NOT NULL` | Ciri atau patokan visual untuk memudahkan pencarian lokasi (wajib). |
| `luas_area` | `VARCHAR(100)`| `NOT NULL` | Deskripsi luas area (misal: 'Tipe 36', 'Kamar 3x4 m', '2 Lantai') untuk konteks operasional petugas (wajib). |
| `catatan_khusus`| `TEXT` | `NULL` | Permintaan khusus atau instruksi penanganan dari pelanggan (bersifat **OPSIONAL** / *nullable*). |
| `tanggal_layanan`| `DATE` | `NOT NULL` | Tanggal pelaksanaan pekerjaan ($\ge H+0$). |
| `start_time` | `TIME` | `NOT NULL` | Jam mulai kedatangan petugas (08:00 - 17:00 WIB). |
| `end_time` | `TIME` | `NOT NULL` | Jam selesai pengerjaan ($\text{start\_time} + \text{duration}$). |
| `duration` | `INTEGER` | `NOT NULL` | Durasi pengerjaan dalam jam. |
| `harga_saat_booking`| `NUMERIC(12,2)`| `NOT NULL` | **Snapshot:** Nilai tarif paket yang disalin langsung dari `services.tarif_dasar`. |
| `total_biaya` | `NUMERIC(12,2)`| `NOT NULL` | **Snapshot:** Nominal akhir transaksi ($\text{total\_biaya} = \text{harga\_saat\_booking}$). |
| `status_pembayaran`| `VARCHAR(20)`| `NOT NULL`, `DEFAULT 'Belum Bayar'` | Status pembayaran (`Belum Bayar` / `Sudah Bayar`), diatur mutlak oleh server. Prasyarat mutlak konfirmasi Admin. |
| `payment_timestamp`| `TIMESTAMPTZ`| `NULL` | Waktu pencatatan simulasi pembayaran sukses oleh server. |
| `status_pekerjaan`| `VARCHAR(30)` | `NOT NULL`, `DEFAULT 'Menunggu Konfirmasi'` | 7 status sekuensial atau `Dibatalkan`. |
| `preferensi_petugas_id`| `UUID` | `NULL`, `REFERENCES cleaners(id)` | ID petugas yang dipilih pelanggan saat Smart Matching (opsional). |
| `cancellation_reason`| `TEXT` | `NULL` | Alasan pembatalan jika pesanan dibatalkan. |
| `cancelled_by` | `UUID` | `NULL`, `REFERENCES users(id)` | ID aktor yang melakukan pembatalan. |
| `cancelled_at` | `TIMESTAMPTZ`| `NULL` | Waktu pesanan dibatalkan. |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT NOW()` | Waktu pesanan dibuat pertama kali. |

---

### 2.5 Tabel `quality_reports` (Laporan Mutu Hasil Kerja)
Dokumen digital bukti fisik hasil pengerjaan lapangan sebagai gerbang status `Selesai`.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik dokumen Quality Report. |
| `order_id` | `UUID` | `NOT NULL`, `REFERENCES orders(id)`, `UNIQUE` | ID pesanan yang dilaporkan (relasi 1-to-1). |
| `cleaner_id` | `UUID` | `NOT NULL`, `REFERENCES cleaners(id)` | ID petugas pelaksana yang menyusun laporan. |
| `checklist_area`| `JSONB` | `NOT NULL` | Array objek verifikasi checklist seluruh area sesuai template layanan (seluruh area wajib `completed: true`). |
| `foto_before_path`| `VARCHAR(255)`| `NOT NULL` | Path relatif di private bucket Supabase Storage (`orders/{order_id}/before_{timestamp}.webp`). |
| `foto_after_path`| `VARCHAR(255)`| `NOT NULL` | Path relatif di private bucket Supabase Storage (`orders/{order_id}/after_{timestamp}.webp`). |
| `catatan_petugas`| `TEXT` | `NOT NULL` | Ringkasan catatan hasil pembersihan dari petugas. |
| `started_at` | `TIMESTAMPTZ`| `NOT NULL` | Waktu petugas mulai bekerja di lapangan (status `Sedang Dikerjakan`). |
| `completed_at` | `TIMESTAMPTZ`| `NOT NULL` | Waktu fisik pembersihan selesai (invarian server: `started_at <= completed_at <= submitted_at`, dan `completed_at <= NOW()`). |
| `submitted_at` | `TIMESTAMPTZ`| `NOT NULL`, `DEFAULT NOW()` | Waktu saat server berhasil menerima dan memvalidasi laporan (`NOW()`). |

---

### 2.6 Tabel `status_logs` (Catatan Audit Riwayat Status & Reassignment)
Menyimpan riwayat kronologis setiap perubahan tahapan pesanan dan mutasi operasional.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik log status. |
| `order_id` | `UUID` | `NOT NULL`, `REFERENCES orders(id)` | ID pesanan yang mengalami perubahan status. |
| `status_sebelumnya`| `VARCHAR(50)`| `NULL` | Status sebelum terjadinya transisi. |
| `status_baru` | `VARCHAR(50)`| `NOT NULL` | Status baru yang dicapai setelah transisi. |
| `diubah_oleh` | `VARCHAR(100)`| `NOT NULL` | Informasi ID dan peran aktor yang melakukan aksi. |
| `catatan` | `TEXT` | `NULL` | Keterangan tambahan audit (misal: alasan pembatalan atau log reassignment). |
| `waktu_perubahan`| `TIMESTAMPTZ`| `DEFAULT NOW()` | Timestamp tepat terjadinya perubahan status. |

---

### 2.7 Tabel `reviews` (Rating & Ulasan — Fase V1.1)
Menyimpan umpan balik dan penilaian dari pelanggan setelah pesanan tuntas.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik ulasan. |
| `order_id` | `UUID` | `NOT NULL`, `REFERENCES orders(id)`, `UNIQUE` | ID pesanan (1 order = 1 ulasan). |
| `customer_id` | `UUID` | `NOT NULL`, `REFERENCES users(id)` | ID pelanggan pengirim ulasan. |
| `cleaner_id` | `UUID` | `NOT NULL`, `REFERENCES cleaners(id)` | ID petugas yang dinilai. |
| `rating` | `INTEGER` | `NOT NULL`, `CHECK (rating BETWEEN 1 AND 5)` | Nilai kepuasan skala 1 hingga 5 bintang. |
| `catatan_ulasan`| `TEXT` | `NULL` | Komentar atau ulasan tertulis dari pelanggan. |
| `created_at` | `TIMESTAMPTZ`| `DEFAULT NOW()` | Waktu ulasan dikirim. |

---

### 2.8 Tabel `cleaning_plans` (Langganan Rutin — Fase V2)
Menyimpan data paket jadwal berulang berkala.

| Nama Kolom | Tipe Data | Constraint | Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | ID unik paket langganan. |
| `customer_id` | `UUID` | `NOT NULL`, `REFERENCES users(id)` | ID pelanggan pemilik langganan. |
| `service_id` | `UUID` | `NOT NULL`, `REFERENCES services(id)` | ID layanan yang dirutinkan. |
| `cleaner_id` | `UUID` | `NULL`, `REFERENCES cleaners(id)` | Preferensi petugas tetap yang dipilih pelanggan. |
| `frekuensi` | `VARCHAR(20)`| `NOT NULL`, `CHECK (frekuensi IN ('mingguan', 'dua_mingguan'))` | Siklus perulangan jadwal. |
| `hari_tetap` | `VARCHAR(20)`| `NOT NULL` | Nama hari rutin pelaksanaan (misal: 'Senin', 'Sabtu'). |
| `jam_mulai` | `TIME` | `NOT NULL` | Jam kedatangan rutin yang disepakati. |
| `status_plan` | `VARCHAR(20)`| `NOT NULL`, `CHECK (status_plan IN ('Aktif', 'Jeda', 'Berhenti'))` | Status aktif paket langganan. |
