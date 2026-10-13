import crypto from 'crypto';

/**
 * Format objek Date UTC menjadi string YYYY-MM-DD
 * @param {Date} d
 * @returns {string}
 */
export function formatUtcDate(d) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * Konversi string waktu (HH:mm atau format ISO) menjadi menit dari 00:00
 * @param {string} timeStr
 * @returns {number}
 */
export function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  if (timeStr.includes('T')) {
    const match = timeStr.match(/T(\d{2}):(\d{2})/);
    if (match) {
      return parseInt(match[1], 10) * 60 + parseInt(match[2], 10);
    }
  }
  const parts = String(timeStr).split(':');
  const hours = parseInt(parts[0], 10) || 0;
  const minutes = parseInt(parts[1], 10) || 0;
  return hours * 60 + minutes;
}

/**
 * Ekstrak tanggal YYYY-MM-DD dari objek order
 * @param {object} order
 * @returns {string}
 */
export function getOrderDate(order) {
  if (!order) return '';
  if (order.tanggal_layanan) return String(order.tanggal_layanan).substring(0, 10);
  if (order.start_time) {
    if (order.start_time.includes('T')) {
      return order.start_time.split('T')[0];
    }
    return String(order.start_time).substring(0, 10);
  }
  return '';
}

/**
 * Menghitung target tanggal sesi berikutnya secara deterministik (BR-SCH-001, BR-SCH-002)
 *
 * @param {object} params
 * @param {number} params.dayOfWeek - 1 (Senin) s.d. 7 (Minggu)
 * @param {string} [params.frequency='mingguan'] - 'mingguan' atau 'dua_mingguan'
 * @param {Date|string} [params.fromDate=new Date()] - Titik awal kalkulasi
 * @param {string} [params.startTime] - Format 'HH:mm'
 * @param {string} [params.currentTimeStr] - Format 'HH:mm'
 * @param {boolean} [params.skipFirstInterval=false] - Jika true, langsung lompat interval
 * @returns {string} Target tanggal dalam format 'YYYY-MM-DD'
 */
export function calculateNextSessionDate({
  dayOfWeek,
  frequency = 'mingguan',
  fromDate = new Date(),
  startTime,
  currentTimeStr,
  skipFirstInterval = false
}) {
  const base = fromDate instanceof Date ? fromDate : new Date(fromDate);
  const year = base.getUTCFullYear();
  const month = base.getUTCMonth();
  const date = base.getUTCDate();
  const targetDay = Number(dayOfWeek);

  if (skipFirstInterval) {
    const daysToAdd = frequency === 'dua_mingguan' ? 14 : 7;
    const next = new Date(Date.UTC(year, month, date + daysToAdd));
    return formatUtcDate(next);
  }

  // JS getUTCDay: 0=Sun, 1=Mon, ..., 6=Sat -> konversi 1=Mon, ..., 7=Sun
  const jsDay = base.getUTCDay();
  const currentDay = jsDay === 0 ? 7 : jsDay;

  let daysToAdd = (targetDay - currentDay + 7) % 7;

  if (daysToAdd === 0) {
    if (currentTimeStr && startTime && currentTimeStr >= startTime) {
      daysToAdd = frequency === 'dua_mingguan' ? 14 : 7;
    } else if (!currentTimeStr && !startTime) {
      daysToAdd = frequency === 'dua_mingguan' ? 14 : 7;
    }
  }

  const next = new Date(Date.UTC(year, month, date + daysToAdd));
  return formatUtcDate(next);
}

/**
 * Validasi apakah jadwal petugas bentrok dengan pesanan lain pada tanggal tertentu,
 * memperhitungkan buffer operasional 30 menit (BR-SCH-007, BR-MTG-001)
 *
 * @param {object} params
 * @param {string} params.cleanerId
 * @param {string} params.date - 'YYYY-MM-DD'
 * @param {string} params.startTime - 'HH:mm'
 * @param {number} params.duration - Durasi dalam jam
 * @param {Array} params.existingOrders - Daftar pesanan aktif
 * @param {number} [params.bufferMinutes=30]
 * @returns {boolean} true jika terdapat bentrok jadwal
 */
export function checkScheduleConflict({
  cleanerId,
  date,
  startTime,
  duration,
  existingOrders = [],
  bufferMinutes = 30
}) {
  if (!cleanerId || !date || !startTime) return false;

  const targetStart = timeToMinutes(startTime);
  const targetDurationMinutes = Math.round(Number(duration || 2) * 60);
  const targetEnd = targetStart + targetDurationMinutes;

  const targetBufferedStart = targetStart - bufferMinutes;
  const targetBufferedEnd = targetEnd + bufferMinutes;

  for (const order of existingOrders) {
    if (order.cleaner_id !== cleanerId && order.cleanerId !== cleanerId) continue;

    const orderStatus = (order.status || order.status_pekerjaan || '').toLowerCase();
    if (orderStatus === 'dibatalkan' || orderStatus === 'cancelled') continue;

    const orderDate = getOrderDate(order);
    if (orderDate !== date) continue;

    const existStart = timeToMinutes(order.start_time);
    const existDurationMinutes = order.duration ? Math.round(Number(order.duration) * 60) : 120;
    const existEnd = order.end_time ? timeToMinutes(order.end_time) : (existStart + existDurationMinutes);

    const isOverlap = Math.max(targetBufferedStart, existStart) < Math.min(targetBufferedEnd, existEnd);
    if (isOverlap) {
      return true;
    }
  }

  return false;
}

/**
 * Generator pesanan sesi berkala deterministik & idempotent (FR-12)
 *
 * @param {object} params
 * @param {object} params.plan - Entitas cleaning plan
 * @param {Array} [params.existingOrders=[]] - Daftar pesanan eksisting untuk pengecekan idempotensi & bentrok
 * @returns {object} Objek pesanan baru yang siap disimpan
 */
export function generateNextSessionOrder({ plan, existingOrders = [] }) {
  if (!plan) throw new Error('Data cleaning plan tidak boleh kosong');

  const targetDate = plan.nextSessionDate || plan.next_session_date;
  if (!targetDate) throw new Error('Target tanggal sesi tidak valid');

  // 1. Idempotency Guard: Mencegah pembuatan pesanan ganda pada tanggal yang sama
  const duplicate = existingOrders.find(o => {
    const isSamePlan = (o.cleaning_plan_id === plan.id || o.cleaningPlanId === plan.id);
    if (!isSamePlan) return false;
    const oDate = getOrderDate(o);
    const oStatus = (o.status || o.status_pekerjaan || '').toLowerCase();
    return oDate === targetDate && oStatus !== 'dibatalkan' && oStatus !== 'cancelled';
  });

  if (duplicate) {
    throw new Error(`Pesanan untuk tanggal sesi ${targetDate} sudah dibuat (idempotency guard)`);
  }

  const preferredCleanerId = plan.preferredCleanerId || plan.preferred_cleaner_id || null;
  const startTimeStr = plan.startTime || plan.start_time || '09:00';
  const duration = Number(plan.duration || 2);
  const existingPlanOrders = existingOrders.filter(o => o.cleaning_plan_id === plan.id || o.cleaningPlanId === plan.id);
  const totalCompleted = Number(plan.totalSessionsCompleted !== undefined ? plan.totalSessionsCompleted : (plan.total_sessions_completed || 0));
  const nextSessionNumber = Math.max(existingPlanOrders.length + 1, totalCompleted + 1);

  // 2. Conflict Fallback: Periksa apakah petugas favorit bentrok jadwal
  let cleanerIdToAssign = preferredCleanerId;
  let notes = plan.notes || '';

  if (preferredCleanerId) {
    const isConflict = checkScheduleConflict({
      cleanerId: preferredCleanerId,
      date: targetDate,
      startTime: startTimeStr,
      duration,
      existingOrders
    });

    if (isConflict) {
      cleanerIdToAssign = null;
      const conflictNotice = `[Jadwal Bentrok] Petugas langganan berhalangan, dialihkan ke Smart Matching`;
      notes = notes ? `${notes} ${conflictNotice}` : conflictNotice;
    }
  }

  const orderId = `ord-cp-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
  const startIso = `${targetDate}T${startTimeStr}:00.000Z`;

  const startMin = timeToMinutes(startTimeStr);
  const endMin = startMin + Math.round(duration * 60);
  const endHours = String(Math.floor(endMin / 60)).padStart(2, '0');
  const endMinutes = String(endMin % 60).padStart(2, '0');
  const endIso = `${targetDate}T${endHours}:${endMinutes}:00.000Z`;

  const price = Number(plan.pricePerSession !== undefined ? plan.pricePerSession : (plan.price_per_session || 0));

  const newOrder = {
    id: orderId,
    customer_id: plan.customerId || plan.customer_id,
    cleaner_id: cleanerIdToAssign,
    cleaning_plan_id: plan.id,
    session_number: nextSessionNumber,
    service_id: plan.serviceId || plan.service_id || null,
    service_kategori: plan.serviceCategory || plan.service_category,
    tanggal_layanan: targetDate,
    start_time: startIso,
    end_time: endIso,
    duration,
    harga_saat_booking: price,
    total_biaya: price,
    alamat_lengkap: plan.address,
    patokan_lokasi: plan.landmark || null,
    catatan_khusus: notes || null,
    notes: notes || '',
    status: 'Menunggu Konfirmasi',
    status_pekerjaan: 'Menunggu Konfirmasi',
    status_pembayaran: 'Belum Bayar',
    created_at: new Date().toISOString()
  };

  return newOrder;
}
