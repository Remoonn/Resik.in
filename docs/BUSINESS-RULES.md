# BUSINESS RULES DOKUMENTASI (BRD)
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

> **Status Dokumen:** Active Source of Truth untuk Aturan Bisnis & Logika Validasi  
> **Versi Dokumen:** 1.2 (Hardened & Deterministic)  
> **Tanggal Pembaruan:** 26 September 2026  
> **Dokumen Induk:** `docs/PRD-Resik.in.md`  

---

## 1. Pendahuluan & Prinsip Penegakan Aturan
Dokumen ini mendokumentasikan seluruh aturan bisnis (*business rules*), batasan operasional, logika kalkulasi, dan formula validasi sistem **Resik.in**.

### Prinsip Utama Penegakan Aturan:
1. **Server-Side Validation Mandate:** Seluruh aturan bisnis, validasi ketersediaan, hak pembatalan, dan kalkulasi tarif **WAJIB divalidasi di sisi backend (Node.js/Express & RLS PostgreSQL)**. Validasi pada antarmuka pengguna (frontend) hanya berfungsi sebagai pemandu interaksi (*user feedback*), bukan penjamin integritas.
2. **Server-Authoritative States:** Status penting (pembayaran, tahapan kerja, alokasi petugas) sepenuhnya ditentukan dan divalidasi oleh server. Klien dilarang menyuntikkan status final secara langsung.
3. **Immutability of Historical Transactions:** Data historis yang telah disahkan (seperti harga saat booking, audit status log, dan Quality Report) tidak boleh dimutasi atau berubah akibat perubahan data master di masa depan.
4. **Deterministic Logic:** Seluruh algoritma pencocokan (*matching*), perhitungan ketersediaan, dan transisi status beroperasi secara deterministik dan dapat dipertanggungjawabkan tanpa komponen acak (*non-deterministic*).

---

## 2. Aturan Penjadwalan & Anti-Double Booking (BR-SCH)

### BR-SCH-001: Batasan Tanggal Pemesanan
- Pelanggan hanya diizinkan memilih tanggal layanan untuk hari ini ($H+0$) dan hari-hari mendatang ($H+N$, di mana $N \ge 0$).
- Pemilihan tanggal di masa lampau ($< H+0$) wajib ditolak oleh sistem dengan error:  
  `"Tanggal layanan tidak valid. Silakan pilih hari ini atau tanggal di masa mendatang."`

### BR-SCH-002: Jam Operasional & Batas Akhir Layanan
- Waktu mulai layanan (`start_time`) harus berada dalam rentang jam operasional: **08:00 WIB s.d. 17:00 WIB**.
- Slot waktu kedatangan standar yang disediakan antarmuka adalah: `08:00`, `10:00`, `13:00`, dan `15:00` WIB.
- Waktu selesai layanan (`end_time`) tidak boleh melampaui batas maksimal operasional harian: **19:00 WIB**.

### BR-SCH-003: Formula Rentang Waktu Layanan
- Setiap jenis layanan memiliki durasi standar (`duration`) dalam satuan jam:
  $$\text{end\_time} = \text{start\_time} + \text{duration}$$
- Durasi standar per layanan:
  - Pembersihan Rumah: 2 jam
  - Pembersihan Kos: 1 jam
  - Pembersihan Kantor: 3 jam
  - Pembersihan Pasca Renovasi: 4 jam

### BR-SCH-004: Buffer Operasional Antar-Pesanan
- Sistem menetapkan jeda operasional wajib sebesar **30 menit (0.5 jam)** setelah setiap pekerjaan selesai untuk waktu perjalanan petugas ke lokasi berikutnya dan pembersihan peralatan.
- Petugas yang menyelesaikan pekerjaan pada pukul `10:00` baru dapat dialokasikan kembali pada pukul `10:30` atau setelahnya.
- Formula waktu ketersediaan kembali:
  $$\text{available\_again} = \text{end\_time} + 30\text{ menit}$$

### BR-SCH-005: Formula Deteksi Bentrok Jadwal (*Schedule Overlap*)
- Petugas $C$ dianggap mengalami bentrok jadwal pada tanggal yang sama jika terdapat irisan waktu antara interval pesanan baru $N$ dan interval pesanan yang sudah ada $E$ (keduanya menyertakan buffer 30 menit).
- Dua interval $[start_N, end_N + 30')$ dan $[start_E, end_E + 30')$ dinyatakan **bentrok** jika dan hanya jika:
  $$\max(start_N, start_E) < \min(end_N + 30', end_E + 30')$$
- **Kondisi Valid (Tidak Bentrok):**
  - Order baru selesai + buffer sebelum order lama dimulai: $end_N + 30' \le start_E$
  - ATAU order lama selesai + buffer sebelum order baru dimulai: $end_E + 30' \le start_N$
- Jika terjadi bentrok saat admin melakukan assignment, backend mengembalikan status HTTP `409 Conflict`.

### BR-SCH-006: Validasi Ulang Ketersediaan (*Re-validation Triggers*)
Sistem wajib memvalidasi ulang ketersediaan jadwal petugas secara otomatis pada kondisi:
1. Pelanggan mengubah tanggal atau jam mulai pada formulir pemesanan.
2. Pelanggan menekan tombol "Bayar Sekarang (Simulasi)".
3. Admin mengonfirmasi pilihan petugas dari pelanggan di dasbor admin.
4. Admin melakukan penugasan langsung (*direct assignment*) atau penggantian petugas (*reassignment*).

### BR-SCH-007: Parameter Wajib & Opsional Formulir Pemesanan
Untuk menjaga kelayakan operasional, formulir pemesanan memberlakukan klasifikasi atribut berikut:
1. **Atribut Wajib Diisi (*Mandatory Fields*):**
   - `service_id`: ID layanan valid dari katalog `services` yang aktif.
   - `tanggal_layanan`: Tanggal layanan valid ($\ge H+0$).
   - `start_time`: Jam mulai layanan dalam rentang operasional (08:00–17:00 WIB).
   - `duration`: Durasi pengerjaan dalam jam sesuai standar layanan (1 s.d. 4 jam).
   - `alamat_lengkap`: Alamat lengkap lokasi pembersihan (minimal 10 karakter).
   - `patokan_lokasi`: Petunjuk fisik/acuan jalan untuk kurir/petugas (minimal 3 karakter).
   - `luas_area`: Keterangan deskriptif ukuran area (misal: "Tipe 36", "Kamar 3x4 m", "2 Lantai") sebagai panduan beban kerja petugas.
2. **Atribut Opsional (*Optional Fields*):**
   - `catatan_khusus`: Catatan permintaan khusus atau instruksi penanganan dari pelanggan (bersifat **OPTIONAL**, boleh kosong/`NULL`).
   - `preferensi_petugas_id`: ID petugas pilihan pelanggan hasil Smart Matching (bersifat **OPTIONAL**, bernilai `NULL` jika pelanggan memilih diserahkan ke Admin).

---

## 3. Aturan Smart Petugas Matching Engine (BR-MTG)

### BR-MTG-001: Sifat Sistem Rekomendasi
- Sistem rekomendasi *Smart Matching* murni **berbasis aturan (*rule-based*)**, bukan Machine Learning dan bukan model prediktif berbasis kecerdasan buatan.
- Sistem bertugas menyajikan rekomendasi objektif kepada pelanggan; penetapan akhir tetap memerlukan konfirmasi Admin (*Hybrid Assignment*).

### BR-MTG-002: Hard Filter (Diskualifikasi Mutlak)
Seorang petugas otomatis dieliminasi dari daftar rekomendasi apabila memenuhi salah satu kondisi berikut:
1. `status_operasional` $\neq$ `'Aktif'` (petugas berstatus administratif `'Cuti'` atau `'Nonaktif'` langsung gugur). Ketersediaan tidak ditentukan oleh status `'Aktif'` semata, melainkan kombinasi status `'Aktif'` dengan ketiadaan bentrok penugasan pada tanggal dan jam yang diminta.
2. Memiliki penugasan aktif lain yang beririsan jadwal pada tanggal tersebut (memperhitungkan formula deteksi bentrok BR-SCH-005 beserta buffer operasional 30 menit).
3. Tidak memiliki keahlian minimum yang diwajibkan untuk kategori layanan teknis (misal: Layanan *Pasca Renovasi* mewajibkan keahlian `'pasca_renovasi'`; petugas tanpa keahlian ini langsung gugur).

### BR-MTG-003: Formula Pembobotan Skor Deterministik (100%)
Kandidat yang lolos Hard Filter dinilai menggunakan formula skor:
$$\text{Total Score} = (0.40 \times S_{\text{skill}}) + (0.30 \times S_{\text{avail}}) + (0.20 \times S_{\text{rating}}) + (0.10 \times S_{\text{exp}})$$

#### Rincian Komponen Skor:
1. **Skill Match Score ($S_{\text{skill}}$ — Bobot 40%):**
   Dievaluasi berdasarkan **Skill Matrix** minimum per kategori layanan:
   - **Pembersihan Rumah:**
     - Memiliki keahlian `'general_cleaning'` $\implies S_{\text{skill}} = 100$.
   - **Pembersihan Kos:**
     - Memiliki keahlian `'general_cleaning'` $\implies S_{\text{skill}} = 100$.
   - **Pembersihan Kantor:**
     - Memiliki keahlian `'office_cleaning'` $\implies S_{\text{skill}} = 100$ (prioritas utama).
     - Memiliki keahlian `'general_cleaning'` $\implies S_{\text{skill}} = 70$ (kecocokan sekunder yang dapat diterima).
   - **Pembersihan Pasca Renovasi:**
     - Wajib memiliki keahlian `'pasca_renovasi'` (disaring di Hard Filter). Jika lolos $\implies S_{\text{skill}} = 100$.
   - Tidak ada kecocokan keahlian $\implies S_{\text{skill}} = 0$.

2. **Availability Score ($S_{\text{avail}}$ — Bobot 30%):**
   Ditentukan secara deterministik berdasarkan beban penugasan lain pada tanggal layanan yang sama (hanya untuk petugas yang lolos Hard Filter):
   - Nilai `100`: Tidak memiliki pesanan aktif lain pada tanggal tersebut (petugas bebas penuh).
   - Nilai `80`: Memiliki 1 pesanan aktif lain pada tanggal tersebut, dan seluruh jadwal tetap valid (memenuhi jeda buffer 30 menit).
   - Nilai `60`: Memiliki 2 atau lebih pesanan aktif lain pada tanggal tersebut, tetapi seluruh jadwal tetap valid (memenuhi jeda buffer 30 menit).
   - Nilai `0`: Tidak lolos Hard Filter / terjadi bentrok jadwal $\implies$ gugur dari daftar rekomendasi.

3. **Rating Score ($S_{\text{rating}}$ — Bobot 20%):**
   - **Petugas dengan Riwayat Ulasan Customer:**
     $$S_{\text{rating}} = \left(\frac{\text{cleaners.rating\_rata\_rata}}{5.0}\right) \times 100$$
   - **Petugas Baru Tanpa Ulasan Customer (Aturan V1 Provisional Rating):**
     Diberikan nilai rating awal/provisional standar sebesar $4.5$ ($S_{\text{rating}} = 90.0$ poin).
   - **Ketentuan Tampilan UI:** Antarmuka wajib membedakan rating aktual customer (misal: "⭐ 4.8 (94 ulasan)") dengan petugas baru ("Petugas Baru - Rating Awal 4.5"). Rating provisional dilarang ditampilkan seolah-olah merupakan ulasan customer asli.

4. **Experience Score ($S_{\text{exp}}$ — Bobot 10%):**
   - Formula: $S_{\text{exp}} = \min\left(100, \frac{\text{pengalaman\_tahun}}{5} \times 100\right)$.
   - Contoh: 1 tahun = 20 poin, 3 tahun = 60 poin, $\ge 5$ tahun = 100 poin.

### BR-MTG-004: Aturan Pemecah Seri (*Tie-Breaking Rules*)
Apabila dua atau lebih kandidat memiliki `Total Score` yang identik, urutan penempatan kartu ditentukan secara deterministik melalui:
1. **Prioritas 1:** Nilai `rating_rata_rata` tertinggi.
2. **Prioritas 2:** Jumlah akumulasi `total_pekerjaan` sukses terbanyak.
3. **Prioritas 3:** ID unik petugas terkecil (`id` ASC) untuk memastikan hasil selalu konsisten (*reproducible*).

### BR-MTG-005: Penanganan Kondisi Tanpa Kandidat (*Zero Candidates Fallback*)
- Jika tidak ada satu pun petugas yang lolos Hard Filter pada slot jadwal yang diminta, antarmuka wajib menampilkan informasi:  
  > *"Tidak ada petugas tersedia pada jadwal ini."*
- Sistem menyediakan 3 opsi tindakan:
  1. Pelanggan memilih tanggal lain.
  2. Pelanggan memilih slot jam lain.
  3. Pelanggan memilih *"Lanjutkan dan Serahkan ke Admin"*.
- Jika opsi 3 dipilih, pesanan tetap dibuat dengan status awal `Menunggu Konfirmasi`, diberi penanda khusus `preferensi_petugas_id = NULL` dan flag `"Membutuhkan Alokasi Admin"`, lalu dialokasikan secara manual oleh Admin melalui dasbor operasional setelah pesanan terkonfirmasi.

---

## 4. Aturan Penugasan Hibrida & Audit Reassignment (BR-ASN)

### BR-ASN-001: Prasyarat Status Penugasan Mutlak (*No Lifecycle Skipping*)
- Penugasan petugas melalui endpoint `POST /api/orders/:id/assign` **HANYA DAPAT DILAKUKAN** jika pesanan telah berstatus **`Dikonfirmasi`**.
- Sistem **DILARANG KERAS** mengizinkan lompatan langsung dari `Menunggu Konfirmasi` $\rightarrow$ `Petugas Ditugaskan`.
- Jika pesanan masih berstatus `Menunggu Konfirmasi`, upaya penugasan wajib ditolak oleh backend dengan galat validasi:
  `ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT` (HTTP 400 Bad Request).

### BR-ASN-002: Jalur Pilihan Pelanggan (*Customer Preference*)
- Jika pelanggan memilih kandidat rekomendasi saat pemesanan, pesanan masuk ke antrean Admin dengan label `"Pilihan Pelanggan: [Nama Petugas]"`.
- Setelah pesanan berstatus `Dikonfirmasi` (pembayaran telah lunas), Admin menekan tombol "Tugaskan Pilihan Pelanggan" (`POST /api/orders/:id/assign`).
- Sistem memvalidasi ketersediaan jadwal petugas bersangkutan pada detik tombol ditekan (memastikan bebas bentrok dan memenuhi buffer 30 menit).
- Jika validasi lolos, status pesanan berpindah dari `Dikonfirmasi` $\rightarrow$ `Petugas Ditugaskan`, dan petugas menerima notifikasi penugasan di dasbornya.

### BR-ASN-003: Jalur Alokasi Langsung (*Direct Admin Assignment Fallback*)
- Jika pelanggan memilih opsi default *"Pilihkan Otomatis oleh Admin"* (atau pada kondisi zero candidates), pesanan masuk ke antrean Admin dengan label `"Alokasi Admin"`.
- Setelah pesanan berstatus `Dikonfirmasi`, Admin memilih petugas dari daftar dropdown petugas yang berstatus `Aktif` dan bebas bentrok jadwal.
- Admin menekan tombol "Tugaskan Langsung" (`POST /api/orders/:id/assign`) $\rightarrow$ sistem memvalidasi ketersediaan $\rightarrow$ status pesanan berubah dari `Dikonfirmasi` $\rightarrow$ `Petugas Ditugaskan`.

### BR-ASN-004: Penggantian Petugas Ber-Audit (*Audited Reassignment*)
- Penggantian petugas hanya dapat dilakukan oleh **Admin**.
- Penggantian hanya diizinkan jika pesanan masih berada pada status `Petugas Ditugaskan` (sebelum petugas menekan status `Menuju Lokasi`).
- Petugas pengganti wajib berstatus `Aktif` dan bebas dari bentrok jadwal.
- **Audit Logging Wajib:** Aksi reassignment wajib dicatat secara permanen pada `status_logs` dengan menyimpan:
  - `order_id`: ID pesanan terkait.
  - `status_sebelumnya`: `'Petugas Ditugaskan'`.
  - `status_baru`: `'Petugas Ditugaskan'`.
  - `diubah_oleh`: ID Admin pelaksana.
  - `catatan`: Format audit baku: `REASSIGN_CLEANER: dari {old_cleaner_id} ke {new_cleaner_id} - Alasan: {alasan}`.

---

## 5. Aturan Siklus 7 Status Pekerjaan & Pembatalan (BR-STS)

### BR-STS-001: Siklus Sekuensial Baku Tanpa Lompatan
Perubahan status pesanan wajib mengikuti urutan sekuensial berikut tanpa ada tahap yang dilompati:
$$\text{Menunggu Konfirmasi} \overset{(1)}{\longrightarrow} \text{Dikonfirmasi} \overset{(2)}{\longrightarrow} \text{Petugas Ditugaskan} \overset{(3)}{\longrightarrow} \text{Menuju Lokasi} \overset{(4)}{\longrightarrow} \text{Tiba di Lokasi} \overset{(5)}{\longrightarrow} \text{Sedang Dikerjakan} \overset{(6)}{\longrightarrow} \text{Selesai}$$

### BR-STS-002: Matriks Otoritas Pengubahan Status Berbasis Peran
Pengubahan status dibatasi secara ketat berdasarkan peran aktor untuk mencegah perubahan sepihak:
1. **Transisi Wewenang Admin:**
   - `Menunggu Konfirmasi` $\rightarrow$ `Dikonfirmasi`:
     - **Syarat Mutlak:** `orders.status_pembayaran` **WAJIB** bernilai `'Sudah Bayar'`.
     - Admin **DILARANG KERAS** mengonfirmasi pesanan jika status pembayaran masih `'Belum Bayar'`. Backend menolak dengan galat `ORDER_NOT_PAID_YET` (HTTP 400 Bad Request).
   - `Dikonfirmasi` $\rightarrow$ `Petugas Ditugaskan`:
     - Dilakukan via endpoint dedicated `POST /api/orders/:id/assign`.
   - `Pembatalan Operasional`: Admin berhak membatalkan pesanan sebelum status `Selesai` via `POST /api/orders/:id/cancel`.
   - *Pencegahan Abuse:* Admin **DILARANG** mengubah status operasional lapangan (`Menuju Lokasi`, `Tiba di Lokasi`, `Sedang Dikerjakan`, `Selesai`) melalui endpoint generic `PATCH /api/orders/:id/status`.
2. **Transisi Wewenang Petugas (Cleaner):**
   Petugas yang ditugaskan pada pesanan tersebut (`cleaner_id = cleaner_profile.id`) berwenang memajukan status operasional lapangan secara berurutan via `PATCH /api/orders/:id/status`:
   - `Petugas Ditugaskan` $\rightarrow$ `Menuju Lokasi`
   - `Menuju Lokasi` $\rightarrow$ `Tiba di Lokasi`
   - `Tiba di Lokasi` $\rightarrow$ `Sedang Dikerjakan` (sistem otomatis mencatat `started_at = NOW()`)
3. **Transisi Wewenang Sistem Quality Report:**
   - `Sedang Dikerjakan` $\rightarrow$ `Selesai`:
     - **HANYA DAPAT DIPICU** oleh pengiriman Quality Report lengkap yang terverifikasi melalui endpoint resmi `POST /api/quality-reports`.
     - Petugas maupun Admin dilarang mengubah status menjadi `Selesai` melalui endpoint generic `PATCH /api/orders/:id/status`.

### BR-STS-003: Aturan Pembatalan Pesanan (`Dibatalkan`)
1. **Hak Pembatalan Pelanggan:**
   - Pelanggan **HANYA DAPAT** membatalkan pesanan mandiri jika status pekerjaan masih berada pada:
     - `Menunggu Konfirmasi`
     - `Dikonfirmasi`
     - `Petugas Ditugaskan`
   - Pelanggan **DILARANG KERAS** membatalkan pesanan jika status telah mencapai:
     - `Menuju Lokasi`
     - `Tiba di Lokasi`
     - `Sedang Dikerjakan`
     - `Selesai`
2. **Hak Pembatalan Admin:**
   - Admin berhak membatalkan pesanan kapan saja **sebelum status mencapai `Selesai`**.
   - Admin diizinkan melakukan pembatalan darurat (*emergency/exception action*) termasuk saat status berada pada `Menuju Lokasi`, `Tiba di Lokasi`, maupun `Sedang Dikerjakan` apabila terjadi kendala operasional luar biasa (misal: musibah lokasi, pembatalan sepihak tempat kerja, atau pelanggaran keselamatan).
3. **Pencatatan Atribut Pembatalan:**
   - Setiap pembatalan wajib mengisi alasan pembatalan (`cancellation_reason`, minimal 5 karakter).
   - Sistem wajib mencatat:
     - `orders.status_pekerjaan = 'Dibatalkan'`
     - `orders.cancellation_reason = [alasan]`
     - `orders.cancelled_by = [user_id aktor]`
     - `orders.cancelled_at = [current_timestamp]`
   - Seluruh aksi pembatalan wajib dicatat ke dalam `status_logs`.
4. **Terminal State:**
   - Status `Dibatalkan` bersifat final (*terminal state*). Pesanan yang telah dibatalkan tidak dapat diproses atau dihidupkan kembali.
5. **Pemulihan Status Petugas:**
   - Jika pesanan yang dibatalkan telah memiliki petugas yang dialokasikan, status operasional petugas bersangkutan dikembalikan menjadi `'Aktif'`.

---

## 6. Aturan Quality Report Digital & Private Storage (BR-QRP)

### BR-QRP-001: Quality Report sebagai Gerbang Mutlak Status `Selesai`
- Status pesanan **HANYA DAPAT** berubah menjadi `Selesai` apabila formulir Quality Report telah berhasil dikirimkan (*submitted*) dan divalidasi oleh sistem.
- Tidak ada jalan pintas (*bypass*) atau tombol ubah status manual ke `Selesai` di luar pengiriman laporan mutu.

### BR-QRP-002: Standar Tiga Timestamp Pengerjaan & Invarian Validasi
Quality Report wajib merekam tiga timestamp terpisah dan presisi:
1. `started_at`: Dicatat otomatis saat pesanan berpindah status ke `Sedang Dikerjakan`.
2. `completed_at`: Waktu saat petugas menyatakan pekerjaan fisik lapangan telah selesai, dikirim dari perangkat petugas saat pengisian laporan.
3. `submitted_at`: Waktu saat server berhasil memvalidasi dan menyimpan rekaman laporan ke basis data (`NOW()`).
4. **Validasi Invarian Timestamp (Server-Side):**
   Backend wajib memvalidasi konsistensi kronologis ketiga timestamp:
   $$\text{started\_at} \le \text{completed\_at} \le \text{submitted\_at}$$
   Selain itu, `completed_at` tidak boleh berada di masa depan ($\text{completed\_at} \le \text{NOW()}$). Jika melanggar urutan atau berada di masa depan, backend menolak pengiriman laporan dengan status HTTP `400 Bad Request` (`INVALID_TIMESTAMPS`).

### BR-QRP-003: Alur Unggah Private Storage & Verifikasi Backend
Untuk mencegah pengiriman path arbitrer atau pembajakan berkas pengguna lain:
1. Petugas mengambil foto melalui antarmuka dasbor.
2. Peramban melakukan kompresi Canvas (WebP/JPEG, target 1–2 MB).
3. Berkas diunggah ke private Supabase Storage bucket `quality-reports` menggunakan path standar:  
   `orders/{order_id}/before_{timestamp}.webp` dan `orders/{order_id}/after_{timestamp}.webp`.
4. Klien mengirimkan string path: `foto_before_path` dan `foto_after_path`.
5. Backend melakukan verifikasi:
   - User terautentikasi adalah cleaner resmi yang ditugaskan pada `order_id`.
   - Pesanan sedang berada pada status `Sedang Dikerjakan`.
   - String path wajib memiliki prefix yang cocok dengan `orders/{order_id}/`.
   - Berkas fisik benar-benar ada di private bucket Supabase Storage.
6. Laporan disimpan ke tabel `quality_reports`.

### BR-QRP-004: Akses Aman Berbasis Temporary Signed URL (Customer, Cleaner, Admin)
- Seluruh berkas pada bucket `quality-reports` bersifat privat (tanpa akses publik langsung).
- Saat mengakses laporan (`GET /api/quality-reports/:order_id`), server memvalidasi otorisasi:
  - **Customer pemilik pesanan:** berhak membaca laporan miliknya (`customer_id = auth.uid()`).
  - **Cleaner yang ditugaskan:** berhak membaca laporan dari pesanan yang ditugaskan kepadanya (`cleaner_id = cleaner_profile.id`).
  - **Admin:** berhak membaca laporan seluruh pesanan untuk pengawasan mutu operasional.
  - **Pengguna lain / Tidak Terautentikasi:** ditolak dengan status HTTP `403 Forbidden` / `401 Unauthorized`.
- Server menerbitkan temporary Signed URL menggunakan Supabase Storage Client dengan masa berlaku **30 menit (1800 detik)**.

### BR-QRP-005: Dampak Finalisasi Quality Report
Setelah pengiriman laporan sukses:
1. `orders.status_pekerjaan` berubah menjadi `'Selesai'`.
2. Data laporan dikunci menjadi *read-only*.
3. `cleaners.status_operasional` kembali menjadi `'Aktif'`.
4. `cleaners.total_pekerjaan` bertambah $+1$.

### BR-QRP-006: Validasi Checklist Area Berbasis Template Layanan
Quality Report berfungsi sebagai bukti akuntabilitas bahwa seluruh area yang disepakati dalam paket layanan telah tuntas dikerjakan.
1. **Larangan Validasi Parsial:** Sistem **DILARANG KERAS** meloloskan laporan dengan aturan parsial (seperti "minimal 1 area selesai = valid").
2. **Template Wajib per Kategori Layanan:** Setiap laporan wajib menyertakan verifikasi checklist untuk seluruh area standar berikut:
   - **Pembersihan Rumah:**
     - Ruang Tamu (`completed: true`)
     - Kamar Tidur (`completed: true`)
     - Dapur (`completed: true`)
     - Kamar Mandi (`completed: true`)
     - Area Tambahan Sesuai Paket (`completed: true`)
   - **Pembersihan Kos:**
     - Kamar Tidur / Utama (`completed: true`)
     - Kamar Mandi (`completed: true`)
     - Area yang Termasuk Paket (`completed: true`)
   - **Pembersihan Kantor:**
     - Ruang Kerja (`completed: true`)
     - Area Umum / Koridor (`completed: true`)
     - Toilet Kantor (`completed: true`)
     - Pantry / Dapur Bersih (`completed: true`)
   - **Pembersihan Pasca Renovasi:**
     - Area Utama Pekerjaan (`completed: true`)
     - Pembersihan Lantai & Sudut Ruangan (`completed: true`)
     - Pembersihan Debu & Sisa Material Semen/Cat (`completed: true`)
     - Ruangan yang Termasuk Paket (`completed: true`)
3. **Validasi Backend:** Seluruh area pada template wajib memiliki hasil pemeriksaan lengkap dengan status `completed: true`. Jika terdapat area yang diabaikan atau belum tuntas, backend wajib menolak pengiriman dengan status HTTP `400 Bad Request` (`CHECKLIST_AREAS_INCOMPLETE`).

---

## 7. Aturan Keuangan & Snapshot Transaksi (BR-FIN)

### BR-FIN-001: Simulasi Pembayaran Server-Authoritative & Lifecycle Gate
- Sistem prototipe menggunakan mekanisme pembayaran simulasi *dummy checkout*.
- **Pembuatan Pesanan (`POST /api/orders`):**
  - Klien dilarang mengirimkan `status_pembayaran`.
  - Backend selalu menginisialisasi: `status_pembayaran = 'Belum Bayar'` dan `payment_timestamp = NULL`.
- **Eksekusi Pembayaran (`POST /api/orders/:id/pay`):**
  - Pelanggan memicu endpoint pembayaran simulasi.
  - Server memvalidasi kepemilikan pesanan dan status saat ini (`Belum Bayar`).
  - Server mengubah status menjadi `Sudah Bayar` dan mencatat `payment_timestamp = NOW()` (waktu server).
  - Server mencatat peristiwa ini ke `status_logs`.
- **Gerbang Lifecycle Konfirmasi Admin:**
  - Status `orders.status_pembayaran = 'Sudah Bayar'` merupakan **prasyarat mutlak** sebelum Admin dapat mengubah status pesanan dari `Menunggu Konfirmasi` menjadi `Dikonfirmasi`.
  - Admin **DILARANG KERAS** mengonfirmasi pesanan jika pembayaran masih `Belum Bayar`. Backend wajib menolak perubahan status dengan galat `ORDER_NOT_PAID_YET` (HTTP 400 Bad Request).
  - Sistem dilarang menambahkan status pekerjaan baru (seperti "Menunggu Pembayaran"); status pekerjaan awal tetap `Menunggu Konfirmasi`.

### BR-FIN-002: Formula Harga Flat Deterministik (*Price Freezing*)
1. Formula penetapan tarif pada V1 Prototype:
   $$\text{harga\_saat\_booking} = \text{services.tarif\_dasar}$$
   $$\text{total\_biaya} = \text{harga\_saat\_booking}$$
2. Parameter `luas_area` (tipe teks deskriptif, misal: "Tipe 36", "Kamar 3x4 m") disimpan sebagai data operasional penentuan alokasi alat dan persiapan petugas, bukan pengali matematis pada V1 Prototype.
3. Nilai `harga_saat_booking` dan `total_biaya` bersifat *immutable*. Perubahan tarif pada master data `services` di masa depan tidak akan pernah memengaruhi transaksi yang telah dibuat.

---

## 8. Aturan Rating & Review (V1.1 / Phase 2) (BR-REV)

### BR-REV-001: Kelayakan Ulasan
- Formulir rating dan ulasan hanya dapat diakses oleh **Pelanggan pemilik pesanan** (`customer_id = auth.uid()`).
- Ulasan hanya dapat diberikan untuk pesanan yang telah mencapai status **`Selesai`**.
- Pesanan yang dibatalkan (`Dibatalkan`) tidak dapat diberi rating.

### BR-REV-002: Batasan dan Skala Penilaian
- Skala rating berupa bilangan bulat: **1, 2, 3, 4, atau 5 bintang**.
- Ulasan catatan teks bersifat opsional.
- Satu pesanan hanya berhak menerima **1 kali pengiriman rating** (*one review per order*). Upaya mengirimkan ulasan duplikat ditolak dengan status HTTP `409 Conflict`.

### BR-REV-003: Agregasi Reputasi Petugas
- Setiap kali ulasan baru disimpan ke tabel `reviews`, sistem secara otomatis menghitung ulang nilai rata-rata:
  $$\text{cleaners.rating\_rata\_rata} = \frac{\sum \text{rating}}{\text{jumlah\_ulasan}}$$
- Nilai rating petugas diperbarui dengan pembulatan 1 angka di belakang koma (contoh: 4.8).

---

## 9. Aturan Keamanan & Akses Data (BR-SEC)

### BR-SEC-001: Supabase Auth Otoritas Tunggal
- Seluruh manajemen otentikasi (registrasi, login, reset sandi, token JWT) wajib menggunakan **Supabase Auth** (`auth.users`).
- Tabel profil aplikasi `users` dilarang menyimpan password mentah ataupun kolom `password_hash`.

### BR-SEC-002: Isolasi Data Pelanggan (*Tenant Isolation*)
- Pelanggan hanya dapat membaca dan memanipulasi pesanan miliknya sendiri berdasarkan filter `customer_id = auth.uid()`.
- Segala upaya mengakses order pengguna lain melalui manipulasi URL/API harus diblokir oleh backend dengan respon HTTP `403 Forbidden`.

### BR-SEC-003: Isolasi Data Petugas
- Petugas kebersihan hanya dapat melihat dan memperbarui pesanan yang ditugaskan kepada dirinya (`cleaner_id = cleaner_profile.id`).

### BR-SEC-004: Perlindungan Kredensial Backend
- Kunci `SUPABASE_SERVICE_ROLE_KEY` hanya boleh digunakan pada lingkungan internal server Node.js.
- Frontend dan peramban hanya diizinkan menerima `SUPABASE_URL` dan `SUPABASE_ANON_KEY`.

---

## 10. Aturan Perilaku Real-Time (BR-RT)

### BR-RT-001: Strategi Sinkronisasi Antarmuka
- **Pengalaman Pengguna:** Pembaruan status pesanan di lapangan atau oleh admin harus tercermin pada layar pelanggan secara otomatis tanpa refresh peramban manual.
- **Kanal Utama (*Primary*):** Menggunakan **Supabase Realtime (WebSocket / Postgres Changes)** untuk mendengarkan perubahan status pada tabel `orders` berdasarkan ID pesanan aktif.
- **Kanal Cadangan (*Fallback*):** Jika koneksi WebSocket terputus atau tidak didukung jaringan, antarmuka beralih ke **Short Polling** dengan interval **15 detik** selama pesanan berada pada status aktif (`Petugas Ditugaskan` s.d. `Sedang Dikerjakan`).

---

## 11. Matriks Transisi Status & Validasi State Machine

| Status Saat Ini | Status Tujuan | Aktor Pemicu | Prasyarat & Validasi Bisnis | Kode HTTP Penolakan |
| :--- | :--- | :--- | :--- | :---: |
| *Initial (Draft)* | `Menunggu Konfirmasi` | Customer | Formulir booking valid, parameter wajib lengkap, jadwal valid. Server menginisialisasi: `status_pekerjaan = 'Menunggu Konfirmasi'`, `status_pembayaran = 'Belum Bayar'`, `payment_timestamp = NULL`. | `400 Bad Request` |
| `Menunggu Konfirmasi` | `Dikonfirmasi` | Admin | **Prasyarat Mutlak:** `status_pembayaran` **WAJIB** `'Sudah Bayar'` (hasil simulasi bayar `POST /api/orders/:id/pay`). Jika masih `'Belum Bayar'`, ditolak sistem. Admin menyetujui pesanan untuk diproses alokasi. | `400 Bad Request` / `403 Forbidden` |
| `Menunggu Konfirmasi` | `Dibatalkan` | Customer / Admin | Alasan pembatalan wajib diisi (minimal 5 karakter). | `400 Bad Request` |
| `Dikonfirmasi` | `Petugas Ditugaskan` | Admin | Endpoint dedicated `POST /api/orders/:id/assign`. Petugas terpilih berstatus `Aktif` dan bebas bentrok jadwal. | `400 Bad Request` / `409 Conflict` |
| `Dikonfirmasi` | `Dibatalkan` | Customer / Admin | Alasan pembatalan wajib diisi (minimal 5 karakter). | `400 Bad Request` |
| `Petugas Ditugaskan` | `Menuju Lokasi` | Cleaner | Petugas menekan tombol mulai perjalanan di dasbor. | `403 Forbidden` |
| `Petugas Ditugaskan` | `Dibatalkan` | Customer / Admin | Alasan pembatalan wajib diisi; status petugas dipulihkan jadi `Aktif`. | `400 Bad Request` |
| `Menuju Lokasi` | `Tiba di Lokasi` | Cleaner | Petugas menekan tombol konfirmasi telah sampai di alamat. | `403 Forbidden` |
| `Menuju Lokasi` | `Dibatalkan` | Admin Saja | Pembatalan darurat operasional oleh Admin sebelum `Selesai`; alasan wajib diisi; status petugas dipulihkan ke `Aktif`. Pelanggan DILARANG membatalkan. | `400 / 403` |
| `Tiba di Lokasi` | `Sedang Dikerjakan` | Cleaner | Petugas menekan tombol mulai bekerja; sistem mencatat `started_at = NOW()`. | `403 Forbidden` |
| `Tiba di Lokasi` | `Dibatalkan` | Admin Saja | Pembatalan darurat operasional oleh Admin sebelum `Selesai`; alasan wajib diisi; status petugas dipulihkan ke `Aktif`. Pelanggan DILARANG membatalkan. | `400 / 403` |
| `Sedang Dikerjakan` | `Selesai` | Cleaner | **Kirim Quality Report Lengkap via `POST /api/quality-reports`** (seluruh checklist area template bernilai `completed: true` + foto path di private storage + catatan + invarian timestamp `started_at <= completed_at <= submitted_at`). | `400 Bad Request` / `403 Forbidden` / `404 Not Found` |
| `Sedang Dikerjakan` | `Dibatalkan` | Admin Saja (Emergency Action) | **Tindakan Darurat Operasional Admin:** Diizinkan hanya oleh Admin sebelum `Selesai` karena kendala darurat luar biasa; alasan wajib dicatat, aksi dicatat ke `status_logs`, status petugas dipulihkan ke `Aktif`. Pelanggan DILARANG membatalkan. | `400 / 403` |
| `Selesai` | *Any* | - | **TERKUNCI PERMANEN.** Status terminal, tidak dapat diubah ke status lain. | `400 Bad Request` |
| `Dibatalkan` | *Any* | - | **TERMINAL STATE.** Tidak dapat diaktifkan kembali. | `400 Bad Request` |
