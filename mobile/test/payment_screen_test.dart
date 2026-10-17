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

  testWidgets('1. PaymentScreen menampilkan ringkasan pesanan, badge kanal pembayaran, dan tombol Pilih Metode Pembayaran', (WidgetTester tester) async {
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

    // Verifikasi Badge Kanal Pembayaran Midtrans
    expect(find.text('QRIS'), findsOneWidget);
    expect(find.text('Virtual Account'), findsOneWidget);

    // Verifikasi Tombol Pembayaran Midtrans Snap
    expect(find.text('Pilih Metode Pembayaran'), findsOneWidget);
  });

  testWidgets('2. Mengetuk chip metode pembayaran mengubah metode yang dipilih dan teks tombol', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(order: dummyOrder),
      ),
    );

    // Default: tombol menampilkan 'Pilih Metode Pembayaran'
    expect(find.text('Pilih Metode Pembayaran'), findsOneWidget);

    // Ketuk chip QRIS
    await tester.tap(find.text('QRIS'));
    await tester.pump();
    expect(find.text('Bayar via QRIS'), findsOneWidget);

    // Ketuk chip GoPay
    await tester.tap(find.text('GoPay'));
    await tester.pump();
    expect(find.text('Bayar via GoPay'), findsOneWidget);

    // Ketuk chip Virtual Account
    await tester.tap(find.text('Virtual Account'));
    await tester.pump();
    expect(find.text('Bayar via Virtual Account'), findsOneWidget);
  });
}
