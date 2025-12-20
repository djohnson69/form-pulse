import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'supabase_service.dart';

const _jsonHeaders = {'content-type': 'application/json'};

Middleware apiKeyMiddleware(String expectedKey) {
  return (Handler inner) {
    return (Request req) {
      if (expectedKey.isEmpty) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'ADMIN_API_KEY not configured'}),
          headers: _jsonHeaders,
        );
      }
      final provided = req.headers['x-api-key'];
      if (provided == null || provided != expectedKey) {
        return Response(
          401,
          body: jsonEncode({'error': 'Unauthorized'}),
          headers: _jsonHeaders,
        );
      }
      return inner(req);
    };
  };
}

Router buildAdminRouter(SupabaseService supabase) {
  final router = Router();

  router.get('/stats', (Request req) async {
    try {
      final forms = await supabase.count('forms');
      final submissions = await supabase.count('submissions');
      final attachments = await supabase.count('attachments');
      final formsByCategory =
          await supabase.groupedCount('forms', groupBy: 'category');

      return Response.ok(
        jsonEncode({
          'forms': forms,
          'submissions': submissions,
          'attachments': attachments,
          'formsByCategory': formsByCategory,
        }),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load stats', 'details': '$e'}),
        headers: _jsonHeaders,
      );
    }
  });

  router.get('/forms', (Request req) async {
    try {
      final qp = req.requestedUri.queryParameters;
      final limit = int.tryParse(qp['limit'] ?? '50') ?? 50;
      final offset = int.tryParse(qp['offset'] ?? '0') ?? 0;
      final search = qp['search'];
      final category = qp['category'];
      final published = qp['published'];

      final filters = <String, String>{};
      if (search != null && search.isNotEmpty) {
        filters['title'] = 'ilike.*$search*';
      }
      if (category != null && category.isNotEmpty) {
        filters['category'] = 'eq.$category';
      }
      if (published != null) {
        filters['is_published'] =
            published.toLowerCase() == 'true' ? 'is.true' : 'is.false';
      }

      final forms = await supabase.select(
        'forms',
        select:
            'id,org_id,title,description,category,tags,is_published,version,updated_at',
        filters: filters,
        limit: limit,
        offset: offset,
        order: 'updated_at.desc.nullslast',
      );

      return Response.ok(
        jsonEncode({'data': forms}),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load forms', 'details': '$e'}),
        headers: _jsonHeaders,
      );
    }
  });

  router.get('/forms/<id>', (Request req, String id) async {
    try {
      final form = await supabase.single(
        'forms',
        filters: {'id': 'eq.$id'},
      );
      if (form == null) {
        return Response.notFound(
          jsonEncode({'error': 'Form not found'}),
          headers: _jsonHeaders,
        );
      }
      return Response.ok(jsonEncode(form), headers: _jsonHeaders);
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to load form', 'details': '$e'}),
        headers: _jsonHeaders,
      );
    }
  });

  router.patch('/forms/<id>', (Request req, String id) async {
    try {
      final body = await req.readAsString();
      final payload = jsonDecode(body) as Map<String, dynamic>;

      final allowedKeys = {
        'title',
        'description',
        'category',
        'tags',
        'is_published',
        'version',
        'metadata',
        'fields',
      };

      final update = <String, dynamic>{
        for (final entry in payload.entries)
          if (allowedKeys.contains(entry.key)) entry.key: entry.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (update.length == 1) {
        return Response(
          400,
          body: jsonEncode({'error': 'No valid fields to update'}),
          headers: _jsonHeaders,
        );
      }

      final updated = await supabase.update(
        'forms',
        data: update,
        filters: {'id': 'eq.$id'},
      );

      return Response.ok(jsonEncode(updated), headers: _jsonHeaders);
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update form', 'details': '$e'}),
        headers: _jsonHeaders,
      );
    }
  });

  router.get('/submissions', (Request req) async {
    try {
      final qp = req.requestedUri.queryParameters;
      final limit = int.tryParse(qp['limit'] ?? '50') ?? 50;
      final status = qp['status'];
      final filters = <String, String>{
        if (status != null && status.isNotEmpty) 'status': 'eq.$status',
      };

      final submissions = await supabase.select(
        'submissions',
        select:
            'id,org_id,form_id,status,submitted_at,submitted_by,attachments,metadata',
        filters: filters,
        limit: limit,
        order: 'submitted_at.desc',
      );

      return Response.ok(
        jsonEncode({'data': submissions}),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode(
          {'error': 'Failed to load submissions', 'details': '$e'},
        ),
        headers: _jsonHeaders,
      );
    }
  });

  return router;
}
