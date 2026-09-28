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
