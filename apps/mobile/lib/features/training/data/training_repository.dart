import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class TrainingRepositoryBase {
  Future<List<Employee>> fetchEmployees();
  Future<Employee> createEmployee({
    required String firstName,
    required String lastName,
    String? email,
    String? phoneNumber,
    String? employeeNumber,
    String? department,
    String? position,
    String? jobSiteId,
    String? jobSiteName,
    DateTime? hireDate,
    bool isActive,
    List<String>? certifications,
    Map<String, dynamic>? metadata,
  });
  Future<Employee> updateEmployee({
    required String employeeId,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? employeeNumber,
    String? department,
    String? position,
    String? jobSiteId,
    String? jobSiteName,
    DateTime? hireDate,
    DateTime? terminationDate,
    bool? isActive,
    List<String>? certifications,
    Map<String, dynamic>? metadata,
  });
  Future<List<Training>> fetchTrainingRecords({String? employeeId});
  Future<Training> createTrainingRecord({
    required String employeeId,
    required String trainingName,
    String? trainingType,
    TrainingStatus status,
    DateTime? completedDate,
    DateTime? expirationDate,
    String? instructorName,
    double? score,
    String? certificateUrl,
    DateTime? nextRecertificationDate,
    String? location,
    double? ceuCredits,
    List<String>? materials,
    List<String>? documents,
    String? assignedRole,
    String? assignedJob,
    String? assignedSite,
    int? assignedTenureDays,
    Map<String, dynamic>? metadata,
  });
  Future<Training> updateTrainingRecord({
    required String trainingId,
    String? trainingName,
    String? trainingType,
    TrainingStatus? status,
    DateTime? completedDate,
    DateTime? expirationDate,
    String? instructorName,
    double? score,
    String? certificateUrl,
    DateTime? nextRecertificationDate,
    String? location,
    double? ceuCredits,
    List<String>? materials,
    List<String>? documents,
    String? assignedRole,
    String? assignedJob,
    String? assignedSite,
    int? assignedTenureDays,
    Map<String, dynamic>? metadata,
  });
  Future<void> sendTrainingReminder(Training training, {String? message});
  Future<void> notifyTrainingAssigned(Training training);
}

class SupabaseTrainingRepository implements TrainingRepositoryBase {
  SupabaseTrainingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Employee>> fetchEmployees() async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    try {
      final res = await _client
          .from('employees')
          .select()
          .eq('org_id', orgId)
          .order('last_name', ascending: true);
      return (res as List<dynamic>)
          .map((row) => _mapEmployee(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchEmployees failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Employee> createEmployee({
    required String firstName,
    required String lastName,
    String? email,
    String? phoneNumber,
    String? employeeNumber,
    String? department,
    String? position,
    String? jobSiteId,
    String? jobSiteName,
    DateTime? hireDate,
    bool isActive = true,
    List<String>? certifications,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to add employees.');
    }
    final resolvedUserId = await _resolveUserIdByEmail(email);
    final payload = {
      'org_id': orgId,
      if (resolvedUserId != null) 'user_id': resolvedUserId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'employee_number': employeeNumber,
      'department': department,
      'position': position,
      'job_site_id': jobSiteId,
      'job_site_name': jobSiteName,
      'hire_date': hireDate?.toIso8601String(),
      'is_active': isActive,
      'certifications': certifications ?? const <String>[],
      'updated_at': DateTime.now().toIso8601String(),
      'metadata': metadata,
    };
    try {
      final res = await _client.from('employees').insert(payload).select().single();
      return _mapEmployee(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase createEmployee failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Employee> updateEmployee({
    required String employeeId,
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? employeeNumber,
    String? department,
    String? position,
    String? jobSiteId,
    String? jobSiteName,
    DateTime? hireDate,
    DateTime? terminationDate,
    bool? isActive,
    List<String>? certifications,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (firstName != null) payload['first_name'] = firstName;
    if (lastName != null) payload['last_name'] = lastName;
    if (email != null) {
      payload['email'] = email;
      final resolvedUserId = await _resolveUserIdByEmail(email);
      if (resolvedUserId != null) {
        payload['user_id'] = resolvedUserId;
      }
    }
    if (phoneNumber != null) payload['phone_number'] = phoneNumber;
    if (employeeNumber != null) payload['employee_number'] = employeeNumber;
    if (department != null) payload['department'] = department;
    if (position != null) payload['position'] = position;
    if (jobSiteId != null) payload['job_site_id'] = jobSiteId;
    if (jobSiteName != null) payload['job_site_name'] = jobSiteName;
    if (hireDate != null) payload['hire_date'] = hireDate.toIso8601String();
    if (terminationDate != null) {
      payload['termination_date'] = terminationDate.toIso8601String();
    }
    if (isActive != null) payload['is_active'] = isActive;
    if (certifications != null) payload['certifications'] = certifications;
    if (metadata != null) payload['metadata'] = metadata;
    try {
      final res = await _client
          .from('employees')
          .update(payload)
          .eq('id', employeeId)
          .select()
          .single();
      return _mapEmployee(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase updateEmployee failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<Training>> fetchTrainingRecords({String? employeeId}) async {
    final orgId = await _getOrgId();
    if (orgId == null) return const [];
    try {
      final query = _client.from('training_records').select().eq('org_id', orgId);
      final res = employeeId == null
          ? await query.order('expiration_date', ascending: true)
          : await query.eq('employee_id', employeeId).order(
              'expiration_date',
              ascending: true,
            );
      return (res as List<dynamic>)
          .map((row) => _mapTraining(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e, st) {
      developer.log(
        'Supabase fetchTrainingRecords failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Training> createTrainingRecord({
    required String employeeId,
    required String trainingName,
    String? trainingType,
    TrainingStatus status = TrainingStatus.notStarted,
    DateTime? completedDate,
    DateTime? expirationDate,
    String? instructorName,
    double? score,
    String? certificateUrl,
    DateTime? nextRecertificationDate,
    String? location,
    double? ceuCredits,
    List<String>? materials,
    List<String>? documents,
    String? assignedRole,
    String? assignedJob,
    String? assignedSite,
    int? assignedTenureDays,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = await _getOrgId();
    if (orgId == null) {
      throw Exception('User must belong to an organization to assign training.');
    }
    final payload = {
      'org_id': orgId,
      'employee_id': employeeId,
      'training_name': trainingName,
      'training_type': trainingType,
      'status': status.name,
      'completed_date': completedDate?.toIso8601String(),
      'expiration_date': expirationDate?.toIso8601String(),
      'instructor_name': instructorName,
      'score': score,
      'certificate_url': certificateUrl,
      'next_recertification_date': nextRecertificationDate?.toIso8601String(),
      'location': location,
      'ceu_credits': ceuCredits,
      'materials': materials ?? const <String>[],
      'documents': documents ?? const <String>[],
      'assigned_role': assignedRole,
      'assigned_job': assignedJob,
      'assigned_site': assignedSite,
      'assigned_tenure_days': assignedTenureDays,
      'updated_at': DateTime.now().toIso8601String(),
      'metadata': metadata,
    };
    try {
      final res = await _client
          .from('training_records')
          .insert(payload)
          .select()
          .single();
      final record = _mapTraining(Map<String, dynamic>.from(res as Map));
      await notifyTrainingAssigned(record);
      return record;
    } catch (e, st) {
      developer.log(
        'Supabase createTrainingRecord failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<Training> updateTrainingRecord({
    required String trainingId,
    String? trainingName,
    String? trainingType,
    TrainingStatus? status,
    DateTime? completedDate,
    DateTime? expirationDate,
    String? instructorName,
    double? score,
    String? certificateUrl,
    DateTime? nextRecertificationDate,
    String? location,
    double? ceuCredits,
    List<String>? materials,
    List<String>? documents,
    String? assignedRole,
    String? assignedJob,
    String? assignedSite,
    int? assignedTenureDays,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (trainingName != null) payload['training_name'] = trainingName;
    if (trainingType != null) payload['training_type'] = trainingType;
    if (status != null) payload['status'] = status.name;
    if (completedDate != null) {
      payload['completed_date'] = completedDate.toIso8601String();
    }
    if (expirationDate != null) {
      payload['expiration_date'] = expirationDate.toIso8601String();
    }
    if (instructorName != null) payload['instructor_name'] = instructorName;
    if (score != null) payload['score'] = score;
    if (certificateUrl != null) payload['certificate_url'] = certificateUrl;
    if (nextRecertificationDate != null) {
      payload['next_recertification_date'] =
          nextRecertificationDate.toIso8601String();
    }
    if (location != null) payload['location'] = location;
    if (ceuCredits != null) payload['ceu_credits'] = ceuCredits;
    if (materials != null) payload['materials'] = materials;
    if (documents != null) payload['documents'] = documents;
    if (assignedRole != null) payload['assigned_role'] = assignedRole;
    if (assignedJob != null) payload['assigned_job'] = assignedJob;
    if (assignedSite != null) payload['assigned_site'] = assignedSite;
    if (assignedTenureDays != null) {
      payload['assigned_tenure_days'] = assignedTenureDays;
    }
    if (metadata != null) payload['metadata'] = metadata;
    try {
      final res = await _client
          .from('training_records')
          .update(payload)
          .eq('id', trainingId)
          .select()
          .single();
      return _mapTraining(Map<String, dynamic>.from(res as Map));
    } catch (e, st) {
      developer.log(
        'Supabase updateTrainingRecord failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> sendTrainingReminder(Training training, {String? message}) async {
    final employeeUserId = await _resolveEmployeeUserId(training.employeeId);
    if (employeeUserId == null) return;
    final orgId = await _getOrgId();
    if (orgId == null) return;
    final dueText = training.expirationDate != null
        ? 'Expires ${training.expirationDate!.toLocal()}'
        : 'No expiration date';
    await _createNotification(
      orgId: orgId,
      userId: employeeUserId,
      title: 'Training reminder',
      body: message ?? '${training.trainingName} • $dueText',
      type: 'training',
    );
  }

  @override
  Future<void> notifyTrainingAssigned(Training training) async {
    final employeeUserId = await _resolveEmployeeUserId(training.employeeId);
    if (employeeUserId == null) return;
    final orgId = await _getOrgId();
    if (orgId == null) return;
    await _createNotification(
      orgId: orgId,
      userId: employeeUserId,
      title: 'New training assigned',
      body: training.trainingName,
      type: 'training',
    );
  }

  Employee _mapEmployee(Map<String, dynamic> row) {
    return Employee(
      id: row['id'].toString(),
      userId: row['user_id']?.toString() ?? '',
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      photoUrl: row['photo_url'] as String?,
      phoneNumber: row['phone_number'] as String?,
      employeeNumber: row['employee_number'] as String?,
      department: row['department'] as String?,
      position: row['position'] as String?,
      jobSiteId: row['job_site_id']?.toString(),
      jobSiteName: row['job_site_name'] as String?,
      hireDate: _parseDate(row['hire_date']) ?? DateTime.now(),
      terminationDate: _parseNullableDate(row['termination_date']),
      isActive: row['is_active'] as bool? ?? true,
      certifications: (row['certifications'] as List?)?.cast<String>(),
      trainingHistory: const [],
      companyId: row['org_id']?.toString(),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Training _mapTraining(Map<String, dynamic> row) {
    final rawMaterials = row['materials'];
    final rawDocuments = row['documents'];
    final materials = rawMaterials is List
        ? rawMaterials.map((e) => e.toString()).toList()
        : const <String>[];
    final documents = rawDocuments is String
        ? (jsonDecode(rawDocuments) as List).map((e) => e.toString()).toList()
        : (rawDocuments as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
    return Training(
      id: row['id'].toString(),
      employeeId: row['employee_id']?.toString() ?? '',
      trainingName: row['training_name'] as String? ?? '',
      trainingType: row['training_type'] as String?,
      status: TrainingStatus.values.firstWhere(
        (e) => e.name == (row['status'] as String? ?? TrainingStatus.notStarted.name),
        orElse: () => TrainingStatus.notStarted,
      ),
      completedDate: _parseNullableDate(row['completed_date']),
      expirationDate: _parseNullableDate(row['expiration_date']),
      instructorName: row['instructor_name'] as String?,
      score: _parseNullableDouble(row['score']),
      certificateUrl: row['certificate_url'] as String?,
      nextRecertificationDate: _parseNullableDate(row['next_recertification_date']),
      location: row['location'] as String?,
      ceuCredits: _parseNullableDouble(row['ceu_credits']),
      materials: materials,
      documents: documents,
      assignedRole: row['assigned_role'] as String?,
      assignedJob: row['assigned_job'] as String?,
      assignedSite: row['assigned_site'] as String?,
      assignedTenureDays: row['assigned_tenure_days'] is int
          ? row['assigned_tenure_days'] as int
          : int.tryParse(row['assigned_tenure_days']?.toString() ?? ''),
      metadata: row['metadata'] as Map<String, dynamic>?,
    );
  }

  Future<void> _createNotification({
    required String orgId,
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _client.from('notifications').insert({
        'org_id': orgId,
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      developer.log(
        'Supabase createNotification failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String?> _resolveEmployeeUserId(String employeeId) async {
    try {
      final res = await _client
          .from('employees')
          .select('user_id')
          .eq('id', employeeId)
          .maybeSingle();
      final userId = res?['user_id'];
      return userId?.toString();
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<String?> _resolveUserIdByEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return null;
    try {
      final res = await _client
          .from('profiles')
          .select('id')
          .eq('email', email.trim())
          .maybeSingle();
      return res?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getOrgId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await _client
          .from('org_members')
          .select('org_id')
          .eq('user_id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    try {
      final res = await _client
          .from('profiles')
          .select('org_id')
          .eq('id', userId)
          .maybeSingle();
      final orgId = res?['org_id'];
      if (orgId != null) return orgId.toString();
    } catch (_) {}
    developer.log('No org_id found for user $userId in org_members or profiles');
    return null;
  }
}
