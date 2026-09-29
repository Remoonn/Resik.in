/// Model data laporan mutu hasil pekerjaan (Quality Report)
/// Source of Truth: docs/PRD-Resik.in.md (FR-10) & docs/BUSINESS-RULES.md (BR-QRP)

class ChecklistItemModel {
  final String area;
  final bool completed;

  const ChecklistItemModel({
    required this.area,
    this.completed = true,
  });

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      area: json['area'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'area': area,
      'completed': completed,
    };
  }
}

class QualityReportModel {
  final String id;
  final String orderId;
  final String? cleanerId;
  final String cleanerNama;
  final List<ChecklistItemModel> checklistArea;
  final String? fotoBeforeUrl;
  final String? fotoAfterUrl;
  final String? fotoBeforeSignedUrl;
  final String? fotoAfterSignedUrl;
  final int signedUrlExpiresIn;
  final String? catatanPetugas;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? submittedAt;
  final bool isLocked;

  const QualityReportModel({
    required this.id,
    required this.orderId,
    this.cleanerId,
    required this.cleanerNama,
    required this.checklistArea,
    this.fotoBeforeUrl,
    this.fotoAfterUrl,
    this.fotoBeforeSignedUrl,
    this.fotoAfterSignedUrl,
    this.signedUrlExpiresIn = 1800,
    this.catatanPetugas,
    this.startedAt,
    this.completedAt,
    this.submittedAt,
    this.isLocked = true,
  });

  factory QualityReportModel.fromJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist_area'] as List<dynamic>? ?? [];
    final items = rawChecklist
        .map((item) => ChecklistItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return QualityReportModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      cleanerId: json['cleaner_id'] as String?,
      cleanerNama: json['cleaner_nama'] as String? ?? 'Petugas Resik.in',
      checklistArea: items,
      fotoBeforeUrl: json['foto_before_url'] as String?,
      fotoAfterUrl: json['foto_after_url'] as String?,
      fotoBeforeSignedUrl: json['foto_before_signed_url'] as String?,
      fotoAfterSignedUrl: json['foto_after_signed_url'] as String?,
      signedUrlExpiresIn: json['signed_url_expires_in'] as int? ?? 1800,
      catatanPetugas: json['catatan_petugas'] as String?,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'] as String) : null,
      isLocked: json['is_locked'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'cleaner_id': cleanerId,
      'cleaner_nama': cleanerNama,
      'checklist_area': checklistArea.map((item) => item.toJson()).toList(),
      'foto_before_url': fotoBeforeUrl,
      'foto_after_url': fotoAfterUrl,
      'foto_before_signed_url': fotoBeforeSignedUrl,
      'foto_after_signed_url': fotoAfterSignedUrl,
      'signed_url_expires_in': signedUrlExpiresIn,
      'catatan_petugas': catatanPetugas,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'is_locked': isLocked,
    };
  }
}
