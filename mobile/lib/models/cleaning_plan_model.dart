class CleaningPlanCleanerInfo {
  final String id;
  final String nama;
  final String? nomorTelepon;
  final double ratingRataRata;
  final int totalPekerjaan;

  CleaningPlanCleanerInfo({
    required this.id,
    required this.nama,
    this.nomorTelepon,
    required this.ratingRataRata,
    required this.totalPekerjaan,
  });

  factory CleaningPlanCleanerInfo.fromJson(Map<String, dynamic> json) {
    return CleaningPlanCleanerInfo(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      nomorTelepon: json['nomor_telepon']?.toString() ?? json['nomorTelepon']?.toString(),
      ratingRataRata: (json['rating_rata_rata'] is num)
          ? (json['rating_rata_rata'] as num).toDouble()
          : (json['ratingRataRata'] is num)
              ? (json['ratingRataRata'] as num).toDouble()
              : double.tryParse(json['rating_rata_rata']?.toString() ?? '0') ?? 0.0,
      totalPekerjaan: (json['total_pekerjaan'] is num)
          ? (json['total_pekerjaan'] as num).toInt()
          : (json['totalPekerjaan'] is num)
              ? (json['totalPekerjaan'] as num).toInt()
              : int.tryParse(json['total_pekerjaan']?.toString() ?? '0') ?? 0,
    );
  }
}

class CleaningPlanModel {
  final String id;
  final String customerId;
  final String planName;
  final String serviceCategory;
  final String serviceId;
  final String frequency; // 'mingguan' | 'dua_mingguan'
  final int dayOfWeek; // 1 (Senin) - 7 (Minggu)
  final String dayName;
  final String startTime;
  final int duration;
  final double pricePerSession;
  final String address;
  final String? landmark;
  final String? notes;
  final String? preferredCleanerId;
  final CleaningPlanCleanerInfo? preferredCleaner;
  final String status; // 'Aktif', 'Dijeda', 'Dibatalkan'
  final String? nextSessionDate;
  final String? lastGeneratedDate;
  final int totalSessionsCompleted;
  final String? createdAt;
  final String? updatedAt;

  CleaningPlanModel({
    required this.id,
    required this.customerId,
    required this.planName,
    required this.serviceCategory,
    required this.serviceId,
    required this.frequency,
    required this.dayOfWeek,
    required this.dayName,
    required this.startTime,
    required this.duration,
    required this.pricePerSession,
    required this.address,
    this.landmark,
    this.notes,
    this.preferredCleanerId,
    this.preferredCleaner,
    this.status = 'Aktif',
    this.nextSessionDate,
    this.lastGeneratedDate,
    this.totalSessionsCompleted = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAktif => status.toLowerCase() == 'aktif';
  bool get isDijeda => status.toLowerCase() == 'dijeda';
  bool get isDibatalkan => status.toLowerCase() == 'dibatalkan';

  String get frequencyDisplay =>
      frequency == 'mingguan' ? 'Setiap Minggu' : 'Setiap 2 Minggu';

  factory CleaningPlanModel.fromJson(Map<String, dynamic> json) {
    CleaningPlanCleanerInfo? cleanerInfo;
    final rawCleaner = json['preferred_cleaner'] ?? json['cleaner'] ?? json['preferredCleaner'];
    if (rawCleaner is Map<String, dynamic>) {
      cleanerInfo = CleaningPlanCleanerInfo.fromJson(rawCleaner);
    }

    return CleaningPlanModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? json['customerId']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? json['planName']?.toString() ?? '',
      serviceCategory: json['service_category']?.toString() ?? json['serviceCategory']?.toString() ?? '',
      serviceId: json['service_id']?.toString() ?? json['serviceId']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? 'mingguan',
      dayOfWeek: (json['day_of_week'] is num)
          ? (json['day_of_week'] as num).toInt()
          : (json['dayOfWeek'] is num)
              ? (json['dayOfWeek'] as num).toInt()
              : int.tryParse(json['day_of_week']?.toString() ?? '1') ?? 1,
      dayName: json['day_name']?.toString() ?? json['dayName']?.toString() ?? 'Senin',
      startTime: json['start_time']?.toString() ?? json['startTime']?.toString() ?? '09:00',
      duration: (json['duration'] is num)
          ? (json['duration'] as num).toInt()
          : int.tryParse(json['duration']?.toString() ?? '2') ?? 2,
      pricePerSession: (json['price_per_session'] is num)
          ? (json['price_per_session'] as num).toDouble()
          : (json['pricePerSession'] is num)
              ? (json['pricePerSession'] as num).toDouble()
              : double.tryParse(json['price_per_session']?.toString() ?? '0') ?? 0.0,
      address: json['address']?.toString() ?? '',
      landmark: json['landmark']?.toString(),
      notes: json['notes']?.toString(),
      preferredCleanerId: json['preferred_cleaner_id']?.toString() ?? json['preferredCleanerId']?.toString(),
      preferredCleaner: cleanerInfo,
      status: json['status']?.toString() ?? 'Aktif',
      nextSessionDate: json['next_session_date']?.toString() ?? json['nextSessionDate']?.toString(),
      lastGeneratedDate: json['last_generated_date']?.toString() ?? json['lastGeneratedDate']?.toString(),
      totalSessionsCompleted: (json['total_sessions_completed'] is num)
          ? (json['total_sessions_completed'] as num).toInt()
          : (json['totalSessionsCompleted'] is num)
              ? (json['totalSessionsCompleted'] as num).toInt()
              : int.tryParse(json['total_sessions_completed']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
      updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_name': planName,
      'service_category': serviceCategory,
      'service_id': serviceId,
      'frequency': frequency,
      'day_of_week': dayOfWeek,
      'day_name': dayName,
      'start_time': startTime,
      'duration': duration,
      'price_per_session': pricePerSession,
      'address': address,
      if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (preferredCleanerId != null && preferredCleanerId!.isNotEmpty)
        'preferred_cleaner_id': preferredCleanerId,
    };
  }
}
