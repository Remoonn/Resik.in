import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/screens/order_tracking_screen.dart';

void main() {
  group('OrderTrackingScreen Persistent Receipt Tests', () {
    final paidOrder = OrderModel(
      id: 'ord-paid-001',
      orderCode: 'RSK-20261016-001',
      serviceId: 'srv-001',
      serviceName: 'Pembersihan Rumah Mendalam',
      tanggalLayanan: '2026-10-17',
      startTime: '10:00',
      endTime: '12:00',
      duration: 2,
      alamatLengkap: 'Jl. Kaliurang KM 9.3 No. 12',
      patokanLokasi: 'Pagar hijau',
      luasArea: 'Tipe 36',
      hargaSaatBooking: 125000.0,
      totalBiaya: 125000.0,
      statusPembayaran: 'Sudah Bayar',
      statusPekerjaan: 'Dikonfirmasi',
      paymentMethod: 'gopay',
      paymentTransactionId: 'midtrans-txn-998877',
      paymentTimestamp: '2026-10-17T10:15:00Z',
    );

    final unpaidOrder = OrderModel(
      id: 'ord-unpaid-002',
      orderCode: 'RSK-20261016-002',
      serviceId: 'srv-001',
      serviceName: 'Pembersihan Rumah Mendalam',
      tanggalLayanan: '2026-10-17',
      startTime: '10:00',
      endTime: '12:00',
      duration: 2,
      alamatLengkap: 'Jl. Kaliurang KM 9.3 No. 12',
      patokanLokasi: 'Pagar hijau',
      luasArea: 'Tipe 36',
      hargaSaatBooking: 125000.0,
      totalBiaya: 125000.0,
      statusPembayaran: 'Belum Bayar',
      statusPekerjaan: 'Menunggu Konfirmasi',
    );

    testWidgets('1. Tombol "Lihat Kuitansi Pembayaran" tampil saat statusPembayaran == "Sudah Bayar"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: paidOrder.id,
            initialOrder: paidOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lihat Kuitansi Pembayaran'), findsOneWidget);
      expect(find.text('Pembayaran Lunas'), findsOneWidget);
    });

    testWidgets('2. Mengetuk tombol membuka bottom sheet kuitansi digital dengan rincian transaksi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: paidOrder.id,
            initialOrder: paidOrder,
          ),
        ),
      );
      await tester.pump();

      final receiptBtn = find.text('Lihat Kuitansi Pembayaran');
      expect(receiptBtn, findsOneWidget);

      await tester.tap(receiptBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Kuitansi Pembayaran Digital'), findsOneWidget);
      expect(find.textContaining('RSK-20261016-001'), findsWidgets);
      expect(find.text('GOPAY'), findsOneWidget);
      expect(find.text('midtrans-txn-998877'), findsOneWidget);
    });

    testWidgets('3. Tombol "Lihat Kuitansi Pembayaran" TIDAK tampil saat statusPembayaran == "Belum Bayar"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            orderId: unpaidOrder.id,
            initialOrder: unpaidOrder,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lihat Kuitansi Pembayaran'), findsNothing);
      expect(find.text('Pembayaran Lunas'), findsNothing);
    });
  });
}
