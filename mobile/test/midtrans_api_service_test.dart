import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';

void main() {
  test('OrderModel memparsing metadata pembayaran Midtrans dengan benar', () {
    final json = {
      'id': 'ord-test-01',
      'order_code': 'RSK-20261025-001',
      'service_id': 'srv-001',
      'service_name': 'Pembersihan Rumah',
      'tanggal_layanan': '2026-10-25',
      'start_time': '09:00',
      'duration': 2,
      'alamat_lengkap': 'Jl. Colombo No. 1',
      'patokan_lokasi': 'UNY',
      'total_biaya': 150000.0,
      'status_pembayaran': 'Sudah Bayar',
      'payment_method': 'qris',
      'payment_transaction_id': 'midtrans-txn-999',
      'snap_token': 'snap-token-123',
      'snap_redirect_url': 'https://app.sandbox.midtrans.com/snap/v2/vtweb/snap-token-123',
      'status_pekerjaan': 'Menunggu Konfirmasi'
    };

    final order = OrderModel.fromJson(json);
    expect(order.paymentMethod, 'qris');
    expect(order.paymentTransactionId, 'midtrans-txn-999');
    expect(order.snapToken, 'snap-token-123');
    expect(order.snapRedirectUrl, contains('snap-token-123'));
  });
}
