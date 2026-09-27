/**
 * lib/matching.js — Deterministic Smart Matching Engine
 * Resik.in — Prototipe Aplikasi Jasa Kebersihan On-Demand
 *
 * Source of Truth: docs/BUSINESS-RULES.md (BR-MTG-001 s.d BR-MTG-005)
 * Formula: Total Score = (0.40 * S_skill) + (0.30 * S_avail) + (0.20 * S_rating) + (0.10 * S_exp)
 */

/**
 * Konversi string waktu "HH:mm" menjadi menit sejak tengah malam (00:00).
 * @param {string} timeStr - Contoh: "09:00", "11:30"
 * @returns {number} Menit sejak 00:00
 */
export function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + (minutes || 0);
}

/**
 * Validasi apakah jadwal petugas bentrok dengan pesanan lain pada tanggal yang sama,
 * memperhitungkan buffer operasional 30 menit sebelum dan sesudah pekerjaan (BR-SCH-007, BR-MTG-001).
 *
 * @param {string} cleanerId
 * @param {string} date - "YYYY-MM-DD"
 * @param {string} startTime - "HH:mm"
 * @param {number} duration - Durasi dalam jam
 * @param {Array} existingOrders - Daftar pesanan aktif
 * @param {number} [bufferMinutes=30] - Buffer operasional dalam menit
 * @returns {boolean} true jika terdapat bentrok, false jika aman
 */
export function hasScheduleConflict(cleanerId, date, startTime, duration, existingOrders = [], bufferMinutes = 30) {
  const targetStart = timeToMinutes(startTime);
  const targetDurationMinutes = Math.round(Number(duration) * 60);
  const targetEnd = targetStart + targetDurationMinutes;

  // Rentang target yang dilindungi buffer (BR-SCH-007)
  const targetBufferedStart = targetStart - bufferMinutes;
  const targetBufferedEnd = targetEnd + bufferMinutes;

  for (const order of existingOrders) {
    // Lewati pesanan milik petugas lain, tanggal berbeda, atau pesanan yang dibatalkan
    if (order.cleaner_id !== cleanerId) continue;
    if (order.tanggal_layanan !== date) continue;
    if (order.status_pekerjaan === 'Dibatalkan') continue;

    const existStart = timeToMinutes(order.start_time);
    const existDurationMinutes = order.duration ? Math.round(Number(order.duration) * 60) : 120;
    const existEnd = order.end_time ? timeToMinutes(order.end_time) : (existStart + existDurationMinutes);

    // Overlap condition: max(StartA, StartB) < min(EndA, EndB)
    const isOverlap = Math.max(targetBufferedStart, existStart) < Math.min(targetBufferedEnd, existEnd);
    if (isOverlap) {
      return true;
    }
  }

  return false;
}

/**
 * Hitung skor kesesuaian keahlian petugas (Bobot 40% - BR-MTG-002).
 * @param {Array<string>} cleanerSkills
 * @param {string} serviceKategori - 'rumah', 'kos', 'kantor', 'pasca_renovasi'
 * @returns {number} Nilai 0 - 100
 */
export function calculateSkillScore(cleanerSkills = [], serviceKategori = '') {
  const skills = cleanerSkills.map(s => String(s).toLowerCase());
  const kategori = String(serviceKategori).toLowerCase();

  // Primary Exact Match
  if (kategori === 'rumah' && (skills.includes('pembersihan_rumah') || skills.includes('rumah'))) return 100;
  if (kategori === 'kos' && (skills.includes('pembersihan_kos') || skills.includes('kos'))) return 100;
  if (kategori === 'kantor' && (skills.includes('pembersihan_kantor') || skills.includes('kantor'))) return 100;
  if (kategori === 'pasca_renovasi' && (skills.includes('pasca_renovasi') || skills.includes('renovasi'))) return 100;

  // Secondary Acceptable Match (kantor / kos dapat ditangani petugas dengan keahlian rumah)
  if ((kategori === 'kantor' || kategori === 'kos') && (skills.includes('pembersihan_rumah') || skills.includes('rumah'))) {
    return 70;
  }

  return 0;
}

/**
 * Hitung skor ketersediaan petugas berdasarkan beban kerja harian (Bobot 30% - BR-MTG-002).
 * 0 pekerjaan hari itu = 100, 1 pekerjaan = 80, >= 2 pekerjaan = 60.
 *
 * @param {string} cleanerId
 * @param {string} date
 * @param {string} startTime
 * @param {number} duration
 * @param {Array} existingOrders
 * @returns {number} Nilai 0 - 100
 */
export function calculateAvailabilityScore(cleanerId, date, startTime, duration, existingOrders = []) {
  const activeOrdersToday = existingOrders.filter(
    o => o.cleaner_id === cleanerId &&
         o.tanggal_layanan === date &&
         o.status_pekerjaan !== 'Dibatalkan'
  );

  const count = activeOrdersToday.length;
  if (count === 0) return 100;
  if (count === 1) return 80;
  return 60;
}

/**
 * Hitung skor rating petugas (Bobot 20% - BR-MTG-002, BR-MTG-003).
 * Untuk petugas baru tanpa riwayat ulasan, diterapkan Provisional Rating 4.5.
 *
 * @param {number} rating
 * @param {number} totalUlasan
 * @returns {{ ratingScore: number, effectiveRating: number, isProvisional: boolean }}
 */
export function calculateRatingScore(rating, totalUlasan) {
  const numRating = Number(rating) || 0;
  const numUlasan = Number(totalUlasan) || 0;

  if (numRating === 0 || numUlasan === 0) {
    const effectiveRating = 4.5;
    return {
      ratingScore: Number(((effectiveRating / 5.0) * 100).toFixed(1)),
      effectiveRating,
      isProvisional: true
    };
  }

  return {
    ratingScore: Number(((numRating / 5.0) * 100).toFixed(1)),
    effectiveRating: numRating,
    isProvisional: false
  };
}

/**
 * Hitung skor pengalaman kerja petugas (Bobot 10% - BR-MTG-002).
 * Formula: min(100, (pengalaman_tahun / 5) * 100).
 *
 * @param {number} years
 * @returns {number} Nilai 0 - 100
 */
export function calculateExperienceScore(years) {
  const numYears = Number(years) || 0;
  return Math.min(100, Math.round((numYears / 5) * 100));
}

/**
 * Hitung skor total deterministik smart matching (BR-MTG-002).
 *
 * @param {Object} cleaner
 * @param {Object} service
 * @param {string} date
 * @param {string} startTime
 * @param {number} duration
 * @param {Array} existingOrders
 * @returns {Object} Rincian skor dan badge rekomendasi
 */
export function calculateMatchingScore(cleaner, service, date, startTime, duration, existingOrders = []) {
  const skillScore = calculateSkillScore(cleaner.keahlian, service.kategori);
  const availScore = calculateAvailabilityScore(cleaner.id, date, startTime, duration, existingOrders);
  const ratingData = calculateRatingScore(cleaner.rating_rata_rata, cleaner.total_ulasan);
  const expScore = calculateExperienceScore(cleaner.pengalaman_tahun);

  // Bobot: 40% skill + 30% avail + 20% rating + 10% exp
  const totalScore = Number(
    ((0.40 * skillScore) +
     (0.30 * availScore) +
     (0.20 * ratingData.ratingScore) +
     (0.10 * expScore)).toFixed(1)
  );

  let matchBadge = 'Tersedia';
  if (totalScore >= 85) {
    matchBadge = 'Sangat Direkomendasikan';
  } else if (totalScore >= 70) {
    matchBadge = 'Direkomendasikan';
  }

  return {
    skillScore,
    availScore,
    ratingScore: ratingData.ratingScore,
    effectiveRating: ratingData.effectiveRating,
    isProvisionalRating: ratingData.isProvisional,
    expScore,
    totalScore,
    matchBadge
  };
}

/**
 * Hasilkan rekomendasi kandidat petugas terurut deterministik (BR-MTG-001 s.d BR-MTG-005).
 *
 * @param {Object} params
 * @param {Array} params.cleaners
 * @param {Object} params.service
 * @param {string} params.date
 * @param {string} params.startTime
 * @param {number} params.duration
 * @param {Array} [params.existingOrders=[]]
 * @returns {Array<{ cleaner: Object, score: Object }>}
 */
export function getRecommendations({ cleaners = [], service, date, startTime, duration, existingOrders = [] }) {
  const qualifiedCandidates = [];

  for (const cleaner of cleaners) {
    // 1. Hard Filter: Status operasional wajib 'Aktif' (BR-MTG-001)
    if (cleaner.status_operasional !== 'Aktif') {
      continue;
    }

    // 2. Hard Filter: Layanan Pasca Renovasi wajib memiliki keahlian 'pasca_renovasi'
    const serviceKategori = String(service?.kategori || '').toLowerCase();
    if (serviceKategori === 'pasca_renovasi') {
      const skills = (cleaner.keahlian || []).map(s => String(s).toLowerCase());
      const hasRenovasiSkill = skills.includes('pasca_renovasi') || skills.includes('renovasi');
      if (!hasRenovasiSkill) {
        continue;
      }
    }

    // 3. Hard Filter: Tidak boleh ada bentrok jadwal termasuk buffer 30 menit (BR-SCH-007, BR-MTG-001)
    if (hasScheduleConflict(cleaner.id, date, startTime, duration, existingOrders, 30)) {
      continue;
    }

    // Hitung skor evaluasi
    const score = calculateMatchingScore(cleaner, service, date, startTime, duration, existingOrders);
    qualifiedCandidates.push({ cleaner, score });
  }

  // Deterministic Tie-Breaking (BR-MTG-004):
  // 1. Total Score DESC
  // 2. Rating Rata-rata (effective rating) DESC
  // 3. Total Pekerjaan Selesai DESC
  // 4. ID Petugas ASC (lexicographical)
  qualifiedCandidates.sort((a, b) => {
    if (b.score.totalScore !== a.score.totalScore) {
      return b.score.totalScore - a.score.totalScore;
    }
    if (b.score.effectiveRating !== a.score.effectiveRating) {
      return b.score.effectiveRating - a.score.effectiveRating;
    }
    const aTotalPekerjaan = a.cleaner.total_pekerjaan || 0;
    const bTotalPekerjaan = b.cleaner.total_pekerjaan || 0;
    if (bTotalPekerjaan !== aTotalPekerjaan) {
      return bTotalPekerjaan - aTotalPekerjaan;
    }
    return String(a.cleaner.id).localeCompare(String(b.cleaner.id));
  });

  return qualifiedCandidates;
}
