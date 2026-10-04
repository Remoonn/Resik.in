import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cleaner_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/smart_assignment_sheet.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Future<List<OrderModel>> Function()? ordersLoader;
  final Future<List<CleanerModel>> Function()? cleanersLoader;

  const AdminDashboardScreen({
    super.key,
    this.ordersLoader,
    this.cleanersLoader,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderModel> _orders = [];
  List<CleanerModel> _cleaners = [];
  bool _isLoading = true;
  String? _processingOrderId;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.ordersLoader != null && widget.cleanersLoader != null) {
        final results = await Future.wait([
          widget.ordersLoader!(),
          widget.cleanersLoader!(),
        ]);
        _orders = results[0] as List<OrderModel>;
        _cleaners = results[1] as List<CleanerModel>;
      } else {
        final results = await Future.wait([
          ApiService.fetchOrders(role: 'admin'),
          ApiService.fetchCleaners(),
        ]);
        _orders = results[0] as List<OrderModel>;
        _cleaners = results[1] as List<CleanerModel>;
      }
    } catch (_) {
      _orders = [];
      _cleaners = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Pipeline counts
  int get _countPerluKonfirmasi =>
      _orders.where((o) => o.statusPekerjaan == 'Menunggu Konfirmasi').length;
  int get _countPerluPetugas =>
      _orders.where((o) => o.statusPekerjaan == 'Dikonfirmasi').length;
  int get _countSedangBerjalan => _orders.where((o) => [
        'Petugas Ditugaskan',
        'Menuju Lokasi',
        'Tiba di Lokasi',
        'Sedang Dikerjakan',
      ].contains(o.statusPekerjaan)).length;
  int get _countTuntas =>
      _orders.where((o) => o.statusPekerjaan == 'Selesai').length;
  int get _countDibatalkan =>
      _orders.where((o) => o.statusPekerjaan == 'Dibatalkan').length;

  List<OrderModel> get _actionRequiredOrders => _orders
      .where((o) =>
          o.statusPekerjaan == 'Menunggu Konfirmasi' ||
          o.statusPekerjaan == 'Dikonfirmasi')
      .toList();

  List<OrderModel> get _monitoringOrders => _orders
      .where((o) => [
            'Petugas Ditugaskan',
            'Menuju Lokasi',
            'Tiba di Lokasi',
            'Sedang Dikerjakan',
          ].contains(o.statusPekerjaan))
      .toList();

  Future<void> _confirmOrder(OrderModel order) async {
    if (_processingOrderId != null) return;
    setState(() => _processingOrderId = order.id);

    try {
      final res = await ApiService.updateOrderStatus(
        order.id,
        'Dikonfirmasi',
        role: 'admin',
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dikonfirmasi'),
            backgroundColor: Color(0xFF006947),
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal mengonfirmasi pesanan'),
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
        setState(() => _processingOrderId = null);
      }
    }
  }

  Future<void> _openSmartAssignment(OrderModel order) async {
    final assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartAssignmentSheet(order: order),
    );

    if (assigned == true) {
      _loadData();
    }
  }

  Future<void> _promptEmergencyCancel(OrderModel order) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pesanan Darurat'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kode: ${order.orderCode} (${order.serviceName})'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan Pembatalan (Audit)',
                  hintText: 'Misal: Insiden lapangan atau permintaan darurat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Alasan minimal 5 karakter';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A)),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiService.cancelOrder(
        order.id,
        reasonController.text.trim(),
        role: 'admin',
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibatalkan'),
            backgroundColor: Color(0xFF006947),
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal membatalkan pesanan'),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menara Kontrol Admin',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1C30),
              ),
            ),
            Text(
              'Operasional & Manajemen Petugas',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                color: Color(0xFF707881),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0B1C30)),
            tooltip: 'Segarkan',
            onPressed: _loadData,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Pipeline Counter Bar
              _buildPipelineCounterBar(),
              // TabBar
              TabBar(
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
                        const Text('Butuh Tindakan'),
                        if (_actionRequiredOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBA1A1A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_actionRequiredOrders.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                        const Text('Monitoring'),
                        if (_monitoringOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006194),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_monitoringOrders.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                        const Text('Tim Petugas'),
                        if (_cleaners.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('(${_cleaners.length})', style: const TextStyle(fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActionRequiredTab(),
                  _buildMonitoringTab(),
                  _buildCleanersTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildPipelineCounterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCounterChip('🟡 Konfirmasi', _countPerluKonfirmasi, const Color(0xFFFFF3CD), const Color(0xFF856404)),
          const SizedBox(width: 8),
          _buildCounterChip('🔵 Perlu Petugas', _countPerluPetugas, const Color(0xFFE5EEFF), const Color(0xFF006194)),
          const SizedBox(width: 8),
          _buildCounterChip('🟢 Berjalan', _countSedangBerjalan, const Color(0xFFD4F7DC), const Color(0xFF006947)),
          const SizedBox(width: 8),
          _buildCounterChip('⚪ Tuntas', _countTuntas, const Color(0xFFF1F5F9), const Color(0xFF475569)),
          const SizedBox(width: 8),
          _buildCounterChip('🔴 Batal', _countDibatalkan, const Color(0xFFFFE5E5), const Color(0xFFBA1A1A)),
        ],
      ),
    );
  }

  Widget _buildCounterChip(String label, int count, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            ': $count',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRequiredTab() {
    if (_actionRequiredOrders.isEmpty) {
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
                  Icon(Icons.verified_rounded, size: 64, color: Color(0xFF006947)),
                  SizedBox(height: 16),
                  Text(
                    'Operasional Terkendali',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tidak ada pesanan yang memerlukan konfirmasi pembayaran atau penugasan petugas saat ini.',
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
      itemCount: _actionRequiredOrders.length,
      itemBuilder: (context, index) {
        return _buildActionOrderCard(_actionRequiredOrders[index]);
      },
    );
  }

  Widget _buildActionOrderCard(OrderModel order) {
    final isMenungguKonfirmasi = order.statusPekerjaan == 'Menunggu Konfirmasi';
    final isDikonfirmasi = order.statusPekerjaan == 'Dikonfirmasi';
    final isLunas = order.statusPembayaran == 'Sudah Bayar';
    final isProcessing = _processingOrderId == order.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.serviceName ?? 'Layanan',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1C30),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLunas ? const Color(0xFFD4F7DC) : const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.statusPembayaran,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLunas ? const Color(0xFF006947) : const Color(0xFFBA1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.orderCode} • ${order.tanggalLayanan} ${order.startTime} WIB',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF707881),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${order.alamatLengkap} (Patokan: ${order.patokanLokasi})',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF3F4850)),
          ),
          const Divider(height: 20),

          // Actions
          if (isMenungguKonfirmasi) ...[
            if (isLunas)
              ElevatedButton.icon(
                onPressed: isProcessing ? null : () => _confirmOrder(order),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Konfirmasi Pesanan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006947),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: null, // Disabled per BR-FIN-001
                icon: const Icon(Icons.lock_clock_rounded, size: 16),
                label: const Text('Menunggu Pembayaran Pelanggan'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
          ] else if (isDikonfirmasi) ...[
            ElevatedButton.icon(
              onPressed: () => _openSmartAssignment(order),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Tugaskan Petugas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006194),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonitoringTab() {
    if (_monitoringOrders.isEmpty) {
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
                  Icon(Icons.dashboard_outlined, size: 64, color: Color(0xFF707881)),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada aktivitas lapangan saat ini',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Seluruh pesanan aktif yang sedang dikerjakan atau dalam perjalanan akan terpantau di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF707881)),
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
      itemCount: _monitoringOrders.length,
      itemBuilder: (context, index) {
        final order = _monitoringOrders[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.serviceName ?? 'Layanan',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEFF),
                      borderRadius: BorderRadius.circular(8),
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
                '${order.orderCode} • ${order.tanggalLayanan} ${order.startTime} WIB',
                style: const TextStyle(fontSize: 12, color: Color(0xFF707881)),
              ),
              const SizedBox(height: 6),
              Text(
                'Alamat: ${order.alamatLengkap}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF3F4850)),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _promptEmergencyCancel(order),
                    icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFBA1A1A)),
                    label: const Text('Batal Darurat', style: TextStyle(color: Color(0xFFBA1A1A), fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFD5D5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openSmartAssignment(order),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Ganti Petugas', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006194),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCleanersTab() {
    if (_cleaners.isEmpty) {
      return const Center(child: Text('Belum ada data petugas.'));
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _cleaners.length,
      itemBuilder: (context, index) {
        final cleaner = _cleaners[index];
        final isActive = cleaner.statusOperasional == 'Aktif';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE5EEFF),
              child: Text(
                cleaner.nama.isNotEmpty ? cleaner.nama[0].toUpperCase() : 'C',
                style: const TextStyle(color: Color(0xFF006194), fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Text(
                  cleaner.nama,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFD4F7DC) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cleaner.statusOperasional,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF006947) : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '⭐ ${cleaner.ratingRataRata.toStringAsFixed(1)} (${cleaner.totalUlasan} ulasan) • ${cleaner.pengalamanTahun} thn pengalaman',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              '${cleaner.totalPekerjaan} tugas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
