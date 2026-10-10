# Chatbot AI Konsultasi Kebutuhan & Asisten Pemesanan Pintar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun subsistem Chatbot AI Konsultasi Kebutuhan (Resik AI) yang bertindak sebagai *Customer Care* (FAQ/Aturan Layanan) dan *Sales Consultant* cerdas, yang menganalisis kondisi hunian pelanggan, merekomendasikan paket dan durasi layanan, serta merender kartu pemesanan interaktif langsung di dalam obrolan untuk navigasi instan ke formulir pemesanan.

**Architecture:** Arsitektur terpisah *Server-Authoritative* di mana klien Flutter mobile berkomunikasi dengan Express REST API (`POST /api/ai/chat`). Backend menyuntikkan data katalog layanan aktif dari database Supabase (`db.getActiveServices`) dan aturan bisnis ke Google Gemini API via native `fetch` (tanpa dependensi npm berat) dengan batas timeout 8 detik, dilengkapi *Smart Rule-Based Fallback Engine* untuk ketahanan demonstrasi sidang skripsi.

**Tech Stack:** Node.js, Express.js, native `fetch` (Google Gemini REST API), Supabase PostgreSQL, Flutter (Dart), Material 3 Design System, `node:test`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-10-ai-consultation-chatbot-design.md`

## Global Constraints
- Minimal diff principle: Hanya sentuh file dan fungsi yang relevan, jangan refactor massal.
- Server-authoritative: Kunci `GEMINI_API_KEY` hanya boleh di backend (`.env`), tidak boleh diekspos ke mobile.
- Zero-dependency backend: Gunakan native `fetch` dan `AbortController` bawaan Node 18+ untuk komunikasi ke Gemini API.
- Demo-resilience: Fallback cerdas harus menghasilkan rekomendasi kartu yang valid bahkan ketika API key kosong atau internet mati.
- Format respon konsisten: `{ "success": true, "message": "...", "data": { "reply": "...", "recommended_service": {...}, "suggested_replies": [...] } }`.

---

### Task 1: Backend Smart Fallback Engine & Intent Matcher (`backend/lib/gemini.js`)

**Files:**
- Create: `backend/lib/gemini.js`
- Test: `backend/test/gemini_fallback.test.js`

**Interfaces:**
- Produces: `async function consultAi({ message, history, activeServices })` returning `{ reply, recommendedService, suggestedReplies }`.
  - `recommendedService`: `{ id, nama_layanan, kategori, tarif_dasar, durasi_estimasi, suggested_duration, rationale }` atau `null`.
  - `suggestedReplies`: array of strings.

- [ ] **Step 1: Write the failing test for gemini fallback engine**

Buat file `backend/test/gemini_fallback.test.js`:
```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { consultAi } from '../lib/gemini.js';

describe('Task 1: Gemini & Smart Fallback Engine Unit Tests', () => {
  const dummyServices = [
    { id: 'srv-001-rumah', nama_layanan: 'Pembersihan Rumah', kategori: 'rumah', tarif_dasar: 120000, durasi_estimasi: '2 - 3 Jam' },
    { id: 'srv-002-kos', nama_layanan: 'Pembersihan Kos', kategori: 'kos', tarif_dasar: 60000, durasi_estimasi: '1 - 2 Jam' },
    { id: 'srv-003-kantor', nama_layanan: 'Pembersihan Kantor', kategori: 'kantor', tarif_dasar: 180000, durasi_estimasi: '2 - 4 Jam' },
    { id: 'srv-004-renov', nama_layanan: 'Pembersihan Pasca Renovasi', kategori: 'renovasi', tarif_dasar: 250000, durasi_estimasi: '3 - 5 Jam' },
  ];

  it('1. Mengembalikan rekomendasi Pembersihan Kos saat pesan mengandung kata kunci kos', async () => {
    const res = await consultAi({
      message: 'Kamar kos saya berantakan banyak debu setelah libur panjang',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.reply.length > 10);
    assert.ok(res.recommendedService);
    assert.equal(res.recommendedService.id, 'srv-002-kos');
    assert.equal(res.recommendedService.suggested_duration, 1);
    assert.ok(Array.isArray(res.suggestedReplies));
    assert.ok(res.suggestedReplies.length > 0);
  });

  it('2. Mengembalikan rekomendasi Pembersihan Rumah dengan durasi 3 jam untuk rumah 2 lantai', async () => {
    const res = await consultAi({
      message: 'Saya punya rumah 2 lantai luas yang kotor habis acara arisan',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.recommendedService);
    assert.equal(res.recommendedService.id, 'srv-001-rumah');
    assert.equal(res.recommendedService.suggested_duration, 3);
  });

  it('3. Menjawab pertanyaan FAQ jam operasional tanpa memaksakan kartu layanan', async () => {
    const res = await consultAi({
      message: 'Jam berapa layanan Resik.in mulai buka dan tutup?',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.reply.includes('08:00'));
    assert.ok(res.reply.includes('17:00'));
    assert.equal(res.recommendedService, null);
  });

  it('4. Menolak dengan santun jika pertanyaan di luar topik kebersihan', async () => {
    const res = await consultAi({
      message: 'Bisa tolong tuliskan resep ayam bakar kecap?',
      history: [],
      activeServices: dummyServices,
      forceFallback: true,
    });

    assert.ok(res.reply.toLowerCase().includes('kebersihan') || res.reply.toLowerCase().includes('resik'));
    assert.equal(res.recommendedService, null);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/gemini_fallback.test.js`  
Expected: FAIL with "Cannot find module '../lib/gemini.js'".

- [ ] **Step 3: Write minimal implementation in `backend/lib/gemini.js`**

Buat file `backend/lib/gemini.js`:
```javascript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/gemini_fallback.test.js`  
Expected: PASS (4/4 tests passed).

- [ ] **Step 5: Commit**

```bash
git add backend/lib/gemini.js backend/test/gemini_fallback.test.js
git commit -m "feat(ai): implement Gemini integration and smart fallback engine"
```

---

### Task 2: Backend REST API Route & Express Server Mount (`POST /api/ai/chat`)

**Files:**
- Create: `backend/routes/ai.js`
- Modify: `backend/server.js:44-51`
- Test: `backend/test/ai.test.js`

**Interfaces:**
- Consumes: `consultAi` from `backend/lib/gemini.js`, `db.getActiveServices` from `backend/lib/database.js`.
- Produces: REST endpoint `POST /api/ai/chat`.

- [ ] **Step 1: Write the failing integration test in `backend/test/ai.test.js`**

Buat file `backend/test/ai.test.js`:
```javascript
import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../server.js';

describe('Task 2: POST /api/ai/chat API Integration Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('1. POST /api/ai/chat mengembalikan HTTP 200 dengan balasan terstruktur', async () => {
    const res = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Kamar kos saya kotor berdebu setelah pulang kampung',
        history: []
      })
    });

    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.data.reply);
    assert.ok(body.data.recommended_service);
    assert.equal(body.data.recommended_service.kategori, 'kos');
    assert.ok(Array.isArray(body.data.suggested_replies));
  });

  it('2. Menolak request jika pesan kosong dengan HTTP 400', async () => {
    const res = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: '   ',
        history: []
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'VALIDATION_ERROR');
  });

  it('3. Menolak request jika pesan melebihi 500 karakter dengan HTTP 400', async () => {
    const longMessage = 'A'.repeat(501);
    const res = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: longMessage,
        history: []
      })
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'MESSAGE_TOO_LONG');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test backend/test/ai.test.js`  
Expected: FAIL with HTTP 404 (endpoint not found).

- [ ] **Step 3: Implement `backend/routes/ai.js` and mount in `backend/server.js`**

Buat file `backend/routes/ai.js`:
```javascript
import express from 'express';
import { consultAi } from '../lib/gemini.js';
import db from '../lib/database.js';

const router = express.Router();

/**
 * POST /api/ai/chat
 * Endpoint konsultasi AI interaktif untuk rekomendasi layanan dan customer care.
 */
router.post('/chat', async (req, res) => {
  try {
    const { message, history } = req.body;

    // 1. Validasi Input
    if (!message || typeof message !== 'string' || message.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Pesan konsultasi tidak boleh kosong',
        error: 'VALIDATION_ERROR'
      });
    }

    if (message.length > 500) {
      return res.status(400).json({
        success: false,
        message: 'Pesan terlalu panjang (maksimal 500 karakter)',
        error: 'MESSAGE_TOO_LONG'
      });
    }

    const sanitizedHistory = Array.isArray(history) ? history.slice(-10) : [];

    // 2. Ambil Katalog Layanan Aktif dari Database
    const activeServices = await db.getActiveServices();

    // 3. Jalankan Konsultasi AI / Fallback
    const result = await consultAi({
      message: message.trim(),
      history: sanitizedHistory,
      activeServices
    });

    return res.status(200).json({
      success: true,
      message: 'Respons konsultasi AI berhasil dibuat',
      data: {
        reply: result.reply,
        recommended_service: result.recommendedService,
        suggested_replies: result.suggestedReplies || []
      }
    });
  } catch (err) {
    console.error('[AI Router Error]', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal memproses konsultasi AI',
      error: 'INTERNAL_SERVER_ERROR'
    });
  }
});

export default router;
```

Modifikasi `backend/server.js`:
Tambahkan `import aiRouter from './routes/ai.js';` dan `app.use('/api/ai', aiRouter);`.

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test backend/test/ai.test.js`  
Expected: PASS (3/3 tests passed).

- [ ] **Step 5: Run full backend test suite to ensure no regressions**

Run: `npm test` (di folder `backend`)  
Expected: All tests pass (100+ tests pass).

- [ ] **Step 6: Commit**

```bash
git add backend/routes/ai.js backend/server.js backend/test/ai.test.js
git commit -m "feat(ai): add POST /api/ai/chat endpoint with input validation and catalog grounding"
```

---

### Task 3: Mobile Data Models & ApiService Integration

**Files:**
- Create: `mobile/lib/models/ai_consultation_model.dart`
- Modify: `mobile/lib/services/api_service.dart`
- Test: `mobile/test/ai_consultation_model_test.dart`

**Interfaces:**
- Produces: `AiChatMessage`, `AiRecommendedService`, `AiConsultationResponse` classes in Dart.
- Produces: `ApiService.sendAiConsultationMessage({ required String message, List<Map<String, String>> history })`.

- [ ] **Step 1: Write the failing model test in `mobile/test/ai_consultation_model_test.dart`**

Buat file `mobile/test/ai_consultation_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/ai_consultation_model.dart';

void main() {
  group('AiConsultationModel Unit Tests', () {
    test('1. Deserialisasi AiConsultationResponse dengan recommended_service lengkap', () {
      final json = {
        'reply': 'Disarankan Pembersihan Kos',
        'recommended_service': {
          'id': 'srv-002-kos',
          'nama_layanan': 'Pembersihan Kos',
          'kategori': 'kos',
          'tarif_dasar': 60000,
          'durasi_estimasi': '1 - 2 Jam',
          'suggested_duration': 1,
          'rationale': 'Cocok untuk kamar 3x4 meter.'
        },
        'suggested_replies': ['Berapa tarifnya?', 'Pesan sekarang']
      };

      final response = AiConsultationResponse.fromJson(json);

      expect(response.reply, 'Disarankan Pembersihan Kos');
      expect(response.recommendedService, isNotNull);
      expect(response.recommendedService!.id, 'srv-002-kos');
      expect(response.recommendedService!.namaLayanan, 'Pembersihan Kos');
      expect(response.recommendedService!.tarifDasar, 60000.0);
      expect(response.recommendedService!.suggestedDuration, 1);
      expect(response.suggestedReplies.length, 2);
    });

    test('2. Deserialisasi AiConsultationResponse tanpa recommended_service (FAQ)', () {
      final json = {
        'reply': 'Jam operasional buka 08:00 - 17:00 WIB',
        'recommended_service': null,
        'suggested_replies': <String>[]
      };

      final response = AiConsultationResponse.fromJson(json);

      expect(response.recommendedService, isNull);
      expect(response.suggestedReplies, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ai_consultation_model_test.dart`  
Expected: FAIL (model file not found).

- [ ] **Step 3: Implement `mobile/lib/models/ai_consultation_model.dart` and `ApiService` method**

Buat `mobile/lib/models/ai_consultation_model.dart`:
```dart
import 'service_model.dart';

class AiRecommendedService {
  final String id;
  final String namaLayanan;
  final String kategori;
  final double tarifDasar;
  final String durasiEstimasi;
  final int suggestedDuration;
  final String rationale;

  AiRecommendedService({
    required this.id,
    required this.namaLayanan,
    required this.kategori,
    required this.tarifDasar,
    required this.durasiEstimasi,
    required this.suggestedDuration,
    required this.rationale,
  });

  factory AiRecommendedService.fromJson(Map<String, dynamic> json) {
    return AiRecommendedService(
      id: json['id']?.toString() ?? '',
      namaLayanan: json['nama_layanan']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? 'rumah',
      tarifDasar: (json['tarif_dasar'] as num?)?.toDouble() ?? 0.0,
      durasiEstimasi: json['durasi_estimasi']?.toString() ?? '2 Jam',
      suggestedDuration: (json['suggested_duration'] as num?)?.toInt() ?? 2,
      rationale: json['rationale']?.toString() ?? '',
    );
  }

  ServiceModel toServiceModel() {
    return ServiceModel(
      id: id,
      namaLayanan: namaLayanan,
      kategori: kategori,
      deskripsi: rationale,
      durasiEstimasi: durasiEstimasi,
      tarifDasar: tarifDasar,
      iconName: kategori == 'kos'
          ? 'bed'
          : kategori == 'kantor'
              ? 'business'
              : kategori == 'renovasi'
                  ? 'construction'
                  : 'home',
      isActive: true,
    );
  }
}

class AiConsultationResponse {
  final String reply;
  final AiRecommendedService? recommendedService;
  final List<String> suggestedReplies;

  AiConsultationResponse({
    required this.reply,
    this.recommendedService,
    required this.suggestedReplies,
  });

  factory AiConsultationResponse.fromJson(Map<String, dynamic> json) {
    return AiConsultationResponse(
      reply: json['reply']?.toString() ?? '',
      recommendedService: json['recommended_service'] != null
          ? AiRecommendedService.fromJson(Map<String, dynamic>.from(json['recommended_service']))
          : null,
      suggestedReplies: (json['suggested_replies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AiRecommendedService? recommendedService;
  final List<String> suggestedReplies;
  final bool isError;

  AiChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.recommendedService,
    this.suggestedReplies = const [],
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
```

Tambahkan ke `mobile/lib/services/api_service.dart`:
```dart
  /// Mengirim pesan konsultasi AI ke backend (POST /api/ai/chat)
  static Future<Map<String, dynamic>> sendAiConsultationMessage({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/ai/chat');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      ).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body = jsonDecode(response.body);
      return body;
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke layanan Resik AI: ${e.toString()}',
        'error': 'NETWORK_ERROR'
      };
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ai_consultation_model_test.dart`  
Expected: PASS (2/2 tests passed).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/ai_consultation_model.dart mobile/lib/services/api_service.dart mobile/test/ai_consultation_model_test.dart
git commit -m "feat(ai): add AI consultation models and ApiService method"
```

---

### Task 4: BookingScreen Parameter Expansion (`initialDuration`)

**Files:**
- Modify: `mobile/lib/screens/booking_screen.dart:12-25`
- Test: `mobile/test/booking_screen_test.dart`

**Interfaces:**
- Updates: `BookingScreen({super.key, required this.service, this.initialDuration})`.
- Behavior: When `initialDuration` is provided, `_selectedDuration` initializes with that value.

- [ ] **Step 1: Write test verifying `initialDuration` parameter in `booking_screen_test.dart`**

Tambahkan skenario ke `mobile/test/booking_screen_test.dart`:
```dart
  testWidgets('6. BookingScreen menginisialisasi durasi dengan parameter initialDuration jika diberikan', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(
          service: dummyService,
          initialDuration: 4,
        ),
      ),
    );
    await tester.pump();

    // Pastikan chip 4 Jam terpilih
    final chip4Jam = find.widgetWithText(ChoiceChip, '4 Jam');
    expect(chip4Jam, findsOneWidget);
    final ChoiceChip chipWidget = tester.widget(chip4Jam);
    expect(chipWidget.selected, isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/booking_screen_test.dart`  
Expected: FAIL (named parameter `initialDuration` isn't defined).

- [ ] **Step 3: Modify `mobile/lib/screens/booking_screen.dart` to accept `initialDuration`**

Update `BookingScreen`:
```dart
class BookingScreen extends StatefulWidget {
  final ServiceModel service;
  final int? initialDuration;

  const BookingScreen({
    super.key,
    required this.service,
    this.initialDuration,
  });
...
```
Di `_BookingScreenState.initState()`:
```dart
    if (widget.initialDuration != null && widget.initialDuration! >= 1 && widget.initialDuration! <= 4) {
      _selectedDuration = widget.initialDuration!;
    } else {
      switch (widget.service.kategori.toLowerCase()) {
        case 'kos':
          _selectedDuration = 1;
          break;
        case 'kantor':
          _selectedDuration = 3;
          break;
        case 'renovasi':
          _selectedDuration = 4;
          break;
        case 'rumah':
        default:
          _selectedDuration = 2;
          break;
      }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/booking_screen_test.dart`  
Expected: PASS (6/6 tests passed).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/booking_screen.dart mobile/test/booking_screen_test.dart
git commit -m "feat(booking): add initialDuration constructor parameter to BookingScreen"
```

---

### Task 5: Mobile UI - Chat Screen & In-Chat Actionable Cards (`AiConsultationScreen`)

**Files:**
- Create: `mobile/lib/screens/ai_consultation_screen.dart`
- Test: `mobile/test/ai_consultation_screen_test.dart`

**Interfaces:**
- Produces: `AiConsultationScreen` (Material 3 Flutter Widget).
- Features:
  - Welcome Card & Quick Starter Chips.
  - User and AI message bubbles with markdown styling.
  - In-Chat Actionable Service Card with direct link to `BookingScreen`.
  - Typing indicator & auto-scroll on new message / keyboard.
  - Suggested reply chips bar above text input.
  - Error state with tap to retry.
  - Haptic feedback & copy to clipboard on long press.
  - Clear chat dialog confirmation.

- [ ] **Step 1: Write widget test in `mobile/test/ai_consultation_screen_test.dart`**

Buat file `mobile/test/ai_consultation_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/screens/ai_consultation_screen.dart';

void main() {
  testWidgets('1. AiConsultationScreen menampilkan header Resik AI, status online, dan pesan sambutan awal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AiConsultationScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Resik AI'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.textContaining('asisten pintar'), findsOneWidget);
    expect(find.byKey(const Key('input_ai_message')), findsOneWidget);
    expect(find.byKey(const Key('btn_send_ai_message')), findsOneWidget);
  });

  testWidgets('2. Mengetik pesan dan mengirim menambahkan bubble pesan ke percakapan', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AiConsultationScreen(),
      ),
    );
    await tester.pump();

    // Input teks
    await tester.enterText(find.byKey(const Key('input_ai_message')), 'Halo, butuh saran untuk kosan');
    await tester.pump();

    // Tekan kirim
    await tester.tap(find.byKey(const Key('btn_send_ai_message')));
    await tester.pump();

    // Verifikasi pesan user muncul
    expect(find.text('Halo, butuh saran untuk kosan'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ai_consultation_screen_test.dart`  
Expected: FAIL (screen not found).

- [ ] **Step 3: Implement `mobile/lib/screens/ai_consultation_screen.dart`**

Buat file `mobile/lib/screens/ai_consultation_screen.dart`:
- Implementasikan layout lengkap: `AppBar`, `ListView` pesan, `_InChatServiceCard`, `_SuggestedRepliesBar`, dan `_ChatInputBar`.
- Gunakan `AppColors` dan tema Material 3 yang konsisten.
- Tambahkan auto-scroll dengan `ScrollController`.
- Tambahkan haptic feedback pada aksi sentuh.
- Hubungkan dengan `ApiService.sendAiConsultationMessage`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ai_consultation_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/ai_consultation_screen.dart mobile/test/ai_consultation_screen_test.dart
git commit -m "feat(ai): implement interactive AiConsultationScreen with actionable service cards"
```

---

### Task 6: Mobile UI Entry Points in Customer HomeScreen (`main.dart`)

**Files:**
- Modify: `mobile/lib/main.dart:528-545` (Banner "Tanya Resik AI")
- Modify: `mobile/lib/main.dart:450-480` (Floating Action Button)
- Test: `mobile/test/widget_test.dart` atau `mobile/test/ai_entry_point_test.dart`

**Interfaces:**
- Produces: Navigation from HomeScreen to `AiConsultationScreen` on banner tap and on FloatingActionButton press.

- [ ] **Step 1: Write test verifying entry point navigation in `mobile/test/ai_entry_point_test.dart`**

Buat file `mobile/test/ai_entry_point_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/main.dart';

void main() {
  testWidgets('HomeScreen memiliki tombol floating action AI untuk membuka konsultasi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ResikInApp());
    await tester.pumpAndSettle();

    final fab = find.byKey(const Key('fab_tanya_resik_ai'));
    expect(fab, findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ai_entry_point_test.dart`  
Expected: FAIL (Key `fab_tanya_resik_ai` not found).

- [ ] **Step 3: Modify `mobile/lib/main.dart`**

1. Tambahkan `import 'screens/ai_consultation_screen.dart';`
2. Bungkus Container Banner "Tanya Resik AI" dengan `InkWell` / `GestureDetector` dengan aksi:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => const AiConsultationScreen()),
   );
   ```
3. Tambahkan `floatingActionButton` pada `Scaffold` Beranda:
   ```dart
   floatingActionButton: FloatingActionButton.extended(
     key: const Key('fab_tanya_resik_ai'),
     onPressed: () {
       Navigator.push(
         context,
         MaterialPageRoute(builder: (context) => const AiConsultationScreen()),
       );
     },
     backgroundColor: AppColors.primary,
     foregroundColor: Colors.white,
     icon: const Icon(Icons.auto_awesome_rounded),
     label: const Text('Tanya AI', style: TextStyle(fontWeight: FontWeight.w700)),
   ),
   ```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ai_entry_point_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/main.dart mobile/test/ai_entry_point_test.dart
git commit -m "feat(ui): connect customer HomeScreen banner and FAB to AiConsultationScreen"
```

---

### Task 7: Full System Verification, Regression Testing, & Documentation

**Files:**
- Modify: `laporan-skripsi-resikin/LOGBOOK-HARIAN.md`
- Modify: `laporan-skripsi-resikin/PROGRESS-PROJECT.md`

- [ ] **Step 1: Run full Backend test suite**

Run: `cd backend && npm test`  
Expected: 100% PASS on all backend test suites.

- [ ] **Step 2: Run full Mobile test suite**

Run: `cd mobile && flutter test`  
Expected: 100% PASS on all Flutter widget & unit test suites.

- [ ] **Step 3: Run Flutter static analysis**

Run: `cd mobile && flutter analyze`  
Expected: `No issues found!`.

- [ ] **Step 4: Update skripsi logbook & progress documentation**

Catat penambahan subsistem Chatbot AI Konsultasi Kebutuhan di `laporan-skripsi-resikin/LOGBOOK-HARIAN.md` dan `laporan-skripsi-resikin/PROGRESS-PROJECT.md`.

- [ ] **Step 5: Final Commit & Push**

```bash
git add .
git commit -m "feat(ai): complete end-to-end AI Consultation Chatbot with Gemini integration and actionable service cards"
git push origin main
```
