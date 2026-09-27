import { Router } from 'express';

const router = Router();

// GET /api/quality-reports/:order_id — Inspeksi laporan mutu (Sprint 3)
router.get('/:order_id', (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Endpoint Quality Report siap diimplementasikan pada Sprint 3',
    data: null
  });
});

export default router;
