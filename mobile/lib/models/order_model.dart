import 'cleaner_model.dart';

class OrderModel {
  final String id;
  final String orderCode;
  final String? customerId;
  final String serviceId;
  final String? serviceName;
  final String? serviceCategory;
  final String? cleanerId;
  final CleanerModel? cleaner;
  final String tanggalLayanan;
  final String startTime;
  final String? endTime;
  final int duration;
  final String alamatLengkap;
  final String patokanLokasi;
  final String luasArea;
  final String? catatanKhusus;
  final double hargaSaatBooking;
  final double totalBiaya;
  final String statusPembayaran;
  final String? paymentTimestamp;
  final String statusPekerjaan;
  final String? preferensiPetugasId;
  final String? startedAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final String? cancelledAt;
  final List<dynamic>? statusLogs;
  final String? createdAt;

  OrderModel({
    required this.id,
    required this.orderCode,
    this.customerId,
    required this.serviceId,
    this.serviceName,
    this.serviceCategory,
    this.cleanerId,
    this.cleaner,
    required this.tanggalLayanan,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.alamatLengkap,
    required this.patokanLokasi,
    required this.luasArea,
    this.catatanKhusus,
    required this.hargaSaatBooking,
    required this.totalBiaya,
    required this.statusPembayaran,
    this.paymentTimestamp,
    required this.statusPekerjaan,
    this.preferensiPetugasId,
    this.startedAt,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.statusLogs,
    this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Parsing nested service data jika tersedia
    String? sName;
    String? sCategory;
    if (json['service'] is Map<String, dynamic>) {
      sName = json['service']['nama_layanan'];
      sCategory = json['service']['kategori'];
    }
    CleanerModel? cleanerObj;
    if (json['cleaner'] is Map<String, dynamic>) {
      cleanerObj = CleanerModel.fromJson(json['cleaner'] as Map<String, dynamic>);
    }

    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderCode: json['order_code']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      serviceId: json['service_id']?.toString() ?? '',
      serviceName: sName ?? json['nama_layanan']?.toString(),
      serviceCategory: sCategory ?? json['kategori']?.toString() ?? json['service_kategori']?.toString(),
      cleanerId: json['cleaner_id']?.toString(),
      cleaner: cleanerObj,
      tanggalLayanan: json['tanggal_layanan']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString(),
      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? '2') ?? 2,
      alamatLengkap: json['alamat_lengkap']?.toString() ?? '',
      patokanLokasi: json['patokan_lokasi']?.toString() ?? '',
      luasArea: json['luas_area']?.toString() ?? '',
      catatanKhusus: json['catatan_khusus']?.toString(),
      hargaSaatBooking: (json['harga_saat_booking'] is num)
          ? (json['harga_saat_booking'] as num).toDouble()
          : double.tryParse(json['harga_saat_booking']?.toString() ?? '0.0') ?? 0.0,
      totalBiaya: (json['total_biaya'] is num)
          ? (json['total_biaya'] as num).toDouble()
          : double.tryParse(json['total_biaya']?.toString() ?? '0.0') ?? 0.0,
      statusPembayaran: json['status_pembayaran']?.toString() ?? 'Belum Bayar',
      paymentTimestamp: json['payment_timestamp']?.toString(),
      statusPekerjaan: json['status_pekerjaan']?.toString() ?? 'Menunggu Konfirmasi',
      preferensiPetugasId: json['preferensi_petugas_id']?.toString(),
      startedAt: json['started_at']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
      cancelledBy: json['cancelled_by']?.toString(),
      cancelledAt: json['cancelled_at']?.toString(),
      statusLogs: json['status_logs'] as List<dynamic>?,
      createdAt: json['created_at']?.toString(),
    );
  }

  /// Membuat payload untuk dikirimkan ke endpoint POST /api/orders
  /// Klien dilarang menyertakan status_pembayaran sesuai aturan SOT (BR-FIN-001)
  Map<String, dynamic> toBookingPayload() {
    final map = <String, dynamic>{
      'service_id': serviceId,
      'tanggal_layanan': tanggalLayanan,
      'start_time': startTime,
      'duration': duration,
      'alamat_lengkap': alamatLengkap,
      'patokan_lokasi': patokanLokasi,
      'luas_area': luasArea,
    };

    if (catatanKhusus != null && catatanKhusus!.trim().isNotEmpty) {
      map['catatan_khusus'] = catatanKhusus!.trim();
    }
    if (preferensiPetugasId != null && preferensiPetugasId!.isNotEmpty) {
      map['preferensi_petugas_id'] = preferensiPetugasId;
    }

    return map;
  }
}
