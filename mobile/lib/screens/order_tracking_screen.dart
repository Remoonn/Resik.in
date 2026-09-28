import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/operational_simulation_sheet.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  OrderModel? _order;
  bool _isLoading = true;
  Timer? _timer;
  int _elapsedSeconds = 0;
  late AnimationController _pulseController;

  static const List<Map<String, String>> _kOrderSteps = [
    {
      'title': '1. Menunggu Konfirmasi',
      'subtitle': 'Pesanan berhasil dibuat, menunggu konfirmasi mitra',
      'key': 'Menunggu Konfirmasi',
    },
    {
      'title': '2. Dikonfirmasi',
      'subtitle': 'Jadwal dan rincian telah disetujui operasional',
      'key': 'Dikonfirmasi',
    },
    {
      'title': '3. Petugas Ditugaskan',
      'subtitle': 'Mitra kebersihan ditunjuk memimpin tugas',
      'key': 'Petugas Ditugaskan',
    },
    {
      'title': '4. Menuju Lokasi',
      'subtitle': 'Membawa kelengkapan peralatan dan sanitasi',
      'key': 'Menuju Lokasi',
    },
    {
      'title': '5. Tiba di Lokasi',
      'subtitle': 'Check-in dan inspeksi awal ruangan hunian',
      'key': 'Tiba di Lokasi',
    },
    {
      'title': '6. Sedang Dikerjakan',
      'subtitle': 'Pembersihan mendalam sedang berlangsung',
      'key': 'Sedang Dikerjakan',
    },
    {
      'title': '7. Selesai',
      'subtitle': 'Verifikasi mutu pelanggan & serah terima ruangan',
      'key': 'Selesai',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _isLoading = false;
      _initTimer();
    } else {
      _fetchOrder();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _initTimer() {
    _timer?.cancel();
    if (_order != null && _order!.statusPekerjaan == 'Sedang Dikerjakan') {
      DateTime startTime = DateTime.now();
      if (_order!.startedAt != null) {
        startTime = DateTime.tryParse(_order!.startedAt!) ?? DateTime.now();
      }
      _elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
      if (_elapsedSeconds < 0) _elapsedSeconds = 0;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
          });
        }
      });
    }
  }

  Future<void> _fetchOrder() async {
    setState(() => _isLoading = true);
    final fetched = await ApiService.fetchOrderById(widget.orderId);
    if (!mounted) return;

    setState(() {
      _order = fetched;
      _isLoading = false;
    });
    _initTimer();
  }

  String _formatTimer(int totalSecs) {
    final h = (totalSecs ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSecs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  int _getStepIndex(String status) {
    final idx = _kOrderSteps.indexWhere((s) => s['key'] == status);
    return idx == -1 ? 0 : idx;
  }

  bool _canCustomerCancel() {
    if (_order == null) return false;
    final allowed = ['Menunggu Konfirmasi', 'Dikonfirmasi', 'Petugas Ditugaskan'];
    return allowed.contains(_order!.statusPekerjaan);
  }

  void _openSimulationSheet() {
    if (_order == null) return;
    OperationalSimulationSheet.show(
      context,
      order: _order!,
      onOrderUpdated: (updated) {
        setState(() {
          _order = updated;
        });
        _initTimer();
      },
    );
  }

  Future<void> _showCancelDialog() async {
    if (_order == null) return;
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Batalkan Pesanan',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B1C30),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin membatalkan pesanan ini? Masukkan alasan pembatalan:',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: Color(0xFF3F4850),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Misal: Jadwal mendadak berubah...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF707881)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF006194), width: 1.5),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kembali', style: TextStyle(color: Color(0xFF707881))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan pembatalan minimal 5 karakter'),
                    backgroundColor: Color(0xFFBA1A1A),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await ApiService.cancelOrder(_order!.id, reason, role: 'customer');
              if (!mounted) return;

              if (res['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan berhasil dibatalkan'),
                    backgroundColor: Color(0xFF006947),
                  ),
                );
                _fetchOrder();
              } else {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Gagal membatalkan pesanan'),
                    backgroundColor: const Color(0xFFBA1A1A),
                  ),
                );
              }
            },
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0B1C30)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pelacakan Cleaner',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B1C30),
          ),
        ),
        actions: [
          if (AppConfig.kEnableOperationalSimulation)
            IconButton(
              icon: const Icon(Icons.tune, color: Color(0xFF006194)),
              tooltip: 'Simulasi Status Operasional',
              onPressed: _openSimulationSheet,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0B1C30)),
            tooltip: 'Segarkan Status',
            onPressed: _fetchOrder,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: AppConfig.kEnableOperationalSimulation && _order != null
          ? FloatingActionButton.extended(
              onPressed: _openSimulationSheet,
              backgroundColor: const Color(0xFF006194),
              icon: const Icon(Icons.tune, color: Colors.white),
              label: const Text(
                'Simulasi Operasional',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Color(0xFFBA1A1A)),
                      const SizedBox(height: 12),
                      const Text('Data pesanan tidak ditemukan'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchOrder,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrder,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Terminal: Dibatalkan
                        if (_order!.statusPekerjaan == 'Dibatalkan') ...[
                          _buildCancelledCard(),
                          const SizedBox(height: 16),
                        ],

                        // Top Order Info Pill & Pulse Badge
                        _buildHeaderOrderInfo(),
                        const SizedBox(height: 16),

                        // Live Timer & Ambient Progress Card
                        _buildAmbientTimerCard(),
                        const SizedBox(height: 20),

                        // Active Specialist Card
                        _buildCleanerCard(),
                        const SizedBox(height: 24),

                        // 7-Stage Detailed Stepper
                        _build7StageStepper(),
                        const SizedBox(height: 24),

                        // Real-time Checklist Preview
                        _buildRealtimeChecklist(),
                        const SizedBox(height: 20),

                        // Safety Shield Card
                        _buildSafetyShieldCard(),
                        const SizedBox(height: 24),

                        // Tombol Batalkan Pesanan (Customer)
                        if (_canCustomerCancel()) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFBA1A1A),
                              side: const BorderSide(color: Color(0xFFBA1A1A)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 20),
                            label: const Text(
                              'Batalkan Pesanan',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _showCancelDialog,
                          ),
                          const SizedBox(height: 80),
                        ] else
                          const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCancelledCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel, color: Color(0xFFBA1A1A), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pesanan Telah Dibatalkan',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF93000A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alasan: ${_order!.cancellationReason ?? "Dibatalkan oleh sistem"}',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: Color(0xFF93000A),
                  ),
                ),
                if (_order!.cancelledBy != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Dibatalkan oleh: ${_order!.cancelledBy}',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: const Color(0xFF93000A).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderOrderInfo() {
    final currentStatus = _order!.statusPekerjaan;
    final isDispatchedOrActive = currentStatus == 'Sedang Dikerjakan' ||
        currentStatus == 'Menuju Lokasi' ||
        currentStatus == 'Tiba di Lokasi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDispatchedOrActive
                    ? const Color(0xFF006194).withValues(alpha: 0.12)
                    : const Color(0xFFE5EEFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _pulseController,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDispatchedOrActive ? const Color(0xFF006194) : const Color(0xFF006947),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentStatus.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDispatchedOrActive ? const Color(0xFF006194) : const Color(0xFF006947),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '#${_order!.orderCode}',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF707881),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _order!.serviceName ?? 'Layanan Pembersihan',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B1C30),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_order!.alamatLengkap} • Area ${_order!.luasArea}',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            color: Color(0xFF3F4850),
          ),
        ),
      ],
    );
  }

  Widget _buildAmbientTimerCard() {
    final currentStatus = _order!.statusPekerjaan;
    final int stepIdx = _getStepIndex(currentStatus);
    final double progress = ((stepIdx + 1) / 7.0).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006194), Color(0xFF007BB9), Color(0xFF006591)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006194).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timelapse, color: Color(0xFF89CEFF), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Durasi Berjalan',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCCE5FF),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Est. selesai: ${_order!.endTime ?? "14:30"} WIB',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCCE5FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStatus == 'Sedang Dikerjakan'
                        ? _formatTimer(_elapsedSeconds)
                        : (currentStatus == 'Selesai' ? 'TUNTAS' : '00:00:00'),
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentStatus == 'Sedang Dikerjakan'
                        ? 'Pembersihan mendalam sedang aktif'
                        : 'Jadwal layanan: ${_order!.startTime} - ${_order!.endTime ?? ""}',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: Color(0xFFCCE5FF),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Progres Tahap',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      color: Color(0xFFCCE5FF),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6FFBBE)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanerCard() {
    final cleaner = _order!.cleaner;
    final cleanerName = cleaner?.nama ?? 'Menunggu Penetapan Petugas';
    final hasCleaner = cleaner != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE5EEFF),
                    backgroundImage: (cleaner?.fotoUrl != null && cleaner!.fotoUrl!.startsWith('http'))
                        ? NetworkImage(cleaner.fotoUrl!)
                        : null,
                    child: (cleaner?.fotoUrl == null || !cleaner!.fotoUrl!.startsWith('http'))
                        ? const Icon(Icons.person, size: 32, color: Color(0xFF006194))
                        : null,
                  ),
                  if (hasCleaner)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF006947),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified, size: 14, color: Colors.white),
                      ),
                    ),
                ],
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
                            cleanerName,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B1C30),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasCleaner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6FFBBE).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Mitra Pro',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF005236),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCleaner ? 'Mitra Kebersihan Senior' : 'Sedang dialokasikan admin',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Color(0xFF707881),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasCleaner)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            cleaner.ratingRataRata > 0 ? cleaner.ratingRataRata.toStringAsFixed(1) : '4.9',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B1C30),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•  ${cleaner.totalPekerjaan > 0 ? cleaner.totalPekerjaan : 142}+ pekerjaan',
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
            ],
          ),
          if (hasCleaner) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFBFC7D2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.call, size: 18, color: Color(0xFF006194)),
                    label: const Text(
                      'Telepon',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600, color: Color(0xFF006194)),
                    ),
                    onPressed: () {
                      final contact = cleaner.nomorKontak ?? '081234567801';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Menghubungi nomor petugas: $contact'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006194),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat, size: 18, color: Colors.white),
                    label: const Text(
                      'Chat Langsung',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Membuka ruang obrolan dengan ${cleaner.nama}...'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _build7StageStepper() {
    final currentStatus = _order!.statusPekerjaan;
    final activeIdx = _getStepIndex(currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alur Pengerjaan Layanan',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1C30),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6FFBBE).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Tahap ${activeIdx + 1} dari 7',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF005236),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _kOrderSteps.length,
            itemBuilder: (context, index) {
              final step = _kOrderSteps[index];
              final isPassed = index < activeIdx;
              final isActive = index == activeIdx;
              final isLast = index == _kOrderSteps.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline indicator + vertical line
                    Column(
                      children: [
                        if (isPassed)
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFF006947),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 16, color: Colors.white),
                          )
                        else if (isActive)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              FadeTransition(
                                opacity: _pulseController,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF006194).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF006194),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF4FF),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF707881),
                                ),
                              ),
                            ),
                          ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isPassed ? const Color(0xFF006947) : const Color(0xFFE2E8F0),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Text details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  step['title']!,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 14,
                                    fontWeight: isActive ? FontWeight.w700 : (isPassed ? FontWeight.w600 : FontWeight.w500),
                                    color: isActive
                                        ? const Color(0xFF006194)
                                        : (isPassed ? const Color(0xFF0B1C30) : const Color(0xFF707881)),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF006194),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Aktif',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step['subtitle']!,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                color: isPassed || isActive ? const Color(0xFF3F4850) : const Color(0xFF707881).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRealtimeChecklist() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Checklist Pembersihan Real-Time',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B1C30),
                ),
              ),
              Text(
                '2 dari 4 Selesai',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF707881),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('Pembersihan debu plafon & dinding', true, 'Selesai'),
          _buildChecklistItem('Pengikisan sisa semen kering di lantai', true, 'Selesai'),
          _buildChecklistItem('Poles lantai & wet vacuuming', false, 'Sedang Berlangsung', isActive: true),
          _buildChecklistItem('Pembersihan kaca jendela & kusen', false, 'Dalam Antrean'),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isDone, String statusText, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE5EEFF) : const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : (isActive ? Icons.play_circle_fill : Icons.radio_button_unchecked),
              size: 18,
              color: isDone ? const Color(0xFF006947) : (isActive ? const Color(0xFF006194) : const Color(0xFF707881)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? const Color(0xFF707881) : const Color(0xFF0B1C30),
                ),
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDone ? const Color(0xFF006947) : (isActive ? const Color(0xFF006194) : const Color(0xFF707881)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyShieldCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCCE5FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF006194), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'resik.in Safety Shield™',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1C30),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Setiap petugas terikat SOP ketat serta dilindungi garansi perlindungan perabotan hingga Rp15.000.000.',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    color: Color(0xFF3F4850),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
