import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class MidtransSnapScreen extends StatefulWidget {
  final String redirectUrl;
  final String orderCode;
  final WebViewController? controller;

  const MidtransSnapScreen({
    super.key,
    required this.redirectUrl,
    required this.orderCode,
    this.controller,
  });

  @override
  State<MidtransSnapScreen> createState() => _MidtransSnapScreenState();
}

class _MidtransSnapScreenState extends State<MidtransSnapScreen> {
  WebViewController? _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
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
          bottom: _loadingProgress < 100
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
        body: _controller != null
            ? WebViewWidget(controller: _controller!)
            : const Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }
}
