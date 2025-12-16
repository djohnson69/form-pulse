import 'package:shared/src/constants/app_constants.dart';

/// Validation utility functions
class ValidationUtils {
  /// Validate email address
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    final regex = RegExp(AppConstants.emailRegex);
    return regex.hasMatch(email);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    if (password.length < AppConstants.minPasswordLength) return false;
    if (password.length > AppConstants.maxPasswordLength) return false;
    final regex = RegExp(AppConstants.passwordRegex);
    return regex.hasMatch(password);
  }

  /// Get password strength message
  static String getPasswordStrengthMessage(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!password.contains(RegExp(r'[@$!%*#?&]'))) {
      return 'Password must contain at least one special character';
    }
    return 'Password is strong';
  }

  /// Validate phone number
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    final regex = RegExp(AppConstants.phoneRegex);
    return regex.hasMatch(phone);
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate required field
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validate number
  static bool isValidNumber(String value) {
    if (value.isEmpty) return false;
    return double.tryParse(value) != null;
  }

  /// Validate integer
  static bool isValidInteger(String value) {
    if (value.isEmpty) return false;
    return int.tryParse(value) != null;
  }

  /// Validate date string
  static bool isValidDate(String value) {
    if (value.isEmpty) return false;
    try {
      DateTime.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate file size
  static bool isValidFileSize(int fileSize, int maxSize) {
    return fileSize <= maxSize;
  }

  /// Validate file extension
  static bool isValidFileExtension(String filename, List<String> allowedExtensions) {
    final extension = filename.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  /// Validate minimum length
  static bool hasMinLength(String value, int minLength) {
    return value.length >= minLength;
  }

  /// Validate maximum length
  static bool hasMaxLength(String value, int maxLength) {
    return value.length <= maxLength;
  }

  /// Validate length range
  static bool isWithinLengthRange(String value, int minLength, int maxLength) {
    return value.length >= minLength && value.length <= maxLength;
  }
}
