import express from 'express';
import { inMemoryStore, saveStateToDisk } from '../lib/supabase.js';
import { db } from '../lib/database.js';

const router = express.Router();

function maskCustomerName(rawName) {
  if (!rawName) return 'Pelanggan Resik.in';
  const parts = rawName.trim().split(/\s+/);
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[parts.length - 1].charAt(0).toUpperCase()}.`;
}

// 1. POST /api/reviews — Pengiriman Ulasan Baru (5-Stage Validation Pipeline)
router.post('/', async (req, res) => {
  try {
    const { order_id, rating, catatan_ulasan, user_id } = req.body;

    if (!order_id) {
      return res.status(400).json({
        success: false,
        message: 'Parameter order_id wajib disertakan',
        error: 'MISSING_ORDER_ID'
      });
    }

    // Tahap 1: Validasi eksistensi order
    const order = await db.getOrderById(order_id);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Pesanan tidak ditemukan',
        error: 'ORDER_NOT_FOUND'
      });
    }

    // Tahap 2: Validasi otorisasi pemilik order (RBAC)
    const effectiveUserId = user_id || req.headers['x-user-id'];
    if (effectiveUserId && effectiveUserId !== order.customer_id) {
      return res.status(403).json({
        success: false,
        message: 'Hanya pelanggan pemilik pesanan yang berhak mengirimkan ulasan',
        error: 'FORBIDDEN_NOT_ORDER_OWNER'
      });
    }

    // Tahap 3: Validasi status pesanan wajib 'selesai'
    if (!order.status_pekerjaan || order.status_pekerjaan.toLowerCase() !== 'selesai') {
      return res.status(400).json({
        success: false,
        message: 'Ulasan hanya dapat diberikan jika pesanan telah selesai dikerjakan',
        error: 'ORDER_NOT_COMPLETED'
      });
    }

    // Tahap 4: Validasi rentang nilai rating (integer 1 - 5)
    const numRating = Number(rating);
    if (!Number.isInteger(numRating) || numRating < 1 || numRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating wajib berupa bilangan bulat antara 1 hingga 5',
        error: 'INVALID_RATING'
      });
    }

    // Tahap 5: Validasi anti-duplikasi ulasan (One review per order)
    const existingReview = await db.getReviewByOrderId(order_id);
    if (existingReview) {
      return res.status(409).json({
        success: false,
        message: 'Pesanan ini sudah pernah diberikan ulasan sebelumnya',
        error: 'REVIEW_ALREADY_EXISTS'
      });
    }

    // Dapatkan data profil pelanggan untuk nama review
    let customerName = 'Pelanggan Resik.in';
    const customerUser = (inMemoryStore.users || []).find(u => u.id === order.customer_id);
    if (customerUser && customerUser.nama) {
      customerName = customerUser.nama;
    }

    const reviewId = `rev-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const newReview = await db.createReview({
      id: reviewId,
      order_id: order.id,
      customer_id: order.customer_id,
      customer_nama: customerName,
      cleaner_id: order.cleaner_id,
      rating: numRating,
      catatan_ulasan: catatan_ulasan ? String(catatan_ulasan).trim().slice(0, 300) : '',
      created_at: new Date().toISOString()
    });

    // Perbarui agregasi rating cleaner secara sinkron
    const updatedCleaner = await db.updateCleanerRating(order.cleaner_id);

    return res.status(201).json({
      success: true,
      message: 'Rating dan ulasan berhasil dikirim',
      data: {
        id: newReview.id,
        order_id: newReview.order_id,
        customer_id: newReview.customer_id,
        cleaner_id: newReview.cleaner_id,
        rating: newReview.rating,
        catatan_ulasan: newReview.catatan_ulasan,
        created_at: newReview.created_at,
        cleaner_summary: updatedCleaner ? {
          id: updatedCleaner.id,
          rating_rata_rata: updatedCleaner.rating_rata_rata,
          total_ulasan: updatedCleaner.total_ulasan
        } : null
      }
    });
  } catch (err) {
    console.error('[reviewsRouter] Gagal menyimpan ulasan:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan internal saat memproses ulasan',
      error: 'INTERNAL_SERVER_ERROR'
    });
  }
});

// 2. GET /api/reviews/order/:order_id — Cek Status Ulasan Pesanan
router.get('/order/:order_id', async (req, res) => {
  const { order_id } = req.params;
  const review = await db.getReviewByOrderId(order_id);
  if (!review) {
    return res.status(404).json({
      success: false,
      message: 'Pesanan belum memiliki ulasan',
      error: 'REVIEW_NOT_FOUND'
    });
  }

  return res.status(200).json({
    success: true,
    data: {
      id: review.id,
      order_id: review.order_id,
      customer_id: review.customer_id,
      cleaner_id: review.cleaner_id,
      rating: review.rating,
      catatan_ulasan: review.catatan_ulasan || review.ulasan || '',
      created_at: review.created_at || review.tanggal
    }
  });
});

// 3. GET /api/reviews/cleaner/:cleaner_id — Riwayat Ulasan Publik Petugas
router.get('/cleaner/:cleaner_id', async (req, res) => {
  const { cleaner_id } = req.params;
  const cleaner = await db.getCleanerById(cleaner_id);
  if (!cleaner) {
    return res.status(404).json({
      success: false,
      message: 'Petugas kebersihan tidak ditemukan',
      error: 'CLEANER_NOT_FOUND'
    });
  }

  const cleanerReviews = await db.getReviewsByCleanerId(cleaner_id);
  const mappedReviews = cleanerReviews.map(r => ({
    id: r.id,
    order_id: r.order_id,
    customer_name: maskCustomerName(r.customer_nama),
    rating: r.rating,
    catatan_ulasan: r.catatan_ulasan || r.ulasan || '',
    created_at: r.created_at || r.tanggal
  }));

  return res.status(200).json({
    success: true,
    data: {
      cleaner_id: cleaner.id,
      rating_rata_rata: cleaner.rating_rata_rata,
      total_ulasan: cleanerReviews.length,
      reviews: mappedReviews
    }
  });
});

export default router;
