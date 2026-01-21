import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/ai_assistant/data/ai_chat_providers.dart';
import '../../features/ai_assistant/domain/models/ai_position.dart';
import '../../features/ai_assistant/presentation/widgets/ai_chat_panel_v2.dart';
import '../state/demo_mode_provider.dart';

/// Draggable AI Assistant overlay that can be positioned anywhere on screen
class AiAssistantOverlay extends ConsumerStatefulWidget {
  const AiAssistantOverlay({super.key});

  @override
  ConsumerState<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends ConsumerState<AiAssistantOverlay>
    with SingleTickerProviderStateMixin {
  static const _bubbleSize = Size(56, 56);
  static const _edgePadding = 16.0;

  // Use ValueNotifier for efficient drag updates (no full rebuild)
  final _dragOffsetNotifier = ValueNotifier<Offset?>(null);
  bool _isDragging = false;

  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Single persistent listener for snap animation
    _snapController.addListener(_onSnapAnimationTick);
  }

  @override
  void dispose() {
    _snapController.removeListener(_onSnapAnimationTick);
    _snapController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  void _onSnapAnimationTick() {
    if (_snapAnimation != null && mounted) {
      _dragOffsetNotifier.value = _snapAnimation!.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isDemoMode = ref.watch(demoModeProvider);
    final segments = Uri.base.pathSegments;

    // Hide when not authenticated or on share routes
    if ((user == null && !isDemoMode) ||
        (segments.isNotEmpty && segments.first == 'share')) {
      return const SizedBox.shrink();
    }

    final position = ref.watch(aiPositionProvider);
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final scheme = Theme.of(context).colorScheme;

    // Calculate offset
    final baseOffset = position.toOffset(
      screenSize: screenSize,
      bubbleSize: _bubbleSize,
      safeArea: safeArea,
      edgePadding: _edgePadding,
    );

    // Panel dimensions - responsive for mobile/tablet/desktop
    final isCompact = screenSize.width < 480;
    final isMobile = screenSize.width < 600;
    final panelWidth = isCompact
        ? screenSize.width - 24
        : (isMobile ? screenSize.width * 0.9 : 384.0);
    final panelHeight = screenSize.height < 600
        ? screenSize.height * 0.7
        : (screenSize.height < 800 ? screenSize.height * 0.6 : 550.0);

    // Calculate panel position based on bubble position
    final panelLeft = position.dockEdge == DockEdge.left
        ? _edgePadding
        : screenSize.width - panelWidth - _edgePadding;

    return Stack(
      children: [
        // Use ValueListenableBuilder for efficient bubble position updates
        ValueListenableBuilder<Offset?>(
          valueListenable: _dragOffsetNotifier,
          builder: (context, dragOffset, child) {
            final currentOffset = dragOffset ?? baseOffset;

            // Panel top depends on bubble position
            final panelTop = (currentOffset.dy - panelHeight + _bubbleSize.height)
                .clamp(safeArea.top + _edgePadding, screenSize.height - panelHeight - safeArea.bottom - _edgePadding);

            return Stack(
              children: [
                // Expanded chat panel
                if (position.isExpanded)
                  Positioned(
                    left: panelLeft,
                    top: panelTop,
                    child: _buildExpandedPanel(
                      context,
                      panelWidth,
                      panelHeight,
                      scheme,
                      position,
                    ),
                  ),

                // Draggable bubble - only show when collapsed
                if (!position.isExpanded)
                  Positioned(
                    left: currentOffset.dx,
                    top: currentOffset.dy,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: (details) => _onPanUpdate(details, screenSize, safeArea),
                      onPanEnd: (details) => _onPanEnd(details, screenSize, safeArea, position),
                      onTap: _isDragging ? null : () => _toggleExpanded(position),
                      child: _AiBubble(
                        isDragging: _isDragging,
                        isExpanded: position.isExpanded,
                        scheme: scheme,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpandedPanel(
    BuildContext context,
    double width,
    double height,
    ColorScheme scheme,
    AiPosition position,
  ) {
    return Material(
      elevation: 10,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            // Header - uses theme primary color
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Assistant',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onPrimary,
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
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Always available',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onPrimary.withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // New conversation button
                  GestureDetector(
                    onTap: () {
                      ref.read(aiChatProvider.notifier).startNewConversation();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.add, size: 20, color: scheme.onPrimary),
                    ),
                  ),
                  // Delete history button
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete All History'),
                          content: const Text('Are you sure you want to delete all chat history? This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(aiChatProvider.notifier).deleteAllHistory();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline, size: 18, color: scheme.onPrimary),
                    ),
                  ),
                  // Minimize button
                  GestureDetector(
                    onTap: () => _toggleExpanded(position),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.minimize, color: scheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            // Chat panel - uses theme surface color
            Expanded(
              child: ColoredBox(
                color: scheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AiChatPanelV2(
                    maxHeight: height - 100,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    _snapController.stop();
    _snapAnimation = null;
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize, EdgeInsets safeArea) {
    // Use ValueNotifier for efficient updates - no setState needed
    final position = ref.read(aiPositionProvider);
    final baseOffset = position.toOffset(
      screenSize: screenSize,
      bubbleSize: _bubbleSize,
      safeArea: safeArea,
      edgePadding: _edgePadding,
    );
    final current = _dragOffsetNotifier.value ?? baseOffset;
    var newOffset = current + details.delta;

    // Clamp to screen bounds
    newOffset = Offset(
      newOffset.dx.clamp(
        _edgePadding,
        screenSize.width - _bubbleSize.width - _edgePadding,
      ),
      newOffset.dy.clamp(
        safeArea.top + _edgePadding,
        screenSize.height - _bubbleSize.height - safeArea.bottom - _edgePadding,
      ),
    );

    _dragOffsetNotifier.value = newOffset;
  }

  void _onPanEnd(
    DragEndDetails details,
    Size screenSize,
    EdgeInsets safeArea,
    AiPosition currentPosition,
  ) {
    final currentDragOffset = _dragOffsetNotifier.value;
    if (currentDragOffset == null) {
      setState(() => _isDragging = false);
      return;
    }

    // Calculate snap position
    final snapPosition = AiPosition.fromOffset(
      offset: currentDragOffset,
      screenSize: screenSize,
      bubbleSize: _bubbleSize,
      safeArea: safeArea,
      edgePadding: _edgePadding,
      isExpanded: currentPosition.isExpanded,
    );

    final targetOffset = snapPosition.toOffset(
      screenSize: screenSize,
      bubbleSize: _bubbleSize,
      safeArea: safeArea,
      edgePadding: _edgePadding,
    );

    // Animate to snap position
    _snapAnimation = Tween<Offset>(
      begin: currentDragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    _snapController.forward(from: 0).then((_) {
      if (mounted) {
        _dragOffsetNotifier.value = null;
        _snapAnimation = null;
        setState(() => _isDragging = false);
      }
    });

    // Save position
    ref.read(aiPositionProvider.notifier).updatePosition(snapPosition);
  }

  void _toggleExpanded(AiPosition position) {
    ref.read(aiPositionProvider.notifier).toggleExpanded();
  }
}

/// The AI assistant bubble (collapsed state)
class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.isDragging,
    required this.isExpanded,
    required this.scheme,
  });

  final bool isDragging;
  final bool isExpanded;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isDragging ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDragging ? 0.3 : 0.26),
                blurRadius: isDragging ? 16 : 12,
                offset: Offset(0, isDragging ? 8 : 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  isExpanded ? Icons.close : Icons.smart_toy_outlined,
                  color: scheme.onPrimary,
                ),
              ),
              if (!isExpanded)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.onPrimary, width: 2),
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
