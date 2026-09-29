import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/quality_report_model.dart';
import '../services/auth_service.dart';
import '../services/quality_report_service.dart';

/// Layar Laporan Mutu Hasil Kerja (Quality Report Screen)
/// Dedicated Full-Screen Viewer untuk Pelanggan (FR-10 & BR-QRP)
class QualityReportScreen extends StatefulWidget {
  final OrderModel order;
  final QualityReportModel? initialReport;
  final QualityReportService? reportService;

  const QualityReportScreen({
    super.key,
    required this.order,
    this.initialReport,
    this.reportService,
  });

  @override
  State<QualityReportScreen> createState() => _QualityReportScreenState();
}

class _QualityReportScreenState extends State<QualityReportScreen> {
  late QualityReportService _service;
  QualityReportModel? _report;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedPhotoTab = 0; // 0: Sebelum, 1: Sesudah

  @override
  void initState() {
    super.initState();
    _service = widget.reportService ?? QualityReportService();
    if (widget.initialReport != null) {
      _report = widget.initialReport;
      _isLoading = false;
    } else {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = AuthService().currentUser;
    final userId = widget.order.customerId ?? currentUser?.id ?? 'usr-customer-001';
    final role = currentUser?.role ?? 'customer';

    final report = await _service.fetchReport(
      widget.order.id,
      userId: userId,
      role: role,
    );
    if (!mounted) return;

    if (report != null) {
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Laporan mutu belum tersedia atau sedang diproses.\nKetuk Coba Lagi setelah server terhubung.';
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$d-$m-$y, $hh:$mm:$ss WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Laporan Hasil Kerja',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00796B)),
      );
    }

    if (_errorMessage != null || _report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Laporan mutu tidak ditemukan.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Lock Badge Card
          _buildLockBadgeCard(report),
          const SizedBox(height: 16),

          // 2. Order & Cleaner Overview
          _buildOverviewCard(report),
          const SizedBox(height: 16),

          // 3. Before & After Photo Comparison
          _buildPhotoComparisonCard(report),
          const SizedBox(height: 16),

          // 4. Checklist Area Terverifikasi
          _buildChecklistCard(report),
          const SizedBox(height: 16),

          // 5. Timestamps Audit Trail
          _buildAuditTimestampsCard(report),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLockBadgeCard(QualityReportModel report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF81C784), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan Mutu Terverifikasi (Read-Only Lock)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Laporan ini telah disetujui secara digital dan dikunci permanen. Bukti pekerjaan tidak dapat diubah.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(QualityReportModel report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF00796B), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.cleanerNama,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Petugas Kebersihan Resik.in • ${widget.order.serviceName}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.catatanPetugas != null && report.catatanPetugas!.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            const Text(
              'Catatan Petugas:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                report.catatanPetugas!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoComparisonCard(QualityReportModel report) {
    final localBefore = QualityReportService.getLocalPhoto(report.orderId, isBefore: true) ??
        QualityReportService.getLocalPhoto(widget.order.orderCode, isBefore: true);
    final localAfter = QualityReportService.getLocalPhoto(report.orderId, isBefore: false) ??
        QualityReportService.getLocalPhoto(widget.order.orderCode, isBefore: false);

    final beforeUrl = (localBefore != null && File(localBefore).existsSync())
        ? localBefore
        : (report.fotoBeforeSignedUrl ?? report.fotoBeforeUrl);
    final afterUrl = (localAfter != null && File(localAfter).existsSync())
        ? localAfter
        : (report.fotoAfterSignedUrl ?? report.fotoAfterUrl);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text(
                'Dokumentasi Visual (Before & After)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPhotoTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPhotoTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _selectedPhotoTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sebelum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedPhotoTab == 0 ? FontWeight.bold : FontWeight.w500,
                          color: _selectedPhotoTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPhotoTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPhotoTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _selectedPhotoTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sesudah',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedPhotoTab == 1 ? FontWeight.bold : FontWeight.w500,
                          color: _selectedPhotoTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Active Photo Container
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 200,
              width: double.infinity,
              color: const Color(0xFFF8FAFC),
              child: _selectedPhotoTab == 0
                  ? _buildImage(beforeUrl, 'Sebelum Pengerjaan', fallbackLocalPath: localBefore)
                  : _buildImage(afterUrl, 'Sesudah Pengerjaan', fallbackLocalPath: localAfter),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? url, String label, {String? fallbackLocalPath}) {
    if (url == null || url.isEmpty) {
      if (fallbackLocalPath != null && File(fallbackLocalPath).existsSync()) {
        return Image.file(File(fallbackLocalPath), fit: BoxFit.cover);
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text('Foto $label tidak tersedia', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    // Format Base64 Data URI
    if (url.startsWith('data:image/') || (url.length > 200 && !url.contains('/') && !url.contains('\\'))) {
      try {
        final rawBase64 = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(rawBase64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    // Path File Lokal di Perangkat
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }

    // URL Jaringan (HTTP / HTTPS Signed URL Backend)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (fallbackLocalPath != null) {
            final f = File(fallbackLocalPath);
            if (f.existsSync()) {
              return Image.file(f, fit: BoxFit.cover);
            }
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, size: 40, color: Color(0xFF00796B)),
                const SizedBox(height: 6),
                Text('Foto $label (Signed URL)', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              ],
            ),
          );
        },
      );
    }

    if (fallbackLocalPath != null && File(fallbackLocalPath).existsSync()) {
      return Image.file(File(fallbackLocalPath), fit: BoxFit.cover);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_outlined, size: 40, color: Color(0xFF00796B)),
          const SizedBox(height: 6),
          Text('Foto $label', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(QualityReportModel report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF00796B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Area Terverifikasi (100% Selesai)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${report.checklistArea.length}/${report.checklistArea.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...report.checklistArea.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.area,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const Text(
                    'Terverifikasi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAuditTimestampsCard(QualityReportModel report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text(
                'Jejak Audit Waktu Digital',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimestampRow(
            icon: Icons.play_arrow_outlined,
            label: 'Waktu Mulai Pengerjaan',
            value: _formatDateTime(report.startedAt),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildTimestampRow(
            icon: Icons.task_alt_outlined,
            label: 'Waktu Selesai Pengerjaan',
            value: _formatDateTime(report.completedAt),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildTimestampRow(
            icon: Icons.verified_user_outlined,
            label: 'Diverifikasi Server (Submitted)',
            value: _formatDateTime(report.submittedAt),
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isHighlight ? const Color(0xFF00796B) : const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isHighlight ? const Color(0xFF00796B) : const Color(0xFF64748B),
                  fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
