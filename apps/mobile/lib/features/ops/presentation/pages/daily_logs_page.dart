import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../data/ops_provider.dart';
import '../../data/ops_repository.dart';

class DailyLogsPage extends ConsumerStatefulWidget {
  const DailyLogsPage({super.key});

  @override
  ConsumerState<DailyLogsPage> createState() => _DailyLogsPageState();
}

class _DailyLogsPageState extends ConsumerState<DailyLogsPage> {
  RealtimeChannel? _dailyLogsChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToDailyLogs();
  }

  @override
  void dispose() {
    _dailyLogsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToDailyLogs() {
    final client = Supabase.instance.client;
    _dailyLogsChannel = client.channel('daily-logs')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'daily_logs',
        callback: (_) {
          if (!mounted) return;
          ref.invalidate(dailyLogsProvider);
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(dailyLogsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Logs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New log'),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (logs) {
          if (logs.isEmpty) {
            return const _EmptyState(
              title: 'No daily logs yet',
              message: 'Capture field activity and AI summaries here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final title = log.title?.trim().isNotEmpty == true
                  ? log.title!.trim()
                  : 'Daily log';
              final preview = log.content?.trim() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(title),
                  subtitle: Text(
                    '${_formatDate(log.logDate)} • ${preview.isEmpty ? 'No content' : _ellipsis(preview)}',
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
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    DateTime logDate = DateTime.now();
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
                  Text('Create daily log',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Log details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final aiResult =
                            await showModalBottomSheet<AiAssistResult>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => AiAssistSheet(
                            title: 'AI Daily Log',
                            initialText: contentController.text.trim(),
                            initialType: 'daily_log',
                            allowImage: false,
                          ),
                        );
                        if (aiResult == null) return;
                        final output = aiResult.outputText.trim();
                        if (output.isEmpty) return;
                        setState(() => contentController.text = output);
                        await _recordAiUsage(ref, aiResult);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('AI Assist'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text('Log date: ${_formatDate(logDate)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          initialDate: logDate,
                        );
                        if (picked == null) return;
                        setState(() => logDate = picked);
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final content = contentController.text.trim();
                            if (content.isEmpty) return;
                            setState(() => isSaving = true);
                            try {
                              await ref.read(opsRepositoryProvider).createDailyLog(
                                    content: content,
                                    title: titleController.text.trim().isEmpty
                                        ? null
                                        : titleController.text.trim(),
                                    logDate: logDate,
                                    metadata: const {'source': 'manual'},
                                  );
                              if (context.mounted) Navigator.of(context).pop(true);
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: Text(isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    titleController.dispose();
    contentController.dispose();
    if (result == true) {
      ref.invalidate(dailyLogsProvider);
    }
  }

  Future<void> _recordAiUsage(WidgetRef ref, AiAssistResult result) async {
    try {
      final attachments = <AttachmentDraft>[];
      if (result.audioBytes != null) {
        attachments.add(
          AttachmentDraft(
            type: 'audio',
            bytes: result.audioBytes!,
            filename: result.audioName ?? 'ai-audio',
            mimeType: result.audioMimeType ?? 'audio/m4a',
          ),
        );
      }
      await ref.read(opsRepositoryProvider).createAiJob(
            type: result.type,
            inputText: result.inputText.isEmpty ? null : result.inputText,
            outputText: result.outputText,
            inputMedia: attachments,
            metadata: const {'source': 'daily_log_editor'},
          );
    } catch (e, st) {
      // Ignore failures; AI output is already in the editor.
      developer.log('DailyLogsPage AI assist logging failed',
          error: e, stackTrace: st, name: 'DailyLogsPage._logAiUsage');
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _ellipsis(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 77)}...';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Error: $message'));
  }
}
