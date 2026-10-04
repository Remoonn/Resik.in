import 'package:flutter/material.dart';
import '../models/cleaner_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class SmartAssignmentSheet extends StatefulWidget {
  final OrderModel order;
  final Future<List<CleanerRecommendation>> Function()? recommendationsLoader;

  const SmartAssignmentSheet({
    super.key,
    required this.order,
    this.recommendationsLoader,
  });

  @override
  State<SmartAssignmentSheet> createState() => _SmartAssignmentSheetState();
}

class _SmartAssignmentSheetState extends State<SmartAssignmentSheet> {
  List<CleanerRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _assigningCleanerId;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      if (widget.recommendationsLoader != null) {
        _recommendations = await widget.recommendationsLoader!();
      } else {
        _recommendations = await ApiService.fetchRecommendations(
          serviceId: widget.order.serviceId,
          tanggal: widget.order.tanggalLayanan,
          startTime: widget.order.startTime,
          duration: widget.order.duration,
        );
      }
    } catch (_) {
      _recommendations = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _assignCleaner(CleanerModel cleaner) async {
    if (_assigningCleanerId != null) return;

    setState(() => _assigningCleanerId = cleaner.id);

    try {
      final res = await ApiService.assignCleaner(
        widget.order.id,
        cleaner.id,
        role: 'admin',
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Petugas ${cleaner.nama} berhasil ditugaskan!'),
            backgroundColor: const Color(0xFF006947),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal menugaskan petugas'),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFBA1A1A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _assigningCleanerId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Penugasan Petugas Cerdas',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.order.serviceName} • ${widget.order.tanggalLayanan} ${widget.order.startTime} WIB',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF707881),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF707881)),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Algorithmic explaination banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCE5FF)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFF006194), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Urutan rekomendasi dihitung berdasarkan ketersediaan jadwal (+ buffer 30 mnt), rating, keahlian, dan kepuasan pelanggan.',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: Color(0xFF0B1C30),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List of recommendations
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recommendations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_off_rounded, size: 48, color: Color(0xFF707881)),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada petugas yang tersedia',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B1C30),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Semua petugas memiliki bentrok jadwal atau sedang tidak aktif.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF707881)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          return _buildRecommendationCard(_recommendations[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(CleanerRecommendation rec) {
    final cleaner = rec.cleaner;
    final score = rec.score;
    final isBentrok = score.availScore <= 0 ||
        score.matchBadge.toLowerCase().contains('bentrok') ||
        cleaner.statusOperasional != 'Aktif';
    final isCustomerPreferred = widget.order.preferensiPetugasId == cleaner.id ||
        score.matchBadge.toLowerCase().contains('pilihan');
    final isAssigning = _assigningCleanerId == cleaner.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isBentrok ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBentrok
              ? const Color(0xFFE5E7EB)
              : isCustomerPreferred
                  ? const Color(0xFF006194)
                  : const Color(0xFFE2E8F0),
          width: isCustomerPreferred ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: isBentrok ? Colors.grey.shade300 : const Color(0xFFE5EEFF),
                child: Text(
                  cleaner.nama.isNotEmpty ? cleaner.nama[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isBentrok ? Colors.grey.shade600 : const Color(0xFF006194),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Detail cleaner
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cleaner.nama,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isBentrok ? const Color(0xFF707881) : const Color(0xFF0B1C30),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCustomerPreferred) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Pilihan Pelanggan',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
                        const SizedBox(width: 3),
                        Text(
                          '${cleaner.ratingRataRata.toStringAsFixed(1)} (${cleaner.totalUlasan})',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0B1C30),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${cleaner.pengalamanTahun} thn exp',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            color: Color(0xFF707881),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Score or Status Badge
              if (isBentrok)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Jadwal Bentrok',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBA1A1A),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4F7DC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${score.totalScore.toStringAsFixed(0)}% Match',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF006947),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: isBentrok
                ? OutlinedButton(
                    onPressed: null, // Disabled
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Tidak Tersedia (Bentrok)',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: isAssigning ? null : () => _assignCleaner(cleaner),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006194),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isAssigning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Tugaskan Petugas Ini',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
