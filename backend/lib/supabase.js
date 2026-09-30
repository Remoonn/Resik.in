import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const STATE_FILE = path.join(__dirname, '..', '.in_memory_state.json');

const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || '';

// 1. Inisialisasi Klien Supabase Resmi
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// 2. In-Memory Seed Data (Sesuai database/schema.sql)
export const inMemoryStore = {
  services: [
    {
      id: 'srv-001-rumah',
      nama_layanan: 'Pembersihan Rumah',
      kategori: 'rumah',
      deskripsi: 'Layanan pembersihan menyeluruh untuk hunian rumah tinggal keluarga, meliputi ruang tamu, kamar tidur, dapur, dan area santai.',
      durasi_estimasi: '2 - 3 Jam',
      tarif_dasar: 120000.00,
      icon_name: 'home',
      is_active: true,
      created_at: new Date().toISOString()
    },
    {
      id: 'srv-002-kos',
      nama_layanan: 'Pembersihan Kos',
      kategori: 'kos',
      deskripsi: 'Layanan pembersihan praktis dan higienis khusus kamar kos atau studio apartment, mencakup kamar mandi dalam, debu furnitur, dan lantai.',
      durasi_estimasi: '1 - 2 Jam',
      tarif_dasar: 75000.00,
      icon_name: 'bed',
      is_active: true,
      created_at: new Date().toISOString()
    },
    {
      id: 'srv-003-kantor',
      nama_layanan: 'Pembersihan Kantor',
      kategori: 'kantor',
      deskripsi: 'Pembersihan profesional untuk lingkungan kerja ruko atau ruang kantor UMKM, menjaga meja kerja, ruang meeting, dan lobi tetap rapi dan bersih.',
      durasi_estimasi: '3 - 4 Jam',
      tarif_dasar: 200000.00,
      icon_name: 'briefcase',
      is_active: true,
      created_at: new Date().toISOString()
    },
    {
      id: 'srv-004-renovasi',
      nama_layanan: 'Pembersihan Pasca Renovasi',
      kategori: 'pasca_renovasi',
      deskripsi: 'Pembersihan intensif untuk menghilangkan debu konstruksi pekat, sisa semen pada lantai, noda cat pada kaca jendela, dan serpihan material.',
      durasi_estimasi: '4 - 6 Jam',
      tarif_dasar: 350000.00,
      icon_name: 'tool',
      is_active: true,
      created_at: new Date().toISOString()
    }
  ],
  cleaners: [
    {
      id: 'cln-001',
      nama: 'Candra Pratama',
      nomor_kontak: '081234567801',
      foto_url: 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400',
      keahlian: ['pasca_renovasi', 'rumah', 'kantor'],
      pengalaman_tahun: 4,
      rating_rata_rata: 4.9,
      total_ulasan: 127,
      total_pekerjaan: 142,
      tingkat_kepuasan: 99,
      ketepatan_waktu: 98,
      status_operasional: 'Aktif',
      tentang: 'Spesialis pembersihan mendalam (deep cleaning) dan penanganan pasca renovasi bangunan. Mengedepankan ketelitian hingga ke sudut tersembunyi.',
      sertifikasi: ['Sertifikasi BNSP K3 Kebersihan', 'Vaksinasi Lengkap & Bebas Catatan Kriminal']
    },
    {
      id: 'cln-002',
      nama: 'Budi Santoso',
      nomor_kontak: '081234567802',
      foto_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      keahlian: ['kos', 'rumah'],
      pengalaman_tahun: 3,
      rating_rata_rata: 4.8,
      total_ulasan: 94,
      total_pekerjaan: 108,
      tingkat_kepuasan: 97,
      ketepatan_waktu: 99,
      status_operasional: 'Aktif',
      tentang: 'Berpengalaman menangani hunian praktis, kamar kos, dan studio apartment dengan standar kebersihan higienis hotel.',
      sertifikasi: ['Pelatihan Sanitasi Kamar Mandi & Furnitur', 'Bebas Catatan Kriminal']
    },
    {
      id: 'cln-003',
      nama: 'Siti Aminah',
      nomor_kontak: '081234567803',
      foto_url: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400',
      keahlian: ['rumah', 'kantor'],
      pengalaman_tahun: 5,
      rating_rata_rata: 5.0,
      total_ulasan: 156,
      total_pekerjaan: 170,
      tingkat_kepuasan: 100,
      ketepatan_waktu: 100,
      status_operasional: 'Aktif',
      tentang: 'Petugas kebersihan senior dengan dedikasi tinggi pada kerapihan rumah tinggal dan ruang kerja perkantoran.',
      sertifikasi: ['Sertifikasi Pembersihan Ramah Lingkungan', 'Pelatihan Etika Pelayanan Prima']
    },
    {
      id: 'cln-004',
      nama: 'Ahmad Fauzi',
      nomor_kontak: '081234567804',
      foto_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      keahlian: ['kos', 'pasca_renovasi'],
      pengalaman_tahun: 2,
      rating_rata_rata: 4.7,
      total_ulasan: 62,
      total_pekerjaan: 75,
      tingkat_kepuasan: 95,
      ketepatan_waktu: 96,
      status_operasional: 'Aktif',
      tentang: 'Fokus pada kecepatan dan ketangkasan pembersihan area berdebu tebal dan penataan kamar kos cepat rapi.',
      sertifikasi: ['Sertifikasi Penanganan Peralatan Berat Pembersih']
    },
    {
      id: 'cln-005',
      nama: 'Dewi Lestari',
      nomor_kontak: '081234567805',
      foto_url: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400',
      keahlian: ['rumah', 'kos'],
      pengalaman_tahun: 1,
      rating_rata_rata: 0,
      total_ulasan: 0,
      total_pekerjaan: 0,
      tingkat_kepuasan: 100,
      ketepatan_waktu: 100,
      status_operasional: 'Aktif',
      tentang: 'Petugas kebersihan baru terlatih yang telah menyelesaikan orientasi ketat standar kebersihan Resik.in.',
      sertifikasi: ['Kelulusan Akademi Resik.in 2026', 'Bebas Catatan Kriminal']
    }
  ],
  orders: [
    {
      id: 'ea48e813-ac5d-4004-9ce3-67113d746d37',
      order_code: 'RSK-20261001-001',
      customer_id: 'usr-customer-001',
      service_id: '2abfccbb-1643-4519-b4d0-c72996e8bb9f',
      service_kategori: 'kos',
      cleaner_id: 'cln-004',
      preferensi_petugas_id: 'cln-004',
      tanggal_layanan: '2026-10-01',
      start_time: '10:00',
      end_time: '12:00',
      duration: 2,
      alamat_lengkap: 'Jl. Besi no99',
      patokan_lokasi: 'pagar merah',
      luas_area: 'kamar 3x4m',
      catatan_khusus: null,
      harga_saat_booking: 75000,
      total_biaya: 75000,
      status_pembayaran: 'Sudah Bayar',
      payment_timestamp: '2026-09-29T18:15:10.711Z',
      status_pekerjaan: 'Selesai',
      cancellation_reason: null,
      cancelled_by: null,
      cancelled_at: null,
      created_at: '2026-09-29T18:15:09.693Z',
      started_at: '2026-09-29T18:15:15.523Z'
    },
    {
      id: '994f6abf-b25b-420e-9e86-0a9aa48c2aa7',
      order_code: 'RSK-20261001-001',
      customer_id: 'usr-customer-001',
      service_id: '2abfccbb-1643-4519-b4d0-c72996e8bb9f',
      service_kategori: 'kos',
      cleaner_id: 'cln-004',
      preferensi_petugas_id: 'cln-004',
      tanggal_layanan: '2026-10-01',
      start_time: '10:00',
      end_time: '12:00',
      duration: 2,
      alamat_lengkap: 'Jl. Besi no99',
      patokan_lokasi: 'pagar merah',
      luas_area: 'kamar 3x4m',
      catatan_khusus: null,
      harga_saat_booking: 75000,
      total_biaya: 75000,
      status_pembayaran: 'Sudah Bayar',
      payment_timestamp: '2026-09-29T18:15:10.711Z',
      status_pekerjaan: 'Selesai',
      cancellation_reason: null,
      cancelled_by: null,
      cancelled_at: null,
      created_at: '2026-09-29T18:15:09.693Z',
      started_at: '2026-09-29T18:15:15.523Z'
    }
  ],
  status_logs: [],
  quality_reports: [
    {
      id: 'a8a2f86e-2026-461e-bdcf-2acb2b327094',
      order_id: 'ea48e813-ac5d-4004-9ce3-67113d746d37',
      cleaner_id: 'cln-004',
      checklist_area: [
        { area: 'Kamar Tidur / Utama', completed: true },
        { area: 'Kamar Mandi', completed: true },
        { area: 'Area yang Termasuk Paket', completed: true }
      ],
      foto_before_url: 'orders/ea48e813-ac5d-4004-9ce3-67113d746d37/before.jpg',
      foto_after_url: 'orders/ea48e813-ac5d-4004-9ce3-67113d746d37/after.jpg',
      catatan_petugas: 'Pembersihan tuntas sesuai standar mutu Resik.in',
      started_at: '2026-09-29T18:15:15.523Z',
      completed_at: '2026-09-29T18:15:25.601Z',
      submitted_at: '2026-09-29T18:15:25.525Z'
    },
    {
      id: 'b9b3e97f-2026-461e-bdcf-2acb2b327095',
      order_id: '994f6abf-b25b-420e-9e86-0a9aa48c2aa7',
      cleaner_id: 'cln-004',
      checklist_area: [
        { area: 'Kamar Tidur / Utama', completed: true },
        { area: 'Kamar Mandi', completed: true },
        { area: 'Area yang Termasuk Paket', completed: true }
      ],
      foto_before_url: 'orders/994f6abf-b25b-420e-9e86-0a9aa48c2aa7/before.jpg',
      foto_after_url: 'orders/994f6abf-b25b-420e-9e86-0a9aa48c2aa7/after.jpg',
      catatan_petugas: 'Pembersihan tuntas sesuai standar mutu Resik.in',
      started_at: '2026-09-29T18:15:15.523Z',
      completed_at: '2026-09-29T18:15:25.601Z',
      submitted_at: '2026-09-29T18:15:25.525Z'
    }
  ],
  quality_report_photos: {},
  reviews: [
    {
      id: 'rev-001',
      cleaner_id: 'cln-001',
      customer_nama: 'Anisa Rahmawati',
      rating: 5,
      tanggal: '2026-09-20',
      ulasan: 'Pekerjaan Mas Candra sangat bersih dan rapi! Debu tebal bekas renovasi dapur hilang total tanpa sisa.',
      service_nama: 'Pembersihan Pasca Renovasi'
    },
    {
      id: 'rev-002',
      cleaner_id: 'cln-001',
      customer_nama: 'Bambang Sudarsono',
      rating: 5,
      tanggal: '2026-09-15',
      ulasan: 'Datang tepat waktu dan membawa peralatan lengkap. Kaca jendela yang buram jadi jernih kembali.',
      service_nama: 'Pembersihan Rumah'
    },
    {
      id: 'rev-003',
      cleaner_id: 'cln-002',
      customer_nama: 'Kevin Pratama',
      rating: 5,
      tanggal: '2026-09-18',
      ulasan: 'Kamar kos saya yang berantakan langsung rapi dan wangi dalam 1 jam. Mantap Mas Budi!',
      service_nama: 'Pembersihan Kos'
    },
    {
      id: 'rev-004',
      cleaner_id: 'cln-003',
      customer_nama: 'Dr. Hendra Wijaya',
      rating: 5,
      tanggal: '2026-09-22',
      ulasan: 'Ibu Siti sangat teliti dan sopan. Ruang konsultasi dan meeting kantor kami selalu bersih berkilau.',
      service_nama: 'Pembersihan Kantor'
    }
  ],
  users: [
    {
      id: 'usr-customer-001',
      nama: 'Budi Santoso',
      email: 'pelanggan@resik.in',
      password: 'password123',
      nomor_wa: '081234567890',
      role: 'customer',
      created_at: new Date().toISOString()
    },
    {
      id: 'usr-cleaner-001',
      nama: 'Candra Pratama',
      email: 'petugas@resik.in',
      password: 'password123',
      nomor_wa: '081234567801',
      role: 'cleaner',
      cleaner_id: 'cln-001',
      created_at: new Date().toISOString()
    },
    {
      id: 'usr-admin-001',
      nama: 'Admin Resik',
      email: 'admin@resik.in',
      password: 'password123',
      nomor_wa: '081999888777',
      role: 'admin',
      created_at: new Date().toISOString()
    }
  ]
};

// 3. Helper Fetch Services dengan Dual-Mode Resilien
export async function getServices(all = false) {
  try {
    let query = supabase.from('services').select('*');
    if (!all) {
      query = query.eq('is_active', true);
    }
    const { data, error } = await query;
    if (error || !data || data.length === 0) {
      // Gunakan in-memory fallback
      return {
        data: all ? inMemoryStore.services : inMemoryStore.services.filter(s => s.is_active),
        source: 'in-memory-fallback'
      };
    }
    return { data, source: 'supabase-live' };
  } catch (err) {
    return {
      data: all ? inMemoryStore.services : inMemoryStore.services.filter(s => s.is_active),
      source: 'in-memory-fallback'
    };
  }
}

// 4. Helper untuk Agregasi Rating Petugas Otomatis
export function updateCleanerRating(cleanerId) {
  const reviews = inMemoryStore.reviews.filter(r => r.cleaner_id === cleanerId);
  const cleaner = inMemoryStore.cleaners.find(c => c.id === cleanerId);
  if (!cleaner) return null;

  if (reviews.length === 0) {
    cleaner.total_ulasan = 0;
    return cleaner;
  }

  const sum = reviews.reduce((acc, curr) => acc + curr.rating, 0);
  const avg = Math.round((sum / reviews.length) * 10) / 10;
  cleaner.rating_rata_rata = avg;
  cleaner.total_ulasan = reviews.length;
  saveStateToDisk();
  return cleaner;
}

// 5. Persistence Helper untuk In-Memory Store (Menjaga data saat server di-restart)
export function saveStateToDisk() {
  try {
    const cleanOrders = inMemoryStore.orders.filter(o => !o.id.startsWith('ord-test-') && !o.id.startsWith('ord-qr-'));
    const cleanLogs = inMemoryStore.status_logs.filter(l => !l.order_id.startsWith('ord-test-') && !l.order_id.startsWith('ord-qr-'));
    const cleanReports = inMemoryStore.quality_reports.filter(r => !r.order_id.startsWith('ord-test-') && !r.order_id.startsWith('ord-qr-'));
    const cleanReviews = (inMemoryStore.reviews || []).filter(r => 
      !r.id?.startsWith('rev-test-') && 
      !(r.order_id && (r.order_id.startsWith('ord-test-') || r.order_id.startsWith('ord-qr-')))
    );
    const dataToSave = {
      orders: cleanOrders,
      status_logs: cleanLogs,
      quality_reports: cleanReports,
      cleaners: inMemoryStore.cleaners,
      reviews: cleanReviews
    };
    fs.writeFileSync(STATE_FILE, JSON.stringify(dataToSave, null, 2), 'utf8');
  } catch (err) {
    console.error('[inMemoryStore] Gagal menyimpan cache ke disk:', err.message);
  }
}

export function loadStateFromDisk() {
  try {
    if (fs.existsSync(STATE_FILE)) {
      const content = fs.readFileSync(STATE_FILE, 'utf8');
      const loaded = JSON.parse(content);
      if (Array.isArray(loaded.orders) && loaded.orders.length > 0) {
        inMemoryStore.orders = loaded.orders.filter(o => !o.id.startsWith('ord-test-') && !o.id.startsWith('ord-qr-'));
      }
      if (Array.isArray(loaded.status_logs)) {
        inMemoryStore.status_logs = loaded.status_logs.filter(l => !l.order_id.startsWith('ord-test-') && !l.order_id.startsWith('ord-qr-'));
      }
      if (Array.isArray(loaded.quality_reports) && loaded.quality_reports.length > 0) {
        inMemoryStore.quality_reports = loaded.quality_reports.filter(r => !r.order_id.startsWith('ord-test-') && !r.order_id.startsWith('ord-qr-'));
      }
      if (Array.isArray(loaded.cleaners) && loaded.cleaners.length > 0) {
        inMemoryStore.cleaners = loaded.cleaners;
      }
      if (Array.isArray(loaded.reviews) && loaded.reviews.length > 0) {
        inMemoryStore.reviews = loaded.reviews.filter(r => 
          !r.id?.startsWith('rev-test-') && 
          !(r.order_id && (r.order_id.startsWith('ord-test-') || r.order_id.startsWith('ord-qr-')))
        );
      }
      console.log(`[inMemoryStore] Berhasil memuat status tersimpan: ${inMemoryStore.orders.length} pesanan, ${inMemoryStore.quality_reports.length} laporan mutu, ${inMemoryStore.reviews.length} ulasan.`);
    }
  } catch (err) {
    console.warn('[inMemoryStore] Tidak dapat memuat cache, menggunakan nilai bawaan:', err.message);
  }
}

// Jalankan pemulihan cache saat modul dimuat
loadStateFromDisk();
