import 'dart:convert';
import 'package:http/http.dart' as http;

class SupabaseService {
  SupabaseService(this.supabaseUrl, this.serviceRoleKey, {http.Client? client})
      : _base = Uri.parse(supabaseUrl),
        _client = client ?? http.Client();

  final String supabaseUrl;
  final String serviceRoleKey;
  final Uri _base;
  final http.Client _client;

  Map<String, String> _headers({String? prefer}) {
    return {
      'apikey': serviceRoleKey,
      'Authorization': 'Bearer $serviceRoleKey',
      'Content-Type': 'application/json',
      if (prefer != null) 'Prefer': prefer,
    };
  }

  Uri _buildUri(String table, Map<String, String> query) {
    return _base.replace(
      path: '${_base.path}/rest/v1/$table',
      queryParameters: query,
    );
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String select = '*',
    Map<String, String>? filters,
    int? limit,
    int? offset,
    String? order,
  }) async {
    final query = <String, String>{
      'select': select,
      if (order != null) 'order': order,
      if (limit != null) 'limit': '$limit',
      if (offset != null) 'offset': '$offset',
      ...?filters,
    };

    final resp = await _client.get(
      _buildUri(table, query),
      headers: _headers(),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = jsonDecode(resp.body);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      if (body is Map<String, dynamic>) return [body];
      return <Map<String, dynamic>>[];
    }

    throw SupabaseHttpException(resp.statusCode, resp.body);
  }

  Future<Map<String, dynamic>?> single(
    String table, {
    String columns = '*',
    required Map<String, String> filters,
  }) async {
    final results = await select(
      table,
      select: columns,
      filters: {'limit': '1', ...filters},
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> count(
    String table, {
    Map<String, String>? filters,
  }) async {
    final query = <String, String>{
      'select': 'id',
      'limit': '1',
      ...?filters,
    };
    final resp = await _client.get(
      _buildUri(table, query),
      headers: _headers(prefer: 'count=exact'),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final contentRange = resp.headers['content-range'];
      if (contentRange != null && contentRange.contains('/')) {
        final total = contentRange.split('/').last;
        return int.tryParse(total) ?? 0;
      }
      final body = jsonDecode(resp.body);
      if (body is List) return body.length;
    }

    throw SupabaseHttpException(resp.statusCode, resp.body);
  }

  Future<List<Map<String, dynamic>>> groupedCount(
    String table, {
    required String groupBy,
  }) async {
    return select(
      table,
      select: '$groupBy,count:count',
      filters: {'group': groupBy},
      order: 'count.desc.nullslast',
    );
  }

  Future<Map<String, dynamic>> update(
    String table, {
    required Map<String, dynamic> data,
    required Map<String, String> filters,
  }) async {
    final resp = await _client.patch(
      _buildUri(table, filters),
      headers: _headers(prefer: 'return=representation'),
      body: jsonEncode(data),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = jsonDecode(resp.body);
      if (body is List && body.isNotEmpty) {
        return Map<String, dynamic>.from(body.first as Map);
      }
      if (body is Map<String, dynamic>) {
        return body;
      }
      return data;
    }

    throw SupabaseHttpException(resp.statusCode, resp.body);
  }
}

class SupabaseHttpException implements Exception {
  SupabaseHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'SupabaseHttpException($statusCode): $body';
}
