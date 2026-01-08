import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../ops/data/ops_provider.dart';
import '../../../projects/data/projects_provider.dart';
import 'project_feed_page.dart';

class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _likedItems = {};
  final Set<int> _flaggedItems = {};
  final Set<String> _selectedTags = {};
  _MediaViewMode _viewMode = _MediaViewMode.grid;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(projectPhotosProvider(null));
    final projectsAsync = ref.watch(projectsProvider);
    final projectNames = {
      for (final project in projectsAsync.asData?.value ?? const <Project>[])
        project.id: project.name,
    };
    final mediaFromProjects = photosAsync.asData?.value == null
        ? const <_MediaItem>[]
        : _mediaFromProjectPhotos(
            photosAsync.asData!.value,
            projectNames,
          );
    final mediaItems =
        mediaFromProjects.isNotEmpty ? mediaFromProjects : _demoMediaItems;
    final tags = _allTags(mediaItems);
    final filteredMedia = _applyFilters(mediaItems);
    final isLoading = photosAsync.isLoading || projectsAsync.isLoading;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isLoading) const LinearProgressIndicator(),
          if (photosAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: photosAsync.error.toString()),
            ),
          _buildHeader(context, mediaItems),
          const SizedBox(height: 16),
          _buildSearchControls(context),
          const SizedBox(height: 12),
          _buildQuickActions(context, mediaItems),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTagsPanel(context, tags, filteredMedia.length, mediaItems.length),
          ],
          const SizedBox(height: 16),
          _buildMediaSection(context, filteredMedia),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<_MediaItem> mediaItems) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo & Video Gallery',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cloud storage with GPS timestamps and collaboration',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => _openMultiCapturePanel(context, mediaItems),
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: const Text('Capture'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openUploadPanel(context, mediaItems),
              icon: const Icon(Icons.upload_file_outlined, size: 20),
              label: const Text('Upload'),
            ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 12),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildSearchControls(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final searchField = TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search photos and videos...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          );
          final filterDropdown = DropdownButtonFormField<String>(
            value: _selectedFilter,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child:
                    Text('All Media', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: 'photos',
                child: Text(
                  'Photos Only',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'videos',
                child: Text(
                  'Videos Only',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) =>
                setState(() => _selectedFilter = value ?? 'all'),
          );
          final viewToggle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewToggleButton(
                icon: Icons.grid_view_outlined,
                isSelected: _viewMode == _MediaViewMode.grid,
                onTap: () => setState(() => _viewMode = _MediaViewMode.grid),
              ),
              const SizedBox(width: 6),
              _ViewToggleButton(
                icon: Icons.view_list_outlined,
                isSelected: _viewMode == _MediaViewMode.list,
                onTap: () => setState(() => _viewMode = _MediaViewMode.list),
              ),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: filterDropdown),
                const SizedBox(width: 12),
                viewToggle,
              ],
            );
          }
          return Column(
            children: [
              searchField,
              const SizedBox(height: 12),
              filterDropdown,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: viewToggle),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, List<_MediaItem> mediaItems) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProjectFeedPage()),
              );
            },
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Project Feed'),
          ),
          TextButton.icon(
            onPressed: () => _openTimelinePanel(context, mediaItems),
            icon: const Icon(Icons.history, size: 18),
            label: const Text('View Timeline'),
          ),
          TextButton.icon(
            onPressed: () => _openCuratedGalleryPanel(context, mediaItems),
            icon: const Icon(Icons.collections_outlined, size: 18),
            label: const Text('Create Gallery'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsPanel(
    BuildContext context,
    List<String> tags,
    int filteredCount,
    int totalCount,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell_outlined,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                _selectedTags.isEmpty
                    ? 'Filter by Tags'
                    : 'Filter by Tags (${_selectedTags.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_selectedTags.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedTags.clear()),
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                selected: isSelected,
                label: Text(tag),
                onSelected: (_) => setState(() => _toggleTag(tag)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Showing $filteredCount of $totalCount items',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, List<_MediaItem> items) {
    if (items.isEmpty) {
      return const _EmptyMediaCard();
    }
    if (_viewMode == _MediaViewMode.list) {
      return _MediaList(items: items);
    }
    return _MediaGrid(
      items: items,
      likedItems: _likedItems,
      flaggedItems: _flaggedItems,
      onToggleLike: _toggleLike,
      onToggleFlag: _toggleFlag,
      onOpenComments: (item) => _openCommentsPanel(context, item),
      onOpenWatermark: (item) => _openWatermarkEditor(context, item),
    );
  }

  void _toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
  }

  void _toggleLike(int id) {
    setState(() {
      if (_likedItems.contains(id)) {
        _likedItems.remove(id);
      } else {
        _likedItems.add(id);
      }
    });
  }

  void _toggleFlag(int id) {
    setState(() {
      if (_flaggedItems.contains(id)) {
        _flaggedItems.remove(id);
      } else {
        _flaggedItems.add(id);
      }
    });
  }

  List<_MediaItem> _applyFilters(List<_MediaItem> items) {
    return items.where((item) {
      final matchesType = _selectedFilter == 'all' ||
          (_selectedFilter == 'photos' && item.type == _MediaType.photo) ||
          (_selectedFilter == 'videos' && item.type == _MediaType.video);
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesTags =
          _selectedTags.isEmpty || item.tags.any(_selectedTags.contains);
      return matchesType && matchesSearch && matchesTags;
    }).toList();
  }

  List<String> _allTags(List<_MediaItem> items) {
    final tagSet = <String>{};
    for (final item in items) {
      tagSet.addAll(item.tags);
    }
    final tags = tagSet.toList()..sort();
    return tags;
  }

  List<_TimelineEvent> _buildTimelineEvents(List<_MediaItem> items) {
    final media = items.isNotEmpty ? items : _demoMediaItems;
    final photoMedia = media.firstWhere(
      (item) => item.type == _MediaType.photo,
      orElse: () => media.first,
    );
    final videoMedia = media.firstWhere(
      (item) => item.type == _MediaType.video,
      orElse: () => media.first,
    );
    final now = DateTime.now();
    return [
      _TimelineEvent(
        id: '1',
        type: _TimelineEventType.photo,
        title: 'Safety Inspection Complete',
        description: 'Documented all safety equipment installations.',
        user: 'John Doe',
        timestamp: now.subtract(const Duration(minutes: 5)),
        location: 'Building A - Level 3',
        mediaUrl: photoMedia.url,
        tags: const ['Safety', 'Inspection'],
        project: 'Building A Construction',
      ),
      _TimelineEvent(
        id: '2',
        type: _TimelineEventType.comment,
        title: 'Comment on Foundation Photo',
        description: '@mikechen Please review the foundation depth measurements.',
        user: 'Sarah Johnson',
        timestamp: now.subtract(const Duration(minutes: 10)),
        project: 'Building A Construction',
      ),
      _TimelineEvent(
        id: '3',
        type: _TimelineEventType.video,
        title: 'Equipment Walkthrough',
        description: 'New excavator demonstration and safety briefing.',
        user: 'Mike Chen',
        timestamp: now.subtract(const Duration(minutes: 30)),
        location: 'Equipment Yard',
        mediaUrl: videoMedia.url,
        tags: const ['Equipment', 'Training'],
        project: 'Site Operations',
      ),
      _TimelineEvent(
        id: '4',
        type: _TimelineEventType.photo,
        title: 'Progress Update - Week 12',
        description: 'Main structure completion milestone reached.',
        user: 'Emily Davis',
        timestamp: now.subtract(const Duration(hours: 1)),
        location: 'Building A - Main Floor',
        mediaUrl: photoMedia.url,
        tags: const ['Progress', 'Milestone'],
        project: 'Building A Construction',
      ),
      _TimelineEvent(
        id: '5',
        type: _TimelineEventType.upload,
        title: 'Uploaded 15 photos',
        description: 'Material delivery and storage documentation.',
        user: 'Tom Brown',
        timestamp: now.subtract(const Duration(hours: 2)),
        project: 'Supply Chain',
      ),
    ];
  }

  List<String> _projectOptions(List<_MediaItem> items) {
    final projects = items.map((item) => item.project).toSet().toList()..sort();
    if (projects.isEmpty) {
      projects.add('General');
    }
    return projects;
  }

  Future<void> _openTimelinePanel(
    BuildContext context,
    List<_MediaItem> items,
  ) async {
    final events = _buildTimelineEvents(items);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TimelinePanel(events: events),
    );
  }

  Future<void> _openUploadPanel(
    BuildContext context,
    List<_MediaItem> items,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UploadPanel(
        projects: _projectOptions(items),
        suggestedTags: _allTags(items),
      ),
    );
  }

  Future<void> _openCuratedGalleryPanel(
    BuildContext context,
    List<_MediaItem> items,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CuratedGalleryPanel(items: items),
    );
  }

  Future<void> _openWatermarkEditor(
    BuildContext context,
    _MediaItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WatermarkEditorPanel(item: item),
    );
  }

  Future<void> _openMultiCapturePanel(
    BuildContext context,
    List<_MediaItem> items,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MultiCapturePanel(
        projects: _projectOptions(items),
      ),
    );
  }

  Future<void> _openCommentsPanel(
    BuildContext context,
    _MediaItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhotoCommentsPanel(item: item),
    );
  }
}

enum _MediaViewMode { grid, list }

enum _MediaType { photo, video }

class _MediaItem {
  const _MediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.title,
    required this.project,
    required this.location,
    required this.dateLabel,
    required this.timestampLabel,
    required this.tags,
    required this.uploadedBy,
    required this.initialLikes,
    required this.commentCount,
    this.gps,
    this.duration,
  });

  final int id;
  final _MediaType type;
  final String url;
  final String title;
  final String project;
  final String location;
  final String dateLabel;
  final String timestampLabel;
  final String? gps;
  final List<String> tags;
  final String uploadedBy;
  final int initialLikes;
  final int commentCount;
  final String? duration;
}

class _PhotoComment {
  const _PhotoComment({
    required this.id,
    required this.author,
    required this.timestampLabel,
    this.message,
    this.voiceDurationSeconds,
    this.likes = 0,
    this.isLiked = false,
  });

  final int id;
  final String author;
  final String timestampLabel;
  final String? message;
  final int? voiceDurationSeconds;
  final int likes;
  final bool isLiked;

  bool get isVoiceNote => voiceDurationSeconds != null;

  _PhotoComment copyWith({
    String? author,
    String? timestampLabel,
    String? message,
    int? voiceDurationSeconds,
    int? likes,
    bool? isLiked,
  }) {
    return _PhotoComment(
      id: id,
      author: author ?? this.author,
      timestampLabel: timestampLabel ?? this.timestampLabel,
      message: message ?? this.message,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

enum _TimelineEventType { photo, video, upload, comment }

class _TimelineEvent {
  const _TimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.user,
    required this.timestamp,
    required this.project,
    this.location,
    this.mediaUrl,
    this.tags,
  });

  final String id;
  final _TimelineEventType type;
  final String title;
  final String description;
  final String user;
  final DateTime timestamp;
  final String project;
  final String? location;
  final String? mediaUrl;
  final List<String>? tags;
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _TimelinePanel extends StatefulWidget {
  const _TimelinePanel({required this.events});

  final List<_TimelineEvent> events;

  @override
  State<_TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<_TimelinePanel> {
  late List<_TimelineEvent> _events;
  Timer? _liveTimer;
  bool _liveUpdate = false;

  @override
  void initState() {
    super.initState();
    _events = [...widget.events];
    _liveTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _appendLiveEvent();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _appendLiveEvent() {
    final now = DateTime.now();
    final newEvent = _TimelineEvent(
      id: now.microsecondsSinceEpoch.toString(),
      type: _TimelineEventType.comment,
      title: 'New Activity',
      description: 'Real-time update detected from the field.',
      user: 'System',
      timestamp: now,
      project: 'Building A Construction',
    );
    setState(() {
      _events = [newEvent, ..._events];
      if (_events.length > 20) {
        _events = _events.take(20).toList();
      }
      _liveUpdate = true;
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _liveUpdate = false);
      }
    });
  }

  void _showPanelMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _iconForType(_TimelineEventType type) {
    switch (type) {
      case _TimelineEventType.photo:
        return Icons.photo_outlined;
      case _TimelineEventType.video:
        return Icons.videocam_outlined;
      case _TimelineEventType.comment:
        return Icons.chat_bubble_outline;
      case _TimelineEventType.upload:
        return Icons.cloud_upload_outlined;
    }
  }

  Color _colorForType(_TimelineEventType type) {
    switch (type) {
      case _TimelineEventType.photo:
        return const Color(0xFF2563EB);
      case _TimelineEventType.video:
        return const Color(0xFF7C3AED);
      case _TimelineEventType.comment:
        return const Color(0xFF16A34A);
      case _TimelineEventType.upload:
        return const Color(0xFFF97316);
    }
  }

  String _relativeTime(DateTime timestamp) {
    final delta = DateTime.now().difference(timestamp);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final photoCount =
        _events.where((event) => event.type == _TimelineEventType.photo).length;
    final videoCount =
        _events.where((event) => event.type == _TimelineEventType.video).length;
    final commentCount =
        _events.where((event) => event.type == _TimelineEventType.comment).length;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Activity Timeline',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_liveUpdate)
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Live',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: const Color(0xFF22C55E),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time updates from your team',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showPanelMessage('Filter timeline'),
                        icon: const Icon(Icons.filter_list),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showPanelMessage('Export timeline'),
                        icon: const Icon(Icons.download_outlined),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _TimelineEventTile(
                        event: event,
                        icon: _iconForType(event.type),
                        color: _colorForType(event.type),
                        isLast: index == _events.length - 1,
                        timeLabel: _relativeTime(event.timestamp),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111827)
                        : const Color(0xFFF9FAFB),
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      _TimelineStat(label: 'Photos', value: photoCount),
                      _TimelineStat(label: 'Videos', value: videoCount),
                      _TimelineStat(label: 'Comments', value: commentCount),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.event,
    required this.icon,
    required this.color,
    required this.isLast,
    required this.timeLabel,
  });

  final _TimelineEvent event;
  final IconData icon;
  final Color color;
  final bool isLast;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 24,
          bottom: isLast ? 24 : 0,
          child: Container(
            width: 2,
            color: borderColor,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_vert),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    if (event.mediaUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          event.mediaUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _PhotoImageFallback(),
                        ),
                      ),
                    ],
                    if (event.tags != null && event.tags!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: event.tags!
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isDark
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _MetaPill(
                          icon: Icons.person_outline,
                          label: event.user,
                        ),
                        _MetaPill(
                          icon: Icons.schedule,
                          label: timeLabel,
                        ),
                        if (event.location != null)
                          _MetaPill(
                            icon: Icons.place_outlined,
                            label: event.location!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _TimelineStat extends StatelessWidget {
  const _TimelineStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPanel extends StatefulWidget {
  const _UploadPanel({
    required this.projects,
    required this.suggestedTags,
  });

  final List<String> projects;
  final List<String> suggestedTags;

  @override
  State<_UploadPanel> createState() => _UploadPanelState();
}

class _UploadPanelState extends State<_UploadPanel> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _mentionController = TextEditingController();
  final TextEditingController _timestampController = TextEditingController();
  final FocusNode _mentionFocus = FocusNode();
  final List<String> _tags = [];
  final List<_UploadPreview> _selectedFiles = [];
  final List<_TeamMember> _mentions = [];
  DateTime _timestamp = DateTime.now();
  String? _selectedProject;
  bool _gpsCapturing = false;
  String? _gpsLocation;
  String? _gpsError;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedProject = '';
    _timestampController.text =
        DateFormat('yyyy-MM-dd HH:mm').format(_timestamp);
    _mentionFocus.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _tagController.dispose();
    _notesController.dispose();
    _mentionController.dispose();
    _timestampController.dispose();
    _mentionFocus.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty) return;
    if (_tags.contains(value)) return;
    setState(() => _tags.add(value));
    _tagController.clear();
  }

  void _addSampleFile({required bool isVideo}) {
    final index = _selectedFiles.length + 1;
    setState(() {
      _selectedFiles.add(
        _UploadPreview(
          name: isVideo ? 'Video Clip $index.mp4' : 'Photo $index.jpg',
          sizeLabel: isVideo ? '24.3 MB' : '3.2 MB',
          isVideo: isVideo,
        ),
      );
    });
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  Future<void> _captureGps() async {
    if (_gpsCapturing) return;
    setState(() {
      _gpsCapturing = true;
      _gpsError = null;
    });
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _gpsCapturing = false;
      _gpsLocation = 'Lat: 40.7128, Lng: -74.0060 (±5m)';
    });
  }

  Future<void> _pickTimestamp() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (time == null || !mounted) return;
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _timestampController.text =
          DateFormat('yyyy-MM-dd HH:mm').format(_timestamp);
    });
  }

  void _addMention(_TeamMember member) {
    if (_mentions.contains(member)) return;
    setState(() {
      _mentions.add(member);
      _mentionController.clear();
    });
    _mentionFocus.requestFocus();
  }

  void _removeMention(_TeamMember member) {
    setState(() => _mentions.remove(member));
  }

  Future<void> _submitUpload() async {
    if (_selectedFiles.isEmpty) return;
    setState(() => _isUploading = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isUploading = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final projects =
        widget.projects.isEmpty ? const ['General'] : widget.projects;
    final selectedProject = _selectedProject ?? '';
    final mentionResults = _uploadTeamMembers
        .where(
          (member) =>
              member.name.toLowerCase().contains(_mentionController.text.toLowerCase()) ||
              member.role.toLowerCase().contains(_mentionController.text.toLowerCase()),
        )
        .toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.98,
        builder: (context, controller) {
          final fileSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Media',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedFiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF111827)
                        : const Color(0xFFF9FAFB),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                _addSampleFile(isVideo: false),
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Choose Files'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _addSampleFile(isVideo: false),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Take Photo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'or drag and drop files here',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports: JPG, PNG, MP4, MOV (max 100MB)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    ..._selectedFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF111827)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF1F2937)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                file.isVideo
                                    ? Icons.videocam_outlined
                                    : Icons.photo_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    file.sizeLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeFile(index),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      );
                    }),
                    OutlinedButton(
                      onPressed: () => _addSampleFile(isVideo: false),
                      child: const Text('+ Add More Files'),
                    ),
                  ],
                ),
            ],
          );

          final metadataSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Metadata & Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'GPS Location',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_gpsLocation != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF052E16)
                        : const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF166534)
                          : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _gpsLocation!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _gpsLocation = null),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _gpsCapturing ? null : _captureGps,
                  icon: _gpsCapturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.location_searching, size: 18),
                  label: Text(_gpsCapturing ? 'Capturing...' : 'Capture GPS'),
                ),
              if (_gpsError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _gpsError!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Timestamp',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                readOnly: true,
                onTap: _pickTimestamp,
                controller: _timestampController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  border: const OutlineInputBorder(),
                  labelText: 'Timestamp',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedProject,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Select Project'),
                  ),
                  ...projects.map(
                    (project) => DropdownMenuItem(
                      value: project,
                      child: Text(project),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tags',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        hintText: 'Add tag...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _addTag(_tagController.text),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          onDeleted: () =>
                              setState(() => _tags.remove(tag)),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 8),
              if (widget.suggestedTags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.suggestedTags
                      .where((tag) => !_tags.contains(tag))
                      .map((tag) {
                        return OutlinedButton(
                          onPressed: () => _addTag(tag),
                          child: Text('+ $tag'),
                        );
                      }).toList(),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mentions',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mentionController,
                focusNode: _mentionFocus,
                decoration: const InputDecoration(
                  hintText: 'Mention team members...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_mentionFocus.hasFocus && mentionResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: mentionResults.length,
                    itemBuilder: (context, index) {
                      final member = mentionResults[index];
                      return ListTile(
                        onTap: () => _addMention(member),
                        leading: CircleAvatar(
                          backgroundColor: isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE5E7EB),
                          child: Text(member.initials),
                        ),
                        title: Text(member.name),
                        subtitle: Text(member.role),
                      );
                    },
                  ),
                ),
              if (_mentions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mentions
                      .map(
                        (member) => Chip(
                          label: Text('@${member.name}'),
                          onDeleted: () => _removeMention(member),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          );

          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderColor),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _PanelHeader(
                  title: 'Upload Media with Metadata',
                  subtitle: 'Photos and videos with GPS and timestamp info.',
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 820;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fileSection),
                          const SizedBox(width: 16),
                          Expanded(child: metadataSection),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fileSection,
                        const SizedBox(height: 16),
                        metadataSection,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'} selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed:
                          _selectedFiles.isEmpty || _isUploading ? null : _submitUpload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload Media'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CuratedGalleryPanel extends StatefulWidget {
  const _CuratedGalleryPanel({required this.items});

  final List<_MediaItem> items;

  @override
  State<_CuratedGalleryPanel> createState() => _CuratedGalleryPanelState();
}

class _CuratedGalleryPanelState extends State<_CuratedGalleryPanel> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<int> _selected = {};
  bool _shareLink = true;
  bool _isPublic = false;
  bool _allowDownloads = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final isReady = _selected.isNotEmpty && _nameController.text.trim().isNotEmpty;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.98,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderColor),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _PanelHeader(
                  title: 'Create Curated Gallery',
                  subtitle: 'Select media to publish a focused gallery.',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Gallery Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Visibility',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: !_isPublic,
                        label: const Text('Private Gallery'),
                        onSelected: (_) => setState(() => _isPublic = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: _isPublic,
                        label: const Text('Public Gallery'),
                        onSelected: (_) => setState(() => _isPublic = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _shareLink,
                  onChanged: (value) => setState(() => _shareLink = value),
                  title: const Text('Share link with collaborators'),
                ),
                SwitchListTile(
                  value: _allowDownloads,
                  onChanged: (value) => setState(() => _allowDownloads = value),
                  title: const Text('Allow downloads'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selected ${_selected.length} of ${widget.items.length}',
                  style: theme.textTheme.bodySmall,
                ),
                if (_shareLink)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.link),
                      label: const Text('Copy Share Link'),
                    ),
                  ),
                const SizedBox(height: 12),
                ...widget.items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: InkWell(
                      onTap: () => _toggleSelection(item.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.url,
                                width: 72,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _PhotoImageFallback(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.project} • ${item.location}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: _selected.contains(item.id),
                              onChanged: (_) => _toggleSelection(item.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isReady
                            ? () => Navigator.of(context).pop()
                            : null,
                        child: const Text('Create Gallery'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WatermarkEditorPanel extends StatefulWidget {
  const _WatermarkEditorPanel({required this.item});

  final _MediaItem item;

  @override
  State<_WatermarkEditorPanel> createState() => _WatermarkEditorPanelState();
}

class _WatermarkEditorPanelState extends State<_WatermarkEditorPanel> {
  double _opacity = 0.7;
  double _size = 24;
  String _position = 'bottom-right';
  bool _useLogo = false;
  Color _watermarkColor = Colors.white;
  final TextEditingController _textController =
      TextEditingController(text: 'Form Bridge');

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Alignment _alignmentForPosition() {
    switch (_position) {
      case 'top-left':
        return Alignment.topLeft;
      case 'top-right':
        return Alignment.topRight;
      case 'bottom-left':
        return Alignment.bottomLeft;
      case 'center':
        return Alignment.center;
      case 'bottom-right':
      default:
        return Alignment.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final watermarkText =
        _textController.text.trim().isEmpty ? 'Form Bridge' : _textController.text;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.98,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderColor),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _PanelHeader(
                  title: 'Add Watermark / Logo',
                  subtitle: widget.item.title,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              widget.item.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _PhotoImageFallback(),
                            ),
                          ),
                          Align(
                            alignment: _alignmentForPosition(),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Opacity(
                                opacity: _opacity,
                                child: _useLogo
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _watermarkColor,
                                            width: 2,
                                          ),
                                          color: Colors.black.withOpacity(0.2),
                                        ),
                                        child: Text(
                                          'LOGO',
                                          style:
                                              theme.textTheme.labelLarge?.copyWith(
                                            color: _watermarkColor,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        watermarkText,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontSize: _size,
                                          fontWeight: FontWeight.w700,
                                          color: _watermarkColor,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Watermark Type',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: !_useLogo,
                        label: const Text('Text'),
                        onSelected: (_) => setState(() => _useLogo = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: _useLogo,
                        label: const Text('Logo'),
                        onSelected: (_) => setState(() => _useLogo = true),
                      ),
                    ),
                  ],
                ),
                if (_useLogo) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Logo'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Watermark Text',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Position',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        _PositionCell(
                          label: 'TL',
                          isSelected: _position == 'top-left',
                          onTap: () => setState(() => _position = 'top-left'),
                        ),
                        _PositionCell(
                          label: 'C',
                          isSelected: _position == 'center',
                          onTap: () => setState(() => _position = 'center'),
                        ),
                        _PositionCell(
                          label: 'TR',
                          isSelected: _position == 'top-right',
                          onTap: () => setState(() => _position = 'top-right'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        _PositionSpacer(),
                        _PositionSpacer(),
                        _PositionSpacer(),
                      ],
                    ),
                    TableRow(
                      children: [
                        _PositionCell(
                          label: 'BL',
                          isSelected: _position == 'bottom-left',
                          onTap: () => setState(() => _position = 'bottom-left'),
                        ),
                        _PositionSpacer(),
                        _PositionCell(
                          label: 'BR',
                          isSelected: _position == 'bottom-right',
                          onTap: () => setState(() => _position = 'bottom-right'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Size',
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: _size,
                  min: 14,
                  max: 40,
                  onChanged: (value) => setState(() => _size = value),
                ),
                Text(
                  'Opacity',
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: _opacity,
                  min: 0.2,
                  max: 1,
                  onChanged: (value) => setState(() => _opacity = value),
                ),
                const SizedBox(height: 8),
                Text(
                  'Color',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _watermarkColors.map((color) {
                    final isSelected = _watermarkColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _watermarkColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Save Watermark'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PositionCell extends StatelessWidget {
  const _PositionCell({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB)
                : theme.brightness == Brightness.dark
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionSpacer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 40);
  }
}

const List<Color> _watermarkColors = [
  Colors.white,
  Color(0xFFF97316),
  Color(0xFF38BDF8),
  Color(0xFF22C55E),
  Color(0xFF1F2937),
];

class _CapturedPhoto {
  const _CapturedPhoto({
    required this.id,
    required this.timestamp,
    required this.hasGps,
  });

  final String id;
  final DateTime timestamp;
  final bool hasGps;
}

class _MultiCapturePanel extends StatefulWidget {
  const _MultiCapturePanel({required this.projects});

  final List<String> projects;

  @override
  State<_MultiCapturePanel> createState() => _MultiCapturePanelState();
}

class _MultiCapturePanelState extends State<_MultiCapturePanel> {
  final TextEditingController _galleryController = TextEditingController();
  String? _selectedProject;
  bool _cameraActive = false;
  bool _gpsCapturing = false;
  String? _gpsLocation;
  String? _gpsError;
  final List<_CapturedPhoto> _capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    _selectedProject = '';
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    if (_gpsCapturing) return;
    setState(() {
      _gpsCapturing = true;
      _gpsError = null;
    });
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _gpsCapturing = false;
      _gpsLocation = '40.712800, -74.006000';
    });
  }

  void _startCamera() {
    setState(() => _cameraActive = true);
  }

  void _stopCamera() {
    setState(() => _cameraActive = false);
  }

  void _capturePhoto() {
    if (!_cameraActive) return;
    final now = DateTime.now();
    setState(() {
      _capturedPhotos.add(
        _CapturedPhoto(
          id: now.microsecondsSinceEpoch.toString(),
          timestamp: now,
          hasGps: _gpsLocation != null,
        ),
      );
    });
  }

  void _removePhoto(String id) {
    setState(() => _capturedPhotos.removeWhere((photo) => photo.id == id));
  }

  String _formatCaptureTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.brightness == Brightness.dark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final projects =
        widget.projects.isEmpty ? const ['General'] : widget.projects;
    final selectedProject = _selectedProject ?? '';
    final isReadyToStart = _galleryController.text.trim().isNotEmpty &&
        selectedProject.isNotEmpty &&
        _gpsLocation != null;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: borderColor),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multi-Photo Capture',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_capturedPhotos.length} photo${_capturedPhotos.length == 1 ? '' : 's'} captured',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _galleryController,
                  decoration: const InputDecoration(
                    labelText: 'Gallery Name *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Building A Inspection - Dec 27',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedProject,
                  decoration: const InputDecoration(
                    labelText: 'Project Name *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Select a project...'),
                    ),
                    ...projects.map(
                      (project) => DropdownMenuItem(
                        value: project,
                        child: Text(project),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedProject = value),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _gpsLocation != null
                        ? (isDark
                            ? const Color(0xFF052E16)
                            : const Color(0xFFECFDF3))
                        : (isDark
                            ? const Color(0xFF3F1D1D)
                            : const Color(0xFFFFF1F2)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gpsLocation != null
                          ? (isDark
                              ? const Color(0xFF166534)
                              : const Color(0xFFBBF7D0))
                          : (isDark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: _gpsLocation != null
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _gpsLocation != null
                                  ? 'GPS Location Acquired'
                                  : (_gpsError ?? 'GPS Location Required'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _gpsLocation != null
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_gpsLocation != null)
                              Text(
                                _gpsLocation!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _gpsLocation != null
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFCA5A5),
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _gpsCapturing ? null : _captureGps,
                        child: Text(
                          _gpsCapturing ? 'Getting...' : 'Retry',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 48,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _cameraActive
                                    ? 'Camera active'
                                    : 'Camera not active',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!_cameraActive)
                                FilledButton.icon(
                                  onPressed:
                                      isReadyToStart ? _startCamera : null,
                                  icon:
                                      const Icon(Icons.play_arrow_outlined),
                                  label: const Text('Start Camera'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_cameraActive)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: InkWell(
                              onTap: _gpsLocation == null ? null : _capturePhoto,
                              borderRadius: BorderRadius.circular(40),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF2563EB),
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isReadyToStart)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3F2D16)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF92400E)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_outlined,
                              color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete required fields first',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_galleryController.text.trim().isEmpty)
                                  const Text('• Enter gallery name'),
                                if (selectedProject.isEmpty)
                                  const Text('• Select project name'),
                                if (_gpsLocation == null)
                                  const Text('• Enable GPS location'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_capturedPhotos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.image_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Captured Photos (${_capturedPhotos.length})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final photo = _capturedPhotos[index];
                        return Stack(
                          children: [
                            Container(
                              width: 90,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.photo, size: 24),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCaptureTime(photo.timestamp),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _removePhoto(photo.id),
                                borderRadius: BorderRadius.circular(12),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFFDC2626),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (photo.hasGps)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'GPS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_cameraActive)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _stopCamera,
                          child: const Text('Stop Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _capturedPhotos.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check),
                          label: Text(
                            'Complete (${_capturedPhotos.length})',
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF991B1B),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.items,
    required this.likedItems,
    required this.flaggedItems,
    required this.onToggleLike,
    required this.onToggleFlag,
    required this.onOpenComments,
    required this.onOpenWatermark,
  });

  final List<_MediaItem> items;
  final Set<int> likedItems;
  final Set<int> flaggedItems;
  final ValueChanged<int> onToggleLike;
  final ValueChanged<int> onToggleFlag;
  final ValueChanged<_MediaItem> onOpenComments;
  final ValueChanged<_MediaItem> onOpenWatermark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = 1;
        if (constraints.maxWidth >= 1100) {
          columns = 3;
        } else if (constraints.maxWidth >= 760) {
          columns = 2;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _MediaGridCard(
              item: item,
              liked: likedItems.contains(item.id),
              flagged: flaggedItems.contains(item.id),
              onToggleLike: () => onToggleLike(item.id),
              onToggleFlag: () => onToggleFlag(item.id),
              onOpenComments: () => onOpenComments(item),
              onOpenWatermark: () => onOpenWatermark(item),
            );
          },
        );
      },
    );
  }
}

class _MediaGridCard extends StatelessWidget {
  const _MediaGridCard({
    required this.item,
    required this.liked,
    required this.flagged,
    required this.onToggleLike,
    required this.onToggleFlag,
    required this.onOpenComments,
    required this.onOpenWatermark,
  });

  final _MediaItem item;
  final bool liked;
  final bool flagged;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleFlag;
  final VoidCallback onOpenComments;
  final VoidCallback onOpenWatermark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final likeCount = liked ? item.initialLikes + 1 : item.initialLikes;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                              child: Image.network(
                                item.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _PhotoImageFallback(),
                              ),
              ),
              if (item.type == _MediaType.video)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, size: 28),
                      ),
                    ),
                  ),
                ),
              if (item.duration != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.duration!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    _MediaOverlayButton(
                      icon: Icons.chat_bubble_outline,
                      onTap: onOpenComments,
                    ),
                    const SizedBox(height: 6),
                    _MediaOverlayButton(
                      icon: Icons.brush_outlined,
                      onTap: onOpenWatermark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                _MetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: item.timestampLabel,
                ),
                if (item.gps != null)
                  _MetaRow(
                    icon: Icons.place_outlined,
                    label: item.gps!,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ActionIcon(
                      icon: liked ? Icons.favorite : Icons.favorite_border,
                      label: likeCount.toString(),
                      color: liked ? Colors.redAccent : null,
                      onTap: onToggleLike,
                    ),
                    const SizedBox(width: 8),
                    _ActionIcon(
                      icon: Icons.chat_bubble_outline,
                      label: item.commentCount.toString(),
                      onTap: onOpenComments,
                    ),
                    const Spacer(),
                    _ActionIcon(
                      icon: flagged ? Icons.flag : Icons.outlined_flag,
                      label: '',
                      color: flagged ? Colors.orange : null,
                      onTap: onToggleFlag,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaOverlayButton extends StatelessWidget {
  const _MediaOverlayButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _MediaList extends StatelessWidget {
  const _MediaList({required this.items});

  final List<_MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.url,
                        width: 96,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _PhotoImageFallback(),
                      ),
                    ),
                    if (item.type == _MediaType.video)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.35),
                          child: const Center(
                            child: Icon(Icons.play_arrow, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            item.project,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          Text(
                            item.location,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          Text(
                            item.dateLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        color ?? (isDark ? Colors.grey[300] : Colors.grey[700]);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? textColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoCommentsSection extends StatefulWidget {
  const _PhotoCommentsSection({required this.photoId});

  final int photoId;

  @override
  State<_PhotoCommentsSection> createState() => _PhotoCommentsSectionState();
}

class _PhotoCommentsSectionState extends State<_PhotoCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isRecording = false;
  bool _isExpanded = false;

  @override
  void dispose() {
    _commentController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _addPhotoComment(
      widget.photoId,
      _PhotoComment(
        id: _nextCommentId(),
        author: 'You',
        timestampLabel: 'Just now',
        message: text,
      ),
    );
    _commentController.clear();
  }

  void _toggleRecording() {
    if (_isRecording) {
      _finishRecording(addVoiceNote: true);
      return;
    }
    _startRecording();
  }

  void _startRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 3) {
        _finishRecording(addVoiceNote: true);
      }
    });
  }

  void _finishRecording({required bool addVoiceNote}) {
    _recordingTimer?.cancel();
    if (addVoiceNote) {
      _addPhotoComment(
        widget.photoId,
        _PhotoComment(
          id: _nextCommentId(),
          author: 'You',
          timestampLabel: 'Just now',
          voiceDurationSeconds: _recordingSeconds.clamp(1, 60).toInt(),
        ),
      );
    }
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  void _toggleLike(_PhotoComment comment) {
    _togglePhotoCommentLike(widget.photoId, comment.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return ValueListenableBuilder<int>(
      valueListenable: _commentStoreVersion,
      builder: (context, _, __) {
        final comments = _commentsForPhoto(widget.photoId);
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final visibleComments = isWide || _isExpanded
                ? comments
                : comments.take(2).toList();
            final hasMore = comments.length > 2 && !isWide;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: borderColor),
                if (comments.isEmpty)
                  Text(
                    'No comments yet. Be the first to comment.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  )
                else if (isWide)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      itemCount: comments.length,
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentItem(
                          comment: comment,
                          onToggleLike: () => _toggleLike(comment),
                        );
                      },
                    ),
                  )
                else
                  Column(
                    children: [
                      ...visibleComments.map(
                        (comment) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CommentItem(
                            comment: comment,
                            onToggleLike: () => _toggleLike(comment),
                          ),
                        ),
                      ),
                      if (hasMore && !_isExpanded)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _isExpanded = true),
                            icon: const Icon(Icons.expand_more),
                            label: Text(
                              'View all ${comments.length} comments',
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  enabled: !_isRecording,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _addComment(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        color: _isRecording ? Colors.redAccent : null,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _isRecording
                            ? 'Recording... 0:${_recordingSeconds.toString().padLeft(2, '0')}'
                            : 'Add voice note or send message',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _commentController.text.trim().isEmpty ||
                              _isRecording
                          ? null
                          : _addComment,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PhotoCommentsPanel extends StatefulWidget {
  const _PhotoCommentsPanel({required this.item});

  final _MediaItem item;

  @override
  State<_PhotoCommentsPanel> createState() => _PhotoCommentsPanelState();
}

class _PhotoCommentsPanelState extends State<_PhotoCommentsPanel> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isRecording = false;
  bool _showMentions = false;
  String _mentionQuery = '';
  int _cursorPosition = 0;

  @override
  void initState() {
    super.initState();
    _commentFocus.addListener(() {
      if (!_commentFocus.hasFocus && _showMentions && mounted) {
        setState(() => _showMentions = false);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged(String value) {
    final cursor = _commentController.selection.baseOffset;
    _cursorPosition = cursor;
    if (cursor < 0) {
      setState(() => _showMentions = false);
      return;
    }
    final lastAt = value.lastIndexOf('@', cursor - 1);
    if (lastAt == -1) {
      setState(() => _showMentions = false);
      return;
    }
    final textAfterAt = value.substring(lastAt + 1, cursor);
    if (textAfterAt.contains(' ')) {
      setState(() => _showMentions = false);
      return;
    }
    setState(() {
      _mentionQuery = textAfterAt;
      _showMentions = true;
    });
  }

  void _insertMention(_MentionTarget target) {
    final text = _commentController.text;
    final lastAt = text.lastIndexOf('@', _cursorPosition - 1);
    if (lastAt == -1) return;
    final updated = text.replaceRange(
      lastAt,
      _cursorPosition,
      '@${target.username} ',
    );
    _commentController.text = updated;
    _commentController.selection = TextSelection.collapsed(
      offset: lastAt + target.username.length + 2,
    );
    setState(() => _showMentions = false);
    _commentFocus.requestFocus();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _addPhotoComment(
      widget.item.id,
      _PhotoComment(
        id: _nextCommentId(),
        author: 'You',
        timestampLabel: 'Just now',
        message: text,
      ),
    );
    _commentController.clear();
    setState(() => _showMentions = false);
  }

  void _toggleLike(_PhotoComment comment) {
    _togglePhotoCommentLike(widget.item.id, comment.id);
  }

  void _startRecording() {
    if (_isRecording) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
    });
  }

  void _stopRecording() {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _addPhotoComment(
      widget.item.id,
      _PhotoComment(
        id: _nextCommentId(),
        author: 'You',
        timestampLabel: 'Just now',
        voiceDurationSeconds: _recordingSeconds.clamp(1, 120).toInt(),
      ),
    );
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  void _showPanelMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final mentionResults = _mentionTargets
        .where(
          (member) =>
              member.username.toLowerCase().contains(_mentionQuery.toLowerCase()) ||
              member.name.toLowerCase().contains(_mentionQuery.toLowerCase()),
        )
        .toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.98,
        builder: (context, controller) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comments',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.item.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showPanelMessage('Share comments'),
                          icon: const Icon(Icons.share_outlined),
                        ),
                        IconButton(
                          onPressed: () => _showPanelMessage('Export comments'),
                          icon: const Icon(Icons.download_outlined),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _commentStoreVersion,
                      builder: (context, _, __) {
                        final comments = _commentsForPhoto(widget.item.id);
                        if (comments.isEmpty) {
                          return Center(
                            child: Text(
                              'No comments yet.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return _CommentItem(
                              comment: comment,
                              useBubble: true,
                              onToggleLike: () => _toggleLike(comment),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_showMentions && mentionResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: mentionResults.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: borderColor,
                        ),
                        itemBuilder: (context, index) {
                          final member = mentionResults[index];
                          return ListTile(
                            onTap: () => _insertMention(member),
                            leading: CircleAvatar(
                              backgroundColor: isDark
                                  ? const Color(0xFF374151)
                                  : const Color(0xFFE5E7EB),
                              child: Text(
                                member.name.substring(0, 1),
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            title: Text(member.name),
                            subtitle: Text('@${member.username}'),
                          );
                        },
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF9FAFB),
                      border: Border(
                        top: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3F1D1D)
                                  : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF7F1D1D)
                                    : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 10, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Recording... ${_formatSeconds(_recordingSeconds)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.grey[200]
                                          : Colors.grey[800],
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _stopRecording,
                                  icon: const Icon(Icons.mic_off, size: 16),
                                  label: const Text('Stop'),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocus,
                                minLines: 2,
                                maxLines: 3,
                                enabled: !_isRecording,
                                decoration: const InputDecoration(
                                  hintText: 'Add a comment... Use @ to mention',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _handleTextChanged,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                IconButton(
                                  onPressed: _commentController.text.trim().isEmpty ||
                                          _isRecording
                                      ? null
                                      : _addComment,
                                  icon: const Icon(Icons.send),
                                ),
                                const SizedBox(height: 4),
                                IconButton(
                                  onPressed: _isRecording ? null : _startRecording,
                                  icon: const Icon(Icons.mic),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tip: type @ to mention team members.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.onToggleLike,
    this.useBubble = false,
  });

  final _PhotoComment comment;
  final VoidCallback onToggleLike;
  final bool useBubble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final baseTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: isDark ? Colors.grey[300] : Colors.grey[700],
    );
    final mentionStyle = theme.textTheme.bodySmall?.copyWith(
      color: const Color(0xFF2563EB),
      fontWeight: FontWeight.w600,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              comment.author,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              comment.timestampLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (comment.message != null)
          RichText(
            text: TextSpan(
              children: _buildMentionSpans(
                comment.message!,
                baseTextStyle,
                mentionStyle,
              ),
            ),
          )
        else if (comment.isVoiceNote)
          _VoiceNotePlayer(durationSeconds: comment.voiceDurationSeconds ?? 0),
        const SizedBox(height: 6),
        InkWell(
          onTap: onToggleLike,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: comment.isLiked ? Colors.redAccent : null,
                ),
                const SizedBox(width: 4),
                Text(
                  comment.likes > 0 ? comment.likes.toString() : 'Like',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: comment.isLiked
                        ? Colors.redAccent
                        : isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentAvatar(name: comment.author),
        const SizedBox(width: 10),
        Expanded(
          child: useBubble
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111827)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: content,
                )
              : content,
        ),
      ],
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return CircleAvatar(
      radius: 16,
      backgroundColor:
          isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: theme.textTheme.labelMedium?.copyWith(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  const _VoiceNotePlayer({required this.durationSeconds});

  final int durationSeconds;

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  Timer? _timer;
  double _progress = 0;
  bool _isPlaying = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stop();
    } else {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _isPlaying = true;
      _progress = 0;
    });
    final totalTicks = (widget.durationSeconds * 10).clamp(1, 600);
    var ticks = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      ticks++;
      if (ticks >= totalTicks) {
        _stop();
        return;
      }
      setState(() => _progress = ticks / totalTicks);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final durationLabel = _formatSeconds(widget.durationSeconds);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor:
                  isDark ? const Color(0xFF374151) : const Color(0xFFCBD5F5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionTarget {
  const _MentionTarget({required this.username, required this.name});

  final String username;
  final String name;
}

const List<_MentionTarget> _mentionTargets = [
  _MentionTarget(username: 'johndoe', name: 'John Doe'),
  _MentionTarget(username: 'mikechen', name: 'Mike Chen'),
  _MentionTarget(username: 'sarahjohnson', name: 'Sarah Johnson'),
  _MentionTarget(username: 'emilydavis', name: 'Emily Davis'),
  _MentionTarget(username: 'tombrown', name: 'Tom Brown'),
];

class _UploadPreview {
  const _UploadPreview({
    required this.name,
    required this.sizeLabel,
    required this.isVideo,
  });

  final String name;
  final String sizeLabel;
  final bool isVideo;
}

class _TeamMember {
  const _TeamMember({
    required this.name,
    required this.role,
    required this.initials,
  });

  final String name;
  final String role;
  final String initials;
}

const List<_TeamMember> _uploadTeamMembers = [
  _TeamMember(name: 'John Doe', role: 'Manager', initials: 'JD'),
  _TeamMember(name: 'Sarah Johnson', role: 'Supervisor', initials: 'SJ'),
  _TeamMember(name: 'Mike Chen', role: 'Supervisor', initials: 'MC'),
  _TeamMember(name: 'Emily Davis', role: 'Manager', initials: 'ED'),
  _TeamMember(name: 'Tom Brown', role: 'Supervisor', initials: 'TB'),
  _TeamMember(name: 'Lisa Anderson', role: 'Manager', initials: 'LA'),
  _TeamMember(name: 'David Wilson', role: 'Supervisor', initials: 'DW'),
  _TeamMember(name: 'Maria Garcia', role: 'Super Admin', initials: 'MG'),
];

final ValueNotifier<int> _commentStoreVersion = ValueNotifier<int>(0);
int _commentIdCounter = 2000;

int _nextCommentId() => _commentIdCounter++;

final Map<int, List<_PhotoComment>> _commentStore = {
  1: [
    _PhotoComment(
      id: 1,
      author: 'Sarah Johnson',
      message: 'Great shot. The lighting is perfect.',
      timestampLabel: '2h ago',
      likes: 12,
    ),
    _PhotoComment(
      id: 2,
      author: 'Mike Chen',
      message: '@johndoe can you check the measurements here?',
      timestampLabel: '1h ago',
      likes: 3,
    ),
    _PhotoComment(
      id: 3,
      author: 'Lisa Martinez',
      message: 'This angle shows the detail. Nice work.',
      timestampLabel: '45m ago',
      likes: 7,
    ),
    _PhotoComment(
      id: 4,
      author: 'James Wilson',
      message: 'Can we get a similar shot from the other side?',
      timestampLabel: '30m ago',
      likes: 2,
    ),
    _PhotoComment(
      id: 5,
      author: 'Rachel Green',
      message: '@mike I checked. Measurements look good.',
      timestampLabel: '25m ago',
      likes: 5,
    ),
    _PhotoComment(
      id: 6,
      author: 'Tom Anderson',
      timestampLabel: '20m ago',
      voiceDurationSeconds: 8,
      likes: 4,
    ),
    _PhotoComment(
      id: 7,
      author: 'Jennifer Lee',
      message: 'Great timing on this capture. Weather looks ideal.',
      timestampLabel: '15m ago',
      likes: 9,
    ),
    _PhotoComment(
      id: 8,
      author: 'David Park',
      message: 'Adding this to the project documentation.',
      timestampLabel: '10m ago',
      likes: 6,
    ),
  ],
  2: [
    _PhotoComment(
      id: 9,
      author: 'Emily Davis',
      message: 'Excellent tutorial. Very helpful for new team members.',
      timestampLabel: '3h ago',
      likes: 8,
    ),
    _PhotoComment(
      id: 10,
      author: 'Tom Brown',
      timestampLabel: '2h ago',
      voiceDurationSeconds: 12,
      likes: 5,
    ),
    _PhotoComment(
      id: 11,
      author: 'Amanda White',
      message: 'Bookmarking this for training sessions.',
      timestampLabel: '1h ago',
      likes: 4,
    ),
  ],
  3: [
    _PhotoComment(
      id: 12,
      author: 'David Wilson',
      message: 'Foundation looks solid. Good work team.',
      timestampLabel: '1d ago',
      likes: 15,
    ),
    _PhotoComment(
      id: 13,
      author: 'Carlos Rodriguez',
      message: 'Inspector approved this yesterday. Moving to next phase.',
      timestampLabel: '18h ago',
      likes: 8,
    ),
  ],
};

List<_PhotoComment> _commentsForPhoto(int photoId) {
  return _commentStore.putIfAbsent(photoId, () => <_PhotoComment>[]);
}

void _addPhotoComment(int photoId, _PhotoComment comment) {
  _commentsForPhoto(photoId).add(comment);
  _commentStoreVersion.value++;
}

void _togglePhotoCommentLike(int photoId, int commentId) {
  final comments = _commentsForPhoto(photoId);
  final index = comments.indexWhere((comment) => comment.id == commentId);
  if (index == -1) return;
  final current = comments[index];
  final isLiked = !current.isLiked;
  final likes =
      isLiked ? current.likes + 1 : (current.likes > 0 ? current.likes - 1 : 0);
  comments[index] = current.copyWith(isLiked: isLiked, likes: likes);
  _commentStoreVersion.value++;
}

List<TextSpan> _buildMentionSpans(
  String message,
  TextStyle? baseStyle,
  TextStyle? mentionStyle,
) {
  final defaultBase = baseStyle ?? const TextStyle();
  final defaultMention = mentionStyle ??
      defaultBase.copyWith(
        color: const Color(0xFF2563EB),
        fontWeight: FontWeight.w600,
      );
  final words = message.split(' ');
  return words.map((word) {
    if (word.startsWith('@')) {
      return TextSpan(text: '$word ', style: defaultMention);
    }
    return TextSpan(text: '$word ', style: defaultBase);
  }).toList();
}

String _formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

class _EmptyMediaCard extends StatelessWidget {
  const _EmptyMediaCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No media found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters or upload new media.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}

List<_MediaItem> _mediaFromProjectPhotos(
  List<ProjectPhoto> photos,
  Map<String, String> projectNames,
) {
  final items = <_MediaItem>[];
  for (final photo in photos) {
    final attachments = photo.attachments ?? const <MediaAttachment>[];
    for (final attachment in attachments) {
      final type = attachment.type == 'video'
          ? _MediaType.video
          : _MediaType.photo;
      final capturedAt = attachment.capturedAt;
      final projectName = photo.projectId == null
          ? null
          : projectNames[photo.projectId!];
      final gps = attachment.location == null
          ? null
          : '${attachment.location!.latitude.toStringAsFixed(4)} N, '
              '${attachment.location!.longitude.toStringAsFixed(4)} W';
      items.add(
        _MediaItem(
          id: items.length + 1,
          type: type,
          url: attachment.url,
          title: photo.title ?? 'Project media',
          project: projectName ?? 'Project',
          location: photo.metadata?['location']?.toString() ?? 'Project site',
          dateLabel: _relativeTime(capturedAt),
          timestampLabel: DateFormat('MMM d, yyyy h:mm a').format(capturedAt),
          gps: gps,
          tags: photo.tags,
          uploadedBy: photo.createdBy ?? 'Unknown',
          initialLikes: photo.metadata?['likes'] is int
              ? photo.metadata!['likes'] as int
              : 0,
          commentCount: photo.metadata?['comments'] is int
              ? photo.metadata!['comments'] as int
              : 0,
          duration: attachment.metadata?['duration']?.toString(),
        ),
      );
    }
  }
  return items;
}

String _relativeTime(DateTime date) {
  final now = DateTime.now();
  final delta = now.difference(date);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) return '${delta.inHours} hours ago';
  if (delta.inDays < 7) return '${delta.inDays} days ago';
  return DateFormat('MMM d').format(date);
}

class _PhotoImageFallback extends StatelessWidget {
  const _PhotoImageFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: ColoredBox(
        color: scheme.surfaceVariant,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
          size: 28,
        ),
      ),
    );
  }
}

const List<_MediaItem> _demoMediaItems = [
  _MediaItem(
    id: 1,
    type: _MediaType.photo,
    url: 'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=400',
    title: 'Building A - Main Entrance',
    project: 'Building A Construction',
    location: 'Main Site',
    dateLabel: '2 hours ago',
    timestampLabel: 'Dec 22, 2025 10:30 AM',
    gps: '40.7128 N, 74.0060 W',
    tags: const ['Safety', 'Inspection', 'Progress'],
    uploadedBy: 'John Doe',
    initialLikes: 24,
    commentCount: 8,
  ),
  _MediaItem(
    id: 2,
    type: _MediaType.video,
    url: 'https://images.unsplash.com/photo-1590650516494-0c8e4a4dd67e?w=400',
    title: 'Equipment Operation Tutorial',
    project: 'Training Session',
    location: 'Warehouse',
    dateLabel: '5 hours ago',
    timestampLabel: 'Dec 22, 2025 7:15 AM',
    tags: const ['Training', 'Equipment'],
    uploadedBy: 'Sarah Johnson',
    initialLikes: 42,
    commentCount: 3,
    duration: '2:45',
  ),
  _MediaItem(
    id: 3,
    type: _MediaType.photo,
    url: 'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=400',
    title: 'Foundation Inspection',
    project: 'Building A Construction',
    location: 'Site B',
    dateLabel: '1 day ago',
    timestampLabel: 'Dec 21, 2025 3:20 PM',
    gps: '40.7580 N, 73.9855 W',
    tags: const ['Inspection', 'Foundation'],
    uploadedBy: 'Mike Chen',
    initialLikes: 18,
    commentCount: 2,
  ),
  _MediaItem(
    id: 4,
    type: _MediaType.photo,
    url: 'https://images.unsplash.com/photo-1581094271901-8022df4466f9?w=400',
    title: 'Safety Equipment Check',
    project: 'Safety Audit',
    location: 'Main Site',
    dateLabel: '1 day ago',
    timestampLabel: 'Dec 21, 2025 9:45 AM',
    tags: const ['Safety', 'Equipment'],
    uploadedBy: 'Emily Davis',
    initialLikes: 31,
    commentCount: 0,
  ),
  _MediaItem(
    id: 5,
    type: _MediaType.video,
    url: 'https://images.unsplash.com/photo-1588853953899-b448f6f43916?w=400',
    title: 'Site Walkthrough - Week 12',
    project: 'Building A Construction',
    location: 'Main Site',
    dateLabel: '2 days ago',
    timestampLabel: 'Dec 20, 2025 2:30 PM',
    tags: const ['Progress', 'Walkthrough'],
    uploadedBy: 'John Doe',
    initialLikes: 56,
    commentCount: 23,
    duration: '5:12',
  ),
  _MediaItem(
    id: 6,
    type: _MediaType.photo,
    url: 'https://images.unsplash.com/photo-1597289357-b8e1b0ac37b2?w=400',
    title: 'Material Delivery',
    project: 'Supply Chain',
    location: 'Storage Yard',
    dateLabel: '3 days ago',
    timestampLabel: 'Dec 19, 2025 11:00 AM',
    tags: const ['Materials', 'Logistics'],
    uploadedBy: 'Tom Brown',
    initialLikes: 12,
    commentCount: 3,
  ),
];
