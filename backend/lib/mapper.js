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

export const SERVICE_CATEGORY_MAP = {
  rumah: '14afb604-f297-4526-ba3b-47c1d6fb762a',
  kos: '2abfccbb-1643-4519-b4d0-c72996e8bb9f',
  kantor: '90996ad8-b91e-47d1-a1d9-63dd7519cfd7',
  pasca_renovasi: '392ec1bf-6771-48c8-8604-974386a5615d'
};

export function sanitizeServiceId(serviceId) {
  if (!serviceId) return null;
  if (SERVICE_CATEGORY_MAP[serviceId]) return SERVICE_CATEGORY_MAP[serviceId];
  if (UUID_REGEX.test(serviceId)) return serviceId;
  return null;
}

export function orderToDb(apiPayload) {
  const row = {
    order_code: apiPayload.order_code,
    customer_id: sanitizeCustomerId(apiPayload.customer_id),
    service_id: sanitizeServiceId(apiPayload.service_id),
    cleaner_id: sanitizeCleanerId(apiPayload.cleaner_id),
    preferensi_petugas_id: sanitizeCleanerId(apiPayload.preferensi_petugas_id),
    alamat_lengkap: apiPayload.alamat_lengkap || apiPayload.alamat || '',
    patokan_lokasi: apiPayload.patokan_lokasi || null,
    luas_area: apiPayload.luas_area || null,
    catatan_khusus: apiPayload.catatan_khusus || apiPayload.catatan || null,
    tanggal_layanan: apiPayload.tanggal_layanan,
    jam_mulai: apiPayload.start_time || apiPayload.jam_mulai,
    total_biaya: Number(apiPayload.total_biaya),
    metode_pembayaran: apiPayload.metode_pembayaran || 'simulasi_dummy',
    status_pembayaran: toDbPaymentStatus(apiPayload.status_pembayaran),
    status_pekerjaan: toDbJobStatus(apiPayload.status_pekerjaan)
  };
  if (apiPayload.id && UUID_REGEX.test(apiPayload.id)) {
    row.id = apiPayload.id;
  }
  return row;
}

