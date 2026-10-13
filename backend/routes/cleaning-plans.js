import express from 'express';
import { db } from '../lib/database.js';
import { inMemoryStore } from '../lib/supabase.js';
import { calculateNextSessionDate, generateNextSessionOrder } from '../lib/cleaning-plan-engine.js';

const router = express.Router();

const DAY_NAMES = {
  1: 'Senin',
  2: 'Selasa',
  3: 'Rabu',
  4: 'Kamis',
  5: 'Jumat',
  6: 'Sabtu',
  7: 'Minggu'
};

const DEFAULT_PRICES = {
  kos: 75000,
  rumah: 120000,
  kantor: 200000,
  pasca_renovasi: 350000
};

/**
 * POST /api/cleaning-plans
 * Pendaftaran paket langganan cerdas baru & otomatisasi pembuatan order sesi perdana
 */
router.post('/', async (req, res) => {
  try {
    const {
      customerId,
      customer_id,
      planName,
      plan_name,
      serviceCategory,
      service_category,
      serviceId,
      service_id,
      frequency,
      dayOfWeek,
      day_of_week,
      dayName,
      day_name,
      startTime,
      start_time,
      duration,
      pricePerSession,
      price_per_session,
      address,
      landmark,
      notes,
      preferredCleanerId,
      preferred_cleaner_id
    } = req.body;

    const finalCustomerId = customerId || customer_id;
    const finalPlanName = (planName || plan_name || '').trim();
    const finalCategory = serviceCategory || service_category;
    const finalFrequency = frequency || 'mingguan';
    const finalDayOfWeek = Number(dayOfWeek !== undefined ? dayOfWeek : day_of_week);
    const finalStartTime = startTime || start_time;
    const finalDuration = Number(duration !== undefined ? duration : 2);
    const finalAddress = (address || '').trim();

    // 1. Validasi Input (Server-Side Hardening)
    if (!finalCustomerId) {
      return res.status(400).json({
        success: false,
        message: 'Customer ID wajib diisi',
        error: 'VALIDATION_ERROR'
      });
    }

    if (!finalPlanName || finalPlanName.length < 3) {
      return res.status(400).json({
        success: false,
        message: 'Nama paket langganan minimal 3 karakter',
        error: 'VALIDATION_ERROR'
      });
    }

    if (!['rumah', 'kos', 'kantor', 'pasca_renovasi'].includes(finalCategory)) {
      return res.status(400).json({
        success: false,
        message: 'Kategori layanan tidak valid (pilihan: rumah, kos, kantor, pasca_renovasi)',
        error: 'VALIDATION_ERROR'
      });
    }

    if (!['mingguan', 'dua_mingguan'].includes(finalFrequency)) {
      return res.status(400).json({
        success: false,
        message: 'Frekuensi tidak valid (pilihan: mingguan, dua_mingguan)',
        error: 'VALIDATION_ERROR'
      });
    }

    if (isNaN(finalDayOfWeek) || finalDayOfWeek < 1 || finalDayOfWeek > 7) {
      return res.status(400).json({
        success: false,
        message: 'Hari dalam minggu harus berupa angka antara 1 (Senin) hingga 7 (Minggu)',
        error: 'VALIDATION_ERROR'
      });
    }

    const timeRegex = /^(0[8-9]|1[0-7]):[0-5][0-9]$/;
    if (!finalStartTime || !timeRegex.test(finalStartTime)) {
      return res.status(400).json({
        success: false,
        message: 'Jam mulai harus dalam rentang operasional 08:00 - 17:59 dengan format HH:mm',
        error: 'VALIDATION_ERROR'
      });
    }

    if (isNaN(finalDuration) || finalDuration < 1 || finalDuration > 4) {
      return res.status(400).json({
        success: false,
        message: 'Durasi layanan harus antara 1 hingga 4 jam',
        error: 'VALIDATION_ERROR'
      });
    }

    if (!finalAddress || finalAddress.length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Alamat lengkap wajib diisi minimal 10 karakter',
        error: 'VALIDATION_ERROR'
      });
    }

    const finalDayName = dayName || day_name || DAY_NAMES[finalDayOfWeek] || 'Senin';
    const finalPrice = Number(pricePerSession || price_per_session || DEFAULT_PRICES[finalCategory] || 100000);
    const finalPrefCleanerId = preferredCleanerId || preferred_cleaner_id || null;

    // 2. Hitung Tanggal Sesi Perdana secara Deterministik
    const nextSessionDate = calculateNextSessionDate({
      dayOfWeek: finalDayOfWeek,
      frequency: finalFrequency,
      startTime: finalStartTime
    });

    // 3. Simpan Paket Baru ke Database
    const newPlan = await db.createCleaningPlan({
      customerId: finalCustomerId,
      planName: finalPlanName,
      serviceCategory: finalCategory,
      serviceId: serviceId || service_id || null,
      frequency: finalFrequency,
      dayOfWeek: finalDayOfWeek,
      dayName: finalDayName,
      startTime: finalStartTime,
      duration: finalDuration,
      pricePerSession: finalPrice,
      address: finalAddress,
      landmark: landmark || null,
      notes: notes || null,
      preferredCleanerId: finalPrefCleanerId,
      status: 'Aktif',
      nextSessionDate,
      lastGeneratedDate: null,
      totalSessionsCompleted: 0
    });

    // 4. Otomatisasi Pembuatan Order Sesi Perdana (#1)
    const allOrders = typeof db.getOrders === 'function' ? await db.getOrders() : (inMemoryStore.orders || []);
    const initialOrderPayload = generateNextSessionOrder({
      plan: newPlan,
      existingOrders: allOrders
    });

    const initialOrder = await db.createOrder(initialOrderPayload);

    // 5. Majukan nextSessionDate pada plan untuk sesi berikutnya
    const nextIntervalDate = calculateNextSessionDate({
      dayOfWeek: finalDayOfWeek,
      frequency: finalFrequency,
      fromDate: nextSessionDate,
      skipFirstInterval: true
    });
    const updatedPlan = await db.updateCleaningPlanNextSession(newPlan.id, nextIntervalDate, false);

    return res.status(201).json({
      success: true,
      message: 'Paket langganan cerdas dan pesanan sesi perdana berhasil dibuat',
      data: {
        plan: updatedPlan || newPlan,
        initialOrder
      }
    });
  } catch (err) {
    console.error('[POST /api/cleaning-plans] Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan server saat membuat paket langganan',
      error: err.message
    });
  }
});

/**
 * GET /api/cleaning-plans
 * Mengambil daftar paket langganan (filter berdasarkan customer_id jika ada)
 */
router.get('/', async (req, res) => {
  try {
    const customerId = req.query.customer_id || req.query.customerId;
    let plans = [];

    if (customerId) {
      plans = await db.getCleaningPlansByCustomerId(customerId);
    } else {
      plans = inMemoryStore.cleaning_plans || [];
    }

    // Hidrasi informasi petugas langganan jika ada
    const hydratedPlans = await Promise.all(
      plans.map(async (plan) => {
        const cleanerId = plan.preferredCleanerId || plan.preferred_cleaner_id;
        if (cleanerId) {
          const cleaner = await db.getCleanerById(cleanerId);
          return {
            ...plan,
            preferred_cleaner: cleaner
          };
        }
        return {
          ...plan,
          preferred_cleaner: null
        };
      })
    );

    return res.status(200).json({
      success: true,
      message: 'Daftar paket langganan berhasil diambil',
      data: hydratedPlans
    });
  } catch (err) {
    console.error('[GET /api/cleaning-plans] Error:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan server saat mengambil daftar paket',
      error: err.message
    });
  }
});

/**
 * GET /api/cleaning-plans/:id
 * Mengambil rincian detail paket beserta riwayat pesanan yang terkait
 */
router.get('/:id', async (req, res) => {
  try {
    const planId = req.params.id;
    const plan = await db.getCleaningPlanById(planId);

    if (!plan) {
      return res.status(404).json({
        success: false,
        message: 'Paket langganan tidak ditemukan',
        error: 'NOT_FOUND'
      });
    }

    // Ambil seluruh order yang terafiliasi dengan plan ini
    const allOrders = typeof db.getOrders === 'function' ? await db.getOrders() : (inMemoryStore.orders || []);
    const planOrders = allOrders.filter(
      (o) => o.cleaning_plan_id === planId || o.cleaningPlanId === planId
    );

    let cleaner = null;
    const cleanerId = plan.preferredCleanerId || plan.preferred_cleaner_id;
    if (cleanerId) {
      cleaner = await db.getCleanerById(cleanerId);
    }

    return res.status(200).json({
      success: true,
      message: 'Detail paket langganan berhasil diambil',
      data: {
        plan: {
          ...plan,
          preferred_cleaner: cleaner
        },
        orders: planOrders
      }
    });
  } catch (err) {
    console.error(`[GET /api/cleaning-plans/${req.params.id}] Error:`, err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan server saat mengambil detail paket',
      error: err.message
    });
  }
});

/**
 * PATCH /api/cleaning-plans/:id/status
 * Memperbarui status paket (Aktif, Dijeda, Dibatalkan)
 */
router.patch('/:id/status', async (req, res) => {
  try {
    const planId = req.params.id;
    const { status } = req.body;

    if (!['Aktif', 'Dijeda', 'Dibatalkan'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Status tidak valid. Pilihan: Aktif, Dijeda, Dibatalkan',
        error: 'INVALID_STATUS'
      });
    }

    const updated = await db.updateCleaningPlanStatus(planId, status);
    if (!updated) {
      return res.status(404).json({
        success: false,
        message: 'Paket langganan tidak ditemukan',
        error: 'NOT_FOUND'
      });
    }

    return res.status(200).json({
      success: true,
      message: `Status paket langganan berhasil diubah menjadi ${status}`,
      data: updated
    });
  } catch (err) {
    console.error(`[PATCH /api/cleaning-plans/${req.params.id}/status] Error:`, err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan server saat memperbarui status paket',
      error: err.message
    });
  }
});

/**
 * POST /api/cleaning-plans/:id/generate-next-session
 * Trigger manual pembentukan sesi berikutnya (untuk demonstrasi sidang skripsi)
 */
router.post('/:id/generate-next-session', async (req, res) => {
  try {
    const planId = req.params.id;
    const plan = await db.getCleaningPlanById(planId);

    if (!plan) {
      return res.status(404).json({
        success: false,
        message: 'Paket langganan tidak ditemukan',
        error: 'NOT_FOUND'
      });
    }

    if (plan.status !== 'Aktif') {
      return res.status(400).json({
        success: false,
        message: `Tidak dapat menjadwalkan sesi baru untuk paket dengan status '${plan.status}'`,
        error: 'PLAN_NOT_ACTIVE'
      });
    }

    // Ambil order eksisting untuk pengecekan bentrok & idempotensi
    const allOrders = typeof db.getOrders === 'function' ? await db.getOrders() : (inMemoryStore.orders || []);
    const newOrderPayload = generateNextSessionOrder({
      plan,
      existingOrders: allOrders
    });

    const newOrder = await db.createOrder(newOrderPayload);

    // Hitung tanggal untuk sesi berikutnya setelah ini
    const nextTargetDate = calculateNextSessionDate({
      dayOfWeek: plan.dayOfWeek,
      frequency: plan.frequency,
      fromDate: plan.nextSessionDate,
      skipFirstInterval: true
    });

    // Perbarui plan (increment completed session dan set tanggal target baru)
    const updatedPlan = await db.updateCleaningPlanNextSession(plan.id, nextTargetDate, true);

    return res.status(201).json({
      success: true,
      message: 'Sesi berikutnya berhasil dibuat dan dijadwalkan',
      data: {
        order: newOrder,
        plan: updatedPlan
      }
    });
  } catch (err) {
    console.error(`[POST /api/cleaning-plans/${req.params.id}/generate-next-session] Error:`, err);
    const statusCode = err.message.includes('idempotency') || err.message.includes('sudah dibuat') ? 409 : 500;
    return res.status(statusCode).json({
      success: false,
      message: err.message,
      error: err.message
    });
  }
});

export default router;
