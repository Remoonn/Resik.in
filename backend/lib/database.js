// backend/lib/database.js
import crypto from 'crypto';
import { supabaseAdmin, inMemoryStore, isLiveSupabase, saveStateToDisk, getServices } from './supabase.js';
import {
  orderToDb,
  orderToApi,
  toDbJobStatus,
  toDbPaymentStatus,
  sanitizeCustomerId,
  sanitizeCleanerId
} from './mapper.js';

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
  },

  // ORDERS REPO
  async createOrder(orderPayload) {
    const id = (orderPayload.id && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(orderPayload.id))
      ? orderPayload.id
      : crypto.randomUUID();
    const cleanDate = (orderPayload.tanggal_layanan || new Date().toISOString().split('T')[0]).replace(/-/g, '');
    const order_code = orderPayload.order_code || `RSK-${cleanDate}-${Math.floor(100 + Math.random() * 900)}`;

    const fullOrder = {
      ...orderPayload,
      id,
      order_code,
      customer_id: orderPayload.customer_id || 'usr-customer-001',
      status_pembayaran: orderPayload.status_pembayaran || 'Belum Bayar',
      status_pekerjaan: orderPayload.status_pekerjaan || 'Menunggu Konfirmasi',
      created_at: orderPayload.created_at || new Date().toISOString()
    };

    if (isLiveSupabase()) {
      try {
        const dbRow = orderToDb(fullOrder);
        dbRow.id = id;
        const { data, error } = await supabaseAdmin
          .from('orders')
          .insert(dbRow)
          .select()
          .single();
        if (!error && data) {
          // Log initial status
          await supabaseAdmin.from('status_logs').insert({
            order_id: data.id,
            status_sebelumnya: null,
            status_baru: data.status_pekerjaan,
            diubah_oleh: sanitizeCustomerId(fullOrder.customer_id),
            catatan: 'Pesanan baru dibuat, menunggu pembayaran pelanggan'
          });
          return orderToApi(data);
        }
        if (error) {
          console.warn('[db.createOrder] Supabase insert error:', error.message);
        }
      } catch (err) {
        console.warn('[db.createOrder] Fallback ke in-memory:', err.message);
      }
    }

    // In-memory fallback
    inMemoryStore.orders.push(fullOrder);
    inMemoryStore.status_logs.push({
      id: crypto.randomUUID(),
      order_id: fullOrder.id,
      status_sebelumnya: null,
      status_baru: 'Menunggu Konfirmasi',
      diubah_oleh: fullOrder.customer_id,
      catatan: 'Pesanan baru dibuat, menunggu pembayaran pelanggan',
      created_at: fullOrder.created_at
    });
    saveStateToDisk();
    return fullOrder;
  },

  async getOrderById(orderId) {
    if (!orderId) return null;
    if (isLiveSupabase()) {
      try {
        const { data: order, error } = await supabaseAdmin
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .maybeSingle();
        if (!error && order) {
          // Fetch service & cleaner & status_logs
          const { data: service } = order.service_id
            ? await supabaseAdmin.from('services').select('*').eq('id', order.service_id).maybeSingle()
            : { data: null };
          const { data: cleaner } = order.cleaner_id
            ? await supabaseAdmin.from('cleaners').select('*').eq('id', order.cleaner_id).maybeSingle()
            : { data: null };
          const { data: logs } = await supabaseAdmin
            .from('status_logs')
            .select('*')
            .eq('order_id', orderId)
            .order('created_at', { ascending: true });

          const apiOrder = orderToApi(order, service, cleaner);
          apiOrder.status_logs = logs || [];
          return apiOrder;
        }
      } catch (err) {
        console.warn('[db.getOrderById] Fallback ke in-memory:', err.message);
      }
    }

    const order = inMemoryStore.orders.find(o => o.id === orderId);
    if (!order) return null;

    const { data: services } = await getServices(true);
    const service = (services || []).find(s => s.id === order.service_id) || null;
    const cleaner = order.cleaner_id ? inMemoryStore.cleaners.find(c => c.id === order.cleaner_id) || null : null;
    const logs = inMemoryStore.status_logs.filter(l => l.order_id === order.id);

    return {
      ...order,
      service: service ? {
        id: service.id,
        nama_layanan: service.nama_layanan,
        kategori: service.kategori,
        durasi_estimasi: service.durasi_estimasi
      } : null,
      cleaner: cleaner ? {
        id: cleaner.id,
        nama: cleaner.nama,
        nomor_kontak: cleaner.nomor_kontak,
        foto_url: cleaner.foto_url,
        rating_rata_rata: cleaner.rating_rata_rata,
        total_pekerjaan: cleaner.total_pekerjaan
      } : null,
      status_logs: logs
    };
  },

  async getOrders(filters = {}) {
    if (isLiveSupabase()) {
      try {
        let query = supabaseAdmin.from('orders').select('*').order('created_at', { ascending: false });
        if (filters.customer_id) {
          const sanitizedCustId = sanitizeCustomerId(filters.customer_id);
          if (sanitizedCustId) query = query.eq('customer_id', sanitizedCustId);
        }
        if (filters.cleaner_id) {
          const sanitizedClnId = sanitizeCleanerId(filters.cleaner_id);
          if (sanitizedClnId) query = query.eq('cleaner_id', sanitizedClnId);
        }
        const { data, error } = await query;
        if (!error && data) {
          const { data: services } = await getServices(true);
          return data.map(dbRow => {
            const service = (services || []).find(s => s.id === dbRow.service_id);
            return orderToApi(dbRow, service ? {
              id: service.id,
              nama_layanan: service.nama_layanan,
              kategori: service.kategori
            } : null);
          });
        }
      } catch (err) {
        console.warn('[db.getOrders] Fallback ke in-memory:', err.message);
      }
    }

    const { data: services } = await getServices(true);
    let orders = inMemoryStore.orders;
    if (filters.customer_id) {
      orders = orders.filter(o => o.customer_id === filters.customer_id);
    }
    if (filters.cleaner_id) {
      orders = orders.filter(o => o.cleaner_id === filters.cleaner_id);
    }
    return orders.map(order => {
      const service = (services || []).find(s => s.id === order.service_id);
      return {
        ...order,
        service: service ? {
          id: service.id,
          nama_layanan: service.nama_layanan,
          kategori: service.kategori
        } : null
      };
    });
  },

  async updateOrderStatus(orderId, nextStatus, metadata = {}) {
    const dbStatus = toDbJobStatus(nextStatus);
    const now = new Date().toISOString();
    const updatePayload = {
      status_pekerjaan: dbStatus,
      updated_at: now
    };
    if (nextStatus === 'Sedang Dikerjakan') {
      updatePayload.started_at = now;
    }

    if (isLiveSupabase()) {
      try {
        const { data: updated, error } = await supabaseAdmin
          .from('orders')
          .update(updatePayload)
          .eq('id', orderId)
          .select()
          .maybeSingle();
        if (!error && updated) {
          await supabaseAdmin.from('status_logs').insert({
            order_id: orderId,
            status_sebelumnya: metadata.prevStatus ? toDbJobStatus(metadata.prevStatus) : null,
            status_baru: dbStatus,
            diubah_oleh: sanitizeCustomerId(metadata.updated_by),
            catatan: metadata.catatan || `Status pekerjaan diperbarui menjadi ${nextStatus}`
          });
          return orderToApi(updated);
        }
      } catch (err) {
        console.warn('[db.updateOrderStatus] Fallback ke in-memory:', err.message);
      }
    }

    const order = inMemoryStore.orders.find(o => o.id === orderId);
    if (!order) return null;
    const prevStatus = order.status_pekerjaan;
    order.status_pekerjaan = nextStatus;
    if (nextStatus === 'Sedang Dikerjakan') {
      order.started_at = now;
    }
    inMemoryStore.status_logs.push({
      id: crypto.randomUUID(),
      order_id: order.id,
      status_sebelumnya: prevStatus,
      status_baru: nextStatus,
      diubah_oleh: metadata.updated_by || 'admin',
      catatan: metadata.catatan || `Status pekerjaan diperbarui menjadi ${nextStatus}`,
      created_at: now
    });
    saveStateToDisk();
    return order;
  },

  async assignCleaner(orderId, cleanerId, auditData = {}) {
    const now = new Date().toISOString();
    const isReassign = auditData.isReassign || false;
    const newStatus = 'Petugas Ditugaskan';

    if (isLiveSupabase()) {
      try {
        const { data: updated, error } = await supabaseAdmin
          .from('orders')
          .update({
            cleaner_id: sanitizeCleanerId(cleanerId),
            status_pekerjaan: toDbJobStatus(newStatus),
            updated_at: now
          })
          .eq('id', orderId)
          .select()
          .maybeSingle();
        if (!error && updated) {
          await supabaseAdmin.from('status_logs').insert({
            order_id: orderId,
            status_sebelumnya: isReassign ? toDbJobStatus('Petugas Ditugaskan') : toDbJobStatus('Dikonfirmasi'),
            status_baru: toDbJobStatus(newStatus),
            diubah_oleh: sanitizeCustomerId(auditData.assigned_by),
            catatan: auditData.catatan || (isReassign
              ? `REASSIGN_CLEANER: ke ${cleanerId} - Alasan: ${auditData.alasan || '-'}`
              : `Petugas ${cleanerId} berhasil ditugaskan`)
          });
          return orderToApi(updated);
        }
      } catch (err) {
        console.warn('[db.assignCleaner] Fallback ke in-memory:', err.message);
      }
    }

    const order = inMemoryStore.orders.find(o => o.id === orderId);
    if (!order) return null;
    const prevStatus = order.status_pekerjaan;
    order.cleaner_id = cleanerId;
    order.status_pekerjaan = newStatus;

    inMemoryStore.status_logs.push({
      id: crypto.randomUUID(),
      order_id: order.id,
      status_sebelumnya: prevStatus,
      status_baru: newStatus,
      diubah_oleh: auditData.assigned_by || 'admin',
      catatan: auditData.catatan || (isReassign
        ? `REASSIGN_CLEANER: dari ${auditData.oldCleanerId || '-'} ke ${cleanerId} - Alasan: ${auditData.alasan || '-'}`
        : `Petugas (${cleanerId}) berhasil ditugaskan`),
      created_at: now
    });
    saveStateToDisk();
    return order;
  },

  async cancelOrder(orderId, cancelData = {}) {
    const now = new Date().toISOString();
    const cancellationReason = (cancelData.cancellation_reason || '').trim();
    const cancelledBy = cancelData.cancelled_by || 'customer';

    if (isLiveSupabase()) {
      try {
        const { data: updated, error } = await supabaseAdmin
          .from('orders')
          .update({
            status_pekerjaan: toDbJobStatus('Dibatalkan'),
            cancellation_reason: cancellationReason,
            cancelled_by: sanitizeCustomerId(cancelledBy),
            cancelled_at: now,
            updated_at: now
          })
          .eq('id', orderId)
          .select()
          .maybeSingle();
        if (!error && updated) {
          await supabaseAdmin.from('status_logs').insert({
            order_id: orderId,
            status_sebelumnya: cancelData.prevStatus ? toDbJobStatus(cancelData.prevStatus) : null,
            status_baru: toDbJobStatus('Dibatalkan'),
            diubah_oleh: sanitizeCustomerId(cancelledBy),
            catatan: `Pesanan dibatalkan oleh ${cancelledBy}. Alasan: ${cancellationReason}`
          });
          return orderToApi(updated);
        }
      } catch (err) {
        console.warn('[db.cancelOrder] Fallback ke in-memory:', err.message);
      }
    }

    const order = inMemoryStore.orders.find(o => o.id === orderId);
    if (!order) return null;
    const prevStatus = order.status_pekerjaan;
    order.status_pekerjaan = 'Dibatalkan';
    order.cancellation_reason = cancellationReason;
    order.cancelled_by = cancelledBy;
    order.cancelled_at = now;

    inMemoryStore.status_logs.push({
      id: crypto.randomUUID(),
      order_id: order.id,
      status_sebelumnya: prevStatus,
      status_baru: 'Dibatalkan',
      diubah_oleh: cancelledBy,
      catatan: `Pesanan dibatalkan oleh ${cancelledBy}. Alasan: ${cancellationReason}`,
      created_at: now
    });
    saveStateToDisk();
    return order;
  },

  async updateOrderPayment(orderId, paymentData = {}) {
    const now = paymentData.payment_timestamp || new Date().toISOString();

    if (isLiveSupabase()) {
      try {
        const { data: updated, error } = await supabaseAdmin
          .from('orders')
          .update({
            status_pembayaran: toDbPaymentStatus('Sudah Bayar'),
            payment_timestamp: now,
            updated_at: now
          })
          .eq('id', orderId)
          .select()
          .maybeSingle();
        if (!error && updated) {
          await supabaseAdmin.from('status_logs').insert({
            order_id: orderId,
            status_sebelumnya: toDbJobStatus('Menunggu Konfirmasi'),
            status_baru: toDbJobStatus('Menunggu Konfirmasi'),
            diubah_oleh: sanitizeCustomerId(paymentData.customer_id),
            catatan: 'Simulasi pembayaran diverifikasi server: status pembayaran berubah menjadi Sudah Bayar'
          });
          return orderToApi(updated);
        }
      } catch (err) {
        console.warn('[db.updateOrderPayment] Fallback ke in-memory:', err.message);
      }
    }

    const order = inMemoryStore.orders.find(o => o.id === orderId);
    if (!order) return null;
    order.status_pembayaran = 'Sudah Bayar';
    order.payment_timestamp = now;

    inMemoryStore.status_logs.push({
      id: crypto.randomUUID(),
      order_id: order.id,
      status_sebelumnya: 'Menunggu Konfirmasi',
      status_baru: 'Menunggu Konfirmasi',
      diubah_oleh: order.customer_id,
      catatan: 'Simulasi pembayaran diverifikasi server: status pembayaran berubah menjadi Sudah Bayar',
      created_at: now
    });
    saveStateToDisk();
    return order;
  }
};
