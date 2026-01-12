import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';

class NotificationRulesPage extends ConsumerStatefulWidget {
  const NotificationRulesPage({super.key});

  @override
  ConsumerState<NotificationRulesPage> createState() =>
      _NotificationRulesPageState();
}

class _NotificationRulesPageState extends ConsumerState<NotificationRulesPage> {
  bool _runningSweep = false;

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(notificationRulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation Rules'),
        actions: [
          IconButton(
            onPressed: _runningSweep ? null : _runAutomationSweep,
            icon: _runningSweep
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('No automation rules yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.bolt),
                  title: Text(rule.name),
                  subtitle: Text('${rule.triggerType} • ${rule.targetType}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final sent =
                          await ref.read(opsRepositoryProvider).triggerRule(
                            rule: rule,
                            title: rule.name,
                            body: rule.messageTemplate,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rule triggered for $sent user(s).'),
                          ),
                        );
                      }
                    },
                    child: const Text('Run now'),
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
    final messageController = TextEditingController();
    String triggerType = 'submission';
    String targetType = 'org';
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
                  Text('Create rule',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Rule name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: triggerType,
                    decoration: const InputDecoration(
                      labelText: 'Trigger',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'submission', child: Text('Submission')),
                      DropdownMenuItem(value: 'task_due', child: Text('Task due')),
                      DropdownMenuItem(
                        value: 'training_expire',
                        child: Text('Training expiring'),
                      ),
                      DropdownMenuItem(
                        value: 'asset_due',
                        child: Text('Asset maintenance due'),
                      ),
                      DropdownMenuItem(
                        value: 'inspection_due',
                        child: Text('Inspection due'),
                      ),
                      DropdownMenuItem(
                        value: 'sop_ack_due',
                        child: Text('SOP acknowledgement due'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => triggerType = value ?? 'submission'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetType,
                    decoration: const InputDecoration(
                      labelText: 'Target',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'org', child: Text('Organization')),
                      DropdownMenuItem(value: 'team', child: Text('Team')),
                      DropdownMenuItem(value: 'user', child: Text('Specific user')),
                    ],
                    onChanged: (value) =>
                        setState(() => targetType = value ?? 'org'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notification message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;
                            setState(() => isSaving = true);
                            await ref
                                .read(opsRepositoryProvider)
                                .createNotificationRule(
                                  name: name,
                                  triggerType: triggerType,
                                  targetType: targetType,
                                  messageTemplate: messageController.text.trim().isEmpty
                                      ? null
                                      : messageController.text.trim(),
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Save rule'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    nameController.dispose();
    messageController.dispose();
    if (result == true) {
      ref.invalidate(notificationRulesProvider);
    }
  }

  Future<void> _runAutomationSweep() async {
    setState(() => _runningSweep = true);
    try {
      final summary = await ref.read(opsRepositoryProvider).runDueAutomations();
      if (!mounted) return;
      final message = summary.rulesFired == 0
          ? 'No due automations found.'
          : 'Ran ${summary.rulesFired} rule(s), sent ${summary.notificationsSent} notification(s).';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Automation run failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _runningSweep = false);
    }
  }
}
