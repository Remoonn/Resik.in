import 'service_model.dart';

class AiRecommendedService {
  final String id;
  final String namaLayanan;
  final String kategori;
  final double tarifDasar;
  final String durasiEstimasi;
  final int suggestedDuration;
  final String rationale;

  AiRecommendedService({
    required this.id,
    required this.namaLayanan,
    required this.kategori,
    required this.tarifDasar,
    required this.durasiEstimasi,
    required this.suggestedDuration,
    required this.rationale,
  });

  factory AiRecommendedService.fromJson(Map<String, dynamic> json) {
    return AiRecommendedService(
      id: json['id']?.toString() ?? '',
      namaLayanan: json['nama_layanan']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? 'rumah',
      tarifDasar: (json['tarif_dasar'] as num?)?.toDouble() ?? 0.0,
      durasiEstimasi: json['durasi_estimasi']?.toString() ?? '2 Jam',
      suggestedDuration: (json['suggested_duration'] as num?)?.toInt() ?? 2,
      rationale: json['rationale']?.toString() ?? '',
    );
  }

  ServiceModel toServiceModel() {
    return ServiceModel(
      id: id,
      namaLayanan: namaLayanan,
      kategori: kategori,
      deskripsi: rationale,
      durasiEstimasi: durasiEstimasi,
      tarifDasar: tarifDasar,
      iconName: kategori == 'kos'
          ? 'bed'
          : kategori == 'kantor'
              ? 'business'
              : kategori == 'renovasi'
                  ? 'construction'
                  : 'home',
      isActive: true,
    );
  }
}

class AiConsultationResponse {
  final String reply;
  final AiRecommendedService? recommendedService;
  final List<String> suggestedReplies;

  AiConsultationResponse({
    required this.reply,
    this.recommendedService,
    required this.suggestedReplies,
  });

  factory AiConsultationResponse.fromJson(Map<String, dynamic> json) {
    return AiConsultationResponse(
      reply: json['reply']?.toString() ?? '',
      recommendedService: json['recommended_service'] != null
          ? AiRecommendedService.fromJson(Map<String, dynamic>.from(json['recommended_service']))
          : null,
      suggestedReplies: (json['suggested_replies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AiRecommendedService? recommendedService;
  final List<String> suggestedReplies;
  final bool isError;

  AiChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.recommendedService,
    this.suggestedReplies = const [],
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
