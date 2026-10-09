import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/cleaner_model.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/smart_assignment_sheet.dart';
import 'quality_report_screen.dart';

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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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

  String _monitoringFilter = 'aktif';

  List<OrderModel> get _completedOrders => _orders
      .where((o) => o.statusPekerjaan == 'Selesai')
      .toList();

  List<OrderModel> get _cancelledOrders => _orders
      .where((o) => o.statusPekerjaan == 'Dibatalkan')
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

  CleanerModel? _getPreferredCleaner(OrderModel order) {
    if (order.preferensiPetugasId == null || order.preferensiPetugasId!.isEmpty) {
      return null;
    }
    for (final c in _cleaners) {
      if (c.id == order.preferensiPetugasId) {
        return c;
      }
    }
    if (order.cleaner != null && order.cleaner!.id == order.preferensiPetugasId) {
      return order.cleaner;
    }
    return null;
  }

  CleanerModel? _getAssignedCleaner(OrderModel order) {
    if (order.cleaner != null) return order.cleaner;
    if (order.cleanerId == null || order.cleanerId!.isEmpty) return null;
    for (final c in _cleaners) {
      if (c.id == order.cleanerId) return c;
    }
    return null;
  }

  Future<void> _assignCleanerDirectly(OrderModel order, CleanerModel cleaner) async {
    if (_processingOrderId != null) return;
    setState(() => _processingOrderId = order.id);

    try {
      final res = await ApiService.assignCleaner(
        order.id,
        cleaner.id,
        role: 'admin',
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Petugas ${cleaner.nama} (Pilihan Pelanggan) berhasil ditugaskan!'),
            backgroundColor: const Color(0xFF006947),
          ),
        );
        await _loadData();
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
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Butuh Tindakan'),
                          if (_actionRequiredOrders.isNotEmpty) ...[
                            const SizedBox(width: 4),
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
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Monitoring'),
                          if (_monitoringOrders.isNotEmpty) ...[
                            const SizedBox(width: 4),
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
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Tim Petugas'),
                          if (_cleaners.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text('(${_cleaners.length})', style: const TextStyle(fontSize: 11)),
                          ],
                        ],
                      ),
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
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              key: const Key('admin_fab_add_cleaner'),
              backgroundColor: const Color(0xFF006194),
              foregroundColor: Colors.white,
              onPressed: _promptCreateCleaner,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Tambah Petugas',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }


  Widget _buildPipelineCounterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCounterChip(
            key: const Key('counter_chip_konfirmasi'),
            label: '🟡 Konfirmasi',
            count: _countPerluKonfirmasi,
            bg: const Color(0xFFFFF3CD),
            text: const Color(0xFF856404),
            onTap: () {
              _tabController.animateTo(0);
            },
          ),
          const SizedBox(width: 8),
          _buildCounterChip(
            key: const Key('counter_chip_perlu_petugas'),
            label: '🔵 Perlu Petugas',
            count: _countPerluPetugas,
            bg: const Color(0xFFE5EEFF),
            text: const Color(0xFF006194),
            onTap: () {
              _tabController.animateTo(0);
            },
          ),
          const SizedBox(width: 8),
          _buildCounterChip(
            key: const Key('counter_chip_berjalan'),
            label: '🟢 Berjalan',
            count: _countSedangBerjalan,
            bg: const Color(0xFFD4F7DC),
            text: const Color(0xFF006947),
            onTap: () {
              setState(() => _monitoringFilter = 'aktif');
              _tabController.animateTo(1);
            },
          ),
          const SizedBox(width: 8),
          _buildCounterChip(
            key: const Key('counter_chip_tuntas'),
            label: '⚪ Tuntas',
            count: _countTuntas,
            bg: const Color(0xFFF1F5F9),
            text: const Color(0xFF475569),
            onTap: () {
              setState(() => _monitoringFilter = 'selesai');
              _tabController.animateTo(1);
            },
          ),
          const SizedBox(width: 8),
          _buildCounterChip(
            key: const Key('counter_chip_batal'),
            label: '🔴 Batal',
            count: _countDibatalkan,
            bg: const Color(0xFFFFE5E5),
            text: const Color(0xFFBA1A1A),
            onTap: () {
              setState(() => _monitoringFilter = 'batal');
              _tabController.animateTo(1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCounterChip({
    Key? key,
    required String label,
    required int count,
    required Color bg,
    required Color text,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
    final prefCleaner = _getPreferredCleaner(order);
    final hasPreference = order.preferensiPetugasId != null && order.preferensiPetugasId!.isNotEmpty;

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
          const SizedBox(height: 10),

          // Petugas Preference Info Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasPreference ? const Color(0xFFFFF8E6) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPreference ? const Color(0xFFFFD56B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasPreference ? Icons.stars_rounded : Icons.alt_route_rounded,
                  size: 16,
                  color: hasPreference ? const Color(0xFFB78103) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: hasPreference ? 'Pilihan Pelanggan: ' : 'Alokasi Petugas: ',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasPreference ? const Color(0xFF856404) : const Color(0xFF475569),
                          ),
                        ),
                        TextSpan(
                          text: hasPreference
                              ? (prefCleaner?.nama ?? 'Petugas Spesifik')
                              : 'Pilih Otomatis oleh Admin',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: hasPreference ? const Color(0xFF856404) : const Color(0xFF0B1C30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
            if (prefCleaner != null) ...[
              ElevatedButton.icon(
                onPressed: isProcessing ? null : () => _assignCleanerDirectly(order, prefCleaner),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg_rounded, size: 16),
                label: Text(
                  'Tugaskan ${prefCleaner.nama} (Pilihan Pelanggan)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006194),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isProcessing ? null : () => _openSmartAssignment(order),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Ganti / Pilih Petugas Lain'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF006194),
                  minimumSize: const Size.fromHeight(38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFFCCE5FF)),
                ),
              ),
            ] else ...[
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
        ],
      ),
    );
  }

  Widget _buildMonitoringTab() {
    final List<OrderModel> currentOrders;
    switch (_monitoringFilter) {
      case 'selesai':
        currentOrders = _completedOrders;
        break;
      case 'batal':
        currentOrders = _cancelledOrders;
        break;
      case 'aktif':
      default:
        currentOrders = _monitoringOrders;
        break;
    }

    return Column(
      children: [
        _buildMonitoringFilterBar(),
        Expanded(
          child: currentOrders.isEmpty
              ? _buildMonitoringEmptyState()
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: currentOrders.length,
                  itemBuilder: (context, index) {
                    final order = currentOrders[index];
                    if (_monitoringFilter == 'selesai') {
                      return _buildCompletedOrderCard(order);
                    } else if (_monitoringFilter == 'batal') {
                      return _buildCancelledOrderCard(order);
                    } else {
                      return _buildActiveMonitoringOrderCard(order);
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMonitoringFilterBar() {
    return Container(
      color: const Color(0xFFF8F9FF),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMonitoringFilterChip(
              key: const Key('filter_monitoring_aktif'),
              label: 'Sedang Berjalan',
              count: _countSedangBerjalan,
              filterValue: 'aktif',
              activeColor: const Color(0xFF006194),
            ),
            const SizedBox(width: 8),
            _buildMonitoringFilterChip(
              key: const Key('filter_monitoring_selesai'),
              label: 'Tuntas / Selesai',
              count: _countTuntas,
              filterValue: 'selesai',
              activeColor: const Color(0xFF006947),
            ),
            const SizedBox(width: 8),
            _buildMonitoringFilterChip(
              key: const Key('filter_monitoring_batal'),
              label: 'Dibatalkan',
              count: _countDibatalkan,
              filterValue: 'batal',
              activeColor: const Color(0xFFBA1A1A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringFilterChip({
    required Key key,
    required String label,
    required int count,
    required String filterValue,
    required Color activeColor,
  }) {
    final isSelected = _monitoringFilter == filterValue;
    return InkWell(
      key: key,
      onTap: () {
        setState(() {
          _monitoringFilter = filterValue;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringEmptyState() {
    IconData icon;
    Color iconColor;
    String title;
    String description;

    if (_monitoringFilter == 'selesai') {
      icon = Icons.task_alt_rounded;
      iconColor = const Color(0xFF006947);
      title = 'Belum Ada Pesanan Tuntas';
      description = 'Pesanan yang telah diselesaikan oleh petugas beserta laporan mutu digitalnya akan tersimpan di sini.';
    } else if (_monitoringFilter == 'batal') {
      icon = Icons.cancel_outlined;
      iconColor = const Color(0xFFBA1A1A);
      title = 'Tidak Ada Pesanan Dibatalkan';
      description = 'Pesanan yang dibatalkan oleh pelanggan atau pembatalan darurat admin akan tercatat di sini.';
    } else {
      icon = Icons.dashboard_outlined;
      iconColor = const Color(0xFF707881);
      title = 'Tidak Ada Aktivitas Lapangan';
      description = 'Seluruh pesanan aktif yang sedang dikerjakan atau dalam perjalanan petugas akan terpantau di sini.';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 64, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1C30),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

  Widget _buildActiveMonitoringOrderCard(OrderModel order) {
    final cleaner = _getAssignedCleaner(order);

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
          if (cleaner != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE5EEFF),
                    backgroundImage: (cleaner.fotoUrl != null && cleaner.fotoUrl!.isNotEmpty)
                        ? NetworkImage(cleaner.fotoUrl!)
                        : null,
                    child: (cleaner.fotoUrl == null || cleaner.fotoUrl!.isEmpty)
                        ? Text(
                            cleaner.nama.isNotEmpty ? cleaner.nama[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006194),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Petugas: ${cleaner.nama}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B1C30),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  }

  Widget _buildCompletedOrderCard(OrderModel order) {
    final cleaner = _getAssignedCleaner(order);

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
              Expanded(
                child: Text(
                  order.serviceName ?? 'Layanan',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1C30),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F7DC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF006947)),
                    SizedBox(width: 4),
                    Text(
                      'Selesai',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF006947),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.orderCode} • ${order.tanggalLayanan} ${order.startTime} WIB',
            style: const TextStyle(fontSize: 12, color: Color(0xFF707881), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF707881)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.alamatLengkap,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3F4850)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Petugas Pelaksana Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE5EEFF),
                  backgroundImage: (cleaner?.fotoUrl != null && cleaner!.fotoUrl!.isNotEmpty)
                      ? NetworkImage(cleaner.fotoUrl!)
                      : null,
                  child: (cleaner?.fotoUrl == null || cleaner!.fotoUrl!.isEmpty)
                      ? Text(
                          (cleaner?.nama != null && cleaner!.nama.isNotEmpty)
                              ? cleaner.nama[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006194),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Petugas Pelaksana',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF707881),
                        ),
                      ),
                      Text(
                        cleaner?.nama ?? (order.cleanerId ?? 'Petugas Lapangan'),
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B1C30),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormatter.format(order.totalBiaya),
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006194),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Action Button: Lihat Laporan Mutu
          ElevatedButton.icon(
            key: Key('btn_admin_view_qr_${order.id}'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QualityReportScreen(order: order),
                ),
              );
            },
            icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
            label: const Text(
              'Lihat Laporan Mutu',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006194),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledOrderCard(OrderModel order) {
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
              Expanded(
                child: Text(
                  order.serviceName ?? 'Layanan',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1C30),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel_rounded, size: 12, color: Color(0xFFBA1A1A)),
                    SizedBox(width: 4),
                    Text(
                      'Dibatalkan',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBA1A1A),
                      ),
                    ),
                  ],
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF707881)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.alamatLengkap,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3F4850)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFBA1A1A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.cancellationReason != null && order.cancellationReason!.isNotEmpty
                        ? 'Alasan: ${order.cancellationReason}'
                        : 'Pesanan dibatalkan sebelum pelaksanaan pekerjaan.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBA1A1A),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptChangeCleanerStatus(CleanerModel cleaner) async {
    String selectedStatus = cleaner.statusOperasional;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5EEFF),
                        backgroundImage: (cleaner.fotoUrl != null && cleaner.fotoUrl!.isNotEmpty)
                            ? NetworkImage(cleaner.fotoUrl!)
                            : null,
                        child: (cleaner.fotoUrl == null || cleaner.fotoUrl!.isEmpty)
                            ? Text(
                                cleaner.nama.isNotEmpty ? cleaner.nama[0].toUpperCase() : 'C',
                                style: const TextStyle(
                                  color: Color(0xFF006194),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kelola Status Petugas',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B1C30),
                              ),
                            ),
                            Text(
                              '${cleaner.nama} (${cleaner.id})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF707881),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF006194)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status operasional menentukan apakah petugas muncul di algoritma Smart Matching dan dapat menerima penugasan baru.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusOption(
                    title: 'Aktif (Siap Kerja)',
                    subtitle: 'Petugas siap kerja dan otomatis direkomendasikan pada Smart Matching.',
                    value: 'Aktif',
                    groupValue: selectedStatus,
                    color: const Color(0xFF006947),
                    bgColor: const Color(0xFFD4F7DC),
                    onTap: (val) => setSheetState(() => selectedStatus = val),
                  ),
                  const SizedBox(height: 10),
                  _buildStatusOption(
                    title: 'Cuti (Libur Sementara)',
                    subtitle: 'Petugas sedang libur. Dieliminasi dari rekomendasi Smart Matching dan penugasan.',
                    value: 'Cuti',
                    groupValue: selectedStatus,
                    color: const Color(0xFF856404),
                    bgColor: const Color(0xFFFFF3CD),
                    onTap: (val) => setSheetState(() => selectedStatus = val),
                  ),
                  const SizedBox(height: 10),
                  _buildStatusOption(
                    title: 'Nonaktif (Berhenti)',
                    subtitle: 'Petugas dinonaktifkan dari seluruh penugasan operasional.',
                    value: 'Nonaktif',
                    groupValue: selectedStatus,
                    color: const Color(0xFF64748B),
                    bgColor: const Color(0xFFF1F5F9),
                    onTap: (val) => setSheetState(() => selectedStatus = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006194),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving || selectedStatus == cleaner.statusOperasional
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(sheetContext);
                              setSheetState(() => isSaving = true);
                              final res = await ApiService.updateCleanerStatus(
                                cleaner.id,
                                selectedStatus,
                              );
                              if (!mounted) return;
                              navigator.pop();

                              if (res['success'] == true) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Status ${cleaner.nama} berhasil diubah ke $selectedStatus',
                                    ),
                                    backgroundColor: const Color(0xFF006947),
                                  ),
                                );
                                _loadData();
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['message'] ?? 'Gagal memperbarui status petugas',
                                    ),
                                    backgroundColor: const Color(0xFFBA1A1A),
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan Status',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required Color color,
    required Color bgColor,
    required ValueChanged<String> onTap,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF006194) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF006194) : const Color(0xFF0B1C30),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF707881)),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF006194) : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(
    BuildContext ctx, {
    required void Function(ImageSource source) onSourceSelected,
    VoidCallback? onRemove,
  }) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Pilih Sumber Foto Profil Petugas',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0B1C30),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF006194)),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(bCtx);
                onSourceSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF006194)),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(bCtx);
                onSourceSelected(ImageSource.gallery);
              },
            ),
            if (onRemove != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
                title: const Text('Hapus Foto', style: TextStyle(color: Color(0xFFBA1A1A))),
                onTap: () {
                  Navigator.pop(bCtx);
                  onRemove();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCleanerCreatedSuccessDialog(Map<String, dynamic>? data, String defaultName) {
    final nama = data?['nama'] ?? defaultName;
    final email = data?['account']?['email'] ?? 'petugas@resik.in';
    final password = data?['account']?['default_password'] ?? 'PetugasResik123!';
    final fotoUrl = data?['foto_url'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF006947), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Petugas Berhasil Didaftarkan!',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B1C30),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFE5EEFF),
                  backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                      ? NetworkImage(fotoUrl)
                      : null,
                  child: (fotoUrl == null || fotoUrl.isEmpty)
                      ? Text(
                          nama.isNotEmpty ? nama[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006194),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                nama,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B1C30),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fotoUrl != null && fotoUrl.isNotEmpty
                    ? 'Foto profil tersimpan di Supabase Storage & tampil di profil pelanggan saat memesan.'
                    : 'Profil tersimpan dan siap menerima penugasan operasional.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF707881),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kredensial Login Petugas:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B1C30),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF006194),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            password,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0B1C30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Berikan email & kata sandi bawaan ini kepada petugas untuk login di perangkat petugas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'Email: $email\nPassword: $password'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kredensial login berhasil disalin ke clipboard!'),
                  backgroundColor: Color(0xFF006947),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin Kredensial', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF006194),
              side: const BorderSide(color: Color(0xFF006194)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006194),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Selesai', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _promptCreateCleaner() async {
    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController();
    final kontakController = TextEditingController();
    final tentangController = TextEditingController();
    int pengalaman = 2;
    final selectedKeahlian = <String>{'rumah', 'kos'};
    File? selectedImageFile;
    String? selectedImageBase64;
    final picker = ImagePicker();
    bool isSaving = false;

    final availableSkills = [
      {'key': 'rumah', 'label': 'Rumah'},
      {'key': 'kos', 'label': 'Kos'},
      {'key': 'kantor', 'label': 'Kantor'},
      {'key': 'pasca_renovasi', 'label': 'Pasca Renovasi'},
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EEFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Color(0xFF006194),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pendaftaran Petugas Baru',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0B1C30),
                                  ),
                                ),
                                Text(
                                  'Registrasi staf operasional kebersihan & akun login',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF707881),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Foto Profil Petugas
                      Center(
                        child: Stack(
                          children: [
                            GestureDetector(
                              key: const Key('picker_cleaner_photo'),
                              onTap: () {
                                final messenger = ScaffoldMessenger.of(context);
                                _showImageSourceDialog(
                                  context,
                                  onSourceSelected: (source) async {
                                    try {
                                      final picked = await picker.pickImage(
                                        source: source,
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (picked != null) {
                                        final bytes = await picked.readAsBytes();
                                        setSheetState(() {
                                          selectedImageFile = File(picked.path);
                                          selectedImageBase64 = base64Encode(bytes);
                                        });
                                      }
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal memilih foto: $e'),
                                          backgroundColor: const Color(0xFFBA1A1A),
                                        ),
                                      );
                                    }
                                  },
                                  onRemove: selectedImageFile != null
                                      ? () {
                                          setSheetState(() {
                                            selectedImageFile = null;
                                            selectedImageBase64 = null;
                                          });
                                        }
                                      : null,
                                );
                              },
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: const Color(0xFF006194),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: selectedImageFile != null
                                      ? Image.file(
                                          selectedImageFile!,
                                          width: 88,
                                          height: 88,
                                          fit: BoxFit.cover,
                                        )
                                      : const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.camera_alt_outlined,
                                              size: 30,
                                              color: Color(0xFF006194),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Pilih Foto',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF006194),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF006194),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  selectedImageFile != null ? Icons.edit : Icons.add_a_photo,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          selectedImageFile != null
                              ? 'Foto siap diunggah ke profil'
                              : 'Pilih foto profil (Tampil di profil pelanggan saat memilih petugas)',
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedImageFile != null
                                ? const Color(0xFF006947)
                                : const Color(0xFF707881),
                            fontWeight: selectedImageFile != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Info Banner Pembuatan Akun Otomatis
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Akun Login Otomatis:\nSistem akan otomatis membuat akun Supabase Auth dan akun login (email & password bawaan) untuk petugas baru.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nama Petugas
                      const Text(
                        'Nama Lengkap Petugas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0B1C30),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('input_cleaner_nama'),
                        controller: namaController,
                        decoration: InputDecoration(
                          hintText: 'Misal: Budi Santoso',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 3) {
                            return 'Nama wajib diisi minimal 3 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Nomor Kontak / WhatsApp
                      const Text(
                        'Nomor Kontak / WhatsApp',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0B1C30),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('input_cleaner_kontak'),
                        controller: kontakController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Misal: 081234567890',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 8) {
                            return 'Nomor kontak minimal 8 digit';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Keahlian Layanan
                      const Text(
                        'Keahlian Layanan (Pilih minimal 1)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0B1C30),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableSkills.map((skill) {
                          final key = skill['key'] as String;
                          final label = skill['label'] as String;
                          final isSelected = selectedKeahlian.contains(key);
                          return FilterChip(
                            key: Key('skill_chip_$key'),
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE5EEFF),
                            checkmarkColor: const Color(0xFF006194),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF006194) : const Color(0xFF475569),
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF006194) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (selected) {
                              setSheetState(() {
                                if (selected) {
                                  selectedKeahlian.add(key);
                                } else {
                                  if (selectedKeahlian.length > 1) {
                                    selectedKeahlian.remove(key);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Pengalaman Kerja
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pengalaman Kerja (Tahun)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0B1C30),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EEFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$pengalaman Tahun',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006194),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: pengalaman.toDouble(),
                        min: 1,
                        max: 15,
                        divisions: 14,
                        activeColor: const Color(0xFF006194),
                        onChanged: (val) {
                          setSheetState(() => pengalaman = val.round());
                        },
                      ),
                      const SizedBox(height: 8),

                      // Catatan / Deskripsi Singkat
                      const Text(
                        'Catatan / Profil Singkat (Opsional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0B1C30),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: tentangController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Misal: Berpengalaman membersihkan hunian bertingkat',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tombol Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('btn_submit_create_cleaner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006194),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (selectedKeahlian.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Pilih minimal satu keahlian layanan'),
                                        backgroundColor: Color(0xFFBA1A1A),
                                      ),
                                    );
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(sheetContext);
                                  setSheetState(() => isSaving = true);

                                  final res = await ApiService.createCleaner(
                                    nama: namaController.text.trim(),
                                    nomorKontak: kontakController.text.trim(),
                                    keahlian: selectedKeahlian.toList(),
                                    pengalamanTahun: pengalaman,
                                    fotoData: selectedImageBase64,
                                    tentang: tentangController.text.trim().isNotEmpty
                                        ? tentangController.text.trim()
                                        : null,
                                  );

                                  if (!mounted) return;
                                  navigator.pop();

                                  if (res['success'] == true) {
                                    _loadData();
                                    final cleanerData = res['data'] as Map<String, dynamic>?;
                                    _showCleanerCreatedSuccessDialog(
                                      cleanerData,
                                      namaController.text.trim(),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res['message'] ?? 'Gagal mendaftarkan petugas',
                                        ),
                                        backgroundColor: const Color(0xFFBA1A1A),
                                      ),
                                    );
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Daftarkan Petugas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCleanersTab() {
    if (_cleaners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data petugas.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _promptCreateCleaner,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Tambah Petugas Pertama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006194),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _cleaners.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ${_cleaners.length} Petugas Terdaftar',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1C30),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('admin_header_add_cleaner_btn'),
                  onPressed: _promptCreateCleaner,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                  label: const Text('Tambah Petugas', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF006194),
                    side: const BorderSide(color: Color(0xFF006194)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final cleaner = _cleaners[index - 1];

        final status = cleaner.statusOperasional;
        final isAktif = status == 'Aktif';
        final isCuti = status == 'Cuti';

        final badgeBg = isAktif
            ? const Color(0xFFD4F7DC)
            : isCuti
                ? const Color(0xFFFFF3CD)
                : const Color(0xFFF1F5F9);
        final badgeColor = isAktif
            ? const Color(0xFF006947)
            : isCuti
                ? const Color(0xFF856404)
                : const Color(0xFF64748B);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE5EEFF),
                      backgroundImage: (cleaner.fotoUrl != null && cleaner.fotoUrl!.isNotEmpty)
                          ? NetworkImage(cleaner.fotoUrl!)
                          : null,
                      child: (cleaner.fotoUrl == null || cleaner.fotoUrl!.isEmpty)
                          ? Text(
                              cleaner.nama.isNotEmpty ? cleaner.nama[0].toUpperCase() : 'C',
                              style: const TextStyle(
                                color: Color(0xFF006194),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cleaner.nama,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF0B1C30),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '⭐ ${cleaner.ratingRataRata.toStringAsFixed(1)} (${cleaner.totalUlasan} ulasan) • ${cleaner.pengalamanTahun} thn pengalaman',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF707881),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _promptChangeCleanerStatus(cleaner),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text('Status', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF006194),
                        side: const BorderSide(color: Color(0xFF006194)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Keahlian chips
                if (cleaner.keahlian.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: cleaner.keahlian.map((skill) {
                      final label = skill.replaceAll('_', ' ');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'ID: ${cleaner.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${cleaner.totalPekerjaan} tugas tuntas',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006194),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
