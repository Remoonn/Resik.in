import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/order_model.dart';
import '../models/quality_report_model.dart';
import '../services/quality_report_service.dart';

class QualityReportFormSheet extends StatefulWidget {
  final OrderModel order;
  final Function(QualityReportModel report)? onSubmitted;

  const QualityReportFormSheet({
    super.key,
    required this.order,
    this.onSubmitted,
  });

  @override
  State<QualityReportFormSheet> createState() => _QualityReportFormSheetState();
}

class _QualityReportFormSheetState extends State<QualityReportFormSheet> {
  final QualityReportService _service = QualityReportService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _catatanController = TextEditingController();

  late Map<String, bool> _checklistMap;
  XFile? _fotoBefore;
  XFile? _fotoAfter;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final areas = _service.getChecklistTemplateForCategory(widget.order.serviceCategory);
    _checklistMap = {for (var area in areas) area: false};
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final allChecked = _checklistMap.isNotEmpty && _checklistMap.values.every((v) => v);
    final hasPhotos = _fotoBefore != null && _fotoAfter != null;
    return allChecked && hasPhotos && !_isSubmitting;
  }

  Future<void> _pickPhoto({required bool isBefore, required ImageSource source}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          if (isBefore) {
            _fotoBefore = picked;
          } else {
            _fotoAfter = picked;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: ${e.toString()}')),
      );
    }
  }

  void _showImagePickerOptions({required bool isBefore}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0D9488)),
              title: const Text('Ambil dengan Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(isBefore: isBefore, source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0D9488)),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(isBefore: isBefore, source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final checklistPayload = _checklistMap.entries
        .map((e) => {'area': e.key, 'completed': e.value})
        .toList();

    final payload = {
      'order_id': widget.order.id,
      'checklist_area': checklistPayload,
      'foto_before_path': 'orders/${widget.order.id}/before_${now.millisecondsSinceEpoch}.webp',
      'foto_after_path': 'orders/${widget.order.id}/after_${now.millisecondsSinceEpoch}.webp',
      'catatan_petugas': _catatanController.text.trim(),
      'completed_at': now.toIso8601String(),
      'role': 'cleaner',
      'cleaner_id': widget.order.cleanerId,
      'service_category': widget.order.serviceCategory,
    };

    final result = await _service.submitReport(payload);

    if (!mounted) return;

    if (result['success'] == true) {
      final mockModel = QualityReportModel(
        id: (result['data'] != null && result['data']['report_id'] != null)
            ? result['data']['report_id'] as String
            : 'rep-${now.millisecondsSinceEpoch}',
        orderId: widget.order.id,
        cleanerId: widget.order.cleanerId,
        cleanerNama: widget.order.cleaner?.nama ?? 'Petugas Resik.in',
        checklistArea: checklistPayload
            .map((item) => ChecklistItemModel.fromJson(item))
            .toList(),
        fotoBeforeUrl: payload['foto_before_path'] as String,
        fotoAfterUrl: payload['foto_after_path'] as String,
        catatanPetugas: _catatanController.text.trim(),
        completedAt: now,
        submittedAt: now,
        isLocked: true,
      );

      widget.onSubmitted?.call(mockModel);
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result['message'] as String? ?? 'Gagal menyerahkan laporan mutu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Laporan Mutu Hasil Kerja',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan seluruh area tercentang tuntas dan unggah dokumentasi fisik Before & After.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[800], fontSize: 13),
                ),
              ),
            const Text(
              'Checklist Area Pemeriksaan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            ..._checklistMap.keys.map((area) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(area, style: const TextStyle(fontSize: 14)),
                value: _checklistMap[area],
                activeColor: const Color(0xFF0D9488),
                onChanged: (val) {
                  setState(() {
                    _checklistMap[area] = val ?? false;
                  });
                },
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'Dokumentasi Foto Fisik',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPhotoBox(
                    label: 'Foto Sebelum (Before)',
                    file: _fotoBefore,
                    onTap: () => _showImagePickerOptions(isBefore: true),
                    onClear: () => setState(() => _fotoBefore = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoBox(
                    label: 'Foto Sesudah (After)',
                    file: _fotoAfter,
                    onTap: () => _showImagePickerOptions(isBefore: false),
                    onClear: () => setState(() => _fotoAfter = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Catatan Tambahan Petugas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _catatanController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Misal: Noda membandel pada lantai keramik berhasil dibersihkan...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _canSubmit ? _handleSubmit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Kirim Laporan Mutu & Selesaikan',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPhotoBox({
    required String label,
    required XFile? file,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: file != null ? const Color(0xFF0D9488) : Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(file.path, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                          : Image.file(File(file.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo, color: Color(0xFF0D9488), size: 30),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (file != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
