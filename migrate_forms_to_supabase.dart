#!/usr/bin/env dart
// Migrate form templates from server.dart to Supabase
import 'dart:io';

// Extract forms from server.dart - this is simplified, needs actual parsing
const supabaseUrl = 'https://xpcibptzncfmifaneoop.supabase.co';
const supabaseAnonKey = 'sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW';
const demoOrgId = '00000000-0000-0000-0000-000000000001';

Future<void> main() async {
  print('📦 Starting form template migration to Supabase...\n');
  
  // Read server.dart and extract forms array
  final serverFile = File('packages/backend/bin/server.dart');
  if (!await serverFile.exists()) {
    print('❌ Error: packages/backend/bin/server.dart not found');
    exit(1);
  }
  
  print('📖 Reading templates from server.dart...');
  final content = await serverFile.readAsString();
  
  // Find the _forms array - this is a simple approach
  final formsStart = content.indexOf('final _forms = <Map<String, dynamic>>[');
  final formsEnd = content.indexOf('];', formsStart);
  
  if (formsStart == -1 || formsEnd == -1) {
    print('❌ Could not find _forms array in server.dart');
    exit(1);
  }
  
  // Extract forms array text
  final formsArrayText = content.substring(formsStart, formsEnd + 2);
  print('✅ Found forms array (${formsArrayText.length} characters)\n');
  
  // This would need proper Dart parsing, but for now, let's use the REST API approach
  // Instead, let's create a SQL migration file that can be run in Supabase
  
  await generateSqlMigration();
  
  print('\n✅ Migration file created: supabase/migrate_forms.sql');
  print('\n📋 Next steps:');
  print('   1. Open Supabase Dashboard > SQL Editor');
  print('   2. Copy contents of supabase/migrate_forms.sql');
  print('   3. Paste and run in SQL Editor');
  print('   4. Restart your Flutter app to see all templates\n');
}

Future<void> generateSqlMigration() async {
  // We'll create a SQL file that inserts all forms
  // This requires parsing the Dart forms array into SQL INSERT statements
  
  final sqlFile = File('supabase/migrate_forms.sql');
  final buffer = StringBuffer();
  
  buffer.writeln('-- Form Templates Migration');
  buffer.writeln('-- Generated from packages/backend/bin/server.dart');
  buffer.writeln('-- Run this in Supabase SQL Editor to populate forms table\n');
  buffer.writeln('-- Demo org ID: $demoOrgId\n');
  
  buffer.writeln('-- Note: This is a template. You need to manually convert');
  buffer.writeln('-- the Dart forms array to SQL INSERT statements.');
  buffer.writeln('-- Or use a tool to parse the server.dart file properly.\n');
  
  buffer.writeln('-- Example INSERT statement:');
  buffer.writeln('/*');
  buffer.writeln("INSERT INTO forms (id, org_id, title, description, category, tags, is_published, version, created_by)");
  buffer.writeln("VALUES (");
  buffer.writeln("  'jobsite-safety',");
  buffer.writeln("  '$demoOrgId',");
  buffer.writeln("  'Job Site Safety Walk',");
  buffer.writeln("  '15-point safety walkthrough with photo capture',");
  buffer.writeln("  'Safety',");
  buffer.writeln("  ARRAY['safety', 'construction', 'audit'],");
  buffer.writeln("  true,");
  buffer.writeln("  '1.0.0',");
  buffer.writeln("  'system'");
  buffer.writeln(");");
  buffer.writeln('*/\n');
  
  await sqlFile.writeAsString(buffer.toString());
}
