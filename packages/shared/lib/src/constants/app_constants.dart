/// Application-wide constants
class AppConstants {
  // App Information
  static const String appName = 'Form Bridge';
  static const String appVersion = '2.0.0';
  static const String companyName = 'Form Bridge';

  // Database
  static const String databaseName = 'form_pulse.db';
  static const int databaseVersion = 1;

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String notificationsEnabledKey = 'notifications_enabled';

  // File Upload
  static const int maxFileSize = 50 * 1024 * 1024; // 50 MB
  static const int maxPhotoSize = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100 MB
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  static const List<String> supportedVideoFormats = [
    'mp4',
    'mov',
    'avi',
    'mkv',
  ];
  static const List<String> supportedDocumentFormats = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
  ];

  // Location
  static const double locationUpdateInterval = 30.0; // seconds
  static const double locationAccuracyThreshold = 50.0; // meters

  // Training
  static const int certificationExpiryWarningDays = 30;
  static const int trainingRecertificationDays = 365;

  // Form Builder
  static const int maxFormFields = 100;
  static const int maxFormNameLength = 100;
  static const int maxFieldLabelLength = 200;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const String passwordRegex =
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$';
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String phoneRegex = r'^\+?[1-9]\d{1,14}$';

  // Sync
  static const Duration syncInterval = Duration(minutes: 15);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 5);

  // Cache
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB
}
