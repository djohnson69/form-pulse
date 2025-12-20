import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';

class AiToolsPage extends ConsumerWidget {
  const AiToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(aiJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tools')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New AI job'),
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No AI jobs yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(job.type),
                  subtitle: Text(job.outputText ?? job.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final inputController = TextEditingController();
    String type = 'summary';
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
                  Text('Create AI job',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'summary', child: Text('Summary')),
                      DropdownMenuItem(value: 'caption', child: Text('Photo caption')),
                      DropdownMenuItem(value: 'recap', child: Text('Progress recap')),
                      DropdownMenuItem(value: 'translation', child: Text('Translation')),
                      DropdownMenuItem(value: 'checklist', child: Text('Checklist')),
                    ],
                    onChanged: (value) => setState(() => type = value ?? 'summary'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inputController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Input text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (inputController.text.trim().isEmpty) return;
                            setState(() => isSaving = true);
                            final output = _simpleAi(
                              type: type,
                              input: inputController.text.trim(),
                            );
                            await ref.read(opsRepositoryProvider).createAiJob(
                                  type: type,
                                  inputText: inputController.text.trim(),
                                  outputText: output,
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Generate'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    inputController.dispose();
    if (result == true) {
      ref.invalidate(aiJobsProvider);
    }
  }

  String _simpleAi({required String type, required String input}) {
    final trimmed = input.length > 160 ? '${input.substring(0, 160)}...' : input;
    switch (type) {
      case 'caption':
        return 'Caption: $trimmed';
      case 'recap':
        return 'Progress recap: $trimmed';
      case 'translation':
        return 'Translation (stub): $trimmed';
      case 'checklist':
        return 'Checklist ideas: ${trimmed.split(' ').take(8).join(' ')}...';
      case 'summary':
      default:
        return 'Summary: $trimmed';
    }
  }
}
