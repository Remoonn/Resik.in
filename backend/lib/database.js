import crypto from 'crypto';
import { supabaseAdmin, inMemoryStore, isLiveSupabase, saveStateToDisk, getServices, ensureStorageBucket } from './supabase.js';
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
  },

  // QUALITY REPORTS REPO & STORAGE
  async saveQualityReport(reportPayload) {
    const submittedAt = reportPayload.submitted_at || reportPayload.waktu_submit || new Date().toISOString();
    const id = reportPayload.id || crypto.randomUUID();

    if (isLiveSupabase()) {
      try {
        const dbRow = {
          id,
          order_id: reportPayload.order_id,
          cleaner_id: sanitizeCleanerId(reportPayload.cleaner_id),
          checklist_area: reportPayload.checklist_area || [],
          foto_before_url: reportPayload.foto_before_url,
          foto_after_url: reportPayload.foto_after_url,
          catatan_petugas: reportPayload.catatan_petugas ? reportPayload.catatan_petugas.trim() : null,
          waktu_submit: submittedAt
        };
        const { data, error } = await supabaseAdmin
          .from('quality_reports')
          .upsert(dbRow, { onConflict: 'order_id' })
          .select()
          .maybeSingle();

        if (!error && data) {
          await this.updateOrderStatus(reportPayload.order_id, 'Selesai', {
            updated_by: reportPayload.cleaner_id,
            catatan: 'Laporan mutu pekerjaan berhasil diverifikasi dan diserahkan'
          });

          if (reportPayload.cleaner_id) {
            const { data: cleaner } = await supabaseAdmin
              .from('cleaners')
              .select('total_pekerjaan')
              .eq('id', reportPayload.cleaner_id)
              .maybeSingle();
            if (cleaner) {
              await supabaseAdmin
                .from('cleaners')
                .update({
                  status_operasional: 'aktif',
                  total_pekerjaan: (cleaner.total_pekerjaan || 0) + 1
                })
                .eq('id', reportPayload.cleaner_id);
            }
          }

          return {
            ...data,
            order_id: data.order_id,
            cleaner_id: data.cleaner_id,
            checklist_area: data.checklist_area,
            foto_before_url: data.foto_before_url,
            foto_after_url: data.foto_after_url,
            catatan_petugas: data.catatan_petugas,
            started_at: reportPayload.started_at,
            completed_at: reportPayload.completed_at,
            submitted_at: data.waktu_submit
          };
        }
      } catch (err) {
        console.warn('[db.saveQualityReport] Fallback ke in-memory:', err.message);
      }
    }

    // In-memory fallback
    const fullReport = {
      id,
      order_id: reportPayload.order_id,
      cleaner_id: reportPayload.cleaner_id,
      checklist_area: reportPayload.checklist_area || [],
      foto_before_url: reportPayload.foto_before_url,
      foto_after_url: reportPayload.foto_after_url,
      catatan_petugas: reportPayload.catatan_petugas ? reportPayload.catatan_petugas.trim() : null,
      started_at: reportPayload.started_at,
      completed_at: reportPayload.completed_at,
      submitted_at: submittedAt
    };

    if (!inMemoryStore.quality_reports) {
      inMemoryStore.quality_reports = [];
    }
    const existingIndex = inMemoryStore.quality_reports.findIndex(r => r.order_id === reportPayload.order_id);
    if (existingIndex >= 0) {
      inMemoryStore.quality_reports[existingIndex] = fullReport;
    } else {
      inMemoryStore.quality_reports.push(fullReport);
    }

    const order = inMemoryStore.orders.find(o => o.id === reportPayload.order_id);
    if (order) {
      order.status_pekerjaan = 'Selesai';
      inMemoryStore.status_logs.push({
        id: crypto.randomUUID(),
        order_id: order.id,
        status_sebelumnya: 'Sedang Dikerjakan',
        status_baru: 'Selesai',
        diubah_oleh: reportPayload.cleaner_id || 'cleaner',
        catatan: 'Laporan mutu pekerjaan berhasil diverifikasi dan diserahkan',
        created_at: submittedAt
      });
    }

    if (reportPayload.cleaner_id) {
      const cleaner = inMemoryStore.cleaners.find(c => c.id === reportPayload.cleaner_id);
      if (cleaner) {
        cleaner.status_operasional = 'Aktif';
        cleaner.total_pekerjaan = (cleaner.total_pekerjaan || 0) + 1;
      }
    }

    saveStateToDisk();
    return fullReport;
  },

  async getQualityReportByOrderId(orderId) {
    if (!orderId) return null;
    if (isLiveSupabase()) {
      try {
        let { data, error } = await supabaseAdmin
          .from('quality_reports')
          .select('*')
          .eq('order_id', orderId)
          .maybeSingle();

        if (!data && !error) {
          const { data: order } = await supabaseAdmin
            .from('orders')
            .select('id')
            .eq('order_code', orderId)
            .maybeSingle();
          if (order) {
            const res = await supabaseAdmin
              .from('quality_reports')
              .select('*')
              .eq('order_id', order.id)
              .maybeSingle();
            data = res.data;
          }
        }

        if (data) {
          return {
            ...data,
            order_id: data.order_id,
            cleaner_id: data.cleaner_id,
            checklist_area: data.checklist_area,
            foto_before_url: data.foto_before_url,
            foto_after_url: data.foto_after_url,
            catatan_petugas: data.catatan_petugas,
            submitted_at: data.waktu_submit
          };
        }
      } catch (err) {
        console.warn('[db.getQualityReportByOrderId] Fallback ke in-memory:', err.message);
      }
    }

    const order = inMemoryStore.orders.find(o => o.id === orderId || o.order_code === orderId);
    const targetOrderId = order ? order.id : orderId;
    return (inMemoryStore.quality_reports || []).find(r => r.order_id === targetOrderId) || null;
  },

  async uploadQualityReportPhoto(orderId, type, buffer, mimeType = 'image/jpeg') {
    const storagePath = `orders/${orderId}/${type}.jpg`;
    if (isLiveSupabase()) {
      try {
        await ensureStorageBucket();
        const { error } = await supabaseAdmin.storage
          .from('quality-reports')
          .upload(storagePath, buffer, {
            contentType: mimeType,
            upsert: true
          });
        if (!error) return storagePath;
        console.warn('[db.uploadQualityReportPhoto] Supabase storage upload error:', error.message);
      } catch (err) {
        console.warn('[db.uploadQualityReportPhoto] Fallback ke in-memory:', err.message);
      }
    }

    if (!inMemoryStore.quality_report_photos) {
      inMemoryStore.quality_report_photos = {};
    }
    if (!inMemoryStore.quality_report_photos[orderId]) {
      inMemoryStore.quality_report_photos[orderId] = {};
    }
    inMemoryStore.quality_report_photos[orderId][type] = {
      contentType: mimeType,
      buffer
    };
    return storagePath;
  },

  async getQualityReportSignedUrl(storagePath) {
    if (!storagePath) return null;
    if (isLiveSupabase()) {
      try {
        const { data, error } = await supabaseAdmin.storage
          .from('quality-reports')
          .createSignedUrl(storagePath, 3600);
        if (!error && data && data.signedUrl) {
          return data.signedUrl;
        }
      } catch (err) {
        console.warn('[db.getQualityReportSignedUrl] Fallback URL:', err.message);
      }
    }

    const match = storagePath.match(/^orders\/([^\/]+)\/([^\.]+)/);
    if (match) {
      return `/api/quality-reports/${match[1]}/photo/${match[2]}`;
    }
    return `/api/quality-reports/photo?path=${encodeURIComponent(storagePath)}`;
  },

  // REVIEWS REPO
  async createReview(reviewPayload) {
    if (isLiveSupabase()) {
      try {
        const dbRow = {
          id: (reviewPayload.id && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(reviewPayload.id))
            ? reviewPayload.id
            : crypto.randomUUID(),
          order_id: reviewPayload.order_id,
          customer_id: sanitizeCustomerId(reviewPayload.customer_id),
          cleaner_id: sanitizeCleanerId(reviewPayload.cleaner_id),
          rating: Number(reviewPayload.rating),
          ulasan: reviewPayload.catatan_ulasan || reviewPayload.ulasan || null,
          created_at: reviewPayload.created_at || new Date().toISOString()
        };
        const { data, error } = await supabaseAdmin
          .from('reviews')
          .insert(dbRow)
          .select()
          .single();
        if (!error && data) {
          await this.updateCleanerRating(reviewPayload.cleaner_id);
          return {
            ...data,
            order_id: data.order_id,
            customer_id: data.customer_id,
            cleaner_id: data.cleaner_id,
            rating: data.rating,
            catatan_ulasan: data.ulasan,
            ulasan: data.ulasan,
            customer_nama: reviewPayload.customer_nama || 'Pelanggan Resik.in'
          };
        }
      } catch (err) {
        console.warn('[db.createReview] Fallback ke in-memory:', err.message);
      }
    }

    const fullReview = {
      id: reviewPayload.id || `rev-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      order_id: reviewPayload.order_id,
      customer_id: reviewPayload.customer_id,
      cleaner_id: reviewPayload.cleaner_id,
      customer_nama: reviewPayload.customer_nama || 'Pelanggan Resik.in',
      service_nama: reviewPayload.service_nama || null,
      rating: Number(reviewPayload.rating),
      catatan_ulasan: reviewPayload.catatan_ulasan || reviewPayload.ulasan || '',
      ulasan: reviewPayload.catatan_ulasan || reviewPayload.ulasan || '',
      created_at: reviewPayload.created_at || new Date().toISOString()
    };
    if (!inMemoryStore.reviews) {
      inMemoryStore.reviews = [];
    }
    inMemoryStore.reviews.push(fullReview);
    await this.updateCleanerRating(reviewPayload.cleaner_id);
    saveStateToDisk();
    return fullReview;
  },

  async getReviewByOrderId(orderId) {
    if (!orderId) return null;
    if (isLiveSupabase()) {
      try {
        const { data, error } = await supabaseAdmin
          .from('reviews')
          .select('*')
          .eq('order_id', orderId)
          .maybeSingle();
        if (!error && data) {
          return {
            ...data,
            catatan_ulasan: data.ulasan,
            ulasan: data.ulasan
          };
        }
      } catch (err) {
        console.warn('[db.getReviewByOrderId] Fallback ke in-memory:', err.message);
      }
    }
    return (inMemoryStore.reviews || []).find(r => r.order_id === orderId) || null;
  },

  async getReviewsByCleanerId(cleanerId) {
    if (!cleanerId) return [];
    if (isLiveSupabase()) {
      try {
        const sanitizedId = sanitizeCleanerId(cleanerId);
        if (sanitizedId) {
          const { data, error } = await supabaseAdmin
            .from('reviews')
            .select('*')
            .eq('cleaner_id', sanitizedId)
            .order('created_at', { ascending: false });
          if (!error && data) {
            return data.map(r => ({
              ...r,
              catatan_ulasan: r.ulasan,
              ulasan: r.ulasan
            }));
          }
        }
      } catch (err) {
        console.warn('[db.getReviewsByCleanerId] Fallback ke in-memory:', err.message);
      }
    }
    return (inMemoryStore.reviews || []).filter(r => r.cleaner_id === cleanerId);
  }
};
