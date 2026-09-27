import { Router } from 'express';
import { getServices } from '../lib/supabase.js';

const router = Router();

// GET /api/services — Mengambil katalog layanan kebersihan
router.get('/', async (req, res, next) => {
  try {
    const showAll = req.query.all === 'true';
    const { data } = await getServices(showAll);

    return res.status(200).json({
      success: true,
      message: 'Katalog layanan berhasil diambil',
      data
    });
  } catch (err) {
    next(err);
  }
});

export default router;
