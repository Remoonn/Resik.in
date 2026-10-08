# Sistem Pelacakan Kemajuan (Progress Tracker)
## Resik.in: Prototipe Aplikasi Jasa Kebersihan On-Demand & Naskah Skripsi

**Mahasiswa:** Agil Seno Adjie  
**Program Studi / Fakultas:** Informatika / Fakultas Teknologi Industri  
**Institusi:** Universitas Islam Indonesia  
**Repositori:** Resik.in  

Folder ini dibuat khusus untuk mencatat, mengelola, dan memverifikasi **kemajuan konkret (deliverables)** harian dari pengembangan prototipe aplikasi **Resik.in** dan penulisan **Naskah Skripsi**, terhitung sejak awal inisiasi proyek (25 September 2026) hingga tahap pengujian akhir.

---

## 📁 Struktur Berkas

```text
laporan-skripsi-resikin/
│
├── README.md                     # Panduan penggunaan & aturan pelaporan harian ke dosen
├── TEMPLATE-LAPORAN-DOSEN.md     # Template pesan WhatsApp/email siap kirim ke dosen pembimbing
├── LOGBOOK-HARIAN.md             # Log harian kronologis riil (berbasis riwayat commit & deliverables)
├── PROGRESS-PROJECT.md           # Matriks status modul aplikasi Resik.in (dari PRD v1.2)
├── PROGRESS-SKRIPSI.md           # Matriks status bab, subbab, diagram UML, dan naskah skripsi
│
└── bukti-progres/                # Direktori penyimpanan screenshot UI, diagram UML, & bukti test
```

---

## ⚡ Aturan Emas Pelaporan Harian ke Dosen

1. **Bukan Belajar, Bukan Sekadar Rencana:**  
   Hindari menulis *"Hari ini belajar Flutter"* atau *"Rencana besok mau merancang database"*.  
   Gunakan pernyataan konkret: *"Selesai mengimplementasikan skema database 5 tabel di PostgreSQL Supabase lengkap dengan aturan integritas relasional dan penegakan isolasi RBAC."*
2. **Berbasis Artefak (Bukti Konkret):**  
   Setiap poin capaian wajib memiliki bukti fisik/digital (file kode, screenshot UI, diagram pemodelan, hasil kelulusan automated tests, atau naskah bab skripsi yang bertambah halamannya).
3. **Dua Pilar Setiap Hari:**  
   Selalu laporkan 2 komponen utama secara berimbang:
   * **Pilar 1:** Kemajuan Project Aplikasi (*Mobile Flutter / Backend Node.js / Database Supabase*).
   * **Pilar 2:** Kemajuan Dokumen Skripsi (*Bab / Subbab / Diagram UML / ERD / Pengujian*).
4. **Komitmen Output Hari Berikutnya:**  
   Tuliskan minimal 1 hal konkret yang dijanjikan selesai pada hari berikutnya agar dosen pembimbing dapat memantau arah dan target kerja terukur.

---

## 🚀 Alur Kerja Harian

1. Buka [PROGRESS-PROJECT.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/laporan-skripsi-resikin/PROGRESS-PROJECT.md) dan [PROGRESS-SKRIPSI.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/laporan-skripsi-resikin/PROGRESS-SKRIPSI.md) untuk melihat item yang sedang berjalan (*In Progress*) atau berikutnya (*To Do*).
2. Kerjakan implementasi kode atau penulisan naskah. Jalankan verifikasi mandiri (`npm test` pada backend dan `flutter test` pada mobile).
3. Catat capaian terverifikasi di [LOGBOOK-HARIAN.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/laporan-skripsi-resikin/LOGBOOK-HARIAN.md). Simpan tangkapan layar pendukung di folder `bukti-progres/`.
4. Salin draf pesan dari [TEMPLATE-LAPORAN-DOSEN.md](file:///c:/Users/62859/Documents/Skripsi/Resik.in/laporan-skripsi-resikin/TEMPLATE-LAPORAN-DOSEN.md), isi detail capaian hari ini, lalu kirimkan ke dosen pembimbing via WhatsApp atau Sistem Bimbingan Kampus.
