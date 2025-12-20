import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';
import '../../../dashboard/data/dashboard_provider.dart';
import '../../../tasks/data/tasks_provider.dart';
import '../../../assets/data/assets_provider.dart';

class ExportJobsPage extends ConsumerWidget {
  const ExportJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  subtitle: Text('${job.status.toUpperCase()} • ${job.format}'),
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
                      DropdownMenuItem(value: 'csv', child: Text('CSV (Excel)')),
                      DropdownMenuItem(value: 'xlsx', child: Text('XLSX (BI)')),
                    ],
                    onChanged: (value) => setState(() => format = value ?? 'csv'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            final metadata =
                                await _buildExportMetadata(ref, type);
                            await ref.read(opsRepositoryProvider).createExportJob(
                                  type: type,
                                  format: format,
                                  status: 'completed',
                                  metadata: metadata,
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
}
