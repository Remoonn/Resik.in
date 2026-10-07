import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/order_model.dart';
import 'models/service_model.dart';
import 'models/user_model.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/cleaner_dashboard_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initializeSupabase();
  runApp(const ResikInApp());
}

class ResikInApp extends StatelessWidget {
  const ResikInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resik.in',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        if (user != null) {
          if (user.isAdmin) {
            return AdminDashboardScreen(key: ValueKey('admin_${user.id}'));
          }
          if (user.isCleaner) {
            return CleanerDashboardScreen(key: ValueKey('cleaner_${user.id}'));
          }
          return HomeScreen(key: ValueKey('customer_${user.id}'));
        }
        return const WelcomeScreen();
      },
    );
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ServiceModel>> _servicesFuture;
  late Future<List<OrderModel>> _ordersFuture;
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  int _selectedCategoryIndex = 0;
  int _currentBottomNavIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Semua', 'key': 'all', 'icon': Icons.apps_rounded},
    {'label': 'Rumah', 'key': 'rumah', 'icon': Icons.home_rounded},
    {'label': 'Kos', 'key': 'kos', 'icon': Icons.single_bed_rounded},
    {'label': 'Kantor', 'key': 'kantor', 'icon': Icons.business_center_rounded},
    {'label': 'Pasca Renovasi', 'key': 'pasca_renovasi', 'icon': Icons.construction_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadOrders();
    AuthService.currentUserNotifier.addListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    if (mounted) {
      _loadOrders();
    }
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = ApiService.fetchOrders();
    });
  }

  void _loadServices() {
    setState(() {
      _servicesFuture = ApiService.asyncFetchServices();
      _ordersFuture = ApiService.fetchOrders();
    });
  }

  IconData _getCategoryIcon(String kategori) {
    switch (kategori) {
      case 'rumah':
        return Icons.home_rounded;
      case 'kos':
        return Icons.single_bed_rounded;
      case 'kantor':
        return Icons.business_center_rounded;
      case 'pasca_renovasi':
        return Icons.construction_rounded;
      default:
        return Icons.cleaning_services_rounded;
    }
  }

  void _showUserSessionModal(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0284C7),
                    backgroundImage: user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
                    child: user.fotoUrl == null
                        ? Text(
                            user.nama.isNotEmpty ? user.nama[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nama,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate900,
                          ),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.roleLabel,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('session_logout_button'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await AuthService().logout();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Anda telah berhasil keluar.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                  label: const Text(
                    'Keluar (Logout)',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Logo & Brand Title
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cleaning_services_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Resik.in',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            'LOKASI',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 0.8,
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Jakarta & Sekitarnya',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
                // Notifikasi Bell
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.onSurface),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        tooltip: 'Notifikasi',
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Tombol Refresh
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                    onPressed: _loadServices,
                    padding: EdgeInsets.zero,
                    tooltip: 'Segarkan',
                  ),
                ),
                const SizedBox(width: 8),

                // Tombol Akun / Login
                ValueListenableBuilder<UserModel?>(
                  valueListenable: AuthService.currentUserNotifier,
                  builder: (context, user, _) {
                    if (user == null) {
                      return SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          key: const Key('appbar_login_button'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: const Text(
                            'Masuk',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      );
                    }

                    return InkWell(
                      key: const Key('appbar_profile_chip'),
                      onTap: () => _showUserSessionModal(context, user),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              backgroundImage: user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
                              child: user.fotoUrl == null
                                  ? Text(
                                      user.nama.isNotEmpty ? user.nama[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),

                            const SizedBox(width: 6),
                            Text(
                              user.nama.split(' ').first,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _currentBottomNavIndex == 0
          ? SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Search Bar (Sesuai Stitch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cari layanan kebersihan atau paket...',
                              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Kartu Pelacakan Pesanan Aktif (Jika Ada Pesanan Sedang Berlangsung)
            _buildActiveOrderBanner(),

            // Banner "Tanya Resik AI" / Solusi Noda Instan (Sesuai Stitch Screen 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.tertiaryFixed),
                              SizedBox(width: 5),
                              Text(
                                'TANYA RESIK AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryFixed,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'Gratis',
                            style: TextStyle(
                              color: AppColors.tertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kebersihan Nyata,\nBukti Mutu Terpercaya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pesan jasa on-demand dengan rekomendasi petugas deterministik & laporan mutu digital.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Horizontal Categories Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kategori Layanan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategoryIndex == index;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.outline,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Daftar Layanan dari Backend API
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<List<ServiceModel>>(
                future: _servicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allServices = snapshot.data ?? [];
                  final selectedCategoryKey = _categories[_selectedCategoryIndex]['key'] as String;
                  final services = selectedCategoryKey == 'all'
                      ? allServices
                      : allServices.where((s) => s.kategori == selectedCategoryKey).toList();

                  if (services.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.cleaning_services_rounded, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            allServices.isEmpty ? 'Katalog Belum Terhubung' : 'Tidak Ada Layanan pada Kategori Ini',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            allServices.isEmpty
                                ? 'Pastikan server backend di direktori backend/ sudah aktif via "npm run dev".'
                                : 'Silakan pilih kategori lainnya untuk melihat katalog paket layanan.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: services.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final service = services[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.outline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingScreen(service: service),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Ikon Kategori Bergaya Stitch
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(service.kategori),
                                          color: AppColors.primary,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    service.namaLayanan,
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.w800,
                                                          color: AppColors.onSurface,
                                                        ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceContainerLow,
                                                    borderRadius: BorderRadius.circular(100),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.schedule_rounded, size: 12, color: AppColors.primary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        service.durasiEstimasi,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              service.deskripsi,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: AppColors.onSurfaceVariant,
                                                    height: 1.4,
                                                  ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tarif Flat Deterministik',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: AppColors.onSurfaceVariant,
                                                  fontSize: 10,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            currencyFormatter.format(service.tarifDasar),
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => BookingScreen(service: service),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Pesan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                            SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_rounded, size: 15),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      )
          : (_currentBottomNavIndex == 1
              ? _buildOrdersTab()
              : (_currentBottomNavIndex == 2
                  ? _buildAITab()
                  : _buildAccountTab())),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentBottomNavIndex,
          onTap: (index) {
            setState(() {
              _currentBottomNavIndex = index;
              if (index == 1) {
                _ordersFuture = ApiService.fetchOrders();
              }
            });
          },
          backgroundColor: AppColors.surfaceContainerLowest,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Pesanan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_rounded),
              label: 'Resik AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Akun',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderBanner() {
    return FutureBuilder<List<OrderModel>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final activeOrders = snapshot.data!.where((o) =>
          o.statusPekerjaan != 'Selesai' && o.statusPekerjaan != 'Dibatalkan'
        ).toList();

        if (activeOrders.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeOrder = activeOrders.first;
        final currentStatus = activeOrder.statusPekerjaan;

        Color badgeColor;
        Color badgeTextColor;
        IconData badgeIcon;

        switch (currentStatus) {
          case 'Sedang Dikerjakan':
            badgeColor = const Color(0xFF6FFBBE).withValues(alpha: 0.25);
            badgeTextColor = const Color(0xFF005236);
            badgeIcon = Icons.timelapse_rounded;
            break;
          case 'Menuju Lokasi':
          case 'Tiba di Lokasi':
            badgeColor = const Color(0xFF006194).withValues(alpha: 0.12);
            badgeTextColor = const Color(0xFF006194);
            badgeIcon = Icons.directions_run_rounded;
            break;
          case 'Petugas Ditugaskan':
            badgeColor = const Color(0xFFE0F2FE);
            badgeTextColor = const Color(0xFF0284C7);
            badgeIcon = Icons.assignment_ind_rounded;
            break;
          case 'Dikonfirmasi':
            badgeColor = const Color(0xFFDCFCE7);
            badgeTextColor = const Color(0xFF15803D);
            badgeIcon = Icons.check_circle_outline_rounded;
            break;
          default:
            badgeColor = const Color(0xFFFEF3C7);
            badgeTextColor = const Color(0xFFB45309);
            badgeIcon = Icons.hourglass_top_rounded;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBAE6FD)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderTrackingScreen(
                        orderId: activeOrder.id,
                        initialOrder: activeOrder,
                      ),
                    ),
                  );
                  _loadOrders();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0284C7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'PESANAN AKTIF',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0284C7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  currentStatus,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: badgeTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activeOrder.serviceName ?? 'Layanan Kebersihan',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${activeOrder.tanggalLayanan} • ${activeOrder.startTime} WIB',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                          if (activeOrder.cleaner != null) ...[
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: AppColors.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            const Icon(Icons.person_rounded, size: 13, color: Color(0xFF0284C7)),
                            const SizedBox(width: 3),
                            Text(
                              activeOrder.cleaner!.nama,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currencyFormatter.format(activeOrder.totalBiaya),
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lacak Status',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadOrders();
      },
      child: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Pesanan',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pesan layanan kebersihan Anda sekarang\ndengan mutu terjamin dan petugas profesional.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentBottomNavIndex = 0;
                          });
                        },
                        icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                        label: const Text('Pesan Layanan Sekarang'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    Color badgeColor;
    Color badgeTextColor;
    IconData badgeIcon;

    switch (order.statusPekerjaan) {
      case 'Sedang Dikerjakan':
        badgeColor = const Color(0xFF6FFBBE).withValues(alpha: 0.25);
        badgeTextColor = const Color(0xFF005236);
        badgeIcon = Icons.timelapse_rounded;
        break;
      case 'Menuju Lokasi':
      case 'Tiba di Lokasi':
        badgeColor = const Color(0xFF006194).withValues(alpha: 0.12);
        badgeTextColor = const Color(0xFF006194);
        badgeIcon = Icons.directions_run_rounded;
        break;
      case 'Petugas Ditugaskan':
        badgeColor = const Color(0xFFE0F2FE);
        badgeTextColor = const Color(0xFF0284C7);
        badgeIcon = Icons.assignment_ind_rounded;
        break;
      case 'Dikonfirmasi':
        badgeColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF15803D);
        badgeIcon = Icons.check_circle_outline_rounded;
        break;
      case 'Selesai':
        badgeColor = const Color(0xFFD1FAE5);
        badgeTextColor = const Color(0xFF047857);
        badgeIcon = Icons.task_alt_rounded;
        break;
      case 'Dibatalkan':
        badgeColor = const Color(0xFFFFDAD6);
        badgeTextColor = const Color(0xFF93000A);
        badgeIcon = Icons.cancel_outlined;
        break;
      default:
        badgeColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFFB45309);
        badgeIcon = Icons.hourglass_top_rounded;
    }

    final isTerminal = order.statusPekerjaan == 'Selesai' || order.statusPekerjaan == 'Dibatalkan';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderTrackingScreen(
                  orderId: order.id,
                  initialOrder: order,
                ),
              ),
            );
            _loadOrders();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.orderCode.isNotEmpty ? order.orderCode : '#ORD-${order.id.length >= 6 ? order.id.substring(0, 6) : order.id}',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeTextColor),
                          const SizedBox(width: 4),
                          Text(
                            order.statusPekerjaan,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  order.serviceName ?? 'Layanan Kebersihan',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${order.tanggalLayanan} • ${order.startTime} WIB',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      order.cleaner != null
                          ? 'Petugas: ${order.cleaner!.nama}'
                          : 'Petugas: Belum ditentukan',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: order.cleaner != null ? FontWeight.w600 : FontWeight.w400,
                        color: order.cleaner != null ? const Color(0xFF0284C7) : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Biaya',
                          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                        Text(
                          currencyFormatter.format(order.totalBiaya),
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(
                              orderId: order.id,
                              initialOrder: order,
                            ),
                          ),
                        );
                        _loadOrders();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTerminal ? AppColors.surfaceContainerHigh : AppColors.primary,
                        foregroundColor: isTerminal ? AppColors.onSurface : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isTerminal ? 'Rincian' : 'Lacak Status',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isTerminal ? Icons.chevron_right_rounded : Icons.arrow_forward_rounded,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAITab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Resik AI Smart Consultation',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fitur konsultasi kebutuhan pembersihan dan diagnosis noda dengan AI dijadwalkan hadir pada Tahap 2 (Phase 2 Roadmap).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentBottomNavIndex = 0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTab() {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle_outlined, size: 64, color: AppColors.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('Anda Belum Masuk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
                  },
                  child: const Text('Masuk / Daftar'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    backgroundImage: user.fotoUrl != null ? NetworkImage(user.fotoUrl!) : null,
                    child: user.fotoUrl == null
                        ? Text(
                            user.nama.isNotEmpty ? user.nama[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.nama,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.roleLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    title: const Text('Versi Aplikasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: const Text('1.0.0 (V1)', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService().logout();
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                label: const Text('Keluar (Logout)', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
