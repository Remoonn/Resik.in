import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';
import 'package:resik_in_mobile/screens/payment_screen.dart';

void main() {
  final dummyOrder = OrderModel(
    id: 'ord-123',
    orderCode: 'RSK-20260930-001',
    serviceId: 'srv-001-rumah',
    serviceName: 'Pembersihan Rumah',
    tanggalLayanan: '2026-09-30',
    startTime: '09:00',
    endTime: '11:00',
    duration: 2,
    alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 20, Sleman, Yogyakarta',
    patokanLokasi: 'Depan Warung Madura cat biru',
    luasArea: 'Tipe 36',
    catatanKhusus: 'Pembersihan debu plafon',
    hargaSaatBooking: 120000.0,
    totalBiaya: 120000.0,
    statusPembayaran: 'Belum Bayar',
    paymentTimestamp: null,
    statusPekerjaan: 'Menunggu Konfirmasi',
  );

  testWidgets('1. PaymentScreen menampilkan ringkasan pesanan dan status Belum Bayar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(order: dummyOrder),
      ),
    );

    // Verifikasi Kode Pesanan & Badge Status
    expect(find.text('RSK-20260930-001'), findsOneWidget);
    expect(find.text('Belum Bayar'), findsOneWidget);

    // Verifikasi Rincian Biaya & Layanan
    expect(find.text('Pembersihan Rumah'), findsOneWidget);
    expect(find.textContaining('120.000'), findsWidgets);

    // Verifikasi Tombol Simulasi Pembayaran
    final payBtn = find.byKey(const Key('btn_simulasi_bayar'));
    expect(payBtn, findsOneWidget);
    expect(find.text('Bayar Sekarang (Simulasi)'), findsOneWidget);
  });
}
