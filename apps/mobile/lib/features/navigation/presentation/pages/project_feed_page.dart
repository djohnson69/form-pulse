import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class ProjectFeedPage extends StatefulWidget {
  const ProjectFeedPage({super.key});

  @override
  State<ProjectFeedPage> createState() => _ProjectFeedPageState();
}

class _ProjectFeedPageState extends State<ProjectFeedPage> {
  final _random = Random();
  _FeedFilter _filter = _FeedFilter.all;
  bool _autoRefresh = true;
  Timer? _timer;
  late List<_FeedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<_FeedItem>.from(_seedFeedItems);
    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (!_autoRefresh) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() {
        _items = [_randomItem(), ..._items];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final filtered = _filterItems(_items);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(title: const Text('Project Feed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildFilters(context, filtered.length, _items.length),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _EmptyFeedCard(border: border)
          else
            ...filtered.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeedCard(item: item, border: border),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project Feed',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Real-time updates from all projects',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Live Updates'),
          value: _autoRefresh,
          onChanged: (value) {
            setState(() => _autoRefresh = value);
            _startTimerIfNeeded();
          },
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, int filtered, int total) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$filtered ${filtered == 1 ? 'update' : 'updates'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _FeedFilter.values.map((filter) {
              final selected = filter == _filter;
              return ChoiceChip(
                label: Text(filter.label),
                selected: selected,
                onSelected: (_) => setState(() => _filter = filter),
                selectedColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<_FeedItem> _filterItems(List<_FeedItem> items) {
    if (_filter == _FeedFilter.all) return items;
    return items.where((item) => item.type == _filter.type).toList();
  }

  _FeedItem _randomItem() {
    final samples = [
      _FeedItem(
        id: 'rnd-${DateTime.now().millisecondsSinceEpoch}',
        type: _FeedType.task,
        title: 'New Update Available',
        description: 'Real-time update from the field',
        user: 'Field Worker',
        avatar: 'FW',
        time: DateTime.now(),
        project: 'Live Project',
        location: 'Various',
        status: _FeedStatus.pending,
        likes: 0,
        comments: 0,
      ),
      _FeedItem(
        id: 'rnd-${DateTime.now().millisecondsSinceEpoch}-p',
        type: _FeedType.photo,
        title: 'Photo uploaded',
        description: 'New photo evidence captured on-site',
        user: 'Emily Davis',
        avatar: 'ED',
        time: DateTime.now(),
        project: 'Site Update',
        location: 'Main Site',
        status: _FeedStatus.completed,
        likes: 1,
        comments: 0,
      ),
    ];
    return samples[_random.nextInt(samples.length)];
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item, required this.border});

  final _FeedItem item;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(item.status, theme.brightness);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarCircle(label: item.avatar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.user,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatRelative(item.time),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.project,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: item.status.label, color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(item.type.icon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _MetaRow(icon: Icons.place_outlined, label: item.location),
                _MetaRow(icon: Icons.thumb_up_outlined, label: '${item.likes}'),
                _MetaRow(
                  icon: Icons.chat_bubble_outline,
                  label: '${item.comments}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(_FeedStatus status, Brightness brightness) {
    switch (status) {
      case _FeedStatus.completed:
        return const Color(0xFF16A34A);
      case _FeedStatus.pending:
        return const Color(0xFFF59E0B);
      case _FeedStatus.issue:
        return const Color(0xFFDC2626);
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard({required this.border});

  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(Icons.feed_outlined,
              size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No updates match your filters.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

enum _FeedFilter { all, photo, video, task, inspection }

enum _FeedType { photo, video, task, inspection }

enum _FeedStatus { completed, pending, issue }

extension on _FeedFilter {
  String get label {
    switch (this) {
      case _FeedFilter.all:
        return 'All';
      case _FeedFilter.photo:
        return 'Photo';
      case _FeedFilter.video:
        return 'Video';
      case _FeedFilter.task:
        return 'Task';
      case _FeedFilter.inspection:
        return 'Inspection';
    }
  }

  _FeedType? get type {
    switch (this) {
      case _FeedFilter.all:
        return null;
      case _FeedFilter.photo:
        return _FeedType.photo;
      case _FeedFilter.video:
        return _FeedType.video;
      case _FeedFilter.task:
        return _FeedType.task;
      case _FeedFilter.inspection:
        return _FeedType.inspection;
    }
  }
}

extension on _FeedType {
  IconData get icon {
    switch (this) {
      case _FeedType.photo:
        return Icons.photo_camera_outlined;
      case _FeedType.video:
        return Icons.videocam_outlined;
      case _FeedType.task:
        return Icons.check_circle_outline;
      case _FeedType.inspection:
        return Icons.report_outlined;
    }
  }
}

extension on _FeedStatus {
  String get label {
    switch (this) {
      case _FeedStatus.completed:
        return 'completed';
      case _FeedStatus.pending:
        return 'pending';
      case _FeedStatus.issue:
        return 'issue';
    }
  }
}

class _FeedItem {
  const _FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.user,
    required this.avatar,
    required this.time,
    required this.project,
    required this.location,
    required this.status,
    required this.likes,
    required this.comments,
  });

  final String id;
  final _FeedType type;
  final String title;
  final String description;
  final String user;
  final String avatar;
  final DateTime time;
  final String project;
  final String location;
  final _FeedStatus status;
  final int likes;
  final int comments;
}

String _formatRelative(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final days = diff.inDays;
  return '${days}d ago';
}

List<_FeedItem> get _seedFeedItems {
  final now = DateTime.now();
  return [
    _FeedItem(
      id: '1',
      type: _FeedType.photo,
      title: 'Foundation Inspection Completed',
      description:
          'All structural elements verified and documented with GPS coordinates',
      user: 'John Doe',
      avatar: 'JD',
      time: now.subtract(const Duration(minutes: 15)),
      project: 'Building A Construction',
      location: 'Main Site',
      status: _FeedStatus.completed,
      likes: 12,
      comments: 3,
    ),
    _FeedItem(
      id: '2',
      type: _FeedType.video,
      title: 'Equipment Operation Training',
      description:
          'Safety briefing and crane operation demonstration for new team members',
      user: 'Sarah Johnson',
      avatar: 'SJ',
      time: now.subtract(const Duration(minutes: 45)),
      project: 'Training Session',
      location: 'Warehouse',
      status: _FeedStatus.pending,
      likes: 8,
      comments: 5,
    ),
    _FeedItem(
      id: '3',
      type: _FeedType.inspection,
      title: 'Safety Audit - Zone B',
      description: 'Minor issues found and flagged for immediate attention',
      user: 'Mike Chen',
      avatar: 'MC',
      time: now.subtract(const Duration(hours: 1, minutes: 30)),
      project: 'Safety Audit',
      location: 'Zone B',
      status: _FeedStatus.issue,
      likes: 15,
      comments: 7,
    ),
    _FeedItem(
      id: '4',
      type: _FeedType.task,
      title: 'Material Delivery Confirmed',
      description: 'Steel beams and concrete supplies received and inventoried',
      user: 'Emily Davis',
      avatar: 'ED',
      time: now.subtract(const Duration(hours: 2)),
      project: 'Supply Chain',
      location: 'Storage Yard',
      status: _FeedStatus.completed,
      likes: 6,
      comments: 2,
    ),
    _FeedItem(
      id: '5',
      type: _FeedType.photo,
      title: 'Site Progress Update - Week 12',
      description:
          'Major milestones achieved this week with detailed photographic evidence',
      user: 'Tom Brown',
      avatar: 'TB',
      time: now.subtract(const Duration(hours: 3)),
      project: 'Building A Construction',
      location: 'Main Site',
      status: _FeedStatus.completed,
      likes: 24,
      comments: 9,
    ),
  ];
}
