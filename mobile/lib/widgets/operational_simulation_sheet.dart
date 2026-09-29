import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import 'quality_report_form_sheet.dart';

class OperationalSimulationSheet extends StatefulWidget {
  final OrderModel order;
  final ValueChanged<OrderModel>? onOrderUpdated;

  const OperationalSimulationSheet({
    super.key,
    required this.order,
    this.onOrderUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    ValueChanged<OrderModel>? onOrderUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OperationalSimulationSheet(
        order: order,
        onOrderUpdated: onOrderUpdated,
      ),
    );
  }

  @override
  State<OperationalSimulationSheet> createState() => _OperationalSimulationSheetState();
}

class _OperationalSimulationSheetState extends State<OperationalSimulationSheet> {
  bool _isLoading = false;
  late OrderModel _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  Future<void> _executeAction({
    required Future<Map<String, dynamic>> Function() action,
    required String successMessage,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await action();
      if (!mounted) return;

      if (res['success'] == true) {
        // Ambil detail terbaru
        final updated = await ApiService.fetchOrderById(_currentOrder.id);
        if (updated != null && mounted) {
          setState(() => _currentOrder = updated);
          widget.onOrderUpdated?.call(updated);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF006947), // tertiary
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Aksi gagal dilakukan'),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune,
                  color: Color(0xFF006194),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simulasi Operasional',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B1C30),
                      ),
                    ),
                    Text(
                      'Status saat ini: ${_currentOrder.statusPekerjaan}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Color(0xFF707881),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFC7D2)),
                ),
                child: const Text(
                  'Mode Uji Coba',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006194),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Gunakan tombol di bawah untuk memajukan status pesanan seolah-olah Anda adalah Admin atau Petugas di lapangan:',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              color: Color(0xFF3F4850),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // 1. Menunggu Konfirmasi -> Dikonfirmasi (Admin)
            if (_currentOrder.statusPekerjaan == 'Menunggu Konfirmasi')
              _buildActionButton(
                icon: Icons.check_circle_outline,
                title: 'Konfirmasi Pesanan (Admin)',
                subtitle: 'Memvalidasi pembayaran dan menyetujui jadwal layanan',
                color: const Color(0xFF006194),
                onTap: () {
                  _executeAction(
                    action: () => ApiService.updateOrderStatus(
                      _currentOrder.id,
                      'Dikonfirmasi',
                      role: 'admin',
                    ),
                    successMessage: 'Pesanan berhasil dikonfirmasi oleh Admin',
                  );
                },
              ),

            // 2. Dikonfirmasi -> Petugas Ditugaskan (Admin)
            if (_currentOrder.statusPekerjaan == 'Dikonfirmasi')
              _buildActionButton(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Tugaskan Petugas (Admin)',
                subtitle: 'Menetapkan Candra Pratama (cln-001) bebas bentrok jadwal',
                color: const Color(0xFF006947),
                onTap: () {
                  _executeAction(
                    action: () => ApiService.assignCleaner(
                      _currentOrder.id,
                      _currentOrder.preferensiPetugasId ?? 'cln-001',
                      role: 'admin',
                    ),
                    successMessage: 'Petugas Candra Pratama berhasil ditugaskan',
                  );
                },
              ),

            // 3. Petugas Ditugaskan -> Menuju Lokasi (Cleaner)
            if (_currentOrder.statusPekerjaan == 'Petugas Ditugaskan')
              _buildActionButton(
                icon: Icons.two_wheeler_outlined,
                title: 'Menuju Lokasi (Petugas)',
                subtitle: 'Petugas berangkat membawa kelengkapan sanitasi',
                color: const Color(0xFF0284C7),
                onTap: () {
                  _executeAction(
                    action: () => ApiService.updateOrderStatus(
                      _currentOrder.id,
                      'Menuju Lokasi',
                      role: 'cleaner',
                    ),
                    successMessage: 'Status diperbarui: Petugas menuju lokasi',
                  );
                },
              ),

            // 4. Menuju Lokasi -> Tiba di Lokasi (Cleaner)
            if (_currentOrder.statusPekerjaan == 'Menuju Lokasi')
              _buildActionButton(
                icon: Icons.location_on_outlined,
                title: 'Tiba di Lokasi (Petugas)',
                subtitle: 'Petugas telah sampai di alamat dan siap inspeksi',
                color: const Color(0xFF0284C7),
                onTap: () {
                  _executeAction(
                    action: () => ApiService.updateOrderStatus(
                      _currentOrder.id,
                      'Tiba di Lokasi',
                      role: 'cleaner',
                    ),
                    successMessage: 'Status diperbarui: Petugas tiba di lokasi',
                  );
                },
              ),

            // 5. Tiba di Lokasi -> Sedang Dikerjakan (Cleaner)
            if (_currentOrder.statusPekerjaan == 'Tiba di Lokasi')
              _buildActionButton(
                icon: Icons.cleaning_services_outlined,
                title: 'Mulai Pengerjaan (Petugas)',
                subtitle: 'Memulai pembersihan ruangan & mengaktifkan timer pengerjaan',
                color: const Color(0xFF006947),
                onTap: () {
                  _executeAction(
                    action: () => ApiService.updateOrderStatus(
                      _currentOrder.id,
                      'Sedang Dikerjakan',
                      role: 'cleaner',
                    ),
                    successMessage: 'Status diperbarui: Pekerjaan sedang berlangsung',
                  );
                },
              ),

            // 6. Sedang Dikerjakan -> Selesaikan Pekerjaan via Laporan Mutu
            if (_currentOrder.statusPekerjaan == 'Sedang Dikerjakan')
              _buildActionButton(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Selesaikan Pekerjaan (Kirim Laporan Mutu)',
                subtitle: 'Isi checklist mutu & unggah foto bukti pengerjaan',
                color: const Color(0xFF00796B),
                onTap: () async {
                  await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => QualityReportFormSheet(
                      order: _currentOrder,
                      onSubmitted: (report) async {
                        final updated = await ApiService.fetchOrderById(_currentOrder.id);
                        if (updated != null && mounted) {
                          setState(() => _currentOrder = updated);
                          widget.onOrderUpdated?.call(updated);
                        }
                      },
                    ),
                  );
                },
              ),

            // Status Terminal
            if (_currentOrder.statusPekerjaan == 'Dibatalkan' || _currentOrder.statusPekerjaan == 'Selesai')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Pesanan berada pada status akhir (${_currentOrder.statusPekerjaan}).',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF707881),
                    ),
                  ),
                ),
              ),

            // Opsi Pembatalan Darurat Admin
            if (_currentOrder.statusPekerjaan != 'Dibatalkan' && _currentOrder.statusPekerjaan != 'Selesai') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBA1A1A),
                  side: const BorderSide(color: Color(0xFFFFDAD6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text(
                  'Batalkan Pesanan (Aksi Darurat Admin)',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _showEmergencyCancelDialog(),
              ),
            ],
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: Color(0xFF3F4850),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyCancelDialog() {
    final reasonController = TextEditingController(text: 'Kendala teknis darurat di lokasi');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pembatalan Darurat Admin', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alasan pembatalan operasional darurat:',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Alasan pembatalan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A)),
            onPressed: () {
              Navigator.pop(ctx);
              _executeAction(
                action: () => ApiService.cancelOrder(
                  _currentOrder.id,
                  reasonController.text.trim(),
                  role: 'admin',
                ),
                successMessage: 'Pesanan berhasil dibatalkan oleh Admin',
              );
            },
            child: const Text('Konfirmasi Batal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
