import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class MidtransSnapScreen extends StatefulWidget {
  final String redirectUrl;
  final String orderCode;
  final WebViewController? controller;
  final String? paymentMethod;
  final double? totalBiaya;

  const MidtransSnapScreen({
    super.key,
    required this.redirectUrl,
    required this.orderCode,
    this.controller,
    this.paymentMethod,
    this.totalBiaya,
  });

  @override
  State<MidtransSnapScreen> createState() => _MidtransSnapScreenState();
}

class _MidtransSnapScreenState extends State<MidtransSnapScreen> {
  WebViewController? _controller;
  int _loadingProgress = 0;

  bool get _isMock =>
      widget.redirectUrl.contains('mock-snap-') ||
      widget.redirectUrl.contains('mock-token');

  @override
  void initState() {
    super.initState();
    if (_isMock) {
      // Dalam mode mock/simulator, tidak perlu menginisialisasi WebView eksternal
      return;
    }

    if (widget.controller != null) {
      _controller = widget.controller;
    } else if (WebViewPlatform.instance != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _loadingProgress = progress);
            },
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url.toLowerCase();
              // Cek apakah callback return sukses
              if (url.contains('status_code=200') ||
                  url.contains('transaction_status=settlement') ||
                  url.contains('#/finish') ||
                  url.contains('/finish')) {
                Navigator.of(context).pop(true);
                return NavigationDecision.prevent;
              }
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                return NavigationDecision.prevent; // cegah crash skema eksternal
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.redirectUrl));
    }
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Pembayaran?'),
        content: const Text(
          'Pesanan Anda tetap tersimpan. Anda dapat melanjutkan pembayaran nanti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjut Bayar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  String _getMethodTitle(String? method) {
    switch (method) {
      case 'qris':
        return 'QRIS (GoPay, OVO, Dana, ShopeePay)';
      case 'bank_transfer':
        return 'Virtual Account (BCA / Mandiri / BNI / BRI)';
      case 'gopay':
        return 'GoPay / GoPay Later';
      case 'credit_card':
        return 'Kartu Kredit / Debit (Visa / Mastercard)';
      default:
        return 'Semua Metode Pembayaran';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(
            'Pembayaran #${widget.orderCode}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.onSurface,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldLeave = await _onWillPop();
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          actions: [
            if (_isMock)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warmAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'SIMULATOR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warmAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          bottom: (!_isMock && _loadingProgress < 100)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                )
              : null,
        ),
        body: _isMock
            ? _buildSimulatorUI(context)
            : (_controller != null
                ? WebViewWidget(controller: _controller!)
                : const Center(child: CircularProgressIndicator())),
      ),
    );
  }

  Widget _buildSimulatorUI(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Sandbox Offline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.science_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Simulator Pembayaran Midtrans',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aplikasi berjalan dalam mode simulasi offline (tanpa server key Midtrans). Anda dapat menguji seluruh alur verifikasi otomatis secara instan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Kartu Rincian Tagihan & Metode
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Tagihan',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Tarif Flat',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  currencyFormatter.format(widget.totalBiaya ?? 120000),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const Divider(height: 28),
                _buildInfoLine('Kode Pesanan', '#${widget.orderCode}'),
                const SizedBox(height: 8),
                _buildInfoLine('Kanal Pembayaran', _getMethodTitle(widget.paymentMethod)),
                const SizedBox(height: 16),

                // Komponen visual sesuai kanal pembayaran
                _buildChannelVisual(widget.paymentMethod),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Aksi Simulasi
          ElevatedButton.icon(
            key: const Key('btn_simulasi_sukses'),
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: const Text(
              'Simulasikan Pembayaran Berhasil',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            key: const Key('btn_batalkan_transaksi'),
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: const Text(
              'Batalkan Transaksi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurfaceVariant,
              side: const BorderSide(color: AppColors.outline),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Resik.in Sandbox Environment • SSL 256-bit Mock Mode',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelVisual(String? method) {
    if (method == 'qris' || method == 'gopay') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 110,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pindai QRIS Simulasi menggunakan e-wallet Anda',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Atau tekan tombol "Simulasikan Pembayaran Berhasil" di bawah.',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (method == 'bank_transfer') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'BCA Virtual Account (Simulasi)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '8808 2026 1018 038',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'SIMULASI',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.emerald),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transfer tepat sesuai total tagihan di atas sebelum batas waktu berakhir.',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    } else if (method == 'credit_card') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.credit_card_rounded, color: Colors.white, size: 24),
                Text(
                  'SIMULATION CARD',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              '4111  2222  3333  4444',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RESIK TESTER',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  '12/28',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Pilih konfirmasi pembayaran di bawah untuk mensimulasikan penyelesaian transaksi.',
        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
