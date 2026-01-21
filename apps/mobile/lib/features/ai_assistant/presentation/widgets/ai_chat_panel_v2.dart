import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/ai_chat_providers.dart';
import '../../domain/models/chat_message.dart';

/// Rebuilt AI chat panel with persistence, markdown, and improved UX
class AiChatPanelV2 extends ConsumerStatefulWidget {
  const AiChatPanelV2({
    super.key,
    this.maxHeight = 400,
    this.suggestions,
    this.placeholder = 'Ask me anything...',
  });

  final double maxHeight;
  final List<String>? suggestions;
  final String placeholder;

  @override
  ConsumerState<AiChatPanelV2> createState() => _AiChatPanelV2State();
}

class _AiChatPanelV2State extends ConsumerState<AiChatPanelV2> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  static const _defaultSuggestions = [
    'Show my tasks',
    'Asset tracking',
    'Training progress',
    'Recent forms',
  ];

  List<String> get _suggestions => widget.suggestions ?? _defaultSuggestions;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty) return;

    _controller.clear();
    await ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final messages = chatState.messages;
    final isSending = chatState.isSending;
    final scheme = Theme.of(context).colorScheme;
    final hasMessages = messages.isNotEmpty;

    // Only scroll when NEW messages arrive (not on every rebuild)
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggestion chips (only when no messages)
          if (!hasMessages) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions
                  .map((suggestion) => _SuggestionChip(
                        label: suggestion,
                        onPressed: isSending ? null : () => _sendMessage(suggestion),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Messages list - takes remaining space
          Expanded(
            child: hasMessages
                ? ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      // Use key for efficient rebuilds - only changed messages rebuild
                      return _MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                      );
                    },
                  )
                : Center(child: _EmptyState()),
          ),

          // Typing indicator
          if (isSending) ...[
            const SizedBox(height: 8),
            const _TypingIndicator(),
          ],

          // Error message with retry
          if (chatState.error != null && !isSending) ...[
            const SizedBox(height: 8),
            _ErrorMessage(
              onRetry: () => ref.read(aiChatProvider.notifier).retryLastMessage(),
            ),
          ],

          const SizedBox(height: 12),

          // Input field - fixed at bottom
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !isSending,
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
                  onPressed: isSending ? null : () => _sendMessage(),
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
    );
  }
}

/// Empty state when no messages
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask a question to get instant help with tasks, forms, and assets.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Message bubble with markdown support and timestamp
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message});

  final ChatMessage message;

  MarkdownStyleSheet _getStyleSheet(BuildContext context, Color textColor) {
    final textTheme = Theme.of(context).textTheme;
    return MarkdownStyleSheet(
      p: textTheme.bodyMedium?.copyWith(color: textColor, height: 1.4),
      strong: textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      em: textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontStyle: FontStyle.italic,
        height: 1.4,
      ),
      h1: textTheme.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      h2: textTheme.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      h3: textTheme.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
      listBullet: textTheme.bodyMedium?.copyWith(color: textColor),
      code: textTheme.bodySmall?.copyWith(
        color: textColor,
        fontFamily: 'monospace',
        backgroundColor: textColor.withValues(alpha: 0.1),
      ),
      codeblockDecoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: textColor.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final background = isUser ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = isUser ? scheme.onPrimary : scheme.onSurface;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final timeFormat = DateFormat('h:mm a');

    // Calculate max width based on available space, not full screen
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth < 500 ? screenWidth * 0.75 : 320.0;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message content - markdown for assistant, plain text for user
            if (isUser)
              SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
              )
            else
              MarkdownBody(
                data: message.content,
                selectable: true,
                shrinkWrap: true,
                styleSheet: _getStyleSheet(context, textColor),
              ),
            const SizedBox(height: 4),
            // Timestamp
            Text(
              timeFormat.format(message.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Typing indicator
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
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
          'Thinking...',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
        ),
      ],
    );
  }
}

/// Error message with retry button
class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggestion chip
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
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
        ),
      ),
    );
  }
}
