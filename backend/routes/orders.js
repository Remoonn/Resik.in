import { Router } from 'express';
import crypto from 'crypto';
import { inMemoryStore, getServices, saveStateToDisk } from '../lib/supabase.js';
import { db } from '../lib/database.js';

const router = Router();

// Helper untuk format waktu dan kalkulasi end_time (start_time + duration)
function calculateEndTime(startTime, durationHours) {
  const [hours, minutes] = startTime.split(':').map(Number);
  const endHours = hours + Number(durationHours);
  const formattedHours = String(endHours).padStart(2, '0');
  const formattedMinutes = String(minutes).padStart(2, '0');
  return `${formattedHours}:${formattedMinutes}`;
}

// Konversi format HH:mm ke total menit dari 00:00
function timeToMinutes(timeStr) {
  const [h, m] = timeStr.split(':').map(Number);
  return h * 60 + m;
}

// Pemeriksaan bentrok jadwal dua rentang waktu dengan buffer operasional (default 30 menit)
function isScheduleConflict(startA, endA, startB, endB, bufferMinutes = 30) {
  const aStart = timeToMinutes(startA);
  const aEnd = timeToMinutes(endA) + bufferMinutes;
  const bStart = timeToMinutes(startB);
  const bEnd = timeToMinutes(endB) + bufferMinutes;

  return Math.max(aStart, bStart) < Math.min(aEnd, bEnd);
}

// Helper untuk generate kode pesanan unik: RSK-YYYYMMDD-XXX
function generateOrderCode(tanggalLayanan) {
  const cleanDate = (tanggalLayanan || new Date().toISOString().split('T')[0]).replace(/-/g, '');
  const count = (inMemoryStore.orders.length + 1).toString().padStart(3, '0');
  return `RSK-${cleanDate}-${count}`;
}

// GET /api/orders — Mengambil daftar pesanan
router.get('/', async (req, res) => {
  const orders = await db.getOrders();

  return res.status(200).json({
    success: true,
    message: 'Daftar pesanan berhasil diambil',
    data: orders
  });
});

// GET /api/orders/:id — Detail lengkap pesanan
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  const order = await db.getOrderById(id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  return res.status(200).json({
    success: true,
    message: 'Detail pesanan berhasil diambil',
    data: order
  });
});

// POST /api/orders — Membuat pesanan baru dengan snapshot harga deterministik
router.post('/', async (req, res) => {
  try {
    const body = req.body;

    // 1. Validasi Keamanan: Klien dilarang menginjeksi status_pembayaran
    if (body.status_pembayaran !== undefined) {
      return res.status(400).json({
        success: false,
        message: 'Klien dilarang mengirimkan status_pembayaran pada pembuatan pesanan',
        error: 'FORBIDDEN_PAYMENT_STATUS_INJECTION'
      });
    }

    // 2. Validasi Parameter Wajib
    const mandatoryFields = [
      'service_id',
      'alamat_lengkap',
      'patokan_lokasi',
      'luas_area',
      'tanggal_layanan',
      'start_time',
      'duration'
    ];

    const missingFields = mandatoryFields.filter(f => body[f] === undefined || body[f] === null || body[f] === '');
    if (missingFields.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Field wajib tidak lengkap: ${missingFields.join(', ')}`,
        error: 'MISSING_MANDATORY_FIELDS'
      });
    }

    // 3. Validasi Panjang Karakter Alamat & Patokan
    if (typeof body.alamat_lengkap !== 'string' || body.alamat_lengkap.trim().length < 10) {
      return res.status(400).json({
        success: false,
        message: 'alamat_lengkap minimal 10 karakter',
        error: 'INVALID_ADDRESS_LENGTH'
      });
    }

    if (typeof body.patokan_lokasi !== 'string' || body.patokan_lokasi.trim().length < 3) {
      return res.status(400).json({
        success: false,
        message: 'patokan_lokasi minimal 3 karakter',
        error: 'INVALID_LANDMARK_LENGTH'
      });
    }

    // 4. Validasi Rentang Jam Operasional (08:00 - 17:00 WIB)
    const startTimeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
    if (!startTimeRegex.test(body.start_time)) {
      return res.status(400).json({
        success: false,
        message: 'Format start_time harus HH:mm (contoh: 09:00)',
        error: 'INVALID_TIME_FORMAT'
      });
    }

    if (body.start_time < '08:00' || body.start_time > '17:00') {
      return res.status(400).json({
        success: false,
        message: 'start_time harus berada dalam rentang jam operasional (08:00 - 17:00 WIB)',
        error: 'OUTSIDE_OPERATING_HOURS'
      });
    }

    // 5. Validasi Durasi (1 s.d. 4 jam)
    const duration = Number(body.duration);
    if (isNaN(duration) || duration < 1 || duration > 4) {
      return res.status(400).json({
        success: false,
        message: 'Durasi pengerjaan harus antara 1 sampai 4 jam',
        error: 'INVALID_DURATION'
      });
    }

    // 6. Validasi Tanggal Layanan (>= H+0)
    const today = new Date().toISOString().split('T')[0];
    if (body.tanggal_layanan < today) {
      return res.status(400).json({
        success: false,
        message: 'tanggal_layanan tidak boleh di masa lampau',
        error: 'PAST_DATE_NOT_ALLOWED'
      });
    }

    // 7. Cari Layanan dan Lakukan Snapshot Tarif Flat Deterministik
    const { data: services } = await getServices(true);
    const service = services.find(s => s.id === body.service_id && s.is_active);

    if (!service) {
      return res.status(400).json({
        success: false,
        message: 'Layanan kebersihan tidak ditemukan atau sedang tidak aktif',
        error: 'SERVICE_NOT_FOUND'
      });
    }

    const hargaSaatBooking = Number(service.tarif_dasar);
    const totalBiaya = hargaSaatBooking; // Formula V1 Prototype: total_biaya = harga_saat_booking
    const endTime = calculateEndTime(body.start_time, duration);

    // 8. Buat Objek Pesanan Baru
    const newOrder = {
      id: crypto.randomUUID(),
      order_code: generateOrderCode(body.tanggal_layanan),
      customer_id: body.customer_id || 'usr-customer-001',
      service_id: service.id,
      service_kategori: service.kategori,
      cleaner_id: null,
      preferensi_petugas_id: body.preferensi_petugas_id || null,
      tanggal_layanan: body.tanggal_layanan,
      start_time: body.start_time,
      end_time: endTime,
      duration: duration,
      alamat_lengkap: body.alamat_lengkap.trim(),
      patokan_lokasi: body.patokan_lokasi.trim(),
      luas_area: body.luas_area.trim(),
      catatan_khusus: body.catatan_khusus ? body.catatan_khusus.trim() : null,
      harga_saat_booking: hargaSaatBooking,
      total_biaya: totalBiaya,
      status_pembayaran: 'Belum Bayar',
      payment_timestamp: null,
      status_pekerjaan: 'Menunggu Konfirmasi',
      cancellation_reason: null,
      cancelled_by: null,
      cancelled_at: null,
      created_at: new Date().toISOString()
    };

    const createdOrder = await db.createOrder(newOrder);

    return res.status(201).json({
      success: true,
      message: 'Pesanan berhasil dibuat, silakan selesaikan pembayaran',
      data: {
        id: createdOrder.id,
        order_code: createdOrder.order_code,
        harga_saat_booking: createdOrder.harga_saat_booking,
        total_biaya: createdOrder.total_biaya,
        status_pembayaran: createdOrder.status_pembayaran,
        status_pekerjaan: createdOrder.status_pekerjaan,
        payment_timestamp: createdOrder.payment_timestamp
      }
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message || 'Terjadi kesalahan internal saat membuat pesanan',
      error: 'ORDER_CREATION_FAILED'
    });
  }
});

// POST /api/orders/:id/pay — Simulasi Pembayaran Server-Authoritative
router.post('/:id/pay', async (req, res) => {
  const { id } = req.params;
  const order = await db.getOrderById(id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  if (order.status_pembayaran === 'Sudah Bayar') {
    return res.status(400).json({
      success: false,
      message: 'Pesanan sudah dibayar sebelumnya',
      error: 'ORDER_ALREADY_PAID'
    });
  }

  const updated = await db.updateOrderPayment(id, { customer_id: order.customer_id });

  return res.status(200).json({
    success: true,
    message: 'Simulasi pembayaran berhasil diverifikasi',
    data: {
      id: updated.id,
      status_pembayaran: updated.status_pembayaran,
      payment_timestamp: updated.payment_timestamp
    }
  });
});

// PATCH /api/orders/:id/status — Transisi status sekuensial mutlak
router.patch('/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status_baru, role } = req.body;
  const order = await db.getOrderById(id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  // Matriks alur sekuensial mutlak (No Status Skipping)
  const validTransitions = {
    'Menunggu Konfirmasi': ['Dikonfirmasi'],
    'Dikonfirmasi': ['Petugas Ditugaskan'],
    'Petugas Ditugaskan': ['Menuju Lokasi'],
    'Menuju Lokasi': ['Tiba di Lokasi'],
    'Tiba di Lokasi': ['Sedang Dikerjakan'],
    'Sedang Dikerjakan': [] // Transisi ke Selesai WAJIB lewat Quality Report (Sprint 4)
  };

  // Penguncian Gerbang Status Selesai (Mandatory Gate via Quality Report)
  if (status_baru === 'Selesai') {
    return res.status(400).json({
      success: false,
      message: 'Transisi ke status Selesai wajib melalui pengiriman Quality Report pada POST /api/quality-reports',
      error: 'QUALITY_REPORT_REQUIRED'
    });
  }

  const allowedNext = validTransitions[order.status_pekerjaan] || [];
  if (!allowedNext.includes(status_baru)) {
    return res.status(400).json({
      success: false,
      message: `Transisi status tidak valid dari '${order.status_pekerjaan}' ke '${status_baru}'`,
      error: 'INVALID_STATUS_TRANSITION'
    });
  }

  // Validasi prasyarat pembayaran untuk Dikonfirmasi
  if (status_baru === 'Dikonfirmasi') {
    if (order.status_pembayaran !== 'Sudah Bayar') {
      return res.status(400).json({
        success: false,
        message: 'Pesanan belum dibayar. Konfirmasi hanya diizinkan untuk pesanan yang telah lunas.',
        error: 'ORDER_NOT_PAID_YET'
      });
    }
  }

  const updated = await db.updateOrderStatus(id, status_baru, {
    prevStatus: order.status_pekerjaan,
    updated_by: role || 'admin'
  });

  return res.status(200).json({
    success: true,
    message: 'Status pekerjaan berhasil diperbarui',
    data: {
      id: updated.id,
      status_pekerjaan: updated.status_pekerjaan,
      started_at: updated.started_at || null
    }
  });
});

// POST /api/orders/:id/assign — Penugasan petugas hibrida dengan anti-double booking
router.post('/:id/assign', async (req, res) => {
  const { id } = req.params;
  const { cleaner_id, role } = req.body;
  const order = await db.getOrderById(id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  // Prasyarat Status: Wajib Dikonfirmasi
  if (order.status_pekerjaan !== 'Dikonfirmasi') {
    return res.status(400).json({
      success: false,
      message: 'Penugasan petugas hanya dapat dilakukan pada pesanan berstatus Dikonfirmasi',
      error: 'ORDER_MUST_BE_CONFIRMED_BEFORE_ASSIGNMENT'
    });
  }

  if (!cleaner_id) {
    return res.status(400).json({
      success: false,
      message: 'cleaner_id wajib disertakan',
      error: 'MISSING_CLEANER_ID'
    });
  }

  const cleaner = await db.getCleanerById(cleaner_id);
  if (!cleaner || cleaner.status_operasional !== 'Aktif') {
    return res.status(400).json({
      success: false,
      message: 'Petugas kebersihan tidak ditemukan atau sedang tidak berstatus Aktif',
      error: 'CLEANER_NOT_AVAILABLE'
    });
  }

  // Pemeriksaan Bentrok Jadwal (+ Buffer 30 Menit)
  const allOrders = await db.getOrders();
  const existingCleanerOrders = allOrders.filter(o =>
    o.cleaner_id === cleaner_id &&
    o.tanggal_layanan === order.tanggal_layanan &&
    o.id !== order.id &&
    o.status_pekerjaan !== 'Dibatalkan' &&
    o.status_pekerjaan !== 'Selesai'
  );

  const hasConflict = existingCleanerOrders.some(existing =>
    isScheduleConflict(order.start_time, order.end_time, existing.start_time, existing.end_time, 30)
  );

  if (hasConflict) {
    return res.status(409).json({
      success: false,
      message: 'Jadwal petugas bentrok dengan pesanan lain pada interval waktu yang sama (memperhitungkan buffer 30 menit)',
      error: 'SCHEDULE_CONFLICT_DETECTED'
    });
  }

  const updated = await db.assignCleaner(id, cleaner_id, {
    assigned_by: role || 'admin',
    catatan: `Petugas ${cleaner.nama} (${cleaner.id}) berhasil ditugaskan`
  });

  return res.status(200).json({
    success: true,
    message: 'Petugas berhasil ditugaskan ke pesanan',
    data: {
      id: updated.id,
      cleaner_id: updated.cleaner_id,
      status_pekerjaan: updated.status_pekerjaan
    }
  });
});

// POST /api/orders/:id/reassign — Penggantian petugas ber-audit
router.post('/:id/reassign', async (req, res) => {
  const { id } = req.params;
  const { new_cleaner_id, alasan, role } = req.body;
  const order = await db.getOrderById(id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  if (order.status_pekerjaan !== 'Petugas Ditugaskan') {
    return res.status(400).json({
      success: false,
      message: 'Penggantian petugas hanya diizinkan saat status pesanan masih Petugas Ditugaskan',
      error: 'CANNOT_REASSIGN_AFTER_DISPATCH'
    });
  }

  if (!alasan || alasan.trim().length < 5) {
    return res.status(400).json({
      success: false,
      message: 'Alasan penggantian petugas wajib diisi minimal 5 karakter',
      error: 'INVALID_REASSIGN_REASON'
    });
  }

  const newCleaner = await db.getCleanerById(new_cleaner_id);
  if (!newCleaner || newCleaner.status_operasional !== 'Aktif') {
    return res.status(400).json({
      success: false,
      message: 'Petugas pengganti tidak ditemukan atau sedang tidak berstatus Aktif',
      error: 'CLEANER_NOT_AVAILABLE'
    });
  }

  // Cek bentrok jadwal petugas baru
  const allOrders = await db.getOrders();
  const existingOrders = allOrders.filter(o =>
    o.cleaner_id === new_cleaner_id &&
    o.tanggal_layanan === order.tanggal_layanan &&
    o.id !== order.id &&
    o.status_pekerjaan !== 'Dibatalkan' &&
    o.status_pekerjaan !== 'Selesai'
  );

  const hasConflict = existingOrders.some(existing =>
    isScheduleConflict(order.start_time, order.end_time, existing.start_time, existing.end_time, 30)
  );

  if (hasConflict) {
    return res.status(409).json({
      success: false,
      message: 'Petugas pengganti memiliki jadwal bentrok pada tanggal dan waktu tersebut',
      error: 'SCHEDULE_CONFLICT_DETECTED'
    });
  }

  const oldCleanerId = order.cleaner_id;
  const updated = await db.assignCleaner(id, new_cleaner_id, {
    isReassign: true,
    oldCleanerId,
    alasan: alasan.trim(),
    assigned_by: role || 'admin'
  });

  return res.status(200).json({
    success: true,
    message: 'Petugas berhasil dialihkan',
    data: {
      id: updated.id,
      cleaner_id: updated.cleaner_id,
      status_pekerjaan: updated.status_pekerjaan
    }
  });
});

// POST /api/orders/:id/cancel — Pembatalan pesanan terstruktur berbasis peran
router.post('/:id/cancel', async (req, res) => {
  const { id } = req.params;
  const { cancellation_reason, role } = req.body;
  const order = await db.getOrderById(id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  if (order.status_pekerjaan === 'Dibatalkan' || order.status_pekerjaan === 'Selesai') {
    return res.status(400).json({
      success: false,
      message: `Pesanan sudah berada pada status akhir '${order.status_pekerjaan}' dan tidak dapat dibatalkan`,
      error: 'ORDER_ALREADY_TERMINATED'
    });
  }

  if (!cancellation_reason || cancellation_reason.trim().length < 5) {
    return res.status(400).json({
      success: false,
      message: 'Alasan pembatalan wajib diisi minimal 5 karakter',
      error: 'INVALID_CANCELLATION_REASON'
    });
  }

  const actorRole = role || 'customer';

  // Validasi hak pembatalan pelanggan
  if (actorRole === 'customer') {
    const customerAllowedStatuses = ['Menunggu Konfirmasi', 'Dikonfirmasi', 'Petugas Ditugaskan'];
    if (!customerAllowedStatuses.includes(order.status_pekerjaan)) {
      return res.status(403).json({
        success: false,
        message: 'Pelanggan tidak dapat membatalkan pesanan setelah petugas memasuki tahap penugasan lapangan (Menuju Lokasi ke atas)',
        error: 'CUSTOMER_CANNOT_CANCEL_DISPATCHED_ORDER'
      });
    }
  }

  const updated = await db.cancelOrder(id, {
    cancellation_reason: cancellation_reason.trim(),
    cancelled_by: actorRole,
    prevStatus: order.status_pekerjaan
  });

  return res.status(200).json({
    success: true,
    message: 'Pesanan berhasil dibatalkan',
    data: {
      id: updated.id,
      status_pekerjaan: updated.status_pekerjaan,
      cancelled_by: updated.cancelled_by,
      cancelled_at: updated.cancelled_at
    }
  });
});

export default router;
