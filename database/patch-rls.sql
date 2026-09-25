-- ==============================================================================
-- PATCH RLS POLICIES - RESIK.IN (IZINKAN AKSES BACKEND SERVER)
-- Jalankan skrip ini di SQL Editor Supabase jika ingin mengizinkan backend Express
-- melakukan INSERT & UPDATE pesanan dan master petugas secara langsung.
-- ==============================================================================

-- 1. Izinkan pembuatan pesanan baru (INSERT) dan pembaruan status (UPDATE)
DROP POLICY IF EXISTS "Customers can create orders" ON public.orders;
DROP POLICY IF EXISTS "Enable insert for orders" ON public.orders;
CREATE POLICY "Enable insert for orders" ON public.orders
    FOR INSERT WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Enable update for orders" ON public.orders;
CREATE POLICY "Enable update for orders" ON public.orders
    FOR UPDATE USING (TRUE);

-- 2. Izinkan penambahan dan pembaruan data master petugas (cleaners)
DROP POLICY IF EXISTS "Enable all for cleaners" ON public.cleaners;
CREATE POLICY "Enable all for cleaners" ON public.cleaners
    FOR ALL USING (TRUE);

-- 3. Izinkan pencatatan audit log perubahan status (status_logs)
DROP POLICY IF EXISTS "Enable all for status_logs" ON public.status_logs;
CREATE POLICY "Enable all for status_logs" ON public.status_logs
    FOR ALL USING (TRUE);
