import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
import 'export_jobs_page.dart';

class IntegrationsPage extends ConsumerWidget {
  const IntegrationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webhooksAsync = ref.watch(webhookEndpointsProvider);
    final integrationsAsync = ref.watch(integrationsProvider);
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
      body: integrationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (integrations) {
          final byProvider = {
            for (final item in integrations) item.provider: item,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Automation-ready integrations',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Connect tools for automated updates, location signals, and workflow sync.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ..._catalog.map((item) {
                final profile = byProvider[item.provider];
                final isActive = profile?.status == 'active';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.title),
                    subtitle: Text(
                      profile == null
                          ? item.description
                          : '${item.description}\nStatus: ${_formatStatus(profile.status)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Switch(
                          value: isActive,
                          onChanged: (value) async {
                            await ref.read(opsRepositoryProvider).upsertIntegration(
                                  provider: item.provider,
                                  status: value ? 'active' : 'inactive',
                                  config: profile?.config ?? const {},
                                );
                            ref.invalidate(integrationsProvider);
                          },
                        ),
                        TextButton(
                          onPressed: () =>
                              _openConfigSheet(context, ref, item, profile),
                          child: const Text('Configure'),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text('Webhook endpoints',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              webhooksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Error: $e'),
                ),
                data: (webhooks) {
                  if (webhooks.isEmpty) {
                    return const Text('No webhook endpoints yet.');
                  }
                  return Column(
                    children: webhooks.map((hook) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(hook.name),
                          subtitle: Text(hook.url),
                          trailing: Switch(
                            value: hook.isActive,
                            onChanged: (value) async {
                              await ref
                                  .read(opsRepositoryProvider)
                                  .updateWebhookEndpoint(
                                    id: hook.id,
                                    isActive: value,
                                  );
                              ref.invalidate(webhookEndpointsProvider);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
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

  Future<void> _openConfigSheet(
    BuildContext context,
    WidgetRef ref,
    _IntegrationCatalogItem item,
    IntegrationProfile? profile,
  ) async {
    final controllers = <String, TextEditingController>{};
    for (final field in item.fields) {
      controllers[field.key] = TextEditingController(
        text: profile?.config[field.key]?.toString() ?? '',
      );
    }
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
                  Text('Configure ${item.title}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...item.fields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[field.key],
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: field.isSecret,
                      ),
                    );
                  }),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            final config = <String, dynamic>{
                              for (final field in item.fields)
                                field.key: controllers[field.key]!.text.trim(),
                            };
                            await ref
                                .read(opsRepositoryProvider)
                                .upsertIntegration(
                                  provider: item.provider,
                                  status: profile?.status ?? 'inactive',
                                  config: config,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                    child: Text(isSaving ? 'Saving...' : 'Save settings'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (result == true) {
      ref.invalidate(integrationsProvider);
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ');
  }
}

class _IntegrationCatalogItem {
  const _IntegrationCatalogItem({
    required this.provider,
    required this.title,
    required this.description,
    required this.icon,
    required this.fields,
  });

  final String provider;
  final String title;
  final String description;
  final IconData icon;
  final List<_IntegrationField> fields;
}

class _IntegrationField {
  const _IntegrationField({
    required this.key,
    required this.label,
    this.hint,
    this.isSecret = false,
  });

  final String key;
  final String label;
  final String? hint;
  final bool isSecret;
}

const _catalog = [
  _IntegrationCatalogItem(
    provider: 'zapier',
    title: 'Zapier',
    description: 'Trigger workflows from Form Bridge events.',
    icon: Icons.auto_awesome,
    fields: [
      _IntegrationField(
        key: 'webhookUrl',
        label: 'Zapier webhook URL',
        hint: 'https://hooks.zapier.com/...',
      ),
      _IntegrationField(
        key: 'webhookSecret',
        label: 'Webhook secret',
        hint: 'Provided by Zapier',
        isSecret: true,
      ),
      _IntegrationField(
        key: 'events',
        label: 'Events (comma separated)',
        hint: 'submission.created,task.completed',
      ),
    ],
  ),
  _IntegrationCatalogItem(
    provider: 'chrome_extension',
    title: 'Chrome Extension',
    description: 'Launch form workflows from browser-based tasks.',
    icon: Icons.extension,
    fields: [
      _IntegrationField(
        key: 'extensionId',
        label: 'Extension ID',
        hint: 'Chrome Web Store ID',
      ),
      _IntegrationField(
        key: 'clientId',
        label: 'Client ID',
      ),
      _IntegrationField(
        key: 'clientSecret',
        label: 'Client secret',
        isSecret: true,
      ),
      _IntegrationField(
        key: 'allowedOrigins',
        label: 'Allowed origins',
        hint: 'https://app.example.com',
      ),
    ],
  ),
  _IntegrationCatalogItem(
    provider: 'ibeacon',
    title: 'Apple iBeacon',
    description: 'Trigger location-based automations on job sites.',
    icon: Icons.bluetooth_searching,
    fields: [
      _IntegrationField(key: 'uuid', label: 'Beacon UUID'),
      _IntegrationField(key: 'major', label: 'Major value'),
      _IntegrationField(key: 'minor', label: 'Minor value'),
    ],
  ),
  _IntegrationCatalogItem(
    provider: 'rfid',
    title: 'RFID',
    description: 'Track assets and inventory via RFID tag scans.',
    icon: Icons.nfc,
    fields: [
      _IntegrationField(key: 'provider', label: 'RFID platform'),
      _IntegrationField(key: 'apiBaseUrl', label: 'API base URL'),
      _IntegrationField(key: 'readerId', label: 'Reader ID'),
      _IntegrationField(
        key: 'apiKey',
        label: 'API key',
        isSecret: true,
      ),
    ],
  ),
  _IntegrationCatalogItem(
    provider: 'fleet_gps',
    title: 'Fleet GPS',
    description: 'Sync vehicle and equipment location telemetry.',
    icon: Icons.local_shipping,
    fields: [
      _IntegrationField(key: 'provider', label: 'GPS provider'),
      _IntegrationField(key: 'apiBaseUrl', label: 'API base URL'),
      _IntegrationField(key: 'accountId', label: 'Account ID'),
      _IntegrationField(
        key: 'apiKey',
        label: 'API key',
        isSecret: true,
      ),
    ],
  ),
];
