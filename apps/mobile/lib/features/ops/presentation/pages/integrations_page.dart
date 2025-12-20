import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';
import 'export_jobs_page.dart';

class IntegrationsPage extends ConsumerWidget {
  const IntegrationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webhooksAsync = ref.watch(webhookEndpointsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrations'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportJobsPage()),
              );
            },
            child: const Text('Exports'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New webhook'),
      ),
      body: webhooksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (webhooks) {
          if (webhooks.isEmpty) {
            return const Center(child: Text('No webhook endpoints yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: webhooks.length,
            itemBuilder: (context, index) {
              final hook = webhooks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(hook.name),
                  subtitle: Text(hook.url),
                  trailing: Switch(
                    value: hook.isActive,
                    onChanged: (value) async {
                      await ref.read(opsRepositoryProvider).updateWebhookEndpoint(
                            id: hook.id,
                            isActive: value,
                          );
                      ref.invalidate(webhookEndpointsProvider);
                    },
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
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final eventsController = TextEditingController();
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
                  Text('Create webhook',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: eventsController,
                    decoration: const InputDecoration(
                      labelText: 'Events (comma separated)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty ||
                                urlController.text.trim().isEmpty) {
                              return;
                            }
                            setState(() => isSaving = true);
                            final events = eventsController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            await ref
                                .read(opsRepositoryProvider)
                                .createWebhookEndpoint(
                                  name: nameController.text.trim(),
                                  url: urlController.text.trim(),
                                  events: events,
                                  isActive: true,
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Save webhook'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    nameController.dispose();
    urlController.dispose();
    eventsController.dispose();
    if (result == true) {
      ref.invalidate(webhookEndpointsProvider);
    }
  }
}
