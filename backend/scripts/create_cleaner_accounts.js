import { supabaseAdmin } from '../lib/supabase.js';

const DEFAULT_PASSWORD = 'PetugasResik123!';

async function setupCleanerAccounts() {
  console.log('--- Memulai Pembuatan Akun Petugas di Supabase Auth ---');

  // 1. Ambil seluruh data petugas dari tabel cleaners
  const { data: cleaners, error: clnErr } = await supabaseAdmin
    .from('cleaners')
    .select('*')
    .order('nama', { ascending: true });

  if (clnErr || !cleaners) {
    console.error('Gagal mengambil data cleaners:', clnErr);
    return;
  }

  console.log(`Ditemukan ${cleaners.length} petugas di tabel cleaners:`);

  // Ambil list user auth saat ini
  const { data: authData, error: authListErr } = await supabaseAdmin.auth.admin.listUsers();
  if (authListErr) {
    console.error('Gagal list auth users:', authListErr);
    return;
  }
  const existingUsers = authData.users || [];

  const results = [];

  for (const cleaner of cleaners) {
    // Tentukan email berdasarkan nama (lowercase tanpa spasi)
    const slugName = cleaner.nama.toLowerCase().replace(/[^a-z0-9]/g, '');
    const email = `${slugName}@resik.in`;

    let user = existingUsers.find(u => u.email?.toLowerCase() === email.toLowerCase());

    if (!user) {
      console.log(`Membuat akun baru untuk ${cleaner.nama} (${email})...`);
      const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
        email,
        password: DEFAULT_PASSWORD,
        email_confirm: true,
        user_metadata: {
          nama: cleaner.nama,
          full_name: cleaner.nama,
          role: 'cleaner',
          cleaner_id: cleaner.id,
          nomor_wa: cleaner.nomor_kontak
        }
      });

      if (createErr) {
        console.error(`Gagal membuat user ${email}:`, createErr.message);
        continue;
      }
      user = created.user;
      console.log(`✔ Berhasil membuat user: ${user.id}`);
    } else {
      console.log(`Akun ${email} sudah ada (${user.id}), memperbarui metadata & password...`);
      const { data: updated, error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(
        user.id,
        {
          password: DEFAULT_PASSWORD,
          user_metadata: {
            ...user.user_metadata,
            nama: cleaner.nama,
            full_name: cleaner.nama,
            role: 'cleaner',
            cleaner_id: cleaner.id,
            nomor_wa: cleaner.nomor_kontak
          }
        }
      );
      if (updateErr) {
        console.error(`Gagal update user ${email}:`, updateErr.message);
      } else {
        user = updated.user;
        console.log(`✔ Berhasil update user: ${user.id}`);
      }
    }

    // 2. Pastikan tabel profiles memiliki data role 'cleaner'
    const { error: profErr } = await supabaseAdmin
      .from('profiles')
      .upsert({
        id: user.id,
        nama: cleaner.nama,
        email: email,
        nomor_wa: cleaner.nomor_kontak,
        role: 'cleaner'
      });

    if (profErr) {
      console.warn(`Peringatan saat upsert profiles untuk ${cleaner.nama}:`, profErr.message);
    } else {
      console.log(`✔ Profiles updated untuk ${cleaner.nama}`);
    }

    // 3. Update tabel cleaners agar user_id mengarah ke user.id auth
    const { error: linkErr } = await supabaseAdmin
      .from('cleaners')
      .update({ user_id: user.id })
      .eq('id', cleaner.id);

    if (linkErr) {
      console.error(`Gagal menautkan user_id ke tabel cleaners:`, linkErr.message);
    } else {
      console.log(`✔ cleaners.user_id ditautkan ke ${user.id}`);
    }

    results.push({
      nama: cleaner.nama,
      email: email,
      password: DEFAULT_PASSWORD,
      cleaner_id: cleaner.id,
      user_id: user.id
    });
  }

  console.log('\n--- RINGKASAN AKUN PETUGAS BERHASIL DIBUAT ---');
  console.table(results.map(r => ({
    Nama: r.nama,
    Email: r.email,
    Password: r.password,
    Role: 'cleaner',
    CleanerId: r.cleaner_id
  })));
}

setupCleanerAccounts().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
