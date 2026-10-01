// backend/lib/database.js
import { supabaseAdmin, inMemoryStore, isLiveSupabase, saveStateToDisk } from './supabase.js';

export const db = {
  // CLEANERS REPO
  async getCleaners() {
    if (isLiveSupabase()) {
      try {
        const { data, error } = await supabaseAdmin
          .from('cleaners')
          .select('*')
          .order('rating_rata_rata', { ascending: false });
        if (!error && data && data.length > 0) {
          return data;
        }
        if (error) {
          console.warn('[db.getCleaners] Supabase error:', error.message);
        }
      } catch (err) {
        console.warn('[db.getCleaners] Fallback ke in-memory:', err.message);
      }
    }
    return inMemoryStore.cleaners;
  },

  async getCleanerById(cleanerId) {
    if (!cleanerId) return null;
    if (isLiveSupabase()) {
      try {
        const { data, error } = await supabaseAdmin
          .from('cleaners')
          .select('*')
          .eq('id', cleanerId)
          .maybeSingle();
        if (!error && data) {
          return data;
        }
      } catch (err) {
        console.warn('[db.getCleanerById] Fallback ke in-memory:', err.message);
      }
    }
    return inMemoryStore.cleaners.find(c => c.id === cleanerId) || null;
  },

  async updateCleanerRating(cleanerId) {
    if (!cleanerId) return null;
    if (isLiveSupabase()) {
      try {
        const { data: reviews, error } = await supabaseAdmin
          .from('reviews')
          .select('rating')
          .eq('cleaner_id', cleanerId);
        if (!error && reviews) {
          const total = reviews.length;
          const sum = reviews.reduce((acc, r) => acc + Number(r.rating), 0);
          const avg = total > 0 ? Math.round((sum / total) * 10) / 10 : 0;

          const { data: updated, error: updateErr } = await supabaseAdmin
            .from('cleaners')
            .update({ rating_rata_rata: avg, total_ulasan: total })
            .eq('id', cleanerId)
            .select()
            .maybeSingle();
          if (!updateErr && updated) return updated;
        }
      } catch (err) {
        console.warn('[db.updateCleanerRating] Fallback ke in-memory:', err.message);
      }
    }

    // Fallback in-memory logic
    const reviews = (inMemoryStore.reviews || []).filter(r => r.cleaner_id === cleanerId);
    const cleaner = inMemoryStore.cleaners.find(c => c.id === cleanerId);
    if (!cleaner) return null;
    if (reviews.length === 0) {
      cleaner.total_ulasan = 0;
      return cleaner;
    }
    const sum = reviews.reduce((acc, curr) => acc + curr.rating, 0);
    cleaner.rating_rata_rata = Math.round((sum / reviews.length) * 10) / 10;
    cleaner.total_ulasan = reviews.length;
    saveStateToDisk();
    return cleaner;
  }
};
