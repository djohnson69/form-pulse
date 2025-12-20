import 'package:shared/src/enums/form_field_type.dart';

/// Form definition model
class FormDefinition {
  final String id;
  final String title;
  final String description;
  final String? category;
  final List<String>? tags;
  final List<FormField> fields;
  final bool isPublished;
  final String? version;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  FormDefinition({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    this.tags,
    required this.fields,
    this.isPublished = false,
    this.version,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'fields': fields.map((f) => f.toJson()).toList(),
      'isPublished': isPublished,
      'version': version,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory FormDefinition.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] as List?) ?? const <dynamic>[];
    final parsedFields = <FormField>[];
    for (final f in rawFields) {
      try {
        parsedFields.add(FormField.fromJson(f as Map<String, dynamic>));
      } catch (_) {
        // Skip invalid field entries to avoid crashes from bad data
        continue;
      }
    }

    return FormDefinition(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled form',
      description: json['description'] as String? ?? '',
      category: json['category'] as String?,
      tags: (json['tags'] as List?)?.cast<String>(),
      fields: parsedFields,
      isPublished: json['isPublished'] as bool? ?? false,
      version: json['version'] as String?,
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Form field definition
class FormField {
  final String id;
  final String label;
  final FormFieldType type;
  final String? group;
  final String? placeholder;
  final String? helpText;
  final bool isRequired;
  final List<String>? options;
  final Map<String, dynamic>? validation;
  final Map<String, dynamic>? conditionalLogic;
  final Map<String, dynamic>? calculations;
  final List<FormField>? children;
  final int order;
  final Map<String, dynamic>? metadata;

  FormField({
    required this.id,
    required this.label,
    required this.type,
    this.group,
    this.placeholder,
    this.helpText,
    this.isRequired = false,
    this.options,
    this.validation,
    this.conditionalLogic,
    this.calculations,
    this.children,
    required this.order,
    this.metadata,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'group': group,
      'placeholder': placeholder,
      'helpText': helpText,
      'isRequired': isRequired,
      'options': options,
      'validation': validation,
      'conditionalLogic': conditionalLogic,
      'calculations': calculations,
      'children': children?.map((c) => c.toJson()).toList(),
      'order': order,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory FormField.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final type = FormFieldType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => FormFieldType.text,
    );
    return FormField(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: type,
      group: json['group'] as String?,
      placeholder: json['placeholder'] as String?,
      helpText: json['helpText'] as String?,
      isRequired: json['isRequired'] as bool? ?? false,
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      validation: json['validation'] as Map<String, dynamic>?,
      conditionalLogic: json['conditionalLogic'] as Map<String, dynamic>?,
      calculations: json['calculations'] as Map<String, dynamic>?,
      children: (json['children'] as List?)
          ?.map((f) => FormField.fromJson(f as Map<String, dynamic>))
          .toList(),
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? '0') ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
