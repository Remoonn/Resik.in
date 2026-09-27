import { Router } from 'express';

const router = Router();

// GET /api/auth/me — Memverifikasi profil sesi pengguna aktif
router.get('/me', (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Endpoint autentikasi sesi pengguna',
    data: {
      authenticated: false,
      role: 'guest'
    }
  });
});

export default router;
