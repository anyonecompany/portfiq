/// App-wide constants for Portfiq
class AppConstants {
  AppConstants._();

  static const String appName = 'Portfiq';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // API
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;

  // Cache
  static const String hiveBoxName = 'portfiq_cache';
  static const Duration cacheTtl = Duration(hours: 1);

  // Onboarding
  static const int minEtfSelection = 1;
  static const int maxEtfSelection = 20;

  // Briefing
  static const int briefingHour = 7; // 오전 7시 디폴트
  static const int briefingMinute = 30;

  // Analytics
  static const String mixpanelToken = ''; // Set via env
}
