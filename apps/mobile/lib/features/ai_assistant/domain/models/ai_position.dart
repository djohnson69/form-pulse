import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/painting.dart';

/// Edge where the AI bubble can dock
enum DockEdge {
  left,
  right;

  bool get isLeft => this == DockEdge.left;
  bool get isRight => this == DockEdge.right;
}

/// Position state for the draggable AI assistant bubble
class AiPosition {
  const AiPosition({
    required this.y,
    required this.dockEdge,
    required this.isExpanded,
  });

  /// Vertical position (0.0 = top, 1.0 = bottom, relative to safe area)
  final double y;

  /// Which horizontal edge the bubble is docked to
  final DockEdge dockEdge;

  /// Whether the chat panel is expanded
  final bool isExpanded;

  /// Default position: bottom-right corner, collapsed
  factory AiPosition.defaultPosition() {
    return const AiPosition(
      y: 0.85, // Near bottom
      dockEdge: DockEdge.right,
      isExpanded: false,
    );
  }

  /// Create from JSON (for SharedPreferences)
  factory AiPosition.fromJson(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AiPosition(
        y: (json['y'] as num?)?.toDouble() ?? 0.85,
        dockEdge: DockEdge.values.firstWhere(
          (e) => e.name == json['dockEdge'],
          orElse: () => DockEdge.right,
        ),
        isExpanded: json['isExpanded'] as bool? ?? false,
      );
    } catch (e, st) {
      developer.log('AiPosition fromJson failed',
          error: e, stackTrace: st, name: 'AiPosition.fromJson');
      return AiPosition.defaultPosition();
    }
  }

  /// Convert to JSON string for SharedPreferences
  String toJson() {
    return jsonEncode({
      'y': y,
      'dockEdge': dockEdge.name,
      'isExpanded': isExpanded,
    });
  }

  /// Calculate the actual screen offset for the bubble
  Offset toOffset({
    required Size screenSize,
    required Size bubbleSize,
    required EdgeInsets safeArea,
    required double edgePadding,
  }) {
    final safeTop = safeArea.top + edgePadding;
    final safeBottom = screenSize.height - safeArea.bottom - bubbleSize.height - edgePadding;
    final safeHeight = safeBottom - safeTop;

    final actualY = safeTop + (y * safeHeight);

    final actualX = dockEdge.isLeft
        ? edgePadding
        : screenSize.width - bubbleSize.width - edgePadding;

    return Offset(actualX, actualY.clamp(safeTop, safeBottom));
  }

  /// Create position from a drag offset
  factory AiPosition.fromOffset({
    required Offset offset,
    required Size screenSize,
    required Size bubbleSize,
    required EdgeInsets safeArea,
    required double edgePadding,
    required bool isExpanded,
  }) {
    final safeTop = safeArea.top + edgePadding;
    final safeBottom = screenSize.height - safeArea.bottom - bubbleSize.height - edgePadding;
    final safeHeight = safeBottom - safeTop;

    // Calculate relative Y position (0.0 to 1.0)
    final relativeY = safeHeight > 0
        ? ((offset.dy - safeTop) / safeHeight).clamp(0.0, 1.0)
        : 0.85;

    // Determine dock edge based on which side is closer
    final centerX = offset.dx + bubbleSize.width / 2;
    final dockEdge = centerX < screenSize.width / 2 ? DockEdge.left : DockEdge.right;

    return AiPosition(
      y: relativeY,
      dockEdge: dockEdge,
      isExpanded: isExpanded,
    );
  }

  AiPosition copyWith({
    double? y,
    DockEdge? dockEdge,
    bool? isExpanded,
  }) {
    return AiPosition(
      y: y ?? this.y,
      dockEdge: dockEdge ?? this.dockEdge,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiPosition &&
        other.y == y &&
        other.dockEdge == dockEdge &&
        other.isExpanded == isExpanded;
  }

  @override
  int get hashCode => Object.hash(y, dockEdge, isExpanded);
}
