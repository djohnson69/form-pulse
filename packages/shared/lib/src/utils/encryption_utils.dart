import 'dart:convert';

/// Encryption and security utility functions
///
/// Note: This is a placeholder for basic encryption utilities.
/// For production, use proper encryption libraries like:
/// - encrypt package for AES encryption
/// - pointycastle for RSA and other algorithms
/// - crypto for hashing
class EncryptionUtils {
  /// Base64 encode data
  static String base64Encode(String data) {
    return base64.encode(utf8.encode(data));
  }

  /// Base64 decode data
  static String base64Decode(String encoded) {
    return utf8.decode(base64.decode(encoded));
  }

  /// Generate a simple hash (for demonstration only - use crypto package in production)
  static String simpleHash(String data) {
    return base64Encode(data);
  }

  /// Mask sensitive data (e.g., credit card numbers, SSN)
  static String maskData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars) return data;
    final masked = '*' * (data.length - visibleChars);
    return masked + data.substring(data.length - visibleChars);
  }

  /// Mask email address
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) return email;

    final visibleChars = username.length >= 4 ? 2 : 1;
    final maskedUsername =
        username.substring(0, visibleChars) +
        '*' * (username.length - visibleChars);

    return '$maskedUsername@$domain';
  }

  /// Mask phone number
  static String maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;
    return '*' * (phone.length - 4) + phone.substring(phone.length - 4);
  }

  /// Generate a random token (for demonstration - use uuid package in production)
  static String generateToken() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return base64Encode(timestamp.toString());
  }

  /// Sanitize user input (remove potentially harmful characters)
  static String sanitizeInput(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Validate token format
  static bool isValidToken(String token) {
    try {
      base64.decode(token);
      return true;
    } catch (e) {
      return false;
    }
  }
}
