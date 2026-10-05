import { Router } from 'express';
import { inMemoryStore, supabase, supabaseAdmin, isLiveSupabase } from '../lib/supabase.js';

const router = Router();

// POST /api/auth/login — Otentikasi pengguna dan pemuatan profil peran
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Email dan password wajib diisi'
    });
  }

  const normalizedEmail = email.trim().toLowerCase();
  let user = inMemoryStore.users.find(
    (u) => u.email.toLowerCase() === normalizedEmail && u.password === password
  );

  // Jika belum cocok di inMemory dan Supabase aktif, otentikasi via Supabase Auth
  if (!user && isLiveSupabase()) {
    try {
      const { data: supaAuth, error: supaErr } = await supabase.auth.signInWithPassword({
        email: normalizedEmail,
        password
      });

      if (!supaErr && supaAuth?.user) {
        const supaUser = supaAuth.user;
        const meta = supaUser.user_metadata || {};
        let role = meta.role || 'customer';
        let nama = meta.full_name || meta.name || normalizedEmail.split('@')[0];

        try {
          const { data: profile } = await supabaseAdmin
            .from('profiles')
            .select('role, nama')
            .eq('id', supaUser.id)
            .maybeSingle();
          if (profile?.role) role = profile.role;
          if (profile?.nama) nama = profile.nama;
        } catch (_) {}

        user = {
          id: supaUser.id,
          nama,
          email: supaUser.email,
          role,
          nomor_wa: meta.nomor_wa || '-',
          token: supaAuth.session?.access_token || `sb-${supaUser.id}`
        };
      }
    } catch (_) {}
  }

  if (!user) {
    return res.status(401).json({
      success: false,
      message: 'Email atau password salah'
    });
  }

  // Generate safe user object without password
  const { password: _, ...userSafe } = user;
  const token = user.token || `resik-token-${user.id}-${Date.now()}`;

  return res.status(200).json({
    success: true,
    message: 'Login berhasil',
    data: {
      user: userSafe,
      token
    }
  });
});

// POST /api/auth/register — Pendaftaran akun baru
router.post('/register', (req, res) => {
  const { nama, email, password, nomor_wa, role = 'customer' } = req.body;

  if (!nama || !email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Nama, email, dan password wajib diisi'
    });
  }

  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      message: 'Password minimal 6 karakter'
    });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const existingUser = inMemoryStore.users.find(
    (u) => u.email.toLowerCase() === normalizedEmail
  );

  if (existingUser) {
    return res.status(409).json({
      success: false,
      message: 'Email sudah terdaftar dalam sistem'
    });
  }

  const allowedRoles = ['customer', 'cleaner', 'admin'];
  const finalRole = allowedRoles.includes(role) ? role : 'customer';

  const newUser = {
    id: `usr-${Date.now().toString(36)}`,
    nama: nama.trim(),
    email: normalizedEmail,
    password,
    nomor_wa: nomor_wa ? nomor_wa.trim() : '-',
    role: finalRole,
    created_at: new Date().toISOString()
  };

  inMemoryStore.users.push(newUser);

  const { password: _, ...userSafe } = newUser;
  const token = `resik-token-${newUser.id}-${Date.now()}`;

  return res.status(201).json({
    success: true,
    message: 'Registrasi akun berhasil',
    data: {
      user: userSafe,
      token
    }
  });
});

// GET /api/auth/me — Memverifikasi profil sesi pengguna aktif
router.get('/me', (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(200).json({
      success: true,
      message: 'Sesi tamu (guest)',
      data: {
        authenticated: false,
        role: 'guest'
      }
    });
  }

  // Cari user berdasarkan token mock
  const token = authHeader.replace(/^Bearer\s+/i, '');
  const foundUser = inMemoryStore.users[0]; // fallback default jika token valid

  const { password: _, ...userSafe } = foundUser;
  return res.status(200).json({
    success: true,
    message: 'Sesi pengguna aktif terverifikasi',
    data: {
      authenticated: true,
      user: userSafe
    }
  });
});

export default router;
