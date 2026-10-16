import express from 'express';
import { midtransHelper } from '../lib/midtrans.js';
import { db } from '../lib/database.js';

const router = express.Router();

router.post('/midtrans', async (req, res) => {
  try {
    const {
      order_id,
      status_code,
      gross_amount,
      signature_key,
      transaction_status,
      payment_type,
      transaction_id,
      fraud_status,
      settlement_time
    } = req.body;

    if (!order_id) {
      return res.status(400).json({
        success: false,
        message: 'order_id wajib disertakan',
        error: 'MISSING_ORDER_ID'
      });
    }

    // Verifikasi Tanda Tangan SHA-512 jika signature_key disertakan atau jika bukan mock mode
    if (signature_key || !midtransHelper.isMockMode()) {
      const isValid = midtransHelper.verifySignature({
        orderId: order_id,
        statusCode: status_code,
        grossAmount: gross_amount,
        signatureKey: signature_key
      });
      if (!isValid) {
        return res.status(403).json({
          success: false,
          message: 'Tanda tangan transaksi tidak valid',
          error: 'INVALID_SIGNATURE'
        });
      }
    }

    const order = await db.getOrderById(order_id);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: `Pesanan ${order_id} tidak ditemukan`,
        error: 'ORDER_NOT_FOUND'
      });
    }

    // Idempotency: Jika sudah lunas, tanggapi 200 OK tanpa mengulang mutasi
    if (order.status_pembayaran === 'Sudah Bayar') {
      return res.status(200).json({
        success: true,
        message: 'Pesanan sudah berstatus Sudah Bayar',
        data: { status: 'already_paid' }
      });
    }

    if (transaction_status === 'settlement' || (transaction_status === 'capture' && fraud_status === 'accept')) {
      await db.updateOrderPaymentDetails(order_id, {
        status_pembayaran: 'Sudah Bayar',
        payment_method: payment_type || 'midtrans',
        payment_transaction_id: transaction_id || null,
        payment_timestamp: settlement_time || new Date().toISOString()
      });
    } else if (['cancel', 'deny', 'expire'].includes(transaction_status)) {
      await db.updateOrderPaymentDetails(order_id, {
        status_pembayaran: transaction_status === 'expire' ? 'Kedaluwarsa' : 'Gagal'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Notifikasi webhook Midtrans berhasil diproses'
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: err.message || 'Internal server error processing webhook',
      error: 'WEBHOOK_PROCESSING_FAILED'
    });
  }
});

export default router;
