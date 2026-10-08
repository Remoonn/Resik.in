# Template Pesan Laporan Kemajuan ke Dosen Pembimbing
## Resik.in — Aplikasi Jasa Kebersihan On-Demand

Dokumen ini menyediakan berbagai format pesan siap pakai untuk dikirimkan kepada Dosen Pembimbing melalui WhatsApp, Email, atau Portal Bimbingan Tugas Akhir. Cukup sesuaikan bagian di dalam tanda kurung siku `[...]`.

---

## 1. Format Standar Harian (Paling Sering Digunakan)

```text
Selamat [pagi/siang/sore] Pak/Bu [Nama Dosen Pembimbing],
Izin menyampaikan laporan kemajuan harian pengerjaan Project dan Naskah Skripsi Resik.in per [Hari, Tanggal Bulan Tahun]:

A. KEMAJUAN PROJECT (Aplikasi Resik.in):
1. [Modul/Fitur]: Selesai mengimplementasikan [Nama Fitur/Modul]
   - Hasil konkret: [Misal: Endpoint POST /api/quality-reports dengan validasi 9-tahap dan upload foto Before/After ke Supabase Storage]
   - Status Uji: [Misal: 10/10 test case lulus pada backend (npm test) dan flutter test tanpa galat]
   - Bukti: [Lampirkan screenshot UI / potongan bukti test / link commit GitHub]

B. KEMAJUAN NASKAH SKRIPSI:
1. [Bab/Subbab]: Selesai menulis [Misal: Bab 3 Subbab 3.4 Perancangan Basis Data & Kamus Data]
   - Hasil konkret: Penambahan [X] halaman (total draf naskah saat ini: [Y] halaman)
   - Artefak: [Misal: Diagram ERD Konseptual/Fisik 6 tabel relasional dan diagram alur 7 status pesanan]
   - Naskah: [File PDF draf bab terlampir / link Google Drive]

C. KOMITMEN OUTPUT HARI BERIKUTNYA:
- Project: [Satu fitur konkret yang dijadwalkan selesai, misal: Integrasi ReviewBottomSheet dan perhitungan agregasi rating petugas]
- Skripsi: [Satu subbab konkret yang dijadwalkan selesai, misal: Bab 3 Subbab 3.5 Perancangan Antarmuka Pengguna]

Terima kasih banyak atas waktu, arahan, dan bimbingan Bapak/Ibu. 🙏
```

---

## 2. Format Laporan Saat Menghadapi Kendala Teknis (*Stuck / Bug*)

> **Pedoman Penting:** Saat menyampaikan kendala, hindari hanya melaporkan pesan error. Sertakan diagnosis akar masalah (*root cause*), langkah alternatif yang telah dicoba, dan status penanganan terkini.

```text
Selamat [pagi/siang/sore] Pak/Bu [Nama Dosen Pembimbing],
Izin melaporkan progres pengerjaan Project dan Skripsi Resik.in per [Hari, Tanggal Bulan Tahun]:

A. KEMAJUAN PROJECT:
1. Capaian Berhasil: Selesai membangun [Fitur/Komponen yang berhasil dibuat hari ini].
2. Catatan Kendala Teknis & Solusi:
   - Kendala: [Misal: Penyesuaian skema tabel orders di Supabase Cloud menghasilkan inkonsistensi nama kolom total_price vs total_amount]
   - Tindakan & Pengujian: [Telah dibuat modul data mapper dua arah (mapper.js) serta sanitasi UUID untuk menjembatani format data mobile dan PostgreSQL cloud]
   - Status Saat Ini: Teratasi 100% dan seluruh 17 unit test orders lulus kembali.

B. KEMAJUAN NASKAH SKRIPSI:
1. Penulisan Bab [X Subbab Y]: Bertambah [Z] halaman.
2. Penambahan dokumentasi solusi penanganan inkonsistensi skema data pada Bab 4 (Implementasi Basis Data).

C. KOMITMEN OUTPUT BESOK:
- Project: [Target fitur selanjutnya, misal: Dasbor Cleaner dengan pelacakan tugas aktif].
- Skripsi: [Target naskah berikutnya, misal: Dokumentasi arsitektur multi-role RBAC].

Terima kasih banyak, Pak/Bu. 🙏
```

---

## 3. Format Laporan Milestone Selesai / Siap Demonstrasi Sistem

Gunakan format ini ketika suatu sprint/modul besar selesai diuji dan siap diperlihatkan secara langsung kepada dosen:

```text
Selamat [pagi/siang/sore] Pak/Bu [Nama Dosen Pembimbing],
Izin mengabarkan bahwa Modul [Nama Modul, misal: Quality Report Gate & Sequential Order Tracking] pada aplikasi Resik.in telah selesai diimplementasikan dan berhasil melalui pengujian fungsional.

Ringkasan Hasil Implementasi:
1. Aplikasi Mobile & Backend:
   - Pelanggan dapat memantau 7 tahapan status pesanan secara reaktif.
   - Petugas wajib mengirimkan laporan mutu (foto Before/After dan checklist area kerja) sebelum pesanan dapat diselesaikan (Mandatory Gate Lockout).
   - Pengujian otomatis: Seluruh test suite backend (npm test) dan widget test Flutter (flutter test) berstatus PASS.
   - Video rekaman demonstrasi alur (durasi ~2 menit): [Tautan Google Drive / Video]
2. Dokumen Skripsi:
   - Pembahasan Bab 4 untuk modul ini telah selesai ditulis beserta tabel hasil pengujian Black-Box.
   - Draf naskah terbaru telah diperbarui ([Total] halaman, terlampir).

Apabila Bapak/Ibu memiliki waktu luang, saya siap mendemonstrasikan sistem ini secara langsung pada sesi bimbingan berikutnya. Terima kasih banyak, Pak/Bu. 🙏
```
