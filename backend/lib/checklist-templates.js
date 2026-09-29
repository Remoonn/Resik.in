// backend/lib/checklist-templates.js

/**
 * Template checklist mutu pekerjaan terstandarisasi berdasarkan kategori layanan.
 * Source of Truth: docs/BUSINESS-RULES.md (BR-QRP-006)
 */
export const CHECKLIST_TEMPLATES = {
  rumah: [
    'Ruang Tamu',
    'Kamar Tidur',
    'Dapur',
    'Kamar Mandi',
    'Area Tambahan Sesuai Paket'
  ],
  kos: [
    'Kamar Tidur / Utama',
    'Kamar Mandi',
    'Area yang Termasuk Paket'
  ],
  kantor: [
    'Ruang Kerja',
    'Area Umum / Koridor',
    'Toilet Kantor',
    'Pantry / Dapur Bersih'
  ],
  renovasi: [
    'Area Utama Pekerjaan',
    'Pembersihan Lantai & Sudut Ruangan',
    'Pembersihan Debu & Sisa Material Semen/Cat',
    'Ruangan yang Termasuk Paket'
  ],
  pasca_renovasi: [
    'Area Utama Pekerjaan',
    'Pembersihan Lantai & Sudut Ruangan',
    'Pembersihan Debu & Sisa Material Semen/Cat',
    'Ruangan yang Termasuk Paket'
  ]
};
