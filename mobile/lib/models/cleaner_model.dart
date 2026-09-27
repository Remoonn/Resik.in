class CleanerReviewModel {
  final String id;
  final String cleanerId;
  final String customerNama;
  final int rating;
  final String tanggal;
  final String ulasan;
  final String serviceNama;

  CleanerReviewModel({
    required this.id,
    required this.cleanerId,
    required this.customerNama,
    required this.rating,
    required this.tanggal,
    required this.ulasan,
    required this.serviceNama,
  });

  factory CleanerReviewModel.fromJson(Map<String, dynamic> json) {
    return CleanerReviewModel(
      id: json['id']?.toString() ?? '',
      cleanerId: json['cleaner_id']?.toString() ?? '',
      customerNama: json['customer_nama']?.toString() ?? 'Pelanggan',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      tanggal: json['tanggal']?.toString() ?? '',
      ulasan: json['ulasan']?.toString() ?? '',
      serviceNama: json['service_nama']?.toString() ?? 'Layanan Kebersihan',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cleaner_id': cleanerId,
      'customer_nama': customerNama,
      'rating': rating,
      'tanggal': tanggal,
      'ulasan': ulasan,
      'service_nama': serviceNama,
    };
  }
}

class CleanerScoreModel {
  final double skillScore;
  final double availScore;
  final double ratingScore;
  final double effectiveRating;
  final bool isProvisionalRating;
  final double expScore;
  final double totalScore;
  final String matchBadge;

  CleanerScoreModel({
    required this.skillScore,
    required this.availScore,
    required this.ratingScore,
    required this.effectiveRating,
    required this.isProvisionalRating,
    required this.expScore,
    required this.totalScore,
    required this.matchBadge,
  });

  factory CleanerScoreModel.fromJson(Map<String, dynamic> json) {
    return CleanerScoreModel(
      skillScore: (json['skillScore'] as num?)?.toDouble() ?? 0.0,
      availScore: (json['availScore'] as num?)?.toDouble() ?? 0.0,
      ratingScore: (json['ratingScore'] as num?)?.toDouble() ?? 0.0,
      effectiveRating: (json['effectiveRating'] as num?)?.toDouble() ?? 5.0,
      isProvisionalRating: json['isProvisionalRating'] == true,
      expScore: (json['expScore'] as num?)?.toDouble() ?? 0.0,
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0.0,
      matchBadge: json['matchBadge']?.toString() ?? 'Tersedia',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skillScore': skillScore,
      'availScore': availScore,
      'ratingScore': ratingScore,
      'effectiveRating': effectiveRating,
      'isProvisionalRating': isProvisionalRating,
      'expScore': expScore,
      'totalScore': totalScore,
      'matchBadge': matchBadge,
    };
  }
}

class CleanerModel {
  final String id;
  final String nama;
  final String? nomorKontak;
  final String? fotoUrl;
  final List<String> keahlian;
  final int pengalamanTahun;
  final double ratingRataRata;
  final int totalUlasan;
  final int totalPekerjaan;
  final int tingkatKepuasan;
  final int ketepatanWaktu;
  final String statusOperasional;
  final String? tentang;
  final List<String> sertifikasi;
  final List<CleanerReviewModel> ulasan;

  CleanerModel({
    required this.id,
    required this.nama,
    this.nomorKontak,
    this.fotoUrl,
    required this.keahlian,
    required this.pengalamanTahun,
    required this.ratingRataRata,
    required this.totalUlasan,
    required this.totalPekerjaan,
    required this.tingkatKepuasan,
    required this.ketepatanWaktu,
    required this.statusOperasional,
    this.tentang,
    required this.sertifikasi,
    required this.ulasan,
  });

  factory CleanerModel.fromJson(Map<String, dynamic> json) {
    return CleanerModel(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      nomorKontak: json['nomor_kontak']?.toString(),
      fotoUrl: json['foto_url']?.toString(),
      keahlian: (json['keahlian'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pengalamanTahun: (json['pengalaman_tahun'] as num?)?.toInt() ?? 1,
      ratingRataRata: (json['rating_rata_rata'] as num?)?.toDouble() ?? 0.0,
      totalUlasan: (json['total_ulasan'] as num?)?.toInt() ?? 0,
      totalPekerjaan: (json['total_pekerjaan'] as num?)?.toInt() ?? 0,
      tingkatKepuasan: (json['tingkat_kepuasan'] as num?)?.toInt() ?? 100,
      ketepatanWaktu: (json['ketepatan_waktu'] as num?)?.toInt() ?? 100,
      statusOperasional: json['status_operasional']?.toString() ?? 'Aktif',
      tentang: json['tentang']?.toString(),
      sertifikasi: (json['sertifikasi'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ulasan: (json['ulasan'] as List<dynamic>?)
              ?.map((e) => CleanerReviewModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'nomor_kontak': nomorKontak,
      'foto_url': fotoUrl,
      'keahlian': keahlian,
      'pengalaman_tahun': pengalamanTahun,
      'rating_rata_rata': ratingRataRata,
      'total_ulasan': totalUlasan,
      'total_pekerjaan': totalPekerjaan,
      'tingkat_kepuasan': tingkatKepuasan,
      'ketepatan_waktu': ketepatanWaktu,
      'status_operasional': statusOperasional,
      'tentang': tentang,
      'sertifikasi': sertifikasi,
      'ulasan': ulasan.map((e) => e.toJson()).toList(),
    };
  }
}

class CleanerRecommendation {
  final CleanerModel cleaner;
  final CleanerScoreModel score;

  CleanerRecommendation({
    required this.cleaner,
    required this.score,
  });

  factory CleanerRecommendation.fromJson(Map<String, dynamic> json) {
    return CleanerRecommendation(
      cleaner: CleanerModel.fromJson(json['cleaner'] as Map<String, dynamic>),
      score: CleanerScoreModel.fromJson(json['score'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cleaner': cleaner.toJson(),
      'score': score.toJson(),
    };
  }
}
