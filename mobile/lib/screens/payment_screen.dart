import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/service_model.dart';
import '../models/cleaner_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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

    final result = await ApiService.payOrder(_currentOrder.id);

    setState(() {
      _isProcessing = false;
    });

    if (!mounted) return;

    if (result['success'] == true && result['data'] != null) {
      final payData = result['data'];
      setState(() {
        _currentOrder = OrderModel(
          id: _currentOrder.id,
          orderCode: _currentOrder.orderCode,
          serviceId: _currentOrder.serviceId,
          serviceName: _currentOrder.serviceName,
          serviceCategory: _currentOrder.serviceCategory,
          tanggalLayanan: _currentOrder.tanggalLayanan,
          startTime: _currentOrder.startTime,
          endTime: _currentOrder.endTime,
          duration: _currentOrder.duration,
          alamatLengkap: _currentOrder.alamatLengkap,
          patokanLokasi: _currentOrder.patokanLokasi,
          luasArea: _currentOrder.luasArea,
          catatanKhusus: _currentOrder.catatanKhusus,
          hargaSaatBooking: _currentOrder.hargaSaatBooking,
          totalBiaya: _currentOrder.totalBiaya,
          statusPembayaran: payData['status_pembayaran'] ?? 'Sudah Bayar',
          paymentTimestamp: payData['payment_timestamp'],
          statusPekerjaan: _currentOrder.statusPekerjaan,
          preferensiPetugasId: _currentOrder.preferensiPetugasId,
          createdAt: _currentOrder.createdAt,
        );
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 56),
          title: const Text(
            'Pembayaran Terverifikasi!',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simulasi pembayaran server-authoritative berhasil divalidasi.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status Pekerjaan:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        Text(
                          _currentOrder.statusPekerjaan,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Waktu Server:', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        Text(
                          _currentOrder.paymentTimestamp ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal memproses pembayaran'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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

            // 4. Catatan Server-Authoritative
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Prototipe V1 Resik.in menggunakan simulasi checkout server-authoritative. Pembayaran divalidasi dan dicatat riil di database backend.',
                      style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Tombol Simulasi Pembayaran (Pill Button)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const Key('btn_simulasi_bayar'),
                icon: Icon(isPaid ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded, size: 20),
                label: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isPaid ? 'Pembayaran Telah Lunas' : 'Bayar Sekarang (Simulasi)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaid ? AppColors.emerald : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                onPressed: (isPaid || _isProcessing) ? null : _handlePayment,
              ),
            ),
          ],
        ),
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
