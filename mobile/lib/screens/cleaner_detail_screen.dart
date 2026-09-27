import 'package:flutter/material.dart';
import '../models/cleaner_model.dart';
import '../theme/app_theme.dart';

class CleanerDetailScreen extends StatelessWidget {
  final CleanerModel cleaner;
  final bool isProvisionalRating;
  final String? matchBadge;
  final double? totalScore;

  const CleanerDetailScreen({
    super.key,
    required this.cleaner,
    this.isProvisionalRating = false,
    this.matchBadge,
    this.totalScore,
  });

  String _formatSkill(String skill) {
    switch (skill.toLowerCase()) {
      case 'rumah':
      case 'pembersihan_rumah':
        return 'Pembersihan Rumah';
      case 'kos':
      case 'pembersihan_kos':
        return 'Pembersihan Kos';
      case 'kantor':
      case 'pembersihan_kantor':
        return 'Pembersihan Kantor';
      case 'pasca_renovasi':
      case 'renovasi':
        return 'Pasca Renovasi';
      case 'deep_cleaning':
        return 'Deep Cleaning';
      default:
        return skill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Profil Petugas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Header Profil Petugas
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        ClipOval(
                          child: (cleaner.fotoUrl != null && cleaner.fotoUrl!.isNotEmpty)
                              ? Image.network(
                                  cleaner.fotoUrl!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 96,
                                    height: 96,
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person, size: 54, color: AppColors.primary),
                                  ),
                                )
                              : Container(
                                  width: 96,
                                  height: 96,
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, size: 54, color: AppColors.primary),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    cleaner.nama,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${cleaner.pengalamanTahun} Tahun Pengalaman',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cleaner.statusOperasional,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (matchBadge != null || totalScore != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryContainer,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '⭐ $matchBadge (${totalScore?.toStringAsFixed(1)}% Match)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 2. Metrik Kinerja (Pekerjaan, Kepuasan, Ketepatan Waktu)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Pekerjaan Selesai',
                      value: '${cleaner.totalPekerjaan}',
                      icon: Icons.task_alt,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Kepuasan',
                      value: '${cleaner.tingkatKepuasan}%',
                      icon: Icons.thumb_up_alt_outlined,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Ketepatan Waktu',
                      value: '${cleaner.ketepatanWaktu}%',
                      icon: Icons.schedule,
                      color: AppColors.warmAmber,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Banner Transparansi Rating Awal (Jika Petugas Baru)
            if (isProvisionalRating || cleaner.totalUlasan == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warmAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warmAmber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Petugas Baru (Rating Awal 4.5)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.slate900,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Petugas ini telah lulus sertifikasi standar Resik.in dan diberikan rating awal provisional 4.5 sebelum menerima ulasan pertama dari pelanggan.',
                              style: TextStyle(
                                color: AppColors.slate500,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 4. Keahlian & Spesialisasi
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.stars, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Keahlian & Spesialisasi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cleaner.keahlian
                            .map((skill) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                                  ),
                                  child: Text(
                                    _formatSkill(skill),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Jaminan & Sertifikasi
            if (cleaner.sertifikasi.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.shield_outlined, color: AppColors.emerald, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Jaminan & Sertifikasi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...cleaner.sertifikasi.map((cert) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.emerald, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cert,
                                      style: const TextStyle(fontSize: 13, color: AppColors.slate900),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),

            // 6. Tentang Petugas
            if (cleaner.tentang != null && cleaner.tentang!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tentang Petugas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cleaner.tentang!,
                          style: const TextStyle(fontSize: 13, color: AppColors.slate500, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 7. Riwayat Ulasan Pelanggan
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ulasan Pelanggan (${cleaner.totalUlasan})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (cleaner.totalUlasan > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: AppColors.warmAmber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              cleaner.ratingRataRata.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (cleaner.ulasan.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada ulasan untuk petugas ini.',
                          style: TextStyle(color: AppColors.slate500, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...cleaner.ulasan.map((rev) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rev.customerNama,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (idx) => Icon(
                                        idx < rev.rating ? Icons.star : Icons.star_border,
                                        size: 16,
                                        color: AppColors.warmAmber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rev.serviceNama} • ${rev.tanggal}',
                                style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rev.ulasan,
                                style: const TextStyle(color: AppColors.slate900, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),

            const SizedBox(height: 100), // Spacing for sticky button
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, cleaner);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Pilih Petugas Ini',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
