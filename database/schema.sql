-- ==============================================================================
-- SKRIP BASIS DATA (SQL DDL & SEED DATA) - RESIK.IN
-- Proyek Skripsi: Prototipe Aplikasi Jasa Kebersihan On-Demand
-- Database: PostgreSQL / Supabase
-- Versi: 1.0 (Final Draft Schema)
-- ==============================================================================

-- 1. AKTIFKAN EKSTENSI UUID (Jika belum aktif)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 2. TABEL PROFIL PENGGUNA (users / profiles)
-- Terintegrasi dengan auth.users bawaan Supabase
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nama VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL,
    nomor_wa VARCHAR(30),
    role VARCHAR(20) NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'cleaner', 'admin')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger otomatis untuk membuat baris profile saat user baru register di Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, nama, email, nomor_wa, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nama', NEW.raw_user_meta_data->>'full_name', 'Pelanggan Resik'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'nomor_wa', NEW.raw_user_meta_data->>'phone', '-'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ==============================================================================
-- 3. TABEL KATALOG LAYANAN (services)
-- Menyimpan 4 kategori layanan kebersihan utama
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_layanan VARCHAR(100) NOT NULL,
    kategori VARCHAR(50) NOT NULL UNIQUE CHECK (kategori IN ('rumah', 'kos', 'kantor', 'pasca_renovasi')),
    deskripsi TEXT NOT NULL,
    durasi_estimasi VARCHAR(50) NOT NULL,
    tarif_dasar NUMERIC(12, 2) NOT NULL,
    icon_name VARCHAR(50) DEFAULT 'broom',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ==============================================================================
-- 4. TABEL MASTER DATA PETUGAS KEBERSIHAN (cleaners)
-- Menyimpan profil profesional petugas untuk rekomendasi & penugasan
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.cleaners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Opsional, jika petugas memiliki akun login
    nama VARCHAR(150) NOT NULL,
    nomor_kontak VARCHAR(30) NOT NULL,
    foto_url TEXT,
    keahlian TEXT[] NOT NULL DEFAULT '{}', -- contoh: ARRAY['rumah', 'kos', 'pasca_renovasi']
    pengalaman_tahun INT NOT NULL DEFAULT 1,
    rating_rata_rata NUMERIC(2, 1) NOT NULL DEFAULT 5.0 CHECK (rating_rata_rata >= 1.0 AND rating_rata_rata <= 5.0),
    total_pekerjaan INT NOT NULL DEFAULT 0,
    status_operasional VARCHAR(20) NOT NULL DEFAULT 'aktif' CHECK (status_operasional IN ('aktif', 'sibuk', 'cuti', 'nonaktif')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ==============================================================================
-- 5. TABEL TRANSAKSI PEMESANAN (orders)
-- Mencatat seluruh alur transaksi, jadwal, petugas, dan tahapan pekerjaan
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_code VARCHAR(30) UNIQUE NOT NULL, -- Format contoh: RSK-20260921-001
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id UUID REFERENCES public.services(id) ON DELETE RESTRICT,
    cleaner_id UUID REFERENCES public.cleaners(id) ON DELETE SET NULL, -- Petugas resmi yang ditugaskan
    preferensi_petugas_id UUID REFERENCES public.cleaners(id) ON DELETE SET NULL, -- Pilihan rekomendasi awal dari pelanggan
    alamat_lengkap TEXT NOT NULL,
    patokan_lokasi TEXT,
    luas_area VARCHAR(100), -- misal: 'Tipe 36', 'Kamar 3x4 m', '2 Lantai'
    catatan_khusus TEXT,
    tanggal_layanan DATE NOT NULL,
    jam_mulai TIME NOT NULL,
    total_biaya NUMERIC(12, 2) NOT NULL,
    metode_pembayaran VARCHAR(50) DEFAULT 'simulasi_dummy',
    status_pembayaran VARCHAR(30) NOT NULL DEFAULT 'belum_bayar' CHECK (status_pembayaran IN ('belum_bayar', 'sudah_bayar')),
    status_pekerjaan VARCHAR(40) NOT NULL DEFAULT 'menunggu_konfirmasi' CHECK (status_pekerjaan IN (
        'menunggu_konfirmasi',
        'dikonfirmasi',
        'petugas_ditugaskan',
        'menuju_lokasi',
        'tiba_di_lokasi',
        'sedang_dikerjakan',
        'selesai',
        'dibatalkan'
    )),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- ==============================================================================
-- 6. TABEL QUALITY REPORT (quality_reports)
-- Mencatat dokumentasi hasil pekerjaan: foto before/after & checklist area
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.quality_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    cleaner_id UUID REFERENCES public.cleaners(id) ON DELETE SET NULL,
    checklist_area JSONB NOT NULL DEFAULT '[]'::jsonb, -- Contoh: [{"area": "Kamar Tidur", "done": true}, ...]
    foto_before_url TEXT,
    foto_after_url TEXT,
    catatan_petugas TEXT,
    waktu_submit TIMESTAMPTZ DEFAULT NOW()
);


-- ==============================================================================
-- 7. TABEL AUDIT LOG STATUS PEKERJAAN (status_logs)
-- Mencatat kronologi perubahan status untuk auditabilitas
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.status_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    status_sebelumnya VARCHAR(40),
    status_baru VARCHAR(40) NOT NULL,
    diubah_oleh UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    catatan TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ==============================================================================
-- 8. TABEL CLEANING PLAN / LAYANAN RUTIN (cleaning_plans)
-- Kebutuhan Fitur Bernilai Tambah Fase 3 (Should Have)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.cleaning_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE RESTRICT,
    cleaner_id UUID REFERENCES public.cleaners(id) ON DELETE SET NULL,
    frekuensi VARCHAR(30) NOT NULL DEFAULT 'mingguan' CHECK (frekuensi IN ('mingguan', 'dua_mingguan', 'bulanan')),
    hari_tetap VARCHAR(20) NOT NULL, -- Contoh: 'Senin', 'Sabtu'
    jam_mulai TIME NOT NULL,
    status_plan VARCHAR(20) NOT NULL DEFAULT 'aktif' CHECK (status_plan IN ('aktif', 'nonaktif')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ==============================================================================
-- 9. TABEL RATING & ULASAN PELANGGAN (reviews)
-- Menampung ulasan pelanggan setelah pesanan berstatus 'selesai'
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    cleaner_id UUID NOT NULL REFERENCES public.cleaners(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    ulasan TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger untuk memperbarui rating rata-rata cleaner otomatis saat ulasan baru masuk
CREATE OR REPLACE FUNCTION public.update_cleaner_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.cleaners
    SET 
        rating_rata_rata = ROUND((SELECT AVG(rating)::numeric FROM public.reviews WHERE cleaner_id = NEW.cleaner_id), 1),
        total_pekerjaan = (SELECT COUNT(*) FROM public.orders WHERE cleaner_id = NEW.cleaner_id AND status_pekerjaan = 'selesai')
    WHERE id = NEW.cleaner_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_review_created ON public.reviews;
CREATE TRIGGER on_review_created
    AFTER INSERT OR UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_cleaner_rating();


-- ==============================================================================
-- 10. INDEX OPTIMASI QUERY & ANTI-DOUBLE BOOKING
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON public.orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_cleaner_id ON public.orders (cleaner_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders (status_pekerjaan);
CREATE INDEX IF NOT EXISTS idx_orders_schedule_check ON public.orders (cleaner_id, tanggal_layanan, jam_mulai) 
    WHERE status_pekerjaan NOT IN ('selesai', 'dibatalkan');

CREATE INDEX IF NOT EXISTS idx_status_logs_order_id ON public.status_logs (order_id);
CREATE INDEX IF NOT EXISTS idx_reviews_cleaner_id ON public.reviews (cleaner_id);


-- ==============================================================================
-- 11. PENGATURAN ROW LEVEL SECURITY (RLS) - PERMISI AKSES SUPABASE
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cleaners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quality_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cleaning_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Policy Layanan (Semua orang dapat membaca katalog aktif)
DROP POLICY IF EXISTS "Public can view active services" ON public.services;
CREATE POLICY "Public can view active services" ON public.services
    FOR SELECT USING (is_active = TRUE);

-- Policy Petugas (Semua pengguna terotentikasi dapat melihat profil petugas aktif)
DROP POLICY IF EXISTS "Users can view active cleaners" ON public.cleaners;
CREATE POLICY "Users can view active cleaners" ON public.cleaners
    FOR SELECT USING (TRUE);

-- Policy Profil (Pengguna dapat melihat & mengedit profilnya sendiri)
DROP POLICY IF EXISTS "Users can manage own profile" ON public.profiles;
CREATE POLICY "Users can manage own profile" ON public.profiles
    FOR ALL USING (auth.uid() = id);

-- Policy Pesanan (Pelanggan melihat pesanannya, Admin & Petugas melihat pesanan terkait)
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
CREATE POLICY "Users can view own orders" ON public.orders
    FOR SELECT USING (
        auth.uid() = customer_id 
        OR auth.uid() IN (SELECT id FROM public.profiles WHERE role = 'admin')
        OR auth.uid() IN (SELECT user_id FROM public.cleaners WHERE id = orders.cleaner_id)
    );

DROP POLICY IF EXISTS "Customers can create orders" ON public.orders;
CREATE POLICY "Customers can create orders" ON public.orders
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

DROP POLICY IF EXISTS "Admin and assigned cleaners can update orders" ON public.orders;
CREATE POLICY "Admin and assigned cleaners can update orders" ON public.orders
    FOR UPDATE USING (
        auth.uid() = customer_id
        OR auth.uid() IN (SELECT id FROM public.profiles WHERE role = 'admin')
        OR auth.uid() IN (SELECT user_id FROM public.cleaners WHERE id = orders.cleaner_id)
    );

-- Policy Quality Report
DROP POLICY IF EXISTS "Quality reports viewable by order participants" ON public.quality_reports;
CREATE POLICY "Quality reports viewable by order participants" ON public.quality_reports
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.orders 
            WHERE orders.id = quality_reports.order_id 
            AND (orders.customer_id = auth.uid() OR auth.uid() IN (SELECT id FROM public.profiles WHERE role = 'admin') OR auth.uid() IN (SELECT user_id FROM public.cleaners WHERE id = orders.cleaner_id))
        )
    );

-- Policy Reviews
DROP POLICY IF EXISTS "Public can view reviews" ON public.reviews;
CREATE POLICY "Public can view reviews" ON public.reviews
    FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Customers can create reviews for own completed orders" ON public.reviews;
CREATE POLICY "Customers can create reviews for own completed orders" ON public.reviews
    FOR INSERT WITH CHECK (
        auth.uid() = customer_id 
        AND EXISTS (
            SELECT 1 FROM public.orders 
            WHERE orders.id = reviews.order_id 
            AND orders.customer_id = auth.uid() 
            AND orders.status_pekerjaan = 'selesai'
        )
    );


-- ==============================================================================
-- 12. SEED DATA AWAL (DATA MASTER & CONTOH DATA SIAP UJI)
-- ==============================================================================

-- Seed 4 Kategori Layanan Resik.in
INSERT INTO public.services (nama_layanan, kategori, deskripsi, durasi_estimasi, tarif_dasar, icon_name, is_active)
VALUES
(
    'Pembersihan Rumah',
    'rumah',
    'Layanan pembersihan menyeluruh untuk hunian rumah tinggal keluarga, meliputi ruang tamu, kamar tidur, dapur, dan area santai.',
    '2 - 3 Jam',
    120000.00,
    'home',
    TRUE
),
(
    'Pembersihan Kos',
    'kos',
    'Layanan pembersihan praktis dan higienis khusus kamar kos atau studio apartment, mencakup kamar mandi dalam, debu furnitur, dan lantai.',
    '1 - 2 Jam',
    75000.00,
    'bed',
    TRUE
),
(
    'Pembersihan Kantor',
    'kantor',
    'Pembersihan profesional untuk lingkungan kerja ruko atau ruang kantor UMKM, menjaga meja kerja, ruang meeting, dan lobi tetap rapi dan bersih.',
    '3 - 4 Jam',
    200000.00,
    'briefcase',
    TRUE
),
(
    'Pembersihan Pasca Renovasi',
    'pasca_renovasi',
    'Pembersihan intensif untuk menghilangkan debu konstruksi pekat, sisa semen pada lantai, noda cat pada kaca jendela, dan serpihan material.',
    '4 - 6 Jam',
    350000.00,
    'tool',
    TRUE
)
ON CONFLICT (kategori) DO UPDATE 
SET nama_layanan = EXCLUDED.nama_layanan,
    deskripsi = EXCLUDED.deskripsi,
    durasi_estimasi = EXCLUDED.durasi_estimasi,
    tarif_dasar = EXCLUDED.tarif_dasar;

-- Seed 4 Profil Petugas Kebersihan Teladan (Untuk Demonstrasi Smart Matching)
INSERT INTO public.cleaners (nama, nomor_kontak, keahlian, pengalaman_tahun, rating_rata_rata, total_pekerjaan, status_operasional)
VALUES
(
    'Candra Pratama',
    '081234567801',
    ARRAY['pasca_renovasi', 'rumah', 'kantor'],
    4,
    4.9,
    127,
    'aktif'
),
(
    'Budi Santoso',
    '081234567802',
    ARRAY['kos', 'rumah'],
    3,
    4.8,
    94,
    'aktif'
),
(
    'Siti Aminah',
    '081234567803',
    ARRAY['rumah', 'kantor'],
    5,
    5.0,
    156,
    'aktif'
),
(
    'Ahmad Fauzi',
    '081234567804',
    ARRAY['kos', 'pasca_renovasi'],
    2,
    4.7,
    62,
    'aktif'
);
