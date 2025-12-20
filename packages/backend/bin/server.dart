import 'dart:io';

import 'package:backend/admin_api.dart';
import 'package:backend/config.dart';
import 'package:backend/supabase_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> main(List<String> args) async {
  final config = AppConfig.fromEnv();
  final supabase = SupabaseService(
    config.supabaseUrl,
    config.supabaseServiceKey,
  );

  final router = Router();
  router.get('/health', (Request _) => Response.ok('ok'));

  final adminHandler = Pipeline()
      .addMiddleware(apiKeyMiddleware(config.adminApiKey))
      .addHandler(buildAdminRouter(supabase).call);

  router.mount('/admin/', adminHandler);

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final server = await serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  stdout.writeln('Admin API listening on port ${server.port}');
}
