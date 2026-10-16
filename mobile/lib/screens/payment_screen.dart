import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/service_model.dart';
import '../models/cleaner_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_tracking_screen.dart';
import 'midtrans_snap_screen.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel order;
  final ServiceModel? service;
  final CleanerModel? selectedCleaner;

  const PaymentScreen({
    super.key,
    required this.order,
    this.service,
    this.selectedCleaner,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late OrderModel _currentOrder;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final tokenRes = await ApiService.getSnapPaymentToken(_currentOrder.id);
      if (tokenRes['success'] != true || tokenRes['data'] == null) {
        throw Exception(tokenRes['message'] ?? 'Gagal membuat sesi pembayaran');
      }

      final redirectUrl = tokenRes['data']['redirect_url']?.toString() ?? '';

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      // Buka In-App WebView Midtrans Snap
      final bool? isSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => MidtransSnapScreen(
            redirectUrl: redirectUrl,
            orderCode: _currentOrder.orderCode,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = true;
      });

      // Jalur B: Direct Status Check ke Midtrans Server via backend API
      final statusRes = await ApiService.checkPaymentStatus(_currentOrder.id);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      if (statusRes['success'] == true && statusRes['data'] != null) {
        final updatedOrder = OrderModel.fromJson(statusRes['data'] as Map<String, dynamic>);
        setState(() {
          _currentOrder = updatedOrder;
        });

        if (updatedOrder.statusPembayaran == 'Sudah Bayar') {
          if (!mounted) return;
          _showDigitalReceiptModal(context, updatedOrder);
          return;
        }
      }

      if (isSuccess == true) {
        final refreshed = await ApiService.fetchOrderById(_currentOrder.id);
        if (refreshed != null && mounted) {
          setState(() => _currentOrder = refreshed);
          if (refreshed.statusPembayaran == 'Sudah Bayar') {
            _showDigitalReceiptModal(context, refreshed);
            return;
          }
        }
      }

      // Jika belum selesai atau dibatalkan pengguna
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Pembayaran belum selesai. Anda dapat mencoba lagi kapan saja.'),
                ),
              ],
            ),
            backgroundColor: AppColors.onSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: AppColors.secondaryContainer,
              onPressed: _handlePayment,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDigitalReceiptModal(BuildContext context, OrderModel order) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.emeraldLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.emerald,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pembayaran Berhasil!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kuitansi Pembayaran Digital',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Dibayar:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      Text(
                        currencyFormatter.format(order.totalBiaya),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.emerald),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Metode:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      Text(
                        (order.paymentMethod ?? 'Midtrans').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ID Transaksi:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      Flexible(
                        child: Text(
                          order.paymentTransactionId ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Waktu Bayar:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      Text(
                        order.paymentTimestamp != null
                            ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.tryParse(order.paymentTimestamp!)?.toLocal() ?? DateTime.now())
                            : '-',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => OrderTrackingScreen(
                        orderId: order.id,
                        initialOrder: order,
                      ),
                    ),
                  );
                },
                child: const Text('Lacak Pesanan Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final isPaid = _currentOrder.statusPembayaran == 'Sudah Bayar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rincian & Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Order Code & Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPaid ? AppColors.emeraldLight : AppColors.amberLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaid ? AppColors.emerald.withValues(alpha: 0.3) : AppColors.warmAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KODE PESANAN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 0.8,
                              color: isPaid ? AppColors.emeraldDark : AppColors.amberDark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentOrder.orderCode.isNotEmpty ? _currentOrder.orderCode : 'RSK-ORD-NEW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isPaid ? AppColors.emeraldDark : AppColors.amberDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid ? AppColors.emerald : AppColors.warmAmber,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentOrder.statusPembayaran,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Rincian Layanan & Jadwal Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rincian Pesanan',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Layanan', _currentOrder.serviceName ?? 'Pembersihan Standar'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Tanggal', _currentOrder.tanggalLayanan),
                  const SizedBox(height: 10),
                  _buildInfoRow('Jam Mulai', '${_currentOrder.startTime} WIB'),
                  if (_currentOrder.endTime != null) ...[
                    const SizedBox(height: 10),
                    _buildInfoRow('Estimasi Selesai', '${_currentOrder.endTime} WIB'),
                  ],
                  const SizedBox(height: 10),
                  _buildInfoRow('Durasi', '${_currentOrder.duration} Jam'),
                  const SizedBox(height: 10),
                  _buildInfoRow('Alamat Lokasi', _currentOrder.alamatLengkap),
                  const SizedBox(height: 10),
                  _buildInfoRow('Patokan', _currentOrder.patokanLokasi),
                  const SizedBox(height: 10),
                  _buildInfoRow('Luas / Tipe', _currentOrder.luasArea),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Preferensi Petugas',
                    widget.selectedCleaner != null
                        ? '${widget.selectedCleaner!.nama} (${widget.selectedCleaner!.ratingRataRata > 0 ? "⭐ ${widget.selectedCleaner!.ratingRataRata.toStringAsFixed(1)}" : "Petugas Baru 4.5"})'
                        : 'Pilihkan Otomatis oleh Admin',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Snapshot Tarif Flat Deterministik
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rincian Pembayaran (Tarif Flat)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tarif Dasar Layanan', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                      Text(
                        currencyFormatter.format(_currentOrder.hargaSaatBooking),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Biaya Layanan & Admin', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                      Text('Rp 0', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                      ),
                      Text(
                        currencyFormatter.format(_currentOrder.totalBiaya),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. Kanal Pembayaran Resmi (Midtrans Badges)
            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Metode Pembayaran Tersedia',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPaymentChip(Icons.qr_code_2_rounded, 'QRIS'),
                        _buildPaymentChip(Icons.account_balance_rounded, 'Virtual Account'),
                        _buildPaymentChip(Icons.account_balance_wallet_rounded, 'GoPay'),
                        _buildPaymentChip(Icons.credit_card_rounded, 'Kartu Kredit / Debit'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Diproses secara aman via Midtrans Payment Gateway dengan enkripsi 256-bit SSL.',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Tombol Pembayaran / Lacak Status (Pill Button)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const Key('btn_simulasi_bayar'),
                icon: Icon(isPaid ? Icons.timeline_rounded : Icons.lock_outline_rounded, size: 20),
                label: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isPaid ? 'Lacak Status Pesanan' : 'Pilih Metode Pembayaran',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                onPressed: _isProcessing
                    ? null
                    : (isPaid
                        ? () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => OrderTrackingScreen(
                                  orderId: _currentOrder.id,
                                  initialOrder: _currentOrder,
                                ),
                              ),
                            );
                          }
                        : _handlePayment),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          ),
        ),
      ],
    );
  }
}
