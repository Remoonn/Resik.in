/**
 * Modul Integrasi AI & Smart Fallback Engine untuk Resik AI
 * Mendukung Google Gemini 1.5 Flash via REST API (tanpa dependensi npm)
 * dengan Fallback Deterministic Intent Matcher untuk ketahanan demo sidang skripsi.
 */

export async function consultAi({ message, history = [], activeServices = [], forceFallback = false }) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!forceFallback && apiKey && apiKey.trim() !== '') {
    try {
      const geminiResult = await callGeminiApi({ message, history, activeServices, apiKey });
      if (geminiResult) return geminiResult;
    } catch (err) {
      console.warn('[Resik AI] Gemini API call failed, switching to Smart Fallback:', err.message);
    }
  }

  // Smart Rule-Based Fallback Engine
  return runSmartFallback({ message, activeServices });
}

async function callGeminiApi({ message, history, activeServices, apiKey }) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 8000); // 8 detik timeout

  const systemInstruction = `Anda adalah Resik AI, asisten virtual cerdas, ramah, dan profesional dari aplikasi jasa kebersihan on-demand "Resik.in".
Tugas utama Anda:
1. Membantu pelanggan berkonsultasi mengenai kebutuhan kebersihan hunian, kos, kantor, atau pasca-renovasi.
2. Memberikan rekomendasi jenis layanan dan durasi pengerjaan yang paling sesuai berdasarkan kondisi yang diceritakan.
3. Menjawab pertanyaan umum (Customer Care) seputar jam operasional, garansi mutu, dan kebijakan pembersihan.

Katalog Layanan Resmi Resik.in:
${JSON.stringify(activeServices, null, 2)}

Aturan Operasional Bisnis:
- Jam operasional: 08:00 - 17:00 WIB setiap hari.
- Buffer operasional: Ada jeda wajib 30 menit antarpekerjaan untuk perjalanan dan sterilisasi peralatan petugas.
- Garansi Mutu: Setiap pekerjaan dijamin dengan checklist mutu digital dan foto komparasi Sebelum (Before) & Sesudah (After) pengerjaan.
- Peralatan: Petugas kebersihan membawa peralatan pembersih dan bahan kimia pembersih standar.
- Penugasan: Dilakukan menggunakan algoritma rekomendasi deterministik (Smart Matching) berbasis keahlian dan ulasan.

Pedoman Menjawab:
- Gunakan bahasa Indonesia yang ramah, sopan, ringkas, dan solutif.
- Format balasan WAJIB berupa JSON dengan struktur persis:
{
  "reply": "teks balasan Anda",
  "recommended_service_id": "ID_layanan_terkait atau null",
  "suggested_duration": integer_durasi_jam_atau_null,
  "rationale": "alasan_singkat_atau_null",
  "suggested_replies": ["pertanyaan_1", "pertanyaan_2", "pertanyaan_3"]
}
- BATASAN MUTLAK: Anda HANYA melayani percakapan seputar jasa kebersihan dan ekosistem Resik.in. Tolak dengan sopan jika ditanya di luar topik ini.`;

  const contents = [];
  // History
  for (const h of history.slice(-6)) {
    contents.push({
      role: h.role === 'model' ? 'model' : 'user',
      parts: [{ text: h.content }]
    });
  }
  // Current user message
  contents.push({
    role: 'user',
    parts: [{ text: message }]
  });

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

  const payload = {
    system_instruction: {
      parts: [{ text: systemInstruction }]
    },
    contents,
    generationConfig: {
      responseMimeType: 'application/json',
      temperature: 0.2,
      maxOutputTokens: 600
    }
  };

  try {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!res.ok) {
      throw new Error(`Gemini API error: HTTP ${res.status}`);
    }

    const data = await res.json();
    const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawText) throw new Error('Empty response from Gemini');

    const parsed = JSON.parse(rawText);

    // Cross-check recommended service to ensure server-authoritative integrity
    let matchedService = null;
    if (parsed.recommended_service_id) {
      const found = activeServices.find(s => s.id === parsed.recommended_service_id);
      if (found) {
        matchedService = {
          id: found.id,
          nama_layanan: found.nama_layanan,
          kategori: found.kategori,
          tarif_dasar: found.tarif_dasar,
          durasi_estimasi: found.durasi_estimasi,
          suggested_duration: parsed.suggested_duration || 2,
          rationale: parsed.rationale || `Disarankan berdasarkan konsultasi kebutuhan Anda.`
        };
      }
    }

    return {
      reply: parsed.reply || 'Halo! Ada yang bisa kami bantu seputar kebersihan hunian Anda?',
      recommendedService: matchedService,
      suggestedReplies: Array.isArray(parsed.suggested_replies) ? parsed.suggested_replies : []
    };
  } finally {
    clearTimeout(timeoutId);
  }
}

function runSmartFallback({ message, activeServices }) {
  const q = (message || '').toLowerCase();

  // Find services from catalog
  const srvRumah = activeServices.find(s => s.kategori === 'rumah');
  const srvKos = activeServices.find(s => s.kategori === 'kos');
  const srvKantor = activeServices.find(s => s.kategori === 'kantor');
  const srvRenov = activeServices.find(s => s.kategori === 'renovasi');

  // Guardrail Out-of-Domain Detection
  if (q.includes('resep') || q.includes('masak') || q.includes('politik') || q.includes('coding') || q.includes('javascript') || q.includes('flutter')) {
    return {
      reply: 'Maaf, saya adalah asisten khusus kebersihan hunian dan kantor Resik.in. Saya hanya dapat membantu seputar konsultasi layanan kebersihan, estimasi waktu, dan aturan operasional kami.',
      recommendedService: null,
      suggestedReplies: [
        'Layanan apa saja yang tersedia?',
        'Berapa jam operasional Resik.in?',
        'Apa itu Garansi Mutu?'
      ]
    };
  }

  // 1. Kos intent
  if (q.includes('kos') || q.includes('kost') || q.includes('kamar kos') || q.includes('anak kos')) {
    return {
      reply: 'Untuk kamar kos atau hunian studio, kami merekomendasikan **Pembersihan Kos**. Layanan ini mencakup pembersihan lantai, debu furnitur, dan kamar mandi kos secara menyeluruh dengan Garansi Mutu digital.',
      recommendedService: srvKos ? {
        id: srvKos.id,
        nama_layanan: srvKos.nama_layanan,
        kategori: srvKos.kategori,
        tarif_dasar: srvKos.tarif_dasar,
        durasi_estimasi: srvKos.durasi_estimasi,
        suggested_duration: 1,
        rationale: 'Sangat ideal untuk pembersihan kamar kos standar dengan waktu tuntas 1–2 jam.'
      } : null,
      suggestedReplies: [
        'Berapa tarif pembersihan kos?',
        'Apakah alat pembersih disediakan?',
        'Pesan Pembersihan Kos sekarang'
      ]
    };
  }

  // 2. Kantor intent
  if (q.includes('kantor') || q.includes('office') || q.includes('ruang kerja') || q.includes('meeting') || q.includes('gedung')) {
    return {
      reply: 'Untuk area kantor atau tempat kerja, kami sarankan memilih layanan **Pembersihan Kantor**. Tim petugas kami akan membersihkan meja kerja, lantai, pantry, dan area komunal agar lingkungan kerja tetap higienis dan nyaman.',
      recommendedService: srvKantor ? {
        id: srvKantor.id,
        nama_layanan: srvKantor.nama_layanan,
        kategori: srvKantor.kategori,
        tarif_dasar: srvKantor.tarif_dasar,
        durasi_estimasi: srvKantor.durasi_estimasi,
        suggested_duration: 3,
        rationale: 'Alokasi 3 jam dirancang untuk sanitasi menyeluruh area kerja profesional.'
      } : null,
      suggestedReplies: [
        'Apakah bisa pesan di akhir pekan?',
        'Berapa jumlah petugas kantor?',
        'Pesan Pembersihan Kantor sekarang'
      ]
    };
  }

  // 3. Renovasi intent
  if (q.includes('renov') || q.includes('debu semen') || q.includes('cat') || q.includes('bangun') || q.includes('tukang')) {
    return {
      reply: 'Untuk membersihkan sisa material, debu semen, dan percikan cat setelah pengerjaan proyek, layanan **Pembersihan Pasca Renovasi** adalah pilihan yang tepat. Kami menyarankan alokasi waktu 4 jam untuk pembersihan intensif mendalam.',
      recommendedService: srvRenov ? {
        id: srvRenov.id,
        nama_layanan: srvRenov.nama_layanan,
        kategori: srvRenov.kategori,
        tarif_dasar: srvRenov.tarif_dasar,
        durasi_estimasi: srvRenov.durasi_estimasi,
        suggested_duration: 4,
        rationale: 'Dibutuhkan alokasi waktu 4 jam untuk mengangkat sisa noda membandel pasca konstruksi.'
      } : null,
      suggestedReplies: [
        'Berapa tarif pasca renovasi?',
        'Apakah noda semen bisa hilang?',
        'Pesan Pasca Renovasi sekarang'
      ]
    };
  }

  // 4. Rumah / Hunian Luas intent
  if (q.includes('rumah') || q.includes('lantai') || q.includes('ruang tamu') || q.includes('keluarga') || q.includes('kamar tidur')) {
    const isMultiLantai = q.includes('2 lantai') || q.includes('dua lantai') || q.includes('luas') || q.includes('besar');
    const durasi = isMultiLantai ? 3 : 2;
    return {
      reply: `Untuk hunian keluarga${isMultiLantai ? ' 2 lantai atau area luas' : ''}, kami sangat menyarankan layanan **Pembersihan Rumah** dengan alokasi durasi **${durasi} Jam** agar seluruh ruangan utama dan kamar mandi dapat dituntaskan secara maksimal.`,
      recommendedService: srvRumah ? {
        id: srvRumah.id,
        nama_layanan: srvRumah.nama_layanan,
        kategori: srvRumah.kategori,
        tarif_dasar: srvRumah.tarif_dasar,
        durasi_estimasi: srvRumah.durasi_estimasi,
        suggested_duration: durasi,
        rationale: `Alokasi waktu ${durasi} jam ideal untuk kebersihan menyeluruh hunian keluarga.`
      } : null,
      suggestedReplies: [
        'Apa saja area yang dibersihkan?',
        'Bagaimana dengan garansi mutunya?',
        'Pesan Pembersihan Rumah sekarang'
      ]
    };
  }

  // 5. FAQ Jam & Jadwal
  if (q.includes('jam') || q.includes('buka') || q.includes('jadwal') || q.includes('waktu') || q.includes('operasional')) {
    return {
      reply: 'Layanan Resik.in beroperasi setiap hari mulai pukul **08:00 WIB hingga 17:00 WIB** (dengan batas selesai maksimal pukul 19:00 WIB). Setiap antarpekerjaan petugas memiliki jeda operasional wajib sebesar **30 menit** untuk perjalanan dan persiapan peralatan.',
      recommendedService: null,
      suggestedReplies: [
        'Apakah bisa pesan untuk hari ini?',
        'Rekomendasi untuk pembersihan rumah',
        'Berapa tarif layanannya?'
      ]
    };
  }

  // 6. FAQ Garansi Mutu & Petugas
  if (q.includes('garansi') || q.includes('mutu') || q.includes('kualitas') || q.includes('laporan') || q.includes('foto')) {
    return {
      reply: 'Semua layanan Resik.in dilengkapi **Garansi Mutu Digital**. Sebelum pekerjaan dinyatakan selesai, petugas kebersihan wajib menyelesaikan checklist verifikasi area dan mengunggah bukti foto perbandingan **Sebelum (Before)** & **Sesudah (After)** langsung di aplikasi.',
      recommendedService: null,
      suggestedReplies: [
        'Siapa saja petugas yang tersedia?',
        'Bagaimana cara memesan layanan?',
        'Rekomendasi pembersihan kos'
      ]
    };
  }

  // Default General Help
  return {
    reply: 'Halo! Saya Resik AI, asisten pintar Resik.in. Ceritakan kondisi hunian Anda (misalnya kamar kos, rumah 2 lantai, kantor, atau pasca renovasi) agar saya dapat memberikan rekomendasi paket dan durasi yang paling tepat!',
    recommendedService: srvRumah ? {
      id: srvRumah.id,
      nama_layanan: srvRumah.nama_layanan,
      kategori: srvRumah.kategori,
      tarif_dasar: srvRumah.tarif_dasar,
      durasi_estimasi: srvRumah.durasi_estimasi,
      suggested_duration: 2,
      rationale: 'Paket standar terpopuler untuk kebersihan hunian.'
    } : null,
    suggestedReplies: [
      'Rekomendasi pembersihan rumah',
      'Rekomendasi kamar kos',
      'Berapa jam operasional Resik.in?'
    ]
  };
}
