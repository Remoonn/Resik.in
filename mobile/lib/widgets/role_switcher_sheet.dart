import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class RoleSwitcherSheet extends StatelessWidget {
  const RoleSwitcherSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RoleSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUserNotifier.value;

    final roles = [
      {
        'key': 'customer',
        'title': 'Pelanggan (Customer)',
        'subtitle': 'Akses pemesanan layanan, lacak progres, dan ulasan mutu',
        'icon': Icons.person_rounded,
        'color': AppColors.primary,
        'user': AuthService.demoAccounts['customer']!,
        'badge': 'Customer App',
      },
      {
        'key': 'cleaner',
        'title': 'Petugas Lapangan (Cleaner)',
        'subtitle': 'Tugas berjalan, checklist area, upload foto laporan mutu',
        'icon': Icons.cleaning_services_rounded,
        'color': AppColors.secondary,
        'user': AuthService.demoAccounts['cleaner']!,
        'badge': 'Mitra Lapangan',
      },
      {
        'key': 'admin',
        'title': 'Administrator Operasional (Admin)',
        'subtitle': 'Menara kontrol penugasan cerdas, monitoring, dan audit',
        'icon': Icons.admin_panel_settings_rounded,
        'color': AppColors.tertiary,
        'user': AuthService.demoAccounts['admin']!,
        'badge': 'Menara Kontrol',
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ganti Peran Demonstrasi',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pilih profil untuk menguji antarmuka 3 aktor sistem',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...roles.map((item) {
            final user = item['user'] as UserModel;
            final isCurrent = currentUser?.role == user.role;
            final color = item['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    AuthService.currentUserNotifier.value = user;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Beralih ke peran: ${item['title']}',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: color,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent ? color.withValues(alpha: 0.08) : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? color : AppColors.outline,
                        width: isCurrent ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item['title'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isCurrent ? color : AppColors.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item['badge'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['subtitle'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nama: ${user.nama} • ${user.email}',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent ? color : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isCurrent)
                          Icon(Icons.check_circle_rounded, color: color, size: 24)
                        else
                          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
