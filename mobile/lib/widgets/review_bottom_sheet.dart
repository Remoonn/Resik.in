import 'package:flutter/material.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';

/// Modal Bottom Sheet interaktif untuk pengiriman rating bintang 1–5 dan catatan ulasan (FR-11)
class ReviewBottomSheet extends StatefulWidget {
  final String orderId;
  final String cleanerName;
  final String? serviceName;
  final String? userId;
  final Future<bool> Function(int rating, String? notes)? onSubmit;

  const ReviewBottomSheet({
    super.key,
    required this.orderId,
    required this.cleanerName,
    this.serviceName,
    this.userId,
    this.onSubmit,
  });

  /// Helper statis untuk menampilkan ReviewBottomSheet
  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required String cleanerName,
    String? serviceName,
    String? userId,
    Future<bool> Function(int rating, String? notes)? onSubmit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ReviewBottomSheet(
          orderId: orderId,
          cleanerName: cleanerName,
          serviceName: serviceName,
          userId: userId,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  final TextEditingController _notesController = TextEditingController();
  final ReviewService _reviewService = ReviewService();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Kurang';
      case 2:
        return 'Kurang Memuaskan';
      case 3:
        return 'Cukup';
      case 4:
        return 'Memuaskan';
      case 5:
        return 'Sangat Puas & Bersih';
      default:
        return 'Ketuk bintang untuk menilai';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return const Color(0xFFE11D48); // Rose
      case 2:
        return const Color(0xFFF97316); // Orange
      case 3:
        return const Color(0xFFEAB308); // Amber
      case 4:
        return const Color(0xFF14B8A6); // Teal
      case 5:
        return const Color(0xFF10B981); // Emerald
      default:
        return AppColors.slate500;
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedRating < 1 || _selectedRating > 5 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final notes = _notesController.text.trim();
      bool success = false;

      if (widget.onSubmit != null) {
        success = await widget.onSubmit!(_selectedRating, notes.isNotEmpty ? notes : null);
      } else {
        final review = await _reviewService.submitReview(
          orderId: widget.orderId,
          rating: _selectedRating,
          catatanUlasan: notes.isNotEmpty ? notes : null,
          userId: widget.userId,
        );
        success = review != null;
      }

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ulasan berhasil dikirim! Terima kasih atas apresiasi Anda.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim ulasan. Silakan periksa koneksi dan coba lagi.'),
            backgroundColor: Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beri Ulasan Petugas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.cleanerName,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    if (widget.serviceName != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        widget.serviceName!,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.slate500),
              ),
            ],
          ),
          const Divider(height: 24),

          // Star Selection Row
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isSelected = starValue <= _selectedRating;
                return GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _selectedRating = starValue;
                          });
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.star_rounded,
                        size: 42,
                        color: isSelected
                            ? AppColors.warmAmber
                            : AppColors.outline,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          // Dynamic emotional label
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _getRatingLabel(_selectedRating),
                key: ValueKey<int>(_selectedRating),
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _getRatingColor(_selectedRating),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Catatan ulasan (Opsional)
          Text(
            'Catatan Ulasan (Opsional)',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 300,
            enabled: !_isSubmitting,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ceritakan pengalaman Anda terkait ketelitian, kerapian, atau keramahan petugas...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.slate500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Submit
          ElevatedButton(
            onPressed: (_selectedRating > 0 && !_isSubmitting) ? _handleSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              disabledBackgroundColor: AppColors.outline,
              disabledForegroundColor: AppColors.slate500,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Kirim Ulasan',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
