import { Router } from 'express';
import crypto from 'node:crypto';
import { inMemoryStore, supabase } from '../lib/supabase.js';
import { CHECKLIST_TEMPLATES } from '../lib/checklist-templates.js';

const router = Router();

// POST /api/quality-reports — Pembuatan & Finalisasi Laporan Mutu (Mandatory Gate to Selesai)
router.post('/', (req, res) => {
  const {
    order_id,
    checklist_area,
    foto_before_path,
    foto_after_path,
    catatan_petugas,
    completed_at,
    role,
    cleaner_id
  } = req.body;

  if (!order_id) {
    return res.status(400).json({
      success: false,
      message: 'order_id wajib disertakan',
      error: 'MISSING_ORDER_ID'
    });
  }

  // 1. Temukan Order
  const order = inMemoryStore.orders.find(o => o.id === order_id);
  if (!order) {
    return res.status(404).json({
      success: false,
      message: `Pesanan dengan ID ${order_id} tidak ditemukan`,
      error: 'ORDER_NOT_FOUND'
    });
  }

  // 2. Verifikasi Hak Akses Petugas
  if (role !== 'admin' && cleaner_id && order.cleaner_id && order.cleaner_id !== cleaner_id) {
    return res.status(403).json({
      success: false,
      message: 'Hanya petugas yang ditugaskan yang berhak menyerahkan Quality Report',
      error: 'UNAUTHORIZED_CLEANER'
    });
  }

  // 3. Verifikasi Status Saat Ini (Wajib Sedang Dikerjakan)
  if (order.status_pekerjaan !== 'Sedang Dikerjakan') {
    return res.status(400).json({
      success: false,
      message: `Pengiriman Quality Report hanya dapat dilakukan saat pesanan 'Sedang Dikerjakan', status saat ini: '${order.status_pekerjaan}'`,
      error: 'ORDER_NOT_IN_PROGRESS'
    });
  }

  // 4. Verifikasi Template Checklist Penuh
  const service = inMemoryStore.services.find(s => s.id === order.service_id);
  const kategori = service ? service.kategori : 'rumah';
  const expectedAreas = CHECKLIST_TEMPLATES[kategori] || CHECKLIST_TEMPLATES.rumah;

  if (!Array.isArray(checklist_area)) {
    return res.status(400).json({
      success: false,
      message: 'checklist_area harus berupa array',
      error: 'INVALID_CHECKLIST_FORMAT'
    });
  }

  // Setiap expected area wajib ada dan bernilai completed: true
  const isComplete = expectedAreas.every(expectedArea => {
    const matched = checklist_area.find(item => item.area === expectedArea);
    return matched && matched.completed === true;
  });

  if (!isComplete) {
    return res.status(400).json({
      success: false,
      message: `Seluruh area checklist untuk layanan kategori '${kategori}' wajib diselesaikan (completed: true)`,
      error: 'CHECKLIST_AREAS_INCOMPLETE'
    });
  }

  // 5. Verifikasi Invarian Timestamp Server
  const startedAt = order.started_at || order.created_at;
  const startedMs = new Date(startedAt).getTime();
  const completedMs = new Date(completed_at).getTime();
  const nowMs = Date.now();

  if (isNaN(completedMs) || completedMs < startedMs || completedMs > nowMs + 5000) {
    return res.status(400).json({
      success: false,
      message: 'Invarian timestamp tidak valid: completed_at tidak boleh mendahului started_at atau berada di masa depan',
      error: 'INVALID_TIMESTAMPS'
    });
  }

  // 6. Verifikasi Prefix Path Berkas Storage
  const expectedPrefix = `orders/${order.id}/`;
  if (
    typeof foto_before_path !== 'string' ||
    typeof foto_after_path !== 'string' ||
    !foto_before_path.startsWith(expectedPrefix) ||
    !foto_after_path.startsWith(expectedPrefix)
  ) {
    return res.status(400).json({
      success: false,
      message: `Path foto wajib berupa string dengan prefix '${expectedPrefix}'`,
      error: 'INVALID_STORAGE_PATH'
    });
  }

  // 7. Simpan Laporan Mutu ke inMemoryStore
  const submittedAt = new Date().toISOString();
  const newReport = {
    id: crypto.randomUUID(),
    order_id: order.id,
    cleaner_id: order.cleaner_id,
    checklist_area,
    foto_before_url: foto_before_path,
    foto_after_url: foto_after_path,
    catatan_petugas: catatan_petugas ? catatan_petugas.trim() : null,
    started_at: startedAt,
    completed_at: new Date(completed_at).toISOString(),
    submitted_at: submittedAt
  };
  inMemoryStore.quality_reports.push(newReport);

  // 8. Mutasi Status Pesanan Menjadi 'Selesai'
  order.status_pekerjaan = 'Selesai';
  inMemoryStore.status_logs.push({
    id: crypto.randomUUID(),
    order_id: order.id,
    status_sebelumnya: 'Sedang Dikerjakan',
    status_baru: 'Selesai',
    diubah_oleh: order.cleaner_id || 'cleaner',
    catatan: 'Laporan mutu pekerjaan berhasil diverifikasi dan diserahkan',
    created_at: submittedAt
  });

  // 9. Pemulihan Metrik Petugas Kebersihan
  if (order.cleaner_id) {
    const cleaner = inMemoryStore.cleaners.find(c => c.id === order.cleaner_id);
    if (cleaner) {
      cleaner.status_operasional = 'Aktif';
      cleaner.total_pekerjaan = (cleaner.total_pekerjaan || 0) + 1;
    }
  }

  return res.status(201).json({
    success: true,
    message: 'Quality Report berhasil disimpan dan pesanan dinyatakan Selesai',
    data: {
      report_id: newReport.id,
      order_id: order.id,
      status_pekerjaan: 'Selesai',
      submitted_at: submittedAt
    }
  });
});

// GET /api/quality-reports/:order_id — Inspeksi laporan mutu (Sprint 4)
router.get('/:order_id', (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'Endpoint Quality Report siap diimplementasikan pada Sprint 4',
    data: null
  });
});

export default router;
