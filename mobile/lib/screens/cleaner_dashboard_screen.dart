import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/role_switcher_sheet.dart';
import 'quality_report_screen.dart';

class CleanerDashboardScreen extends StatefulWidget {
  final Future<List<OrderModel>> Function()? ordersLoader;

  const CleanerDashboardScreen({
    super.key,
    this.ordersLoader,
  });

  @override
  State<CleanerDashboardScreen> createState() => _CleanerDashboardScreenState();
}

class _CleanerDashboardScreenState extends State<CleanerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _allOrders = [];
  bool _isLoading = true;
  String? _updatingOrderId;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      if (widget.ordersLoader != null) {
        _allOrders = await widget.ordersLoader!();
      } else {
        final cleanerId = AuthService().currentUser?.cleanerId;
        _allOrders = await ApiService.fetchOrders(
          cleanerId: cleanerId,
          role: 'cleaner',
        );
      }
    } catch (_) {
      _allOrders = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<OrderModel> get _activeOrders {
    final activeStatuses = [
      'Petugas Ditugaskan',
      'Menuju Lokasi',
      'Tiba di Lokasi',
      'Sedang Dikerjakan',
    ];
    return _allOrders.where((o) => activeStatuses.contains(o.statusPekerjaan)).toList();
  }

  List<OrderModel> get _completedOrders {
    return _allOrders.where((o) => o.statusPekerjaan == 'Selesai').toList();
  }

  Future<void> _updateStatus(OrderModel order, String nextStatus) async {
    if (_updatingOrderId != null) return; // Debounce

    setState(() => _updatingOrderId = order.id);

    try {
      final res = await ApiService.updateOrderStatus(
        order.id,
        nextStatus,
        role: 'cleaner',
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status berhasil diperbarui menjadi "$nextStatus"'),
            backgroundColor: const Color(0xFF006947),
          ),
        );
        await _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal memperbarui status'),
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
        setState(() => _updatingOrderId = null);
      }
    }
  }

  Future<void> _openGoogleMaps(String alamat) async {
    final encoded = Uri.encodeComponent(alamat);
    final geoUri = Uri.parse('geo:0,0?q=$encoded');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka aplikasi peta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.nama ?? 'Petugas Lapangan',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1C30),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006947),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Aktif Bertugas',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006947),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF006194)),
            tooltip: 'Ganti Peran Demonstrasi',
            onPressed: () => RoleSwitcherSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0B1C30)),
            tooltip: 'Segarkan',
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFBA1A1A)),
            tooltip: 'Keluar',
            onPressed: () async {
              await AuthService().logout();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF006194),
          unselectedLabelColor: const Color(0xFF707881),
          indicatorColor: const Color(0xFF006194),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tugas Berjalan'),
                  if (_activeOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006194),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activeOrders.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Riwayat Pekerjaan'),
                  if (_completedOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006947),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_completedOrders.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveOrdersTab(),
                  _buildCompletedOrdersTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveOrdersTab() {
    if (_activeOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF006947)),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada tugas aktif saat ini',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Anda sedang dalam status siaga (Aktif). Tarik layar ke bawah untuk memeriksa pesanan baru yang ditugaskan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: Color(0xFF707881),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _activeOrders.length,
      itemBuilder: (context, index) {
        return _buildActiveOrderCard(_activeOrders[index]);
      },
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final isProcessing = _updatingOrderId == order.id;

    String nextStatus = '';
    String actionLabel = '';
    IconData actionIcon = Icons.arrow_forward;
    Color actionColor = const Color(0xFF006194);
    bool isQualityReport = false;

    switch (order.statusPekerjaan) {
      case 'Petugas Ditugaskan':
        nextStatus = 'Menuju Lokasi';
        actionLabel = 'Mulai Berangkat (Menuju Lokasi)';
        actionIcon = Icons.directions_bike_rounded;
        break;
      case 'Menuju Lokasi':
        nextStatus = 'Tiba di Lokasi';
        actionLabel = 'Saya Sudah Tiba di Lokasi';
        actionIcon = Icons.place_rounded;
        break;
      case 'Tiba di Lokasi':
        nextStatus = 'Sedang Dikerjakan';
        actionLabel = 'Mulai Pengerjaan';
        actionIcon = Icons.play_arrow_rounded;
        actionColor = const Color(0xFF006947);
        break;
      case 'Sedang Dikerjakan':
        isQualityReport = true;
        actionLabel = 'Tuntaskan & Buat Laporan Mutu';
        actionIcon = Icons.assignment_turned_in_rounded;
        actionColor = const Color(0xFF006947);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama Layanan & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.serviceName ?? 'Layanan Kebersihan',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1C30),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.statusPekerjaan,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF006194),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.orderCode,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF707881),
            ),
          ),
          const Divider(height: 24),

          // Detail Hunian & Waktu
          _buildInfoRow(Icons.calendar_today_rounded, '${order.tanggalLayanan} • ${order.startTime} WIB (${order.duration} jam)'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on_rounded, order.alamatLengkap),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.map_rounded, 'Patokan: ${order.patokanLokasi}'),
          if (order.catatanKhusus != null && order.catatanKhusus!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.note_alt_rounded, 'Catatan: ${order.catatanKhusus}'),
          ],

          const SizedBox(height: 16),

          // Tombol Navigasi Peta
          OutlinedButton.icon(
            onPressed: () => _openGoogleMaps(order.alamatLengkap),
            icon: const Icon(Icons.navigation_rounded, size: 18),
            label: const Text('Navigasi Peta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF006194),
              side: const BorderSide(color: Color(0xFFCCE5FF)),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 10),

          // Tombol Aksi Lapangan Bertahap
          ElevatedButton.icon(
            onPressed: isProcessing
                ? null
                : () async {
                    if (isQualityReport) {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QualityReportScreen(
                            order: order,
                          ),
                        ),
                      );
                      if (updated == true) {
                        _loadOrders();
                      }
                    } else {
                      _updateStatus(order, nextStatus);
                    }
                  },
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(actionIcon, size: 18),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedOrdersTab() {
    if (_completedOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.history_rounded, size: 64, color: Color(0xFF707881)),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat pekerjaan',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Riwayat pekerjaan Anda akan dicatat di sini setelah Anda menyelesaikan laporan mutu pekerjaan pertama Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: Color(0xFF707881),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _completedOrders.length,
      itemBuilder: (context, index) {
        final order = _completedOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.serviceName ?? 'Layanan Kebersihan',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0B1C30),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4F7DC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          color: Color(0xFF006947),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.orderCode} • ${order.tanggalLayanan}',
                  style: const TextStyle(
                    color: Color(0xFF707881),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.alamatLengkap,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3F4850)),
                ),
                const Divider(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QualityReportScreen(
                            order: order,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_turned_in, size: 16, color: Color(0xFF006194)),
                    label: const Text(
                      'Lihat Laporan Mutu',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF006194),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF707881)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              color: Color(0xFF3F4850),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
