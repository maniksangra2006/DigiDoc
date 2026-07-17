import 'package:flutter/foundation.dart';

class AppConfig {
  /// Base URL for the DigiDoc FastAPI backend.
  static String get baseUrl => 'https://digidoc-backend-l974.onrender.com';

  /// Toggle for developer mode tokens during local testing.
  /// If true, uses unverified dev-mode tokens to bypass Firebase signature validation
  /// in local database tests. Set to false in production.
  static const bool useDevMode = true;

  // Mock session variables for offline/bypass dev mode
  static String? mockEmail;
  static String? mockName;
  static String? mockUid;
  static String? mockRole;
  static String? mockSpecialty;
}
