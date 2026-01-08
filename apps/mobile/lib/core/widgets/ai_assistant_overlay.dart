import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/ops/presentation/pages/ai_tools_page.dart';
import '../../features/ops/presentation/widgets/ai_chat_panel.dart';
import '../state/demo_mode_provider.dart';

class AiAssistantOverlay extends ConsumerStatefulWidget {
  const AiAssistantOverlay({super.key});

  @override
  ConsumerState<AiAssistantOverlay> createState() =>
      _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends ConsumerState<AiAssistantOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isDemoMode = ref.watch(demoModeProvider);
    final segments = Uri.base.pathSegments;
    if ((user == null && !isDemoMode) ||
        (segments.isNotEmpty && segments.first == 'share')) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 480;
    final maxWidth = isCompact ? size.width - 24 : 384.0;
    final maxHeight = size.height < 700 ? size.height * 0.65 : 600.0;
    final scheme = Theme.of(context).colorScheme;

    final viewPadding = MediaQuery.of(context).padding;
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + viewPadding.bottom,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _expanded
              ? ConstrainedBox(
                  key: const ValueKey('ai-panel'),
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Material(
                    elevation: 10,
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.smart_toy_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Assistant',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22C55E),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Always available',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.white70,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Open AI tools',
                                icon: const Icon(Icons.open_in_new, size: 18),
                                color: Colors.white,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AiToolsPage(),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Minimize',
                                icon: const Icon(Icons.minimize),
                                color: Colors.white,
                                onPressed: () => setState(() {
                                  _expanded = false;
                                }),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: const Color(0xFFF9FAFB),
                            padding: const EdgeInsets.all(12),
                            child: AiChatPanel(
                              suggestions: const [
                                'Show my tasks',
                                'Asset tracking',
                                'Training progress',
                                'Recent forms',
                              ],
                              placeholder: 'Ask me anything...',
                              initialMessage:
                                  'Hi! I can help with tasks, forms, assets, and training.',
                              maxHeight: maxHeight - 180,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _AiAssistantBubble(
                  key: const ValueKey('ai-button'),
                  onPressed: () => setState(() {
                    _expanded = true;
                  }),
                ),
        ),
      ),
    );
  }
}

class _AiAssistantBubble extends StatelessWidget {
  const _AiAssistantBubble({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.smart_toy_outlined, color: Colors.white),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
