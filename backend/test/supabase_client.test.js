// backend/test/supabase_client.test.js
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { supabase, supabaseAdmin, isLiveSupabase } from '../lib/supabase.js';

describe('Supabase Client Dual-Mode Initialization', () => {
  it('harus menginisialisasi supabase anon client dan supabaseAdmin', () => {
    assert.ok(supabase, 'Anon client harus terdefinisi');
    assert.ok(supabaseAdmin, 'Admin client harus terdefinisi');
  });

  it('isLiveSupabase harus bernilai boolean yang konsisten dengan environment', () => {
    const isLive = isLiveSupabase();
    assert.strictEqual(typeof isLive, 'boolean');
    // Saat dijalankan lewat node --test / NODE_ENV=test, isLiveSupabase harus false
    assert.strictEqual(isLive, false);
  });
});
