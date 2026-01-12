import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/ai/ai_providers.dart';
import '../../../dashboard/data/user_profile_provider.dart';
import '../../../projects/data/projects_provider.dart';
import '../../../tasks/data/tasks_provider.dart';

class AiChatPanel extends ConsumerStatefulWidget {
  const AiChatPanel({
    super.key,
    this.suggestions = const [],
    this.placeholder = 'Ask a question...',
    this.initialMessage,
    this.maxHeight = 240,
  });

  final List<String> suggestions;
  final String placeholder;
  final String? initialMessage;
  final double maxHeight;

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AiChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMessage;
    if (initial != null && initial.trim().isNotEmpty) {
      _messages.add(_AiChatMessage.assistant(initial.trim()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? value]) async {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _messages.add(_AiChatMessage.user(text));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();
    try {
      final prompt = await _buildPrompt(text);
      final ai = ref.read(aiJobRunnerProvider);
      final response = await ai.runJob(
        type: 'assistant',
        inputText: prompt,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_AiChatMessage.assistant(response.trim()));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AiChatMessage.assistant(
            'AI is unavailable right now. ${error.toString()}',
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _buildPrompt(String question) async {
    // Gather app context
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    // Build context string
    final contextParts = <String>[];

    // Conversation history (exclude latest user message already in question)
    if (_messages.length > 1) {
      final history = _messages.sublist(0, _messages.length - 1);
      final recentHistory = history.length > 6
          ? history.sublist(history.length - 6)
          : history;
      final transcript = recentHistory
          .map((message) =>
              '${message.role == _AiChatRole.user ? 'User' : 'Assistant'}: ${message.text}')
          .join('\n');
      if (transcript.trim().isNotEmpty) {
        contextParts.add('Conversation History:\n$transcript');
      }
    }

    // User info
    if (user != null) {
      UserProfile? profile;
      try {
        final loadedProfile = await ref.read(userProfileProvider.future);
        profile = loadedProfile;
        contextParts.add('User ID: ${loadedProfile.id}');
        if (loadedProfile.email != null) {
          contextParts.add('Email: ${loadedProfile.email}');
        }
        if (loadedProfile.orgId != null) {
          contextParts.add('Organization ID: ${loadedProfile.orgId}');
        }
        
        // Get role
        final roleRes = await client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        final roleStr = roleRes?['role']?.toString() ?? 'viewer';
        contextParts.add('Role: $roleStr');
      } catch (e) {
        contextParts.add('User: ${user.email ?? "Unknown"}');
      }

      // Get projects
      try {
        final projects = await ref.read(projectsProvider.future);
        contextParts.add('Projects: ${projects.length}');
        if (projects.isNotEmpty) {
          final formatter = DateFormat('MMM d, yyyy');
          final lines = projects.take(5).map((project) {
            final metadata = project.metadata ?? const <String, dynamic>{};
            final rawDue =
                metadata['dueDate'] ?? metadata['due_date'] ?? metadata['due'];
            DateTime? dueDate;
            if (rawDue is String) {
              dueDate = DateTime.tryParse(rawDue);
            } else if (rawDue is DateTime) {
              dueDate = rawDue;
            }
            final dueLabel =
                dueDate == null ? '' : ' (due ${formatter.format(dueDate)})';
            return '- ${project.name} [${project.status}]$dueLabel';
          }).join('\n');
          contextParts.add('Recent Projects:\n$lines');
        }
      } catch (e) {
        contextParts.add('Projects: Unable to load');
      }
      
      // Get tasks
      try {
        final tasks = await ref.read(tasksProvider.future);
        final activeTasks = tasks.where((t) => !t.isComplete).toList();
        contextParts.add('Active Tasks: ${activeTasks.length}');
        if (activeTasks.isNotEmpty && activeTasks.length <= 5) {
          final formatter = DateFormat('MMM d, yyyy');
          final taskList = activeTasks
              .map((t) =>
                  '- ${t.title}${t.dueDate != null ? " (due ${formatter.format(t.dueDate!.toLocal())})" : ""} [${t.status.name}]')
              .join('\n');
          contextParts.add('Current Tasks:\n$taskList');
        } else if (activeTasks.length > 5) {
          final topTasks = activeTasks.take(5).map((t) => t.title).join(', ');
          contextParts.add('Recent Tasks: $topTasks, and ${activeTasks.length - 5} more');
        }
      } catch (e) {
        contextParts.add('Tasks: Unable to load');
      }
      
      // Get work orders
      try {
        final orgId = profile?.orgId;
        if (orgId != null) {
        final workOrders = await client
            .from('work_orders')
            .select('id, title, status, priority, due_date')
            .eq('org_id', orgId)
            .order('updated_at', ascending: false)
            .limit(5);
          final orderList = workOrders as List<dynamic>;
          if (orderList.isNotEmpty) {
            final formatter = DateFormat('MMM d, yyyy');
            final lines = orderList.map((row) {
              final data = row as Map;
              final title = data['title']?.toString() ?? 'Work Order';
              final status = data['status']?.toString() ?? 'unknown';
              final priority = data['priority']?.toString() ?? 'normal';
              final dueRaw = data['due_date']?.toString();
              final dueDate = dueRaw == null ? null : DateTime.tryParse(dueRaw);
              final dueLabel =
                  dueDate == null ? '' : ' (due ${formatter.format(dueDate)})';
              return '- $title [$status/$priority]$dueLabel';
            }).join('\n');
            contextParts.add('Recent Work Orders:\n$lines');
          }
        }
      } catch (e) {
        contextParts.add('Work Orders: Unable to load');
      }

      // Get recent forms
      try {
        final formsRes = await client
            .from('forms')
            .select('id, title, category')
            .eq('is_published', true)
            .order('updated_at', ascending: false)
            .limit(3);
        if (formsRes.isNotEmpty) {
          final formTitles = (formsRes as List)
              .map((f) => f['title']?.toString() ?? 'Untitled')
              .join(', ');
          contextParts.add('Available Forms: $formTitles');
        }
      } catch (e) {
        // Silently skip forms context
      }
      
      // Get assets count
      try {
        final assetsRes = await client
            .from('assets')
            .select('id')
            .eq('assigned_to', user.id);
        final count = (assetsRes as List<dynamic>).length;
        if (count > 0) {
          contextParts.add('Assigned Assets: $count');
        }
      } catch (e) {
        // Silently skip assets context
      }
    }
    
    final context = contextParts.isNotEmpty 
        ? '\n\nContext:\n${contextParts.join('\n')}'
        : '';
    
    return 'Use the context to answer the user. If details are missing, say so and ask a clarifying question. '
        'When listing records, include name, status, and due date if available.'
        '$context'
        '\n\nUser question: $question';
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasMessages = _messages.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.suggestions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.suggestions
                .map(
                  (suggestion) => _SuggestionChip(
                    label: suggestion,
                    onPressed: _isSending ? null : () => _sendMessage(suggestion),
                  ),
                )
                .toList(),
          ),
        if (widget.suggestions.isNotEmpty) const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: hasMessages
                    ? ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _AiChatBubble(message: message);
                        },
                      )
                    : _AiChatEmptyState(),
              ),
              if (_isSending) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generating response...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isSending,
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: FilledButton(
                      onPressed: _isSending ? null : () => _sendMessage(),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AiChatEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Ask a question to get instant help with audits, workflows, and forms.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _AiChatBubble extends StatelessWidget {
  const _AiChatBubble({required this.message});

  final _AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == _AiChatRole.user;
    final background =
        isUser ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isUser ? scheme.onPrimary : scheme.onSurface;
    final alignment =
        isUser ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                height: 1.3,
              ),
        ),
      ),
    );
  }
}

enum _AiChatRole { user, assistant }

class _AiChatMessage {
  _AiChatMessage(this.role, this.text);

  final _AiChatRole role;
  final String text;

  factory _AiChatMessage.user(String text) =>
      _AiChatMessage(_AiChatRole.user, text);

  factory _AiChatMessage.assistant(String text) =>
      _AiChatMessage(_AiChatRole.assistant, text);
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled 
              ? scheme.secondaryContainer.withValues(alpha: 0.5)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled 
                ? scheme.outline.withValues(alpha: 0.3)
                : scheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isEnabled 
                ? scheme.onSecondaryContainer
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
