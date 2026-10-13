import 'package:flutter/material.dart';
import '../models/cleaning_plan_model.dart';
import '../services/api_service.dart';
import 'create_cleaning_plan_screen.dart';

class CleaningPlansScreen extends StatefulWidget {
  final List<CleaningPlanModel>? initialPlans;

  const CleaningPlansScreen({
    super.key,
    this.initialPlans,
  });

  @override
  State<CleaningPlansScreen> createState() => _CleaningPlansScreenState();
}

class _CleaningPlansScreenState extends State<CleaningPlansScreen> {
  late List<CleaningPlanModel> _plans;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlans != null) {
      _plans = List.from(widget.initialPlans!);
    } else {
      _plans = [];
      _loadPlans();
    }
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final plans = await ApiService.fetchCleaningPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePlanStatus(CleaningPlanModel plan) async {
    final newStatus = plan.isAktif ? 'Dijeda' : 'Aktif';
    final actionText = plan.isAktif ? 'menjeda' : 'mengaktifkan kembali';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan.isAktif ? 'Jeda Paket Langganan?' : 'Aktifkan Kembali Paket?'),
        content: Text(
          'Apakah Anda yakin ingin $actionText paket "${plan.planName}"? '
          '${plan.isAktif ? 'Sesi berkala baru tidak akan diterbitkan selama dijeda.' : 'Sesi berkala akan kembali dijadwalkan secara otomatis.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(plan.isAktif ? 'Jeda' : 'Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await ApiService.updateCleaningPlanStatus(plan.id, newStatus);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paket berhasil diubah menjadi: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      if (widget.initialPlans == null) {
        _loadPlans();
      } else {
        setState(() {
          final idx = _plans.indexWhere((p) => p.id == plan.id);
          if (idx >= 0) {
            _plans[idx] = CleaningPlanModel(
              id: plan.id,
              customerId: plan.customerId,
              planName: plan.planName,
              serviceCategory: plan.serviceCategory,
              serviceId: plan.serviceId,
              frequency: plan.frequency,
              dayOfWeek: plan.dayOfWeek,
              dayName: plan.dayName,
              startTime: plan.startTime,
              duration: plan.duration,
              pricePerSession: plan.pricePerSession,
              address: plan.address,
              landmark: plan.landmark,
              notes: plan.notes,
              preferredCleanerId: plan.preferredCleanerId,
              preferredCleaner: plan.preferredCleaner,
              status: newStatus,
              nextSessionDate: plan.nextSessionDate,
              lastGeneratedDate: plan.lastGeneratedDate,
              totalSessionsCompleted: plan.totalSessionsCompleted,
            );
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal memperbarui status paket'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerNextSession(CleaningPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jadwalkan Sesi Sekarang?'),
        content: Text(
          'Sistem akan menerbitkan pesanan resmi sesi berikutnya untuk paket "${plan.planName}" '
          'dengan tanggal target: ${plan.nextSessionDate ?? 'sesi terdekat'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Jadwalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await ApiService.generateNextCleaningPlanSession(plan.id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi baru berhasil diterbitkan! Pesanan masuk ke daftar pesanan Anda.'),
          backgroundColor: Colors.green,
        ),
      );
      if (widget.initialPlans == null) {
        _loadPlans();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Gagal menjadwalkan sesi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelPlan(CleaningPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Langganan?'),
        content: Text(
          'Paket "${plan.planName}" akan dibatalkan permanen. Sesi yang belum berjalan tidak akan diterbitkan kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan Paket'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await ApiService.updateCleaningPlanStatus(plan.id, 'Dibatalkan');
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paket langganan berhasil dibatalkan'),
          backgroundColor: Colors.grey,
        ),
      );
      if (widget.initialPlans == null) {
        _loadPlans();
      } else {
        setState(() {
          final idx = _plans.indexWhere((p) => p.id == plan.id);
          if (idx >= 0) {
            _plans[idx] = CleaningPlanModel(
              id: plan.id,
              customerId: plan.customerId,
              planName: plan.planName,
              serviceCategory: plan.serviceCategory,
              serviceId: plan.serviceId,
              frequency: plan.frequency,
              dayOfWeek: plan.dayOfWeek,
              dayName: plan.dayName,
              startTime: plan.startTime,
              duration: plan.duration,
              pricePerSession: plan.pricePerSession,
              address: plan.address,
              landmark: plan.landmark,
              notes: plan.notes,
              preferredCleanerId: plan.preferredCleanerId,
              preferredCleaner: plan.preferredCleaner,
              status: 'Dibatalkan',
              nextSessionDate: plan.nextSessionDate,
              lastGeneratedDate: plan.lastGeneratedDate,
              totalSessionsCompleted: plan.totalSessionsCompleted,
            );
          }
        });
      }
    }
  }

  String _formatKey(String prefix, String id) {
    return '${prefix}_${id.replaceAll('-', '_')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aktif':
        return Colors.green;
      case 'dijeda':
        return Colors.amber[800]!;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paket Langganan Saya'),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('btn_appbar_create_plan'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Paket',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateCleaningPlanScreen()),
              );
              if (created == true) {
                _loadPlans();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlans,
          ),
        ],
      ),
      floatingActionButton: _plans.isNotEmpty
          ? FloatingActionButton.extended(
              key: const Key('fab_create_cleaning_plan'),
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCleaningPlanScreen()),
                );
                if (created == true) {
                  _loadPlans();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Paket'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPlans,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plans.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      return _buildPlanCard(plan);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Paket Langganan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nikmati kemudahan layanan rutin berkala mingguan atau dua mingguan dengan prioritas petugas favorit dan tarif hemat terencana.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('btn_create_cleaning_plan'),
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCleaningPlanScreen()),
                );
                if (created == true) {
                  _loadPlans();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Daftar Layanan Rutin'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(CleaningPlanModel plan) {
    final statusColor = _getStatusColor(plan.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card: Nama & Badge Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.autorenew, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          plan.planName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        plan.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (!plan.isDibatalkan)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'cancel') {
                            _cancelPlan(plan);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Batalkan Paket', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Detail Jadwal
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${plan.dayName}, ${plan.startTime} (${plan.duration} Jam)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plan.frequencyDisplay,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Preferensi Petugas
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.preferredCleaner != null
                        ? 'Petugas Favorit: ${plan.preferredCleaner!.nama} (⭐ ${plan.preferredCleaner!.ratingRataRata})'
                        : 'Petugas: Smart Matching Otomatis',
                    style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Alamat
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Banner Sesi Info (Total Selesai & Sesi Berikutnya)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.task_alt, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        '${plan.totalSessionsCompleted} Sesi Selesai',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (plan.nextSessionDate != null)
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Sesi Berikutnya: ${plan.nextSessionDate}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Aksi Card
            if (!plan.isDibatalkan)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: Key(_formatKey('btn_toggle_status', plan.id)),
                    onPressed: () => _togglePlanStatus(plan),
                    icon: Icon(
                      plan.isAktif ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      size: 16,
                    ),
                    label: Text(plan.isAktif ? 'Jeda' : 'Aktifkan'),
                  ),
                  const SizedBox(width: 8),
                  if (plan.isAktif)
                    ElevatedButton.icon(
                      key: Key(_formatKey('btn_trigger_next_session', plan.id)),
                      onPressed: () => _triggerNextSession(plan),
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('Jadwalkan Sesi Sekarang'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
