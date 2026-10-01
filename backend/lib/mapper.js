// backend/lib/mapper.js
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const PAYMENT_STATUS_MAP = {
  'Belum Bayar': 'belum_bayar',
  'Sudah Bayar': 'sudah_bayar'
};

const JOB_STATUS_MAP = {
  'Menunggu Konfirmasi': 'menunggu_konfirmasi',
  'Dikonfirmasi': 'dikonfirmasi',
  'Petugas Ditugaskan': 'petugas_ditugaskan',
  'Menuju Lokasi': 'menuju_lokasi',
  'Tiba di Lokasi': 'tiba_di_lokasi',
  'Sedang Dikerjakan': 'sedang_dikerjakan',
  'Selesai': 'selesai',
  'Dibatalkan': 'dibatalkan'
};

const REVERSE_PAYMENT_STATUS_MAP = Object.fromEntries(
  Object.entries(PAYMENT_STATUS_MAP).map(([k, v]) => [v, k])
);

const REVERSE_JOB_STATUS_MAP = Object.fromEntries(
  Object.entries(JOB_STATUS_MAP).map(([k, v]) => [v, k])
);

export function toDbPaymentStatus(apiStatus) {
  if (!apiStatus) return 'belum_bayar';
  return PAYMENT_STATUS_MAP[apiStatus] || apiStatus.toLowerCase().replace(/ /g, '_');
}

export function fromDbPaymentStatus(dbStatus) {
  if (!dbStatus) return 'Belum Bayar';
  return REVERSE_PAYMENT_STATUS_MAP[dbStatus] || dbStatus;
}

export function toDbJobStatus(apiStatus) {
  if (!apiStatus) return 'menunggu_konfirmasi';
  return JOB_STATUS_MAP[apiStatus] || apiStatus.toLowerCase().replace(/ /g, '_');
}

export function fromDbJobStatus(dbStatus) {
  if (!dbStatus) return 'Menunggu Konfirmasi';
  return REVERSE_JOB_STATUS_MAP[dbStatus] || dbStatus;
}

export function sanitizeCustomerId(customerId) {
  if (!customerId || typeof customerId !== 'string') return null;
  return UUID_REGEX.test(customerId.trim()) ? customerId.trim() : null;
}

export function sanitizeCleanerId(cleanerId) {
  if (!cleanerId || typeof cleanerId !== 'string') return null;
  return UUID_REGEX.test(cleanerId.trim()) ? cleanerId.trim() : null;
}

export function orderToApi(dbRow, service = null, cleaner = null) {
  if (!dbRow) return null;
  return {
    id: dbRow.id,
    order_code: dbRow.order_code,
    customer_id: dbRow.customer_id,
    service_id: dbRow.service_id,
    cleaner_id: dbRow.cleaner_id,
    preferensi_petugas_id: dbRow.preferensi_petugas_id,
    tanggal_layanan: dbRow.tanggal_layanan,
    start_time: dbRow.jam_mulai || dbRow.start_time,
    end_time: dbRow.end_time || null,
    duration: Number(dbRow.duration || 2),
    alamat_lengkap: dbRow.alamat_lengkap,
    patokan_lokasi: dbRow.patokan_lokasi,
    luas_area: dbRow.luas_area,
    catatan_khusus: dbRow.catatan_khusus,
    harga_saat_booking: Number(dbRow.harga_saat_booking || dbRow.total_biaya || 0),
    total_biaya: Number(dbRow.total_biaya || 0),
    status_pembayaran: fromDbPaymentStatus(dbRow.status_pembayaran),
    payment_timestamp: dbRow.payment_timestamp,
    status_pekerjaan: fromDbJobStatus(dbRow.status_pekerjaan),
    started_at: dbRow.started_at,
    cancellation_reason: dbRow.cancellation_reason,
    cancelled_by: dbRow.cancelled_by,
    cancelled_at: dbRow.cancelled_at,
    created_at: dbRow.created_at,
    service: service || null,
    cleaner: cleaner || null
  };
}

export function orderToDb(apiPayload) {
  return {
    id: apiPayload.id,
    order_code: apiPayload.order_code,
    customer_id: sanitizeCustomerId(apiPayload.customer_id),
    service_id: apiPayload.service_id,
    cleaner_id: sanitizeCleanerId(apiPayload.cleaner_id),
    preferensi_petugas_id: sanitizeCleanerId(apiPayload.preferensi_petugas_id),
    alamat_lengkap: apiPayload.alamat_lengkap,
    patokan_lokasi: apiPayload.patokan_lokasi,
    luas_area: apiPayload.luas_area,
    catatan_khusus: apiPayload.catatan_khusus || null,
    tanggal_layanan: apiPayload.tanggal_layanan,
    jam_mulai: apiPayload.start_time || apiPayload.jam_mulai,
    duration: Number(apiPayload.duration || 2),
    end_time: apiPayload.end_time || null,
    harga_saat_booking: Number(apiPayload.harga_saat_booking || apiPayload.total_biaya),
    total_biaya: Number(apiPayload.total_biaya),
    status_pembayaran: toDbPaymentStatus(apiPayload.status_pembayaran),
    payment_timestamp: apiPayload.payment_timestamp || null,
    status_pekerjaan: toDbJobStatus(apiPayload.status_pekerjaan),
    started_at: apiPayload.started_at || null,
    cancellation_reason: apiPayload.cancellation_reason || null,
    cancelled_by: sanitizeCustomerId(apiPayload.cancelled_by),
    cancelled_at: apiPayload.cancelled_at || null
  };
}
