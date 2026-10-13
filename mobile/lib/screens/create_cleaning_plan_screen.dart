import 'package:flutter/material.dart';
import '../models/service_model.dart';
import '../models/cleaner_model.dart';
import '../services/api_service.dart';

class CreateCleaningPlanScreen extends StatefulWidget {
  final ServiceModel? service;
  final List<ServiceModel>? initialServices;
  final List<CleanerModel>? initialCleaners;

  const CreateCleaningPlanScreen({
    super.key,
    this.service,
    this.initialServices,
    this.initialCleaners,
  });

  static final List<ServiceModel> defaultServices = [
    ServiceModel(
      id: 'srv-001',
      namaLayanan: 'Pembersihan Rumah',
      kategori: 'rumah',
      deskripsi: 'Pembersihan menyeluruh seluruh ruangan rumah tinggal.',
      durasiEstimasi: '3 jam',
      tarifDasar: 150000.0,
      iconName: 'home',
      isActive: true,
    ),
    ServiceModel(
      id: 'srv-002',
      namaLayanan: 'Pembersihan Kos',
      kategori: 'kos',
      deskripsi: 'Pembersihan kamar kos dan kamar mandi dalam.',
      durasiEstimasi: '2 jam',
      tarifDasar: 80000.0,
      iconName: 'single_bed',
      isActive: true,
    ),
    ServiceModel(
      id: 'srv-003',
      namaLayanan: 'Pembersihan Kantor',
      kategori: 'kantor',
      deskripsi: 'Pembersihan meja kerja, lantai, dan ruang pertemuan.',
      durasiEstimasi: '3 jam',
      tarifDasar: 200000.0,
      iconName: 'business_center',
      isActive: true,
    ),
    ServiceModel(
      id: 'srv-004',
      namaLayanan: 'Pembersihan Pasca Renovasi',
      kategori: 'pasca_renovasi',
      deskripsi: 'Pembersihan debu semen, sisa cat, dan puing halus.',
      durasiEstimasi: '4 jam',
      tarifDasar: 350000.0,
      iconName: 'construction',
      isActive: true,
    ),
  ];

  @override
  State<CreateCleaningPlanScreen> createState() => _CreateCleaningPlanScreenState();
}

class _CreateCleaningPlanScreenState extends State<CreateCleaningPlanScreen> {
  final _formKey = GlobalKey<FormState>();

  late ServiceModel _selectedService;
  late List<ServiceModel> _availableServices;

  late TextEditingController _planNameController;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _timeController = TextEditingController(text: '09:00');

  String _selectedFrequency = 'mingguan'; // 'mingguan' | 'dua_mingguan'
  int _selectedDayOfWeek = 1; // 1 = Senin ... 7 = Minggu
  int _selectedDuration = 2; // Jam
  String? _selectedCleanerId;

  List<CleanerModel> _availableCleaners = [];
  bool _isLoadingCleaners = false;
  bool _isSubmitting = false;

  final Map<int, String> _daysMap = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };

  @override
  void initState() {
    super.initState();
    _availableServices = widget.initialServices ?? CreateCleaningPlanScreen.defaultServices;
    if (widget.service != null) {
      _selectedService = widget.service!;
    } else {
      _selectedService = _availableServices.first;
      _loadServices();
    }

    _planNameController = TextEditingController(
      text: 'Langganan ${_selectedService.namaLayanan}',
    );
    if (widget.initialCleaners != null) {
      _availableCleaners = widget.initialCleaners!;
    } else {
      _loadCleaners();
    }
  }

  Future<void> _loadServices() async {
    try {
      final services = await ApiService.asyncFetchServices();
      if (mounted && services.isNotEmpty) {
        setState(() {
          _availableServices = services;
          final match = _availableServices.firstWhere(
            (s) => s.id == _selectedService.id,
            orElse: () => _availableServices.first,
          );
          _selectedService = match;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadCleaners() async {
    setState(() => _isLoadingCleaners = true);
    try {
      final cleaners = await ApiService.fetchCleaners();
      if (mounted) {
        setState(() {
          _availableCleaners = cleaners;
          _isLoadingCleaners = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCleaners = false);
      }
    }
  }

  double get _calculatedPricePerSession => _selectedService.tarifDasar * _selectedDuration;

  Future<void> _selectTime() async {
    final parts = _timeController.text.split(':');
    final initialHour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9;
    final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = '$hourStr:$minuteStr';
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'plan_name': _planNameController.text.trim(),
      'service_category': _selectedService.kategori,
      'service_id': _selectedService.id,
      'frequency': _selectedFrequency,
      'day_of_week': _selectedDayOfWeek,
      'day_name': _daysMap[_selectedDayOfWeek] ?? 'Senin',
      'start_time': _timeController.text.trim(),
      'duration': _selectedDuration,
      'price_per_session': _calculatedPricePerSession,
      'address': _addressController.text.trim(),
      'landmark': _landmarkController.text.trim(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      if (_selectedCleanerId != null && _selectedCleanerId!.isNotEmpty)
        'preferred_cleaner_id': _selectedCleanerId,
    };

    final result = await ApiService.createCleaningPlan(payload);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paket langganan rutin berhasil didaftarkan! Sesi pertama siap dikonfirmasi.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Gagal mendaftarkan paket langganan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Langganan Kebersihan Rutin'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Pilihan Kategori Layanan (jika dipanggil tanpa pra-seleksi service)
              if (widget.service == null) ...[
                Text(
                  'Pilih Kategori Layanan',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('dropdown_service_selection'),
                  isExpanded: true,
                  initialValue: _selectedService.id,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.cleaning_services_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _availableServices.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(
                        '${s.namaLayanan} (Rp ${_formatCurrency(s.tarifDasar)}/jam)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedService = _availableServices.firstWhere((s) => s.id == val);
                        _planNameController.text = 'Langganan ${_selectedService.namaLayanan}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 1. Header Card Info Layanan
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.autorenew, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedService.namaLayanan,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tarif Dasar: Rp ${_formatCurrency(_selectedService.tarifDasar)} / jam',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Prioritas Petugas & Otomatisasi Sesi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Nama Paket
              Text(
                'Nama Paket Langganan',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('input_nama_paket'),
                controller: _planNameController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Langganan Bersih Kos Mingguan',
                  prefixIcon: const Icon(Icons.bookmark_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Nama paket minimal 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 3. Frekuensi Sesi
              Text(
                'Frekuensi Kunjungan',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('choice_freq_mingguan'),
                      label: const Center(child: Text('Setiap Minggu')),
                      selected: _selectedFrequency == 'mingguan',
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFrequency = 'mingguan');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('choice_freq_dua_mingguan'),
                      label: const Center(child: Text('Setiap 2 Minggu')),
                      selected: _selectedFrequency == 'dua_mingguan',
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFrequency = 'dua_mingguan');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Hari & Jam Pelaksanaan
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hari Rutin',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          key: const Key('dropdown_hari'),
                          initialValue: _selectedDayOfWeek,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: _daysMap.entries.map((entry) {
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDayOfWeek = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jam Mulai',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectTime,
                          child: IgnorePointer(
                            child: TextFormField(
                              key: const Key('input_jam_mulai'),
                              controller: _timeController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.access_time),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. Durasi Sesi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Durasi per Sesi',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Direkomendasikan ${_selectedService.durasiEstimasi}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _selectedDuration > 1
                            ? () => setState(() => _selectedDuration--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          '$_selectedDuration Jam',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _selectedDuration < 8
                            ? () => setState(() => _selectedDuration++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 6. Preferensi Petugas Favorit (Opsional)
              Text(
                'Preferensi Petugas (Opsional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _isLoadingCleaners
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String?>(
                      key: const Key('dropdown_cleaner_favorit'),
                      initialValue: _selectedCleanerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Pilih Petugas Favorit (Default: Acak/Smart Matching)',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Smart Matching Otomatis (Rekomendasi)'),
                        ),
                        ..._availableCleaners.map((cleaner) {
                          return DropdownMenuItem<String?>(
                            value: cleaner.id,
                            child: Text('${cleaner.nama} (⭐ ${cleaner.ratingRataRata})'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCleanerId = val);
                      },
                    ),
              const SizedBox(height: 20),

              // 7. Lokasi & Detail Alamat
              Text(
                'Alamat Lengkap',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('input_alamat_lengkap'),
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Nama jalan, nomor rumah, RT/RW, kelurahan...',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Alamat lengkap wajib diisi minimal 10 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Patokan Lokasi',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('input_patokan_lokasi'),
                controller: _landmarkController,
                decoration: InputDecoration(
                  hintText: 'Warna pagar, seberang masjid, dekat minimarket...',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Patokan lokasi minimal 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Catatan Khusus (Opsional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('input_catatan'),
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Instruksi akses, area yang diprioritaskan, dll.',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // 8. Ringkasan Tarif per Sesi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimasi Biaya per Sesi',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Rp ${_formatCurrency(_calculatedPricePerSession)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Chip(
                      label: Text(
                        '$_selectedDuration Jam',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 9. Tombol Submit Pendaftaran
              ElevatedButton(
                key: const Key('btn_submit_cleaning_plan'),
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Daftar Paket Langganan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
