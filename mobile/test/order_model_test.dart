import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/order_model.dart';

void main() {
  group('OrderModel Serialization Tests', () {
    test('1. fromJson harus mem-parsing response API dengan benar', () {
      final json = {
        'id': 'ord-123',
        'order_code': 'RSK-20260930-001',
        'service_id': 'srv-001',
        'tanggal_layanan': '2026-09-30',
        'start_time': '09:00',
        'end_time': '11:00',
        'duration': 2,
        'alamat_lengkap': 'Jl. Kaliurang KM 14.5 No. 20, Sleman',
        'patokan_lokasi': 'Depan Warung Madura cat biru',
        'luas_area': 'Tipe 36',
        'catatan_khusus': 'Plafon ruang tamu banyak debu',
        'harga_saat_booking': 120000.0,
        'total_biaya': 120000.0,
        'status_pembayaran': 'Belum Bayar',
        'payment_timestamp': null,
        'status_pekerjaan': 'Menunggu Konfirmasi',
        'service': {
          'id': 'srv-001',
          'nama_layanan': 'Pembersihan Rumah',
          'kategori': 'rumah'
        }
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, 'ord-123');
      expect(order.orderCode, 'RSK-20260930-001');
      expect(order.serviceName, 'Pembersihan Rumah');
      expect(order.hargaSaatBooking, 120000.0);
      expect(order.totalBiaya, 120000.0);
      expect(order.statusPembayaran, 'Belum Bayar');
      expect(order.statusPekerjaan, 'Menunggu Konfirmasi');
      expect(order.endTime, '11:00');
    });

    test('2. toJson harus menghasilkan payload yang valid untuk API backend', () {
      final order = OrderModel(
        id: '',
        orderCode: '',
        serviceId: 'srv-001',
        tanggalLayanan: '2026-09-30',
        startTime: '09:00',
        duration: 2,
        alamatLengkap: 'Jl. Kaliurang KM 14.5 No. 20, Sleman',
        patokanLokasi: 'Depan Warung Madura cat biru',
        luasArea: 'Tipe 36',
        catatanKhusus: 'Catatan tambahan',
        hargaSaatBooking: 120000.0,
        totalBiaya: 120000.0,
        statusPembayaran: 'Belum Bayar',
        statusPekerjaan: 'Menunggu Konfirmasi',
      );

      final payload = order.toBookingPayload();

      expect(payload['service_id'], 'srv-001');
      expect(payload['tanggal_layanan'], '2026-09-30');
      expect(payload['start_time'], '09:00');
      expect(payload['duration'], 2);
      expect(payload['alamat_lengkap'], 'Jl. Kaliurang KM 14.5 No. 20, Sleman');
      expect(payload['patokan_lokasi'], 'Depan Warung Madura cat biru');
      expect(payload['luas_area'], 'Tipe 36');
      expect(payload.containsKey('status_pembayaran'), false, reason: 'Klien dilarang menyertakan status_pembayaran');
    });

    test('3. fromJson harus mem-parsing cleaner tersemat dan data lifecycle pembatalan', () {
      final json = {
        'id': 'ord-456',
        'order_code': 'RSK-20260930-002',
        'service_id': 'srv-001',
        'tanggal_layanan': '2026-09-30',
        'start_time': '13:00',
        'end_time': '15:00',
        'duration': 2,
        'alamat_lengkap': 'Kost Putri Melati No 12, Sleman',
        'patokan_lokasi': 'Pagar hitam samping minimarket',
        'luas_area': 'Kos Standar',
        'harga_saat_booking': 100000.0,
        'total_biaya': 100000.0,
        'status_pembayaran': 'Sudah Bayar',
        'status_pekerjaan': 'Sedang Dikerjakan',
        'started_at': '2026-09-30T13:05:00.000Z',
        'cleaner_id': 'cleaner-01',
        'cleaner': {
          'id': 'cleaner-01',
          'nama': 'Siti Rahmawati',
          'nomor_telepon': '081234567890',
          'rating_rata_rata': 4.9,
          'total_pekerjaan_selesai': 42,
          'status_ketersediaan': 'Bertugas'
        },
        'status_logs': [
          {'status': 'Menunggu Konfirmasi', 'timestamp': '2026-09-30T08:00:00Z'},
          {'status': 'Sedang Dikerjakan', 'timestamp': '2026-09-30T13:05:00Z'}
        ]
      };

      final order = OrderModel.fromJson(json);

      expect(order.cleanerId, 'cleaner-01');
      expect(order.cleaner, isNotNull);
      expect(order.cleaner!.nama, 'Siti Rahmawati');
      expect(order.cleaner!.ratingRataRata, 4.9);
      expect(order.startedAt, '2026-09-30T13:05:00.000Z');
      expect(order.statusLogs?.length, 2);
    });
  });
}
