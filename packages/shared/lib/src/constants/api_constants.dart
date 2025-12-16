/// API-related constants
class ApiConstants {
  // Base URLs (to be configured via environment)
  static const String baseUrlDev = 'http://localhost:8080';
  static const String baseUrlProd = 'https://api.formpulse.com';

  // API Endpoints
  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';

  static const String users = '/api/users';
  static const String employees = '/api/employees';
  static const String forms = '/api/forms';
  static const String submissions = '/api/submissions';
  static const String documents = '/api/documents';
  static const String clients = '/api/clients';
  static const String vendors = '/api/vendors';
  static const String notifications = '/api/notifications';
  static const String news = '/api/news';
  static const String jobSites = '/api/job-sites';
  static const String equipment = '/api/equipment';
  static const String training = '/api/training';

  // WebSocket endpoints
  static const String wsNotifications = '/ws/notifications';
  static const String wsCollaboration = '/ws/collaboration';

  // Request timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Headers
  static const String authHeader = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String acceptHeader = 'Accept';
  static const String jsonContentType = 'application/json';
}
