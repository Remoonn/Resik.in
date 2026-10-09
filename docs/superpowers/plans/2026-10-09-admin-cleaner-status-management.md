# Manajemen Status Operasional Petugas oleh Admin (`Aktif` ↔ `Cuti` ↔ `Nonaktif`) Implementation Plan

> **Fokus:** Mengimplementasikan fitur bagi Admin untuk melihat dan mengubah status operasional administratif petugas (`Aktif`, `Cuti`, `Nonaktif`) pada Tab Tim Petugas di Dasbor Admin, terintegrasi penuh ke backend REST API dan Supabase Cloud.  
> **Source of Truth:** [docs/PRD-Resik.in.md](../../PRD-Resik.in.md) (FR-04), [docs/BUSINESS-RULES.md](../../BUSINESS-RULES.md) (BR-MTG-001), [docs/DATA-DICTIONARY.md](../../DATA-DICTIONARY.md).

---

## 1. Arsitektur & Kontrak Teknis

### A. Kontrak Endpoint REST API
- **Endpoint:** `PATCH /api/cleaners/:id/status`
- **Request Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  {
    "status_operasional": "Cuti"
  }
  ```
  *Nilai yang valid:* `"Aktif"`, `"Cuti"`, `"Nonaktif"` (case-insensitive, disimpan lowercase di Supabase sesuai CHECK constraint: `'aktif', 'sibuk', 'cuti', 'nonaktif'`).
- **Response Success (200 OK):**
  ```json
  {
    "success": true,
    "message": "Status operasional petugas berhasil diperbarui menjadi Cuti",
    "data": {
      "id": "cln-001",
      "nama": "Candra Pratama",
      "status_operasional": "Cuti",
      ...
    }
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Jika `status_operasional` tidak valid (`INVALID_OPERATIONAL_STATUS`).
  - `404 Not Found`: Jika `id` petugas tidak ditemukan (`CLEANER_NOT_FOUND`).

### B. Perubahan File
1. `backend/lib/database.js` — Menambahkan method `db.updateCleanerStatus(cleanerId, statusOperasional)` dengan fallback dual-mode (Supabase + In-Memory) & perbaikan `normalizeCleaner`.
2. `backend/routes/cleaners.js` — Menambahkan endpoint `PATCH /api/cleaners/:id/status`.
3. `backend/test/cleaner_status.test.js` — Automated test suite untuk endpoint status cleaner.
4. `mobile/lib/services/api_service.dart` — Menambahkan fungsi `ApiService.updateCleanerStatus(cleanerId, newStatus)`.
5. `mobile/lib/screens/admin_dashboard_screen.dart` — Mempercantik Tab Tim Petugas, menambahkan tombol "Ubah Status", sheet pemilihan status dengan radio chips & penjelasan dampak operasional, serta feedback SnackBar.
6. `mobile/test/admin_cleaner_status_test.dart` — Widget test untuk pengujian interaksi ubah status petugas di sisi Admin.

---

## 2. Rincian Task Eksekusi

### Task 1: Backend Database & Repository Layer (TDD)
- **Files:** `backend/lib/database.js`, `backend/test/cleaner_status.test.js`
- **Langkah:**
  1. Buat test awal di `backend/test/cleaner_status.test.js` yang menguji `db.updateCleanerStatus` dan endpoint `PATCH /api/cleaners/:id/status`.
  2. Implementasikan `updateCleanerStatus` di `backend/lib/database.js`:
     - Standarisasi nilai: `'Aktif'`, `'Cuti'`, `'Nonaktif'`.
     - Update Supabase table `cleaners` kolom `status_operasional = status.toLowerCase()`.
     - Update `inMemoryStore.cleaners` jika mode in-memory.
     - Perbarui `normalizeCleaner` agar memetakan status canonical PascalCase (`'Aktif'`, `'Cuti'`, `'Nonaktif'`).
  3. Jalankan `npm test` untuk memverifikasi kelulusan.

### Task 2: Backend REST API Route
- **Files:** `backend/routes/cleaners.js`
- **Langkah:**
  1. Tambahkan handler `PATCH /:id/status` dengan validasi parameter `status_operasional`.
  2. Kembalikan envelope respon JSON baku.
  3. Verifikasi dengan test suite `backend/test/cleaner_status.test.js`.

### Task 3: Mobile Service Integration
- **Files:** `mobile/lib/services/api_service.dart`
- **Langkah:**
  1. Tambahkan static method `updateCleanerStatus(String cleanerId, String newStatus)` dengan HTTP PATCH ke `${ApiConstants.baseUrl}/cleaners/$cleanerId/status`.
  2. Tangani decoding response dan penanganan error jaringan.

### Task 4: Mobile Admin Dashboard UI Enhancement & Status Bottom Sheet
- **Files:** `mobile/lib/screens/admin_dashboard_screen.dart`
- **Langkah:**
  1. Perbarui `_buildCleanersTab()`:
     - Kartu petugas menampilkan badge status visual:
       - Hijau untuk `Aktif`
       - Oranye/Kuning untuk `Cuti`
       - Abu-abu/Netral untuk `Nonaktif`
     - Tambahkan tombol aksi `Ubah Status` (OutlinedButton / PopupMenu).
  2. Buat method `_showChangeStatusSheet(CleanerModel cleaner)`:
     - Menampilkan modal bottom sheet dengan opsi 3 status disertai ikon dan deskripsi singkat dampaknya terhadap Smart Matching.
     - Menampilkan indikator loading saat proses mutasi.
     - Menampilkan SnackBar konfirmasi sukses/gagal.
     - Memanggil `_loadData()` untuk me-refresh data petugas dan pipeline.

### Task 5: Mobile Widget Test & Verifikasi Menyeluruh
- **Files:** `mobile/test/admin_cleaner_status_test.dart`
- **Langkah:**
  1. Tulis widget test untuk `AdminDashboardScreen` guna memastikan kartu petugas menampilkan status dan sheet perubahan status dapat dibuka.
  2. Jalankan `flutter test`.
  3. Jalankan `flutter analyze` untuk memastikan tidak ada linting issues.
