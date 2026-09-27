import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Gunakan 10.0.2.2 untuk Android Emulator, localhost untuk Web/Desktop/iOS Sim
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }
}
