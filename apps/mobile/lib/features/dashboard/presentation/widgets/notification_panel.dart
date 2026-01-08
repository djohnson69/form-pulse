import 'package:flutter/material.dart';

enum NotificationPriority { urgent, high, medium, low }

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timeLabel,
    required this.icon,
    required this.priority,
  });

  final String id;
  final String title;
  final String description;
  final String timeLabel;
  final IconData icon;
  final NotificationPriority priority;
}

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({
    super.key,
    required this.notifications,
    this.onDismiss,
    this.initialLimit = 6,
  });

  final List<NotificationItem> notifications;
  final ValueChanged<NotificationItem>? onDismiss;
  final int initialLimit;

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  var _showMore = false;
  NotificationPriority? _filter;

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final backgroundColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final filtered = _filter == null
        ? widget.notifications
        : widget.notifications
            .where((item) => item.priority == _filter)
            .toList();
    final visible = _showMore
        ? filtered
        : filtered.take(widget.initialLimit).toList();
    final counts = _priorityCounts(widget.notifications);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDesktopFilters = constraints.maxWidth >= 768;
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                    ),
                    const SizedBox(width: 8),
                    _CountChip(
                      label: filtered.length.toString(),
                      background: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                          : const Color(0xFFDBEAFE),
                      foreground:
                          isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    const Spacer(),
                    if (showDesktopFilters)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          _PriorityFilter(
                            active: _filter,
                            counts: counts,
                            compact: false,
                            onSelected: (value) => setState(() => _filter = value),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (!showDesktopFilters)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_outlined,
                        size: 16,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PriorityFilter(
                          active: _filter,
                          counts: counts,
                          compact: true,
                          onSelected: (value) => setState(() => _filter = value),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _emptyLabel(_filter),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      )
                    else
                      ...visible.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NotificationTile(
                            item: item,
                            onDismiss: widget.onDismiss,
                          ),
                        ),
                      ),
                    if (filtered.length > widget.initialLimit)
                      TextButton.icon(
                        onPressed: () => setState(() => _showMore = !_showMore),
                        icon: Icon(
                          _showMore ? Icons.expand_less : Icons.expand_more,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFF374151),
                          backgroundColor: isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFF3F4F6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        label: Text(
                          _showMore
                              ? 'Show Less'
                              : 'Show ${filtered.length - widget.initialLimit} More',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PriorityFilter extends StatelessWidget {
  const _PriorityFilter({
    required this.active,
    required this.counts,
    required this.compact,
    required this.onSelected,
  });

  final NotificationPriority? active;
  final Map<NotificationPriority?, int> counts;
  final bool compact;
  final ValueChanged<NotificationPriority?> onSelected;

  @override
  Widget build(BuildContext context) {
    final priorities = <NotificationPriority?>[
      null,
      NotificationPriority.urgent,
      NotificationPriority.high,
      NotificationPriority.medium,
      NotificationPriority.low,
    ];
    final labels = <NotificationPriority?, String>{
      null: 'All',
      NotificationPriority.urgent: 'Urgent',
      NotificationPriority.high: 'High',
      NotificationPriority.medium: 'Medium',
      NotificationPriority.low: 'Low',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: priorities.map((priority) {
          final selected = priority == active;
          final count = counts[priority] ?? 0;
          final colors =
              _priorityFilterStyle(context, priority, selected: selected, compact: compact);
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(priority),
              child: Container(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                    : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  count > 0
                      ? '${labels[priority] ?? ''} ($count)'
                      : labels[priority] ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.item,
    required this.onDismiss,
  });

  final NotificationItem item;
  final ValueChanged<NotificationItem>? onDismiss;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _priorityCardStyle(context, widget.item.priority);
    final background = _isHovered ? colors.hoverBackground : colors.background;
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.item.icon, size: 16, color: colors.icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final title = Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.title,
                          ),
                    );
                    final trailing = FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CountChip(
                            label: widget.item.priority.name,
                            background: colors.badgeBackground,
                            foreground: colors.badgeText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            onPressed: widget.onDismiss == null
                                ? null
                                : () => widget.onDismiss!(widget.item),
                            icon: Icon(
                              Icons.check,
                              size: 14,
                              color: colors.dismiss,
                            ),
                          ),
                        ],
                      ),
                    );
                    final isNarrow = constraints.maxWidth < 260;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: trailing,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        trailing,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.description),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.timeLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colors.time),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final wrapped = widget.item.priority == NotificationPriority.urgent
        ? _Pulse(child: content)
        : content;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.basic,
      child: wrapped,
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  });

  final String label;
  final Color background;
  final Color foreground;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

_PriorityFilterStyle _priorityFilterStyle(
  BuildContext context,
  NotificationPriority? priority, {
  required bool selected,
  required bool compact,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (!selected) {
    return _PriorityFilterStyle(
      background: compact
          ? isDark
              ? const Color(0xFF1F2937)
              : const Color(0xFFF9FAFB)
          : Colors.transparent,
      border: compact
          ? isDark
              ? const Color(0xFF374151)
              : const Color(0xFFE5E7EB)
          : Colors.transparent,
      foreground:
          isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
    );
  }

  if (priority == null) {
    return _PriorityFilterStyle(
      background: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      foreground: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
    );
  }

  switch (priority) {
    case NotificationPriority.urgent:
    case NotificationPriority.high:
      return _PriorityFilterStyle(
        background: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFFFEE2E2),
        border: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFFFEE2E2),
        foreground:
            isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      );
    case NotificationPriority.medium:
      return _PriorityFilterStyle(
        background: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : const Color(0xFFFEF3C7),
        border: isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : const Color(0xFFFEF3C7),
        foreground:
            isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      );
    case NotificationPriority.low:
      return _PriorityFilterStyle(
        background: isDark
            ? const Color(0xFF14532D).withValues(alpha: 0.3)
            : const Color(0xFFDCFCE7),
        border: isDark
            ? const Color(0xFF14532D).withValues(alpha: 0.3)
            : const Color(0xFFDCFCE7),
        foreground:
            isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      );
  }
}

_NotificationCardStyle _priorityCardStyle(
  BuildContext context,
  NotificationPriority priority,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const red50 = Color(0xFFFEF2F2);
  const red100 = Color(0xFFFEE2E2);
  const red200 = Color(0xFFFECACA);
  const red300 = Color(0xFFFCA5A5);
  const red400 = Color(0xFFF87171);
  const red500 = Color(0xFFEF4444);
  const red600 = Color(0xFFDC2626);
  const red700 = Color(0xFFB91C1C);
  const red800 = Color(0xFF991B1B);
  const red900 = Color(0xFF7F1D1D);
  const yellow50 = Color(0xFFFFFBEB);
  const yellow100 = Color(0xFFFEF3C7);
  // const yellow200 = Color(0xFFFDE68A);
  const yellow300 = Color(0xFFFCD34D);
  const yellow400 = Color(0xFFFBBF24);
  const yellow500 = Color(0xFFF59E0B);
  const yellow600 = Color(0xFFD97706);
  const yellow700 = Color(0xFFB45309);
  // const yellow800 = Color(0xFF92400E);
  const yellow900 = Color(0xFF78350F);
  const green50 = Color(0xFFF0FDF4);
  const green100 = Color(0xFFDCFCE7);
  // const green200 = Color(0xFFBBF7D0);
  const green300 = Color(0xFF86EFAC);
  const green400 = Color(0xFF4ADE80);
  const green500 = Color(0xFF22C55E);
  const green600 = Color(0xFF16A34A);
  const green700 = Color(0xFF15803D);
  // const green800 = Color(0xFF166534);
  const green900 = Color(0xFF14532D);

  switch (priority) {
    case NotificationPriority.urgent:
      return _NotificationCardStyle(
        background: isDark ? red900.withValues(alpha: 0.4) : red100,
        hoverBackground:
            isDark ? red900.withValues(alpha: 0.5) : red200,
        border: Colors.transparent,
        icon: isDark ? red400 : red600,
        title: isDark ? red200 : red900,
        description: isDark ? red300 : red800,
        time: isDark ? red400 : red700,
        badgeBackground: red600,
        badgeText: Colors.white,
        dismiss: isDark ? red400 : red600,
      );
    case NotificationPriority.high:
      return _NotificationCardStyle(
        background: isDark ? red900.withValues(alpha: 0.2) : red50,
        hoverBackground:
            isDark ? red900.withValues(alpha: 0.3) : red100,
        border: Colors.transparent,
        icon: isDark ? red400 : red600,
        title: isDark ? red300 : red900,
        description: isDark ? red400 : red700,
        time: isDark ? red500 : red600,
        badgeBackground: red500,
        badgeText: Colors.white,
        dismiss: isDark ? red400 : red600,
      );
    case NotificationPriority.medium:
      return _NotificationCardStyle(
        background: isDark ? yellow900.withValues(alpha: 0.2) : yellow50,
        hoverBackground:
            isDark ? yellow900.withValues(alpha: 0.3) : yellow100,
        border: Colors.transparent,
        icon: isDark ? yellow400 : yellow600,
        title: isDark ? yellow300 : yellow900,
        description: isDark ? yellow400 : yellow700,
        time: isDark ? yellow500 : yellow600,
        badgeBackground: yellow500,
        badgeText: Colors.white,
        dismiss: isDark ? yellow400 : yellow600,
      );
    case NotificationPriority.low:
      return _NotificationCardStyle(
        background: isDark ? green900.withValues(alpha: 0.2) : green50,
        hoverBackground:
            isDark ? green900.withValues(alpha: 0.3) : green100,
        border: Colors.transparent,
        icon: isDark ? green400 : green600,
        title: isDark ? green300 : const Color(0xFF14532D),
        description: isDark ? green400 : green700,
        time: isDark ? green500 : green600,
        badgeBackground: green500,
        badgeText: Colors.white,
        dismiss: isDark ? green400 : green600,
      );
  }
}

class _PriorityFilterStyle {
  const _PriorityFilterStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

class _NotificationCardStyle {
  const _NotificationCardStyle({
    required this.background,
    required this.hoverBackground,
    required this.border,
    required this.icon,
    required this.title,
    required this.description,
    required this.time,
    required this.badgeBackground,
    required this.badgeText,
    required this.dismiss,
  });

  final Color background;
  final Color hoverBackground;
  final Color border;
  final Color icon;
  final Color title;
  final Color description;
  final Color time;
  final Color badgeBackground;
  final Color badgeText;
  final Color dismiss;
}

Map<NotificationPriority?, int> _priorityCounts(
  List<NotificationItem> items,
) {
  return {
    null: items.length,
    NotificationPriority.urgent:
        items.where((item) => item.priority == NotificationPriority.urgent).length,
    NotificationPriority.high:
        items.where((item) => item.priority == NotificationPriority.high).length,
    NotificationPriority.medium:
        items.where((item) => item.priority == NotificationPriority.medium).length,
    NotificationPriority.low:
        items.where((item) => item.priority == NotificationPriority.low).length,
  };
}

String _emptyLabel(NotificationPriority? filter) {
  if (filter == null) {
    return 'No notifications';
  }
  return 'No ${filter.name} priority notifications';
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
