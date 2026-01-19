import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/ops_provider.dart';
import '../../../projects/data/projects_provider.dart';

class NewsPostsPage extends ConsumerStatefulWidget {
  const NewsPostsPage({super.key});

  @override
  ConsumerState<NewsPostsPage> createState() => _NewsPostsPageState();
}

class _NewsPostsPageState extends ConsumerState<NewsPostsPage> {
  String _categoryFilter = 'All Categories';

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    final newsAsync = ref.watch(newsPostsProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final projects = projectsAsync.asData?.value ?? const [];
    final projectNames = {
      for (final project in projects) project.id: project.name,
    };

    return Scaffold(
      backgroundColor: colors.background,
      body: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (posts) {
          final items = _mapPosts(posts, projectNames);
          final visiblePosts = _applyCategoryFilter(items);
          final announcements = _buildAnnouncements(items);
          final stats = _NewsStats.fromPosts(items);
          final categorySummaries = _buildCategorySummaries(items);
          final trending = _buildTrending(items);
          final upcomingEvents = _buildUpcomingEvents(posts);
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(onCreate: () => _openCreateSheet(context, ref)),
                const SizedBox(height: 16),
                _EmptyState(
                  title: 'No news posts yet',
                  message:
                      'Create the first company update so your team stays informed.',
                ),
              ],
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              final pagePadding = EdgeInsets.all(isWide ? 24 : 16);
              return ListView(
                padding: pagePadding,
                children: [
                  _Header(
                    onCreate: () => _openCreateSheet(context, ref),
                  ),
                  const SizedBox(height: 24),
                  if (announcements.isNotEmpty)
                    _AnnouncementsBanner(items: announcements),
                  const SizedBox(height: 24),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _NewsFeed(
                            posts: visiblePosts,
                            categoryFilter: _categoryFilter,
                            onCategoryChanged: (value) {
                              setState(() => _categoryFilter = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _NewsSidebar(
                            posts: items,
                            stats: stats,
                            categories: categorySummaries,
                            trending: trending,
                            upcomingEvents: upcomingEvents,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _NewsFeed(
                          posts: visiblePosts,
                          categoryFilter: _categoryFilter,
                          onCategoryChanged: (value) {
                            setState(() => _categoryFilter = value);
                          },
                        ),
                        const SizedBox(height: 24),
                        _NewsSidebar(
                          posts: items,
                          stats: stats,
                          categories: categorySummaries,
                          trending: trending,
                          upcomingEvents: upcomingEvents,
                        ),
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<_NewsItem> _mapPosts(
    List<NewsPost> posts,
    Map<String, String> projectNames,
  ) {
    return posts.map((post) {
      final category = _categoryForPost(post, projectNames);
      return _NewsItem(
        id: post.id,
        title: post.title,
        body: (post.body ?? '').trim(),
        category: category,
        tags: post.tags,
        priority: _priorityForPost(post),
        isPinned: _isPinned(post),
        author: post.metadata?['author']?.toString() ?? 'Company',
        dateLabel: _formatDate(post.publishedAt),
        publishedAt: post.publishedAt,
        views: _viewsForPost(post),
      );
    }).toList();
  }

  List<_NewsItem> _applyCategoryFilter(List<_NewsItem> items) {
    final resolvedFilter = _newsCategoryFilters.contains(_categoryFilter)
        ? _categoryFilter
        : 'All Categories';
    if (resolvedFilter == 'All Categories') return items;
    final selected = _normalizeCategory(resolvedFilter);
    return items
        .where((item) => _normalizeCategory(item.category) == selected)
        .toList();
  }

  String _categoryForPost(NewsPost post, Map<String, String> projectNames) {
    if (post.tags.isNotEmpty) return post.tags.first;
    if (post.scope == 'site') {
      return projectNames[post.siteId] ?? 'Project Update';
    }
    return 'Company News';
  }

  String _normalizeCategory(String category) {
    final normalized = category.trim().toLowerCase();
    if (normalized.contains('announcement')) return 'Announcements';
    if (normalized.contains('project')) return 'Projects';
    if (normalized.contains('training')) return 'Training';
    if (normalized.contains('safety')) return 'Safety';
    return category;
  }

  _NewsPriority _priorityForPost(NewsPost post) {
    final raw = post.metadata?['priority']?.toString().toLowerCase();
    switch (raw) {
      case 'high':
        return _NewsPriority.high;
      case 'medium':
        return _NewsPriority.medium;
      case 'low':
        return _NewsPriority.low;
      default:
        return _NewsPriority.medium;
    }
  }

  bool _isPinned(NewsPost post) {
    final pinned = post.metadata?['pinned'] ?? post.metadata?['isPinned'];
    return pinned == true;
  }

  int _viewsForPost(NewsPost post) {
    final raw = post.metadata?['views'];
    if (raw is num) return raw.toInt();
    return 120 + (post.title.length * 3);
  }

  List<_Announcement> _buildAnnouncements(List<_NewsItem> items) {
    final announcements = <_Announcement>[];
    final usedIds = <String>{};
    final primary = items
        .where((item) => item.isPinned || item.priority == _NewsPriority.high)
        .toList();
    for (final item in primary) {
      if (announcements.length >= 3) break;
      usedIds.add(item.id);
      announcements.add(
        _Announcement(
          text: item.body.isNotEmpty ? item.body : item.title,
          type: item.priority == _NewsPriority.high
              ? _AnnouncementType.alert
              : item.isPinned
                  ? _AnnouncementType.warning
                  : _AnnouncementType.info,
        ),
      );
    }
    if (announcements.length < 3) {
      for (final item in items) {
        if (announcements.length >= 3) break;
        if (usedIds.contains(item.id)) continue;
        announcements.add(
          _Announcement(
            text: item.body.isNotEmpty ? item.body : item.title,
            type: _AnnouncementType.info,
          ),
        );
      }
    }
    return announcements;
  }

  List<_TrendingItem> _buildTrending(List<_NewsItem> items) {
    final counts = <String, int>{};
    final labels = <String, String>{};

    void addTag(String raw) {
      final key = _normalizeTagKey(raw);
      if (key.isEmpty) return;
      counts[key] = (counts[key] ?? 0) + 1;
      labels[key] = _formatHashtag(raw);
    }

    for (final item in items) {
      for (final tag in item.tags) {
        addTag(tag);
      }
    }

    if (counts.isEmpty) {
      for (final item in items) {
        addTag(item.category);
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(3)
        .map((e) => _TrendingItem(labels[e.key] ?? '#${e.key}', e.value))
        .toList();
  }

  List<_UpcomingEvent> _buildUpcomingEvents(List<NewsPost> posts) {
    final events = <_UpcomingEvent>[];
    for (final post in posts) {
      final metadata = post.metadata;
      if (metadata == null || metadata.isEmpty) continue;
      final startsAt = _parseEventDateTime(metadata);
      if (startsAt == null) continue;
      events.add(
        _UpcomingEvent(
          title: post.title,
          dateLabel: _formatEventDate(startsAt),
          timeLabel: _eventTimeLabel(metadata, startsAt),
          startsAt: startsAt,
        ),
      );
    }
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return events.take(3).toList();
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final projects = await ref
        .read(projectsProvider.future)
        .catchError((_) => const <Project>[]);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CreateAnnouncementSheet(projects: projects),
    );
    if (result == true) {
      ref.invalidate(newsPostsProvider);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return minutes == 1 ? '1 min ago' : '$minutes min ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    if (diff.inDays < 7) {
      final days = diff.inDays;
      return days == 1 ? '1 day ago' : '$days days ago';
    }
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 4) {
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    return '${local.month}/${local.day}/${local.year}';
  }

  String _normalizeTagKey(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return '';
    final withoutHash =
        trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    return withoutHash.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  String _formatHashtag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return '';
    final withoutHash =
        trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    final cleaned = withoutHash.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return cleaned.isEmpty ? '' : '#$cleaned';
  }

  DateTime? _parseEventDateTime(Map<String, dynamic> metadata) {
    Map<String, dynamic>? eventMap;
    final rawEvent = metadata['event'];
    if (rawEvent is Map) {
      eventMap = Map<String, dynamic>.from(rawEvent);
    }
    final rawDateTime = metadata['event_datetime'] ??
        metadata['eventDateTime'] ??
        metadata['event_date_time'] ??
        eventMap?['dateTime'] ??
        eventMap?['date_time'];
    final rawDate =
        metadata['event_date'] ?? metadata['eventDate'] ?? eventMap?['date'];
    final rawTime =
        metadata['event_time'] ?? metadata['eventTime'] ?? eventMap?['time'];

    var dateTime = _parseDateValue(rawDateTime) ?? _parseDateValue(rawDate);
    if (dateTime == null) return null;
    final timeOfDay = _parseTimeOfDay(rawTime);
    if (timeOfDay != null) {
      dateTime = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );
    }
    return dateTime;
  }

  DateTime? _parseDateValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is double) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  TimeOfDay? _parseTimeOfDay(dynamic raw) {
    if (raw == null) return null;
    if (raw is TimeOfDay) return raw;
    if (raw is DateTime) {
      return TimeOfDay(hour: raw.hour, minute: raw.minute);
    }
    if (raw is int) {
      final hour = raw ~/ 60;
      final minute = raw % 60;
      return TimeOfDay(hour: hour, minute: minute);
    }
    if (raw is double) {
      final totalMinutes = raw.toInt();
      final hour = totalMinutes ~/ 60;
      final minute = totalMinutes % 60;
      return TimeOfDay(hour: hour, minute: minute);
    }
    if (raw is! String) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;
    final upper = value.toUpperCase();
    final match =
        RegExp(r'^(\\d{1,2})(?::(\\d{2}))?\\s*(AM|PM)$').firstMatch(upper);
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2) ?? '0');
      final period = match.group(3);
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    }
    if (value.contains(':')) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    final hour = int.tryParse(value);
    if (hour != null) {
      return TimeOfDay(hour: hour, minute: 0);
    }
    return null;
  }

  String _eventTimeLabel(Map<String, dynamic> metadata, DateTime dateTime) {
    final rawTime = metadata['event_time'] ?? metadata['eventTime'];
    if (rawTime is String && rawTime.trim().isNotEmpty) {
      return rawTime.trim();
    }
    if (rawTime is DateTime) {
      return _formatEventTime(rawTime);
    }
    if (rawTime is num) {
      final time = _parseTimeOfDay(rawTime);
      if (time != null) {
        final resolved = DateTime(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          time.hour,
          time.minute,
        );
        return _formatEventTime(resolved);
      }
    }
    if (dateTime.hour != 0 || dateTime.minute != 0) {
      return _formatEventTime(dateTime);
    }
    return 'All day';
  }

  String _formatEventDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    final month = months[local.month - 1];
    return '$month ${local.day}';
  }

  String _formatEventTime(DateTime date) {
    var hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final isAm = hour < 12;
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    final period = isAm ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _CreateAnnouncementSheet extends ConsumerStatefulWidget {
  const _CreateAnnouncementSheet({required this.projects});

  final List<Project> projects;

  @override
  ConsumerState<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState
    extends ConsumerState<_CreateAnnouncementSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  String _scope = 'company';
  String? _siteId;
  bool _isPublished = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_isSubmitting) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Title is required.');
      return;
    }
    if (_scope == 'site' && _siteId == null) {
      _showSnackBar('Please select a site.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(opsRepositoryProvider).createNewsPost(
            title: title,
            body: _bodyController.text.trim().isEmpty
                ? null
                : _bodyController.text.trim(),
            scope: _scope,
            siteId: _scope == 'site' ? _siteId : null,
            isPublished: _isPublished,
            tags: const [],
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to publish: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create announcement',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _scope,
                decoration: const InputDecoration(
                  labelText: 'Scope',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'company', child: Text('Company')),
                  DropdownMenuItem(value: 'site', child: Text('Site')),
                ],
                onChanged: (value) {
                  setState(() {
                    _scope = value ?? 'company';
                    if (_scope != 'site') _siteId = null;
                  });
                },
              ),
              if (_scope == 'site') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _siteId,
                  decoration: const InputDecoration(
                    labelText: 'Site',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Select site'),
                    ),
                    ...widget.projects.map((project) {
                      return DropdownMenuItem<String?>(
                        value: project.id,
                        child: Text(project.name),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => _siteId = value),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish now'),
                value: _isPublished,
                onChanged: (value) => setState(() => _isPublished = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _publish,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company News & Announcements',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.title,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stay updated with company-wide and site-specific news',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.muted),
            ),
          ],
        );
        final button = ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.campaign, size: 18),
          label: const Text('Post Announcement'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        );
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              button,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            button,
          ],
        );
      },
    );
  }
}

class _AnnouncementsBanner extends StatelessWidget {
  const _AnnouncementsBanner({required this.items});

  final List<_Announcement> items;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Column(
      children: items.map((item) {
        final style = _announcementStyle(item.type, colors);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: style.accent,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(item.type.icon, color: style.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.text,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: style.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NewsFeed extends StatelessWidget {
  const _NewsFeed({
    required this.posts,
    required this.categoryFilter,
    required this.onCategoryChanged,
  });

  final List<_NewsItem> posts;
  final String categoryFilter;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    const categories = _newsCategoryFilters;
    final selectedCategory =
        categories.contains(categoryFilter) ? categoryFilter : 'All Categories';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Latest News',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: _selectDecoration(colors),
                  style: TextStyle(color: colors.body, fontSize: 13),
                  dropdownColor: colors.surface,
                  iconEnabledColor: colors.muted,
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onCategoryChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.more_vert, color: colors.muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (posts.isEmpty)
            const _EmptyState(
              title: 'No news yet',
              message: 'Share company or site updates here.',
            )
          else ...[
            ...posts.map((post) => _NewsCard(item: post)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              child: const Text('Load More News'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final _NewsItem item;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    final scheme = Theme.of(context).colorScheme;
    final priorityColor = _priorityColor(item.priority, colors);
    final hoverColor = colors.isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: hoverColor,
          onTap: () {},
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.isPinned) ...[
                              Icon(Icons.push_pin,
                                  size: 16, color: scheme.primary),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                item.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.title,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(
                                  alpha: colors.isDark ? 0.2 : 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.priority.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: priorityColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (item.body.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.body,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.body,
                                    ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: isWide ? 16 : 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                    ),
                              ),
                            ),
                            Text(
                              item.author,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.muted,
                                  ),
                            ),
                            if (isWide)
                              Text('•',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.muted)),
                            Text(
                              item.dateLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.muted,
                                  ),
                            ),
                            if (isWide)
                              Text('•',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.muted)),
                            Text(
                              '${item.views} views',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.muted,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: colors.muted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsSidebar extends StatelessWidget {
  const _NewsSidebar({
    required this.posts,
    required this.stats,
    required this.categories,
    required this.trending,
    required this.upcomingEvents,
  });

  final List<_NewsItem> posts;
  final _NewsStats stats;
  final List<_CategorySummary> categories;
  final List<_TrendingItem> trending;
  final List<_UpcomingEvent> upcomingEvents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatsCard(stats: stats),
        const SizedBox(height: 24),
        _CategoriesCard(posts: posts, categoriesOverride: categories),
        const SizedBox(height: 24),
        _UpcomingEventsCard(events: upcomingEvents),
        const SizedBox(height: 24),
        _TrendingCard(topics: trending),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final _NewsStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'New Posts', value: stats.newPosts.toString()),
          _StatRow(label: 'Total Views', value: stats.totalViews.toString()),
          _StatRow(
            label: 'Active Alerts',
            value: stats.activeAlerts.toString(),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: highlight ? colors.danger : colors.title,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.posts, required this.categoriesOverride});

  final List<_NewsItem> posts;
  final List<_CategorySummary> categoriesOverride;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    final entries =
        categoriesOverride.isNotEmpty ? categoriesOverride : _buildCategorySummaries(posts);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.title,
                ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No categories yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.muted),
            )
          else
            ...entries.map((entry) {
              final dotColor = _categoryColor(entry.name, colors);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.body),
                            ),
                          ),
                          Text(
                            entry.count.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard({required this.events});

  final List<_UpcomingEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Upcoming Events',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_outlined,
                  size: 18, color: colors.muted),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Text(
              'No upcoming events.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.muted),
            )
          else
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.filterSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: colors.title,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: colors.muted),
                          const SizedBox(width: 6),
                          Text(
                            event.dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.muted),
                          ),
                          const SizedBox(width: 6),
                          Text('•',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.muted)),
                          const SizedBox(width: 6),
                          Text(
                            event.timeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.topics});

  final List<_TrendingItem> topics;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: colors.trendingGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.trendingBorder),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Trending',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.title,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topics.isEmpty)
            Text(
              'No trending topics yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.muted),
            )
          else
            ...topics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      topic.tag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${topic.mentions} mentions',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colors.title),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = _NewsColors.fromTheme(Theme.of(context));
    return Center(
      child: Text(
        'Error: $message',
        style: TextStyle(color: colors.muted),
      ),
    );
  }
}

class _NewsColors {
  const _NewsColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.muted,
    required this.body,
    required this.title,
    required this.primary,
    required this.primarySoft,
    required this.filterSurface,
    required this.inputFill,
    required this.inputBorder,
    required this.danger,
    required this.warning,
    required this.trendingGradient,
    required this.trendingBorder,
    required this.cardShadow,
  });

  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color muted;
  final Color body;
  final Color title;
  final Color primary;
  final Color primarySoft;
  final Color filterSurface;
  final Color inputFill;
  final Color inputBorder;
  final Color danger;
  final Color warning;
  final Gradient trendingGradient;
  final Color trendingBorder;
  final List<BoxShadow> cardShadow;

  factory _NewsColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);
    final primarySoft =
        isDark ? primary.withValues(alpha: 0.2) : const Color(0xFFEFF6FF);
    final trendingGradient = LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF3B82F6).withValues(alpha: 0.1),
              const Color(0xFF6366F1).withValues(alpha: 0.1),
            ]
          : [
              const Color(0xFFDBEAFE),
              const Color(0xFFE0E7FF),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final cardShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
    return _NewsColors(
      isDark: isDark,
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      body: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      title: isDark ? Colors.white : const Color(0xFF111827),
      primary: primary,
      primarySoft: primarySoft,
      filterSurface:
          isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      inputFill: isDark ? const Color(0xFF111827) : Colors.white,
      inputBorder: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      danger: const Color(0xFFDC2626),
      warning: const Color(0xFFF59E0B),
      trendingGradient: trendingGradient,
      trendingBorder:
          isDark ? primary.withValues(alpha: 0.2) : const Color(0xFFBFDBFE),
      cardShadow: cardShadow,
    );
  }
}

class _AnnouncementStyle {
  const _AnnouncementStyle({
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color accent;
}

_AnnouncementStyle _announcementStyle(
  _AnnouncementType type,
  _NewsColors colors,
) {
  final accent = switch (type) {
    _AnnouncementType.alert => const Color(0xFFEF4444),
    _AnnouncementType.warning => const Color(0xFFF59E0B),
    _AnnouncementType.info => const Color(0xFF3B82F6),
  };
  final background = colors.isDark
      ? accent.withValues(alpha: 0.1)
      : switch (type) {
          _AnnouncementType.alert => const Color(0xFFFEF2F2),
          _AnnouncementType.warning => const Color(0xFFFFFBEB),
          _AnnouncementType.info => const Color(0xFFEFF6FF),
        };
  final foreground = colors.isDark
      ? switch (type) {
          _AnnouncementType.alert => const Color(0xFFF87171),
          _AnnouncementType.warning => const Color(0xFFFBBF24),
          _AnnouncementType.info => const Color(0xFF60A5FA),
        }
      : switch (type) {
          _AnnouncementType.alert => const Color(0xFF7F1D1D),
          _AnnouncementType.warning => const Color(0xFF78350F),
          _AnnouncementType.info => const Color(0xFF1E3A8A),
        };
  return _AnnouncementStyle(
    background: background,
    foreground: foreground,
    accent: accent,
  );
}

Color _priorityColor(_NewsPriority priority, _NewsColors colors) {
  switch (priority) {
    case _NewsPriority.high:
      return colors.danger;
    case _NewsPriority.medium:
      return colors.warning;
    case _NewsPriority.low:
      return colors.muted;
  }
}

List<_CategorySummary> _buildCategorySummaries(List<_NewsItem> posts) {
  final categories = <String, int>{};
  for (final post in posts) {
    categories.update(
      post.category,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  final entries = categories.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .map((entry) => _CategorySummary(entry.key, entry.value))
      .toList();
}

Color _categoryColor(String category, _NewsColors colors) {
  final key = category.toLowerCase();
  if (key.contains('safety')) return const Color(0xFFEF4444);
  if (key.contains('announcement')) return const Color(0xFF3B82F6);
  if (key.contains('training')) return const Color(0xFF8B5CF6);
  if (key.contains('project')) return const Color(0xFF22C55E);
  if (key.contains('hr')) return const Color(0xFFF97316);
  const palette = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF97316),
  ];
  final index = category.hashCode.abs() % palette.length;
  return palette[index];
}

InputDecoration _selectDecoration(_NewsColors colors) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: colors.inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
  );
}

class _NewsItem {
  const _NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.tags,
    required this.priority,
    required this.isPinned,
    required this.author,
    required this.dateLabel,
    required this.publishedAt,
    required this.views,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final List<String> tags;
  final _NewsPriority priority;
  final bool isPinned;
  final String author;
  final String dateLabel;
  final DateTime publishedAt;
  final int views;
}

class _UpcomingEvent {
  const _UpcomingEvent({
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.startsAt,
  });

  final String title;
  final String dateLabel;
  final String timeLabel;
  final DateTime startsAt;
}

enum _NewsPriority { high, medium, low }

extension _NewsPriorityLabel on _NewsPriority {
  String get label {
    switch (this) {
      case _NewsPriority.high:
        return 'high';
      case _NewsPriority.medium:
        return 'medium';
      case _NewsPriority.low:
        return 'low';
    }
  }
}

class _NewsStats {
  const _NewsStats({
    required this.newPosts,
    required this.totalViews,
    required this.activeAlerts,
  });

  final int newPosts;
  final int totalViews;
  final int activeAlerts;

  factory _NewsStats.fromPosts(List<_NewsItem> posts) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    final recentPosts = posts
        .where((post) => post.publishedAt.toLocal().isAfter(cutoff))
        .toList();
    final totalViews =
        recentPosts.fold<int>(0, (sum, post) => sum + post.views);
    final activeAlerts = recentPosts
        .where((post) => post.priority == _NewsPriority.high)
        .length;
    return _NewsStats(
      newPosts: recentPosts.length,
      totalViews: totalViews,
      activeAlerts: activeAlerts,
    );
  }
}

class _CategorySummary {
  const _CategorySummary(this.name, this.count);

  final String name;
  final int count;
}

class _Announcement {
  const _Announcement({
    required this.text,
    required this.type,
  });

  final String text;
  final _AnnouncementType type;
}

enum _AnnouncementType { alert, warning, info }

extension _AnnouncementTypeStyle on _AnnouncementType {
  IconData get icon {
    switch (this) {
      case _AnnouncementType.alert:
        return Icons.error_outline;
      case _AnnouncementType.warning:
        return Icons.notifications_active;
      case _AnnouncementType.info:
        return Icons.campaign;
    }
  }
}

class _TrendingItem {
  const _TrendingItem(this.tag, this.mentions);

  final String tag;
  final int mentions;
}

const _newsCategoryFilters = [
  'All Categories',
  'Safety',
  'Announcements',
  'Training',
  'Projects',
];
