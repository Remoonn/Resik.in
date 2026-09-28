import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConstants {
  // Untuk physical device dengan adb reverse gunakan localhost.
  // 10.0.2.2 hanya untuk Android Emulator.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }

    if (Platform.isAndroid) {
      return 'http://localhost:3000/api';
    }

    return 'http://localhost:3000/api';
  }
}

class SupabaseConstants {
  static const String supabaseUrl = 'https://krcrptaslnpnvppikrek.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyY3JwdGFzbG5wbnZwcGlrcmVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1MzE2MDYsImV4cCI6MjEwNTEwNzYwNn0.8K8Qlt6c4pSIswI-bOe-1rcC_sVPWDt6kTGA2umqRxc';
  static const String authRedirectScheme = 'io.supabase.resikin';
  static const String authRedirectHost = 'login-callback';
  static const String authRedirectUrl = '$authRedirectScheme://$authRedirectHost';
}

class AppConfig {
  /// Flag konfigurasi untuk mengaktifkan/menonaktifkan sheet Simulasi Operasional di HP.
  /// Saat diset true, pengguna dapat mensimulasikan aksi Admin & Cleaner langsung dari layar pelacakan.
  /// Saat diset false, sheet simulasi disembunyikan dan sistem mematuhi otorisasi peran riil.
  static const bool kEnableOperationalSimulation = true;
}

