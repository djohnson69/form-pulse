import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/csv_utils.dart';
import '../../data/ops_provider.dart';
import '../../../dashboard/data/dashboard_provider.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../../../assets/data/assets_provider.dart';

class ExportJobsPage extends ConsumerStatefulWidget {
  const ExportJobsPage({super.key});

  @override
  ConsumerState<ExportJobsPage> createState() => _ExportJobsPageState();
}

class _ExportJobsPageState extends ConsumerState<ExportJobsPage> {
  @override
  Widget build(BuildContext context) {
    final exportsAsync = ref.watch(exportJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Export Jobs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New export'),
      ),
      body: exportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (exports) {
          if (exports.isEmpty) {
            return const Center(child: Text('No export jobs yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exports.length,
            itemBuilder: (context, index) {
              final job = exports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.file_download),
                  title: Text(job.type),
                  subtitle: Text(_jobSubtitle(job)),
                  trailing: job.fileUrl == null
                      ? null
                      : IconButton(
                          tooltip: 'Download',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => _openFile(job.fileUrl!),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    String type = 'submissions';
    String format = 'csv';
    String target = 'standard';
    bool isSaving = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create export',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Data type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'submissions',
                        child: Text('Form submissions'),
                      ),
                      DropdownMenuItem(
                        value: 'tasks',
                        child: Text('Tasks'),
                      ),
                      DropdownMenuItem(
                        value: 'assets',
                        child: Text('Assets'),
                      ),
                      DropdownMenuItem(
                        value: 'incidents',
                        child: Text('Incident reports'),
                      ),
                    ],
                    onChanged: (value) => setState(() => type = value ?? 'submissions'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: format,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'csv', child: Text('CSV')),
                      DropdownMenuItem(value: 'xlsx', child: Text('XLSX')),
                    ],
                    onChanged: (value) => setState(() => format = value ?? 'csv'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration: const InputDecoration(
                      labelText: 'BI target',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'standard', child: Text('Standard')),
                      DropdownMenuItem(value: 'tableau', child: Text('Tableau')),
                      DropdownMenuItem(value: 'powerbi', child: Text('Power BI')),
                    ],
                    onChanged: (value) =>
                        setState(() => target = value ?? 'standard'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            final metadata =
                                await _buildExportMetadata(ref, type);
                            metadata['target'] = target;
                            final export = await _buildExportFile(
                              ref,
                              type,
                              format,
                              metadata,
                            );
                            await ref
                                .read(opsRepositoryProvider)
                                .createExportJobWithFile(
                                  type: type,
                                  format: format,
                                  filename: export.filename,
                                  bytes: export.bytes,
                                  metadata: export.metadata,
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Generate export'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (result == true) {
      ref.invalidate(exportJobsProvider);
    }
  }

  Future<Map<String, dynamic>> _buildExportMetadata(
    WidgetRef ref,
    String type,
  ) async {
    switch (type) {
      case 'tasks':
        final tasks = await ref.read(tasksProvider.future);
        return {'rows': tasks.length, 'columns': ['title', 'status', 'dueDate']};
      case 'assets':
        final assets = await ref.read(equipmentProvider.future);
        return {'rows': assets.length, 'columns': ['name', 'category', 'status']};
      case 'incidents':
        final incidents =
            await ref.read(incidentReportsProvider(null).future);
        return {
          'rows': incidents.length,
          'columns': ['title', 'category', 'status']
        };
      case 'submissions':
      default:
        final submissions =
            await ref.read(dashboardRepositoryProvider).fetchSubmissions();
        return {
          'rows': submissions.length,
          'columns': ['form', 'submittedBy', 'submittedAt']
        };
    }
  }

  Future<_ExportFile> _buildExportFile(
    WidgetRef ref,
    String type,
    String format,
    Map<String, dynamic> metadata,
  ) async {
    if (format == 'xlsx') {
      return _buildXlsxExport(ref, type, format, metadata);
    }
    String csv;
    switch (type) {
      case 'tasks':
        csv = buildTasksCsv(await ref.read(tasksProvider.future));
        break;
      case 'assets':
        csv = buildAssetsCsv(await ref.read(equipmentProvider.future));
        break;
      case 'incidents':
        csv = buildIncidentsCsv(
          await ref.read(incidentReportsProvider(null).future),
        );
        break;
      case 'submissions':
      default:
        csv = buildSubmissionsCsv(
          await ref.read(dashboardRepositoryProvider).fetchSubmissions(),
        );
        break;
    }
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'export_${type}_$timestamp.$format';
    return _ExportFile(
      filename: filename,
      bytes: bytes,
      metadata: metadata,
    );
  }

  Future<_ExportFile> _buildXlsxExport(
    WidgetRef ref,
    String type,
    String format,
    Map<String, dynamic> metadata,
  ) async {
    Uint8List bytes;
    switch (type) {
      case 'tasks':
        bytes = buildTasksXlsx(await ref.read(tasksProvider.future));
        break;
      case 'assets':
        bytes = buildAssetsXlsx(await ref.read(equipmentProvider.future));
        break;
      case 'incidents':
        bytes = buildIncidentsXlsx(
          await ref.read(incidentReportsProvider(null).future),
        );
        break;
      case 'submissions':
      default:
        bytes = buildSubmissionsXlsx(
          await ref.read(dashboardRepositoryProvider).fetchSubmissions(),
        );
        break;
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'export_${type}_$timestamp.$format';
    return _ExportFile(
      filename: filename,
      bytes: bytes,
      metadata: metadata,
    );
  }

  String _jobSubtitle(ExportJob job) {
    final target = job.metadata?['target']?.toString();
    final parts = <String>[job.status.toUpperCase(), job.format.toUpperCase()];
    if (target != null && target.isNotEmpty && target != 'standard') {
      parts.add(target.toUpperCase());
    }
    return parts.join(' • ');
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open export link.')),
      );
    }
  }
}

class _ExportFile {
  const _ExportFile({
    required this.filename,
    required this.bytes,
    required this.metadata,
  });

  final String filename;
  final Uint8List bytes;
  final Map<String, dynamic> metadata;
}
