import { Router } from 'express';
import crypto from 'crypto';
import { inMemoryStore, getServices } from '../lib/supabase.js';

const router = Router();

// Helper untuk format waktu dan kalkulasi end_time (start_time + duration)
function calculateEndTime(startTime, durationHours) {
  const [hours, minutes] = startTime.split(':').map(Number);
  const endHours = hours + Number(durationHours);
  const formattedHours = String(endHours).padStart(2, '0');
  const formattedMinutes = String(minutes).padStart(2, '0');
  return `${formattedHours}:${formattedMinutes}`;
}

// Helper untuk generate kode pesanan unik: RSK-YYYYMMDD-XXX
function generateOrderCode(tanggalLayanan) {
  const cleanDate = (tanggalLayanan || new Date().toISOString().split('T')[0]).replace(/-/g, '');
  const count = (inMemoryStore.orders.length + 1).toString().padStart(3, '0');
  return `RSK-${cleanDate}-${count}`;
}

// GET /api/orders — Mengambil daftar pesanan
router.get('/', async (req, res) => {
  const { data: services } = await getServices(true);
  const enrichedOrders = inMemoryStore.orders.map(order => {
    const service = (services || []).find(s => s.id === order.service_id);
    return {
      ...order,
      service: service ? {
        id: service.id,
        nama_layanan: service.nama_layanan,
        kategori: service.kategori
      } : null
    };
  });

  return res.status(200).json({
    success: true,
    message: 'Daftar pesanan berhasil diambil',
    data: enrichedOrders
  });
});

// GET /api/orders/:id — Detail lengkap pesanan
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  const order = inMemoryStore.orders.find(o => o.id === id);

  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  const { data: services } = await getServices(true);
  const service = (services || []).find(s => s.id === order.service_id);

  return res.status(200).json({
    success: true,
    message: 'Detail pesanan berhasil diambil',
    data: {
      ...order,
      service: service ? {
        id: service.id,
        nama_layanan: service.nama_layanan,
        kategori: service.kategori,
        durasi_estimasi: service.durasi_estimasi
      } : null
    }
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
      customer_id: body.customer_id || 'usr-cust-001',
      service_id: service.id,
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

    // Simpan ke inMemoryStore
    inMemoryStore.orders.push(newOrder);

    // Catat Status Log Perdana
    inMemoryStore.status_logs.push({
      id: crypto.randomUUID(),
      order_id: newOrder.id,
      status_sebelumnya: null,
      status_baru: 'Menunggu Konfirmasi',
      diubah_oleh: newOrder.customer_id,
      catatan: 'Pesanan baru dibuat, menunggu pembayaran pelanggan',
      created_at: newOrder.created_at
    });

    return res.status(201).json({
      success: true,
      message: 'Pesanan berhasil dibuat, silakan selesaikan pembayaran',
      data: {
        id: newOrder.id,
        order_code: newOrder.order_code,
        harga_saat_booking: newOrder.harga_saat_booking,
        total_biaya: newOrder.total_biaya,
        status_pembayaran: newOrder.status_pembayaran,
        status_pekerjaan: newOrder.status_pekerjaan,
        payment_timestamp: newOrder.payment_timestamp
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
router.post('/:id/pay', (req, res) => {
  const { id } = req.params;
  const order = inMemoryStore.orders.find(o => o.id === id);

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

  // Update status pembayaran dan catat timestamp server
  const now = new Date().toISOString();
  order.status_pembayaran = 'Sudah Bayar';
  order.payment_timestamp = now;

  // Catat audit ke status_logs
  inMemoryStore.status_logs.push({
    id: crypto.randomUUID(),
    order_id: order.id,
    status_sebelumnya: 'Menunggu Konfirmasi',
    status_baru: 'Menunggu Konfirmasi',
    diubah_oleh: order.customer_id,
    catatan: 'Simulasi pembayaran diverifikasi server: status pembayaran berubah menjadi Sudah Bayar',
    created_at: now
  });

  return res.status(200).json({
    success: true,
    message: 'Simulasi pembayaran berhasil diverifikasi',
    data: {
      id: order.id,
      status_pembayaran: order.status_pembayaran,
      payment_timestamp: order.payment_timestamp
    }
  });
});

export default router;
