import { Router } from 'express';
import { inMemoryStore, getServices } from '../lib/supabase.js';
import { getRecommendations } from '../lib/matching.js';
import { db } from '../lib/database.js';

const router = Router();

// GET /api/cleaners — Mendapatkan daftar petugas kebersihan aktif
router.get('/', async (req, res, next) => {
  try {
    const cleaners = await db.getCleaners();

    return res.status(200).json({
      success: true,
      message: 'Daftar petugas berhasil diambil',
      data: cleaners
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/cleaners/recommendations — Rekomendasi Petugas Smart Matching Deterministik (BR-MTG-001 s.d BR-MTG-005)
router.get('/recommendations', async (req, res, next) => {
  try {
    const { service_id, tanggal, start_time, duration } = req.query;

    // 1. Validasi Keberadaan Parameter Wajib
    if (!service_id || !tanggal || !start_time || !duration) {
      return res.status(400).json({
        success: false,
        message: 'Parameter service_id, tanggal, start_time, dan duration wajib diisi',
        error: 'MISSING_RECOMMENDATION_PARAMS'
      });
    }

    // 2. Validasi Tanggal (>= Hari Ini)
    const today = new Date().toISOString().split('T')[0];
    if (tanggal < today) {
      return res.status(400).json({
        success: false,
        message: 'Tanggal layanan tidak boleh di masa lampau',
        error: 'PAST_DATE_NOT_ALLOWED'
      });
    }

    // 3. Validasi Jam Operasional (08:00 - 17:00 WIB)
    if (start_time < '08:00' || start_time > '17:00') {
      return res.status(400).json({
        success: false,
        message: 'Jam mulai harus berada dalam rentang jam operasional (08:00 - 17:00 WIB)',
        error: 'OUTSIDE_OPERATING_HOURS'
      });
    }

    // 4. Validasi Durasi (1 - 4 Jam)
    const numDuration = Number(duration);
    if (isNaN(numDuration) || numDuration < 1 || numDuration > 4) {
      return res.status(400).json({
        success: false,
        message: 'Durasi harus berupa angka antara 1 sampai 4 jam',
        error: 'INVALID_DURATION'
      });
    }

    // 5. Ambil Data Layanan
    const { data: services } = await getServices(true);
    const service = services.find(s => (s.id === service_id || s.kategori === service_id) && s.is_active);
    if (!service) {
      return res.status(400).json({
        success: false,
        message: 'Layanan kebersihan tidak ditemukan atau sedang tidak aktif',
        error: 'SERVICE_NOT_FOUND'
      });
    }

    // 6. Ambil Data Petugas & Pesanan Aktif
    const cleaners = await db.getCleaners();
    const existingOrders = await db.getOrders();

    // 7. Jalankan Algoritma Smart Matching
    const recommendations = getRecommendations({
      cleaners,
      service,
      date: tanggal,
      startTime: start_time,
      duration: numDuration,
      existingOrders
    });

    return res.status(200).json({
      success: true,
      message: 'Rekomendasi petugas berhasil dihitung',
      data: recommendations
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/cleaners/:id — Detail profil petugas dan riwayat ulasan pelanggan (Stitch Screen 3)
router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const cleaner = await db.getCleanerById(id);

    if (!cleaner) {
      return res.status(404).json({
        success: false,
        message: `Petugas dengan ID ${id} tidak ditemukan`,
        error: 'CLEANER_NOT_FOUND'
      });
    }

    // Ambil ulasan terkait petugas ini
    const reviews = inMemoryStore.reviews.filter(r => r.cleaner_id === id);

    return res.status(200).json({
      success: true,
      message: 'Detail profil petugas berhasil diambil',
      data: {
        ...cleaner,
        ulasan: reviews
      }
    });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/cleaners/:id/status — Memperbarui status operasional administratif petugas (Aktif / Cuti / Nonaktif)
router.patch('/:id/status', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status_operasional } = req.body;

    const validStatuses = ['aktif', 'cuti', 'nonaktif'];
    const normalizedKey = String(status_operasional || '').trim().toLowerCase();

    if (!status_operasional || !validStatuses.includes(normalizedKey)) {
      return res.status(400).json({
        success: false,
        message: 'Status operasional tidak valid. Pilihan yang diizinkan: Aktif, Cuti, Nonaktif',
        error: 'INVALID_OPERATIONAL_STATUS'
      });
    }

    const existing = await db.getCleanerById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        message: `Petugas dengan ID ${id} tidak ditemukan`,
        error: 'CLEANER_NOT_FOUND'
      });
    }

    const updated = await db.updateCleanerStatus(id, status_operasional);

    return res.status(200).json({
      success: true,
      message: `Status operasional petugas ${updated.nama} berhasil diperbarui menjadi ${updated.status_operasional}`,
      data: updated
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/cleaners — Mendaftarkan petugas kebersihan baru (Internal Admin-Only)
router.post('/', async (req, res, next) => {
  try {
    const {
      nama,
      nomor_kontak,
      keahlian,
      pengalaman_tahun,
      foto_url,
      foto_data,
      email,
      password,
      tentang,
      sertifikasi
    } = req.body;

    // 1. Validasi Nama (Wajib, min 3 karakter)
    const trimmedNama = String(nama || '').trim();
    if (!trimmedNama || trimmedNama.length < 3) {
      return res.status(400).json({
        success: false,
        message: 'Nama petugas wajib diisi dan minimal 3 karakter',
        error: 'INVALID_NAME'
      });
    }

    // 2. Validasi Nomor Kontak (Wajib, min 8 digit)
    const trimmedKontak = String(nomor_kontak || '').trim();
    if (!trimmedKontak || trimmedKontak.length < 8 || !/^[0-9+\s\-()]{8,25}$/.test(trimmedKontak)) {
      return res.status(400).json({
        success: false,
        message: 'Nomor kontak/WhatsApp tidak valid (minimal 8 digit)',
        error: 'INVALID_CONTACT'
      });
    }

    // 3. Validasi Keahlian (Wajib array tidak kosong, kategori sah)
    const validSkills = ['rumah', 'kos', 'kantor', 'pasca_renovasi'];
    if (!Array.isArray(keahlian) || keahlian.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Keahlian wajib dipilih minimal 1 kategori layanan',
        error: 'INVALID_SKILLS'
      });
    }

    const sanitizedSkills = keahlian.map(s => String(s || '').trim().toLowerCase());
    const hasInvalidSkill = sanitizedSkills.some(s => !validSkills.includes(s));
    if (hasInvalidSkill) {
      return res.status(400).json({
        success: false,
        message: 'Keahlian harus merupakan kategori layanan yang valid (rumah, kos, kantor, pasca_renovasi)',
        error: 'INVALID_SKILLS'
      });
    }

    // 4. Validasi Pengalaman Tahun (Wajib integer >= 1)
    const numExp = Number(pengalaman_tahun);
    if (isNaN(numExp) || numExp < 1) {
      return res.status(400).json({
        success: false,
        message: 'Pengalaman kerja minimal 1 tahun',
        error: 'INVALID_EXPERIENCE'
      });
    }

    // 5. Simpan ke database (sekaligus buat akun login dan simpan foto)
    const newCleaner = await db.createCleaner({
      nama: trimmedNama,
      nomor_kontak: trimmedKontak,
      keahlian: sanitizedSkills,
      pengalaman_tahun: Math.floor(numExp),
      foto_url,
      foto_data,
      email,
      password,
      tentang,
      sertifikasi
    });

    return res.status(201).json({
      success: true,
      message: `Petugas ${newCleaner.nama} berhasil didaftarkan ke sistem`,
      data: newCleaner
    });
  } catch (err) {
    next(err);
  }
});


export default router;

