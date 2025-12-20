import 'ai_service_base.dart';

/// Data validator that delegates to the shared AI service.
class DataValidator {
  final AIService ai;

  DataValidator(this.ai);

  /// Validate email format and suggest corrections.
  Future<ValidationResult> validateEmail(String email) {
    return ai.validateData(
      data: {'email': email},
      context: 'email',
    );
  }

  /// Validate phone number and formatting.
  Future<ValidationResult> validatePhone(String phone) {
    return ai.validateData(
      data: {'phone': phone},
      context: 'phone',
    );
  }

  /// Validate address and suggest completions.
  Future<ValidationResult> validateAddress(String address) {
    return ai.validateData(
      data: {'address': address},
      context: 'address',
    );
  }

  /// Validate custom field data with an explicit field type.
  Future<ValidationResult> validateCustomField({
    required String value,
    required String fieldType,
    String? context,
  }) {
    return ai.validateData(
      data: {'value': value, 'fieldType': fieldType},
      context: context ?? 'custom',
    );
  }
}
