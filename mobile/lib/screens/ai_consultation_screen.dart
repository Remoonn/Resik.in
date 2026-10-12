import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/ai_consultation_model.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';

class AiConsultationScreen extends StatefulWidget {
  const AiConsultationScreen({super.key});

  @override
  State<AiConsultationScreen> createState() => _AiConsultationScreenState();
}

class _AiConsultationScreenState extends State<AiConsultationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  List<String> _currentSuggestedReplies = [];

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final List<String> _starterPrompts = [
    'Rekomendasi pembersihan kos',
    'Rumah 2 lantai luas',
    'Pembersihan kantor kerja',
    'Jam operasional & garansi mutu',
  ];

  @override
  void initState() {
    super.initState();
    _initWelcomeMessage();
  }

  void _initWelcomeMessage() {
    _messages.add(
      AiChatMessage(
        text:
            'Halo! Saya **Resik AI**, asisten pintar dan konsultan kebersihan Resik.in. 👋\n\nCeritakan kondisi hunian atau tempat kerja Anda (misalnya kamar kos berdebu, rumah 2 lantai luas, kantor, atau pasca renovasi), saya akan memberikan saran layanan dan alokasi durasi yang paling tepat!',
        isUser: false,
        suggestedReplies: [
          'Rekomendasi pembersihan kos',
          'Rumah 2 lantai kotor',
          'Berapa jam operasional Resik.in?',
        ],
      ),
    );
    _currentSuggestedReplies = _messages.first.suggestedReplies;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final query = (textToSend ?? _textController.text).trim();
    if (query.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    _textController.clear();

    setState(() {
      _messages.add(AiChatMessage(text: query, isUser: true));
      _isLoading = true;
      _currentSuggestedReplies = [];
    });
    _scrollToBottom();

    // Persiapkan riwayat percakapan untuk konteks backend
    final List<Map<String, String>> history = _messages
        .where((m) => !m.isError)
        .take(_messages.length - 1)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'content': m.text,
            })
        .toList();

    final response = await ApiService.sendAiConsultationMessage(
      message: query,
      history: history,
    );

    if (!mounted) return;

    if (response['success'] == true && response['data'] != null) {
      final parsed = AiConsultationResponse.fromJson(response['data']);
      setState(() {
        _messages.add(
          AiChatMessage(
            text: parsed.reply,
            isUser: false,
            recommendedService: parsed.recommendedService,
            suggestedReplies: parsed.suggestedReplies,
          ),
        );
        _currentSuggestedReplies = parsed.suggestedReplies;
        _isLoading = false;
      });
    } else {
      setState(() {
        _messages.add(
          AiChatMessage(
            text: response['message']?.toString() ??
                'Maaf, terjadi kendala koneksi ke Resik AI. Silakan coba lagi.',
            isUser: false,
            isError: true,
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bersihkan Obrolan?'),
        content: const Text(
          'Seluruh riwayat konsultasi saat ini akan dihapus dan dimulai kembali dari awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _initWelcomeMessage();
              });
            },
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesan disalin ke papan klip'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resik AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bersihkan Obrolan',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _messages.length > 1 ? _confirmClearChat : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildMessageItem(msg, index == 0);
                },
              ),
            ),
            if (_currentSuggestedReplies.isNotEmpty && !_isLoading)
              _buildSuggestedRepliesBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryLight,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Resik AI sedang berpikir...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage msg, bool isFirst) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () => _copyToClipboard(msg.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primary
                          : msg.isError
                              ? Colors.red.shade50
                              : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: msg.isError
                                  ? Colors.red.shade200
                                  : AppColors.surfaceContainer,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isUser
                            ? Colors.white
                            : msg.isError
                                ? Colors.red.shade800
                                : AppColors.onSurface,
                        fontWeight:
                            isUser ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (msg.recommendedService != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _buildActionableServiceCard(msg.recommendedService!),
            ),
          ],
          if (isFirst && _messages.length == 1) ...[
            const SizedBox(height: 14),
            _buildStarterChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildStarterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 40, bottom: 8),
          child: Text(
            'Atau pilih topik cepat di bawah:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _starterPrompts.map((prompt) {
              return ActionChip(
                backgroundColor: AppColors.surfaceContainerLow,
                side: const BorderSide(color: AppColors.surfaceContainer),
                label: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                onPressed: () => _sendMessage(prompt),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionableServiceCard(AiRecommendedService service) {
    IconData iconData = Icons.cleaning_services_rounded;
    if (service.kategori == 'kos') {
      iconData = Icons.bed_rounded;
    } else if (service.kategori == 'kantor') {
      iconData = Icons.business_rounded;
    } else if (service.kategori == 'renovasi') {
      iconData = Icons.construction_rounded;
    } else if (service.kategori == 'rumah') {
      iconData = Icons.home_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.recommend_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Rekomendasi Paket Resik AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.namaLayanan,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormatter.format(service.tarifDasar),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Disarankan ${service.suggestedDuration} Jam',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ),
                  ],
                ),
                if (service.rationale.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    service.rationale,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: const Text(
                      'Pesan Layanan Ini',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingScreen(
                            service: service.toServiceModel(),
                            initialDuration: service.suggestedDuration,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedRepliesBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _currentSuggestedReplies.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                label: Text(
                  reply,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                onPressed: () => _sendMessage(reply),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('input_ai_message'),
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Tulis keluhan atau konsultasi kebersihan...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.surfaceContainer),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.surfaceContainer),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const Key('btn_send_ai_message'),
            onPressed: _isLoading ? null : () => _sendMessage(),
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
