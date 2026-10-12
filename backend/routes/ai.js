import express from 'express';
import { consultAi } from '../lib/gemini.js';
import { getServices } from '../lib/supabase.js';

const router = express.Router();

/**
 * POST /api/ai/chat
 * Endpoint konsultasi AI interaktif untuk rekomendasi layanan dan customer care.
 */
router.post('/chat', async (req, res) => {
  try {
    const { message, history } = req.body;

    // 1. Validasi Input
    if (!message || typeof message !== 'string' || message.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Pesan konsultasi tidak boleh kosong',
        error: 'VALIDATION_ERROR'
      });
    }

    if (message.length > 500) {
      return res.status(400).json({
        success: false,
        message: 'Pesan terlalu panjang (maksimal 500 karakter)',
        error: 'MESSAGE_TOO_LONG'
      });
    }

    const sanitizedHistory = Array.isArray(history) ? history.slice(-10) : [];

    // 2. Ambil Katalog Layanan Aktif dari Database / In-Memory
    const { data: activeServices } = await getServices(false);

    // 3. Jalankan Konsultasi AI / Fallback
    const result = await consultAi({
      message: message.trim(),
      history: sanitizedHistory,
      activeServices: activeServices || []
    });

    return res.status(200).json({
      success: true,
      message: 'Respons konsultasi AI berhasil dibuat',
      data: {
        reply: result.reply,
        recommended_service: result.recommendedService,
        suggested_replies: result.suggestedReplies || []
      }
    });
  } catch (err) {
    console.error('[AI Router Error]', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal memproses konsultasi AI',
      error: 'INTERNAL_SERVER_ERROR'
    });
  }
});

export default router;
