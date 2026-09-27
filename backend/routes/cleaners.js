import { Router } from 'express';
import { inMemoryStore, supabase, getServices } from '../lib/supabase.js';
import { getRecommendations } from '../lib/matching.js';

const router = Router();

// GET /api/cleaners — Mendapatkan daftar petugas kebersihan aktif
router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('cleaners').select('*');
    const cleaners = (error || !data || data.length === 0) ? inMemoryStore.cleaners : data;

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
    const service = services.find(s => s.id === service_id && s.is_active);
    if (!service) {
      return res.status(400).json({
        success: false,
        message: 'Layanan kebersihan tidak ditemukan atau sedang tidak aktif',
        error: 'SERVICE_NOT_FOUND'
      });
    }

    // 6. Ambil Data Petugas & Pesanan Aktif
    const cleaners = inMemoryStore.cleaners;
    const existingOrders = inMemoryStore.orders;

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
    const cleaner = inMemoryStore.cleaners.find(c => c.id === id);

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

export default router;
