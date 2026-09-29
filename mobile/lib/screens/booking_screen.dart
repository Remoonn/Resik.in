import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/service_model.dart';
import '../models/order_model.dart';
import '../models/cleaner_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'payment_screen.dart';
import 'cleaner_detail_screen.dart';

class BookingScreen extends StatefulWidget {
  final ServiceModel service;

  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _alamatController = TextEditingController();
  final _patokanController = TextEditingController();
  final _luasAreaController = TextEditingController();
  final _catatanController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedStartTime = '09:00';
  int _selectedDuration = 2;
  bool _isLoading = false;

  // Smart Matching State
  List<CleanerRecommendation> _recommendations = [];
  bool _isLoadingRecommendations = false;
  String? _selectedCleanerId; // null = Pilihkan Otomatis oleh Admin
  CleanerModel? _selectedCleaner;

  final List<String> _operatingHours = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _alamatController.dispose();
    _patokanController.dispose();
    _luasAreaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    final tanggalFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final results = await ApiService.fetchRecommendations(
      serviceId: widget.service.id,
      tanggal: tanggalFormatted,
      startTime: _selectedStartTime,
      duration: _selectedDuration,
    );

    if (!mounted) return;

    setState(() {
      _recommendations = results;
      _isLoadingRecommendations = false;
      // Jika petugas terpilih sebelumnya tidak ada di kandidat baru, tetap pertahankan atau reset jika perlu
      if (_selectedCleanerId != null) {
        final match = results.where((r) => r.cleaner.id == _selectedCleanerId);
        if (match.isNotEmpty) {
          _selectedCleaner = match.first.cleaner;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadRecommendations();
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final tanggalFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final currentUser = AuthService().currentUser;
    final payload = {
      if (currentUser?.id != null) 'customer_id': currentUser!.id,
      'service_id': widget.service.id,
      'preferensi_petugas_id': _selectedCleanerId,
      'tanggal_layanan': tanggalFormatted,
      'start_time': _selectedStartTime,
      'duration': _selectedDuration,
      'alamat_lengkap': _alamatController.text.trim(),
      'patokan_lokasi': _patokanController.text.trim(),
      'luas_area': _luasAreaController.text.trim(),
      'catatan_khusus': _catatanController.text.trim(),
    };

    final result = await ApiService.createOrder(payload);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success'] == true && result['data'] != null) {
      final orderData = result['data'];
      final order = OrderModel.fromJson({
        ...orderData,
        'service': {
          'id': widget.service.id,
          'nama_layanan': widget.service.namaLayanan,
          'kategori': widget.service.kategori,
        },
        'preferensi_petugas_id': _selectedCleanerId,
        'tanggal_layanan': tanggalFormatted,
        'start_time': _selectedStartTime,
        'duration': _selectedDuration,
        'alamat_lengkap': _alamatController.text.trim(),
        'patokan_lokasi': _patokanController.text.trim(),
        'luas_area': _luasAreaController.text.trim(),
        'catatan_khusus': _catatanController.text.trim(),
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            order: order,
            service: widget.service,
            selectedCleaner: _selectedCleaner,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal membuat pesanan'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pemesanan Layanan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Service Summary Card (Tarif Flat Snapshot)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(color: AppColors.outline),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.service.namaLayanan,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Garansi Mutu',
                                style: TextStyle(
                                  color: AppColors.emeraldDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• Estimasi ${widget.service.durasiEstimasi}',
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormatter.format(widget.service.tarifDasar),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Form Input
            Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jadwal & Waktu Pembersihan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),

                    // Date & Time Row
                    Row(
                      children: [
                        // Tanggal Layanan
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Tanggal Layanan',
                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Jam Mulai
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedStartTime,
                            decoration: const InputDecoration(
                              labelText: 'Jam Mulai',
                              prefixIcon: Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                            ),
                            items: _operatingHours.map((time) {
                              return DropdownMenuItem(
                                value: time,
                                child: Text('$time WIB', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStartTime = val;
                                });
                                _loadRecommendations();
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Durasi Chips
                    Text(
                      'Durasi Pengerjaan Standar (Jam)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3, 4].map((d) {
                        final isSelected = _selectedDuration == d;
                        return ChoiceChip(
                          label: Text('$d Jam'),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceContainerLowest,
                          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.outline),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.onSurface,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedDuration = d;
                              });
                              _loadRecommendations();
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // 3. SEKSI REKOMENDASI PETUGAS (SMART MATCHING)
                    // Stitch Screen 2: Deterministic Smart Matching
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rekomendasi Petugas (Smart Matching)',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Pencocokan deterministik berbasis keahlian & ketersediaan',
                                style: TextStyle(fontSize: 11, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingRecommendations)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Option A: Pilihkan Otomatis oleh Admin (Default / Fallback BR-ASN-002)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCleanerId = null;
                          _selectedCleaner = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedCleanerId == null ? AppColors.primaryLight.withValues(alpha: 0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedCleanerId == null ? AppColors.primary : AppColors.outline,
                            width: _selectedCleanerId == null ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedCleanerId == null ? AppColors.primary : AppColors.outlineVariant,
                                  width: 2,
                                ),
                              ),
                              child: _selectedCleanerId == null
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pilihkan Otomatis oleh Admin',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Admin akan menugaskan petugas terbaik yang tersedia di area Anda.',
                                    style: TextStyle(fontSize: 11, color: AppColors.slate500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Option B: List of Recommended Candidates
                    if (!_isLoadingRecommendations && _recommendations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warmAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.event_busy, color: AppColors.warmAmber, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tidak ada petugas tersedia di jadwal ini karena batasan operasional/buffer. Silakan ganti jam/tanggal atau gunakan opsi Pilihkan Otomatis oleh Admin.',
                                style: TextStyle(fontSize: 12, color: AppColors.slate900, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._recommendations.map((rec) {
                        final cleaner = rec.cleaner;
                        final score = rec.score;
                        final isSelected = _selectedCleanerId == cleaner.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.35) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.outline,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCleanerId = cleaner.id;
                                _selectedCleaner = cleaner;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        margin: const EdgeInsets.only(top: 12, right: 10),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Center(
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      // Resilient Avatar
                                      ClipOval(
                                        child: (cleaner.fotoUrl != null && cleaner.fotoUrl!.isNotEmpty)
                                            ? Image.network(
                                                cleaner.fotoUrl!,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, st) => Container(
                                                  width: 44,
                                                  height: 44,
                                                  color: AppColors.primaryLight,
                                                  child: const Icon(Icons.person, color: AppColors.primary, size: 24),
                                                ),
                                              )
                                            : Container(
                                                width: 44,
                                                height: 44,
                                                color: AppColors.primaryLight,
                                                child: const Icon(Icons.person, color: AppColors.primary, size: 24),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    cleaner.nama,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: AppColors.slate900,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '${score.totalScore.toStringAsFixed(1)}% Match',
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${cleaner.pengalamanTahun} Thn Pengalaman • ${cleaner.totalPekerjaan} Pekerjaan',
                                              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (score.isProvisionalRating) ...[
                                                  const Icon(Icons.verified_outlined, size: 14, color: AppColors.warmAmber),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Petugas Baru (Rating Awal 4.5)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.warmAmber,
                                                    ),
                                                  ),
                                                ] else ...[
                                                  const Icon(Icons.star, size: 14, color: AppColors.warmAmber),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${cleaner.ratingRataRata.toStringAsFixed(1)} (${cleaner.totalUlasan} ulasan)',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.slate900,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Action "Lihat Detail Profil & Ulasan"
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () async {
                                          final chosen = await Navigator.push<CleanerModel>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (ctx) => CleanerDetailScreen(
                                                cleaner: cleaner,
                                                isProvisionalRating: score.isProvisionalRating,
                                                matchBadge: score.matchBadge,
                                                totalScore: score.totalScore,
                                              ),
                                            ),
                                          );
                                          if (chosen != null) {
                                            setState(() {
                                              _selectedCleanerId = chosen.id;
                                              _selectedCleaner = chosen;
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.badge_outlined, size: 15, color: AppColors.primary),
                                        label: const Text(
                                          'Lihat Profil & Ulasan',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // 4. Lokasi & Rincian Tempat
                    Text(
                      'Lokasi & Rincian Tempat',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),

                    // Alamat Lengkap
                    TextFormField(
                      key: const Key('input_alamat_lengkap'),
                      controller: _alamatController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap *',
                        hintText: 'Contoh: Jl. Senopati No. 42, Kebayoran Baru',
                        prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Alamat lengkap wajib diisi';
                        }
                        if (val.trim().length < 10) {
                          return 'Alamat lengkap minimal 10 karakter';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Patokan Lokasi
                    TextFormField(
                      key: const Key('input_patokan_lokasi'),
                      controller: _patokanController,
                      decoration: const InputDecoration(
                        labelText: 'Patokan Lokasi *',
                        hintText: 'Contoh: Pagar hitam depan minimarket',
                        prefixIcon: Icon(Icons.flag_rounded, color: AppColors.primary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Patokan lokasi wajib diisi';
                        }
                        if (val.trim().length < 3) {
                          return 'Patokan lokasi minimal 3 karakter';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Luas Area
                    TextFormField(
                      key: const Key('input_luas_area'),
                      controller: _luasAreaController,
                      decoration: const InputDecoration(
                        labelText: 'Luas Area / Tipe Properti *',
                        hintText: 'Contoh: Tipe 36, Kamar 3x4 m, 2 Lantai',
                        prefixIcon: Icon(Icons.square_foot_rounded, color: AppColors.primary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Luas area wajib diisi sebagai acuan beban kerja';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Catatan Khusus (Optional)
                    TextFormField(
                      key: const Key('input_catatan_khusus'),
                      controller: _catatanController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Khusus (Opsional)',
                        hintText: 'Contoh: Bersihkan kerak kaca kamar mandi utama',
                        prefixIcon: Icon(Icons.note_alt_rounded, color: AppColors.onSurfaceVariant),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Tombol Submit (Pill Button)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        key: const Key('btn_submit_booking'),
                        onPressed: _isLoading ? null : _submitBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Lanjut ke Pembayaran',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
