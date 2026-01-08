import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_providers.dart';

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
      final ai = ref.read(aiJobRunnerProvider);
      final response = await ai.runJob(
        type: 'summary',
        inputText: _buildPrompt(text),
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

  String _buildPrompt(String question) {
    return 'You are Form Bridge AI assistant for enterprise operations teams. '
        'Answer with concise, actionable guidance in 3-5 bullets. '
        'Question: $question';
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
                  (suggestion) => ActionChip(
                    label: Text(suggestion),
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
