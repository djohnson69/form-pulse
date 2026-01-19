import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared/shared.dart';

import '../../../../core/utils/file_bytes_loader.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart' as ops_repo;
import '../../../projects/data/projects_provider.dart';
import 'project_feed_page.dart';

class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _likedItems = {};
  final Set<String> _flaggedItems = {};
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 768;
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
    final mediaItems = mediaFromProjects;
    final tags = _allTags(mediaItems);
    final filteredMedia = _applyFilters(mediaItems);
    final isLoading = photosAsync.isLoading || projectsAsync.isLoading;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: ListView(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        children: [
          if (isLoading) const LinearProgressIndicator(),
          if (photosAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: photosAsync.error.toString()),
            ),
          _buildHeader(context, mediaItems),
          const SizedBox(height: 24),
          _buildSearchControls(context, mediaItems),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildTagsPanel(context, tags, filteredMedia.length, mediaItems.length),
          ],
          SizedBox(height: tags.isNotEmpty ? 16 : 24),
          _buildMediaSection(context, filteredMedia),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<_MediaItem> mediaItems) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 768;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo & Video Gallery',
          style: TextStyle(
            fontSize: isWide ? 30 : 24,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cloud storage with GPS timestamps and collaboration',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final showLabel = constraints.maxWidth >= 640;
        final uploadBackground =
            isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
        final uploadForeground =
            isDark ? Colors.white : const Color(0xFF111827);
        final captureButton = showLabel
            ? FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 1,
                  shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  textStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _openMultiCapturePanel(context, mediaItems),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('Capture'),
              )
            : FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 1,
                  shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _openMultiCapturePanel(context, mediaItems),
                child: const Icon(Icons.camera_alt_outlined, size: 20),
              );
        final uploadButton = showLabel
            ? OutlinedButton.icon(
                onPressed: () => _openUploadPanel(context, mediaItems),
                icon: const Icon(Icons.upload_file_outlined, size: 20),
                label: const Text('Upload'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: uploadBackground,
                  foregroundColor: uploadForeground,
                  side: BorderSide(color: uploadBackground),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            : OutlinedButton(
                onPressed: () => _openUploadPanel(context, mediaItems),
                style: OutlinedButton.styleFrom(
                  backgroundColor: uploadBackground,
                  foregroundColor: uploadForeground,
                  side: BorderSide(color: uploadBackground),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.upload_file_outlined, size: 20),
              );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            captureButton,
            uploadButton,
          ],
        );
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

  Widget _buildSearchControls(
    BuildContext context,
    List<_MediaItem> mediaItems,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      ),
    );
    InputDecoration inputDecoration({IconData? prefixIcon, String? hintText}) {
      return InputDecoration(
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: 20,
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 16,
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              final searchField = TextField(
                controller: _searchController,
                decoration: inputDecoration(
                  prefixIcon: Icons.search,
                  hintText: 'Search photos and videos...',
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              );
              final filterDropdown = DropdownButtonFormField<String>(
                value: _selectedFilter,
                isExpanded: true,
                decoration: inputDecoration(),
                dropdownColor:
                    isDark ? const Color(0xFF111827) : Colors.white,
                iconEnabledColor:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'All Media',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  const SizedBox(width: 4),
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
                    const SizedBox(width: 16),
                    SizedBox(width: 200, child: filterDropdown),
                  const SizedBox(width: 8),
                  viewToggle,
                ],
              );
            }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickActionButton(
                  icon: Icons.image_outlined,
                  label: 'Project Feed',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProjectFeedPage()),
                    );
                  },
                ),
                _QuickActionButton(
                  icon: Icons.show_chart,
                  label: 'View Timeline',
                  onTap: () => _openTimelinePanel(context, mediaItems),
                ),
                _QuickActionButton(
                  icon: Icons.check_box_outlined,
                  label: 'Create Gallery',
                  onTap: () => _openCuratedGalleryPanel(context, mediaItems),
                ),
              ],
            ),
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
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                _selectedTags.isEmpty
                    ? 'Filter by Tags'
                    : 'Filter by Tags (${_selectedTags.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_selectedTags.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedTags.clear()),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF2563EB),
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
              final background = isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFF3F4F6));
              final textColor = isSelected
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF374151));
              return InkWell(
                onTap: () => setState(() => _toggleTag(tag)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Showing $filteredCount of $totalCount ${filteredCount == 1 ? 'item' : 'items'}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
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

  void _toggleLike(String id) {
    setState(() {
      if (_likedItems.contains(id)) {
        _likedItems.remove(id);
      } else {
        _likedItems.add(id);
      }
    });
  }

  void _toggleFlag(String id) {
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
    return tagSet.toList();
  }

  List<_TimelineEvent> _buildTimelineEvents(List<_MediaItem> items) {
    if (items.isEmpty) return [];
    final sorted = [...items]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return sorted.take(30).map((item) {
      final descriptionParts = <String>[];
      if (item.tags.isNotEmpty) {
        descriptionParts.add(item.tags.join(', '));
      }
      if (item.location.isNotEmpty) {
        descriptionParts.add(item.location);
      }
      final description = descriptionParts.isEmpty
          ? 'Uploaded to ${item.project}'
          : descriptionParts.join(' • ');
      return _TimelineEvent(
        id: item.id.toString(),
        type: item.type == _MediaType.video
            ? _TimelineEventType.video
            : _TimelineEventType.photo,
        title: item.title,
        description: description,
        user: item.uploadedBy,
        timestamp: item.capturedAt,
        project: item.project,
        location: item.location.isEmpty ? null : item.location,
        mediaUrl: item.url,
        tags: item.tags.isEmpty ? null : item.tags,
      );
    }).toList();
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
    required this.photoId,
    required this.attachmentId,
    required this.type,
    required this.url,
    required this.title,
    required this.project,
    required this.location,
    required this.capturedAt,
    required this.dateLabel,
    required this.timestampLabel,
    required this.tags,
    required this.uploadedBy,
    required this.initialLikes,
    required this.commentCount,
    this.gps,
    this.duration,
  });

  final String id;
  final _MediaType type;
  final String url;
  final String title;
  final String project;
  final String location;
  final DateTime capturedAt;
  final String photoId;
  final String attachmentId;
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

  final String id;
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

String _commentAuthorLabel(PhotoComment comment) {
  return comment.metadata?['authorName']?.toString() ??
      comment.metadata?['author_email']?.toString() ??
      comment.authorId ??
      'User';
}

int _commentBaseLikes(PhotoComment comment) {
  final raw = comment.metadata?['likes'];
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

int? _voiceNoteDurationSeconds(Map? voiceNote) {
  if (voiceNote == null) return null;
  final raw = voiceNote['duration'] ??
      voiceNote['durationSeconds'] ??
      voiceNote['duration_seconds'];
  if (raw == null) return 0;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw.toString()) ?? 0;
}

String? _commentMessage(PhotoComment comment, int? voiceDurationSeconds) {
  if (voiceDurationSeconds != null) {
    final body = comment.body.trim();
    if (body.isEmpty || body.toLowerCase() == 'voice note') {
      return null;
    }
  }
  return comment.body;
}

_PhotoComment _mapPhotoComment(
  PhotoComment comment, {
  Set<String>? likedIds,
  String Function(DateTime)? formatTimestamp,
}) {
  final voiceNoteRaw = comment.metadata?['voiceNote'];
  final voiceNote = voiceNoteRaw is Map ? voiceNoteRaw : null;
  final voiceDurationSeconds = _voiceNoteDurationSeconds(voiceNote);
  final baseLikes = _commentBaseLikes(comment);
  final isLiked = likedIds?.contains(comment.id) ?? false;
  final likes = isLiked ? baseLikes + 1 : baseLikes;
  final format = formatTimestamp ?? _relativeTimeShort;
  return _PhotoComment(
    id: comment.id,
    author: _commentAuthorLabel(comment),
    timestampLabel: format(comment.createdAt),
    message: _commentMessage(comment, voiceDurationSeconds),
    voiceDurationSeconds: voiceDurationSeconds,
    likes: likes,
    isLiked: isLiked,
  );
}

List<String> _extractMentions(String text) {
  final regex = RegExp(r'@([A-Za-z0-9_]+)');
  return regex
      .allMatches(text)
      .map((m) => m.group(1) ?? '')
      .where((v) => v.isNotEmpty)
      .toList();
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

  @override
  void initState() {
    super.initState();
    _events = [...widget.events];
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
    return _relativeTimeShort(timestamp);
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
                  child: _events.isEmpty
                      ? Center(
                          child: Text(
                            'No activity yet. Upload photos or videos to see timeline events.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
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

class _UploadPanel extends ConsumerStatefulWidget {
  const _UploadPanel({
    required this.projects,
    required this.suggestedTags,
  });

  final List<String> projects;
  final List<String> suggestedTags;

  @override
  ConsumerState<_UploadPanel> createState() => _UploadPanelState();
}

class _UploadPanelState extends ConsumerState<_UploadPanel> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _mentionController = TextEditingController();
  final TextEditingController _timestampController = TextEditingController();
  final FocusNode _mentionFocus = FocusNode();
  final List<String> _tags = [];
  final List<ops_repo.AttachmentDraft> _selectedFiles = [];
  final List<_TeamMember> _mentions = [];
  final ImagePicker _picker = ImagePicker();
  DateTime _timestamp = DateTime.now();
  String? _selectedProject;
  bool _gpsCapturing = false;
  String? _gpsLocation;
  String? _gpsError;
  bool _isUploading = false;
  String? _uploadError;

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

  String _inferType(String? mime, String name) {
    final lower = name.toLowerCase();
    if (mime != null && mime.startsWith('video')) return 'video';
    if (mime != null && mime.startsWith('image')) return 'photo';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return 'video';
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'photo';
    }
    return 'file';
  }

  String _sizeLabel(int bytes) {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'application/octet-stream';
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.media,
    );
    if (result == null || result.files.isEmpty) return;
    final drafts = <ops_repo.AttachmentDraft>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final mime = _guessMime(file.name);
      final type = _inferType(mime, file.name);
      drafts.add(
        ops_repo.AttachmentDraft(
          type: type,
          bytes: bytes,
          filename: file.name,
          mimeType: mime,
          metadata: _gpsLocation == null ? null : {'gpsLabel': _gpsLocation},
        ),
      );
    }
    if (drafts.isEmpty) return;
    setState(() => _selectedFiles.addAll(drafts));
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedFiles.add(
        ops_repo.AttachmentDraft(
          type: 'photo',
          bytes: bytes,
          filename: picked.name,
          mimeType: 'image/jpeg',
          metadata: _gpsLocation == null ? null : {'gpsLabel': _gpsLocation},
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
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });
    try {
      final repo = ref.read(opsRepositoryProvider);
      final title = _notesController.text.trim().isEmpty
          ? 'Photo Upload'
          : _notesController.text.trim();
      final project = (_selectedProject ?? '').isEmpty ? null : _selectedProject;
      await repo.createProjectPhoto(
        projectId: project,
        title: title,
        description:
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        tags: _tags,
        attachments: _selectedFiles,
        isFeatured: false,
        isShared: true,
      );
      ref.invalidate(projectPhotosProvider(null));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _uploadError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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
                            onPressed: _isUploading ? null : _pickFiles,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Choose Files'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _isUploading ? null : _takePhoto,
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
                      final isVideo = file.type == 'video';
                      final sizeLabel = _sizeLabel(file.bytes.length);
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
                                isVideo
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
                                    file.filename,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    sizeLabel,
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
                      onPressed: _isUploading ? null : _pickFiles,
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
                if (_uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _uploadError!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
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
                    const SizedBox(width: 16),
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
  final Set<String> _selected = {};
  bool _shareLink = true;
  bool _isPublic = false;
  bool _allowDownloads = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
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

class _MultiCapturePanel extends ConsumerStatefulWidget {
  const _MultiCapturePanel({required this.projects});

  final List<String> projects;

  @override
  ConsumerState<_MultiCapturePanel> createState() => _MultiCapturePanelState();
}

class _MultiCapturePanelState extends ConsumerState<_MultiCapturePanel> {
  final TextEditingController _galleryController = TextEditingController();
  String? _selectedProject;
  bool _cameraActive = false;
  bool _gpsCapturing = false;
  String? _gpsLocation;
  String? _gpsError;
  final ImagePicker _picker = ImagePicker();
  final List<ops_repo.AttachmentDraft> _drafts = [];
  final List<_CapturedPhoto> _capturedPhotos = [];
  bool _isUploading = false;
  String? _uploadError;

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

  Future<void> _capturePhoto() async {
    if (!_cameraActive) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final now = DateTime.now();
    setState(() {
      _drafts.add(
        ops_repo.AttachmentDraft(
          type: 'photo',
          bytes: bytes,
          filename: picked.name,
          mimeType: 'image/jpeg',
          metadata: _gpsLocation == null ? null : {'gpsLabel': _gpsLocation},
        ),
      );
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
    final index = _capturedPhotos.indexWhere((photo) => photo.id == id);
    setState(() {
      _capturedPhotos.removeWhere((photo) => photo.id == id);
      if (index >= 0 && index < _drafts.length) {
        _drafts.removeAt(index);
      }
    });
  }

  String _formatCaptureTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  Future<void> _submitCapture() async {
    if (_drafts.isEmpty) return;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });
    try {
      final repo = ref.read(opsRepositoryProvider);
      final project = (_selectedProject ?? '').isEmpty ? null : _selectedProject;
      final title = _galleryController.text.trim().isEmpty
          ? 'Captured Photos'
          : _galleryController.text.trim();
      await repo.createProjectPhoto(
        projectId: project,
        title: title,
        description: 'Uploaded from multi-capture',
        tags: const [],
        attachments: List<ops_repo.AttachmentDraft>.from(_drafts),
        isFeatured: false,
        isShared: true,
      );
      ref.invalidate(projectPhotosProvider(null));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _uploadError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
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
                if (_uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _uploadError!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
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
                          onPressed: _capturedPhotos.isEmpty || _isUploading
                              ? null
                              : _submitCapture,
                          icon: const Icon(Icons.check),
                          label: Text(
                            _isUploading
                                ? 'Uploading...'
                                : 'Complete (${_capturedPhotos.length})',
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: isSelected ? null : hoverColor,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : baseColor,
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: hoverColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
  final Set<String> likedItems;
  final Set<String> flaggedItems;
  final ValueChanged<String> onToggleLike;
  final ValueChanged<String> onToggleFlag;
  final ValueChanged<_MediaItem> onOpenComments;
  final ValueChanged<_MediaItem> onOpenWatermark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = 1;
        if (constraints.maxWidth >= 1024) {
          columns = 3;
        } else if (constraints.maxWidth >= 768) {
          columns = 2;
        }
        final childAspectRatio = columns == 1
            ? 0.9
            : columns == 2
                ? 0.75
                : 0.65;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
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

class _MediaGridCard extends StatefulWidget {
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
  State<_MediaGridCard> createState() => _MediaGridCardState();
}

class _MediaGridCardState extends State<_MediaGridCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final item = widget.item;
    final likeCount =
        widget.liked ? item.initialLikes + 1 : item.initialLikes;
    final supportsHover = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final showOverlayButtons = supportsHover && _hovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: supportsHover && _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      item.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _PhotoImageFallback(),
                    ),
                  ),
                ),
                if (item.type == _MediaType.video)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 32,
                            color: Color(0xFF111827),
                          ),
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
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.duration!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    ignoring: !showOverlayButtons,
                    child: AnimatedOpacity(
                      opacity: showOverlayButtons ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Column(
                        children: [
                          _MediaOverlayButton(
                            icon: Icons.chat_bubble_outline,
                            onTap: widget.onOpenComments,
                          ),
                          const SizedBox(height: 6),
                          _MediaOverlayButton(
                            icon: Icons.branding_watermark_outlined,
                            onTap: widget.onOpenWatermark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.calendar_today_outlined,
                    label: item.timestampLabel,
                  ),
                  if (item.gps != null)
                    _MetaRow(
                      icon: Icons.place_outlined,
                      label: item.gps!,
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF3B82F6)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF1D4ED8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        _ActionIcon(
                          icon:
                              widget.liked ? Icons.favorite : Icons.favorite_border,
                          label: likeCount.toString(),
                          color: widget.liked ? Colors.redAccent : null,
                          onTap: widget.onToggleLike,
                        ),
                        const SizedBox(width: 4),
                        _ActionIcon(
                          icon: Icons.chat_bubble_outline,
                          label: item.commentCount.toString(),
                          onTap: () {},
                        ),
                        const Spacer(),
                        _ActionIcon(
                          icon: widget.flagged
                              ? Icons.flag
                              : Icons.outlined_flag,
                          label: '',
                          color: widget.flagged ? Colors.orange : null,
                          onTap: widget.onToggleFlag,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: _InlineCommentsSection(item: item),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _InlineCommentsSection extends ConsumerStatefulWidget {
  const _InlineCommentsSection({required this.item});

  final _MediaItem item;

  @override
  ConsumerState<_InlineCommentsSection> createState() =>
      _InlineCommentsSectionState();
}

class _InlineCommentsSectionState
    extends ConsumerState<_InlineCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _recordingStopwatch = Stopwatch();
  final Set<String> _likedComments = {};
  bool _isSubmitting = false;
  bool _isRecording = false;
  bool _isExpanded = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _toggleLike(String commentId) {
    setState(() {
      if (_likedComments.contains(commentId)) {
        _likedComments.remove(commentId);
      } else {
        _likedComments.add(commentId);
      }
    });
  }

  Future<void> _submitTextComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final mentions = _extractMentions(text);
      await ref.read(opsRepositoryProvider).addPhotoComment(
            photoId: widget.item.photoId,
            body: text,
            mentions: mentions,
          );
      _commentController.clear();
      ref.invalidate(photoCommentsProvider(widget.item.photoId));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopVoiceNote();
    } else {
      await _startVoiceNote();
    }
  }

  Future<void> _startVoiceNote() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required.')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'photo_comment_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(), path: path);
    _recordingStopwatch
      ..reset()
      ..start();
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _error = null;
    });
  }

  Future<void> _stopVoiceNote() async {
    final path = await _recorder.stop();
    _recordingStopwatch.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null) return;
    final bytes = await loadFileBytes(path);
    if (bytes == null) return;
    final durationSeconds = _recordingStopwatch.elapsed.inSeconds;
    final draft = ops_repo.AttachmentDraft(
      type: 'audio',
      bytes: bytes,
      filename: p.basename(path),
      mimeType: 'audio/m4a',
      metadata: {
        'voiceNote': true,
        'durationSeconds': durationSeconds,
      },
    );
    await _submitVoiceNote(draft);
  }

  Future<void> _submitVoiceNote(ops_repo.AttachmentDraft draft) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(opsRepositoryProvider).addPhotoComment(
            photoId: widget.item.photoId,
            body: 'Voice note',
            voiceNote: draft,
          );
      ref.invalidate(photoCommentsProvider(widget.item.photoId));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final isWide = MediaQuery.of(context).size.width >= 768;
    final commentsAsync = ref.watch(photoCommentsProvider(widget.item.photoId));
    final canSend = !_isRecording &&
        !_isSubmitting &&
        _commentController.text.trim().isNotEmpty;
    final micBg = _isRecording
        ? const Color(0xFFEF4444)
        : Colors.transparent;
    final micIconColor = _isRecording
        ? Colors.white
        : (isDark ? Colors.grey[400] : Colors.grey[600]);
    final micHoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final sendBg = canSend
        ? const Color(0xFF2563EB)
        : isDark
            ? const Color(0xFF374151)
            : const Color(0xFFE5E7EB);
    final sendIconColor = canSend
        ? Colors.white
        : isDark
            ? Colors.grey[500]
            : Colors.grey[400];

    Widget commentsBody = commentsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Failed to load comments.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFDC2626),
          ),
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No comments yet. Be the first to comment!',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        final mapped = comments
            .map((comment) => _mapPhotoComment(
                  comment,
                  likedIds: _likedComments,
                ))
            .toList();
        if (isWide) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              padding: const EdgeInsets.only(right: 8),
              shrinkWrap: true,
              itemCount: mapped.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final comment = mapped[index];
                return _CommentItem(
                  comment: comment,
                  onToggleLike: () => _toggleLike(comment.id),
                );
              },
            ),
          );
        }
        final displayed =
            _isExpanded ? mapped : mapped.take(2).toList(growable: false);
        final hasMore = mapped.length > 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...displayed.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CommentItem(
                  comment: comment,
                  onToggleLike: () => _toggleLike(comment.id),
                ),
              ),
            ),
            if (hasMore && !_isExpanded)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => setState(() => _isExpanded = true),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFF3F4F6),
                    foregroundColor:
                        isDark ? Colors.grey[300] : Colors.grey[700],
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  icon: const Icon(Icons.expand_more, size: 16),
                  label: Text('View all ${mapped.length} comments'),
                ),
              ),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        commentsBody,
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      enabled: !_isRecording,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF374151) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isSubmitting ? null : _toggleRecording,
                    hoverColor: _isRecording ? null : micHoverColor,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: micBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.mic,
                        size: 16,
                        color: micIconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: canSend ? _submitTextComment : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sendBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.send,
                        size: 16,
                        color: sendIconColor,
                      ),
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

class _MediaList extends StatelessWidget {
  const _MediaList({required this.items});

  final List<_MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 768;
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              hoverColor: hoverColor,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Image.network(
                            item.url,
                            width: 96,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _PhotoImageFallback(),
                          ),
                          if (item.type == _MediaType.video)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.35),
                                child: const Center(
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: isWide ? 16 : 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                item.project,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              if (isWide && item.location.isNotEmpty)
                                Text(
                                  '•',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              if (item.location.isNotEmpty)
                                _ListMetaItem(
                                  icon: Icons.place_outlined,
                                  label: item.location,
                                ),
                              if (isWide && item.location.isNotEmpty)
                                Text(
                                  '•',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              _ListMetaItem(
                                icon: Icons.access_time,
                                label: item.dateLabel,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ListMetaItem extends StatelessWidget {
  const _ListMetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
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
          Icon(
            icon,
            size: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
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
    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: hoverColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? textColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoCommentsPanel extends ConsumerStatefulWidget {
  const _PhotoCommentsPanel({required this.item});

  final _MediaItem item;

  @override
  ConsumerState<_PhotoCommentsPanel> createState() => _PhotoCommentsPanelState();
}

class _PhotoCommentsPanelState extends ConsumerState<_PhotoCommentsPanel> {
  final TextEditingController _commentController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final Set<String> _likedComments = {};
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isSubmitting = false;
  bool _isRecording = false;
  bool _showMentions = false;
  String _mentionQuery = '';
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final mentions = _extractMentions(text);
      await ref.read(opsRepositoryProvider).addPhotoComment(
            photoId: widget.item.photoId,
            body: text,
            mentions: mentions,
          );
      _commentController.clear();
      _hideMentions();
      ref.invalidate(photoCommentsProvider(widget.item.photoId));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showPanelMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _toggleLike(String commentId) {
    setState(() {
      if (_likedComments.contains(commentId)) {
        _likedComments.remove(commentId);
      } else {
        _likedComments.add(commentId);
      }
    });
  }

  void _handleTextChanged(String value) {
    final cursor = _commentController.selection.baseOffset;
    if (cursor <= 0 || cursor > value.length) {
      _hideMentions();
      return;
    }
    final atIndex = value.lastIndexOf('@', cursor - 1);
    if (atIndex == -1) {
      _hideMentions();
      return;
    }
    final query = value.substring(atIndex + 1, cursor);
    if (query.contains(' ')) {
      _hideMentions();
      return;
    }
    setState(() {
      _showMentions = true;
      _mentionQuery = query.toLowerCase();
    });
  }

  void _hideMentions() {
    if (!_showMentions && _mentionQuery.isEmpty) return;
    setState(() {
      _showMentions = false;
      _mentionQuery = '';
    });
  }

  void _insertMention(ops_repo.MentionCandidate candidate) {
    final text = _commentController.text;
    final cursor = _commentController.selection.baseOffset;
    if (cursor < 0) return;
    final atIndex = text.lastIndexOf('@', cursor - 1);
    if (atIndex == -1) return;
    final before = text.substring(0, atIndex);
    final after = text.substring(cursor);
    final handle = candidate.handle;
    final insert = '@$handle ';
    final updated = '$before$insert$after';
    _commentController.text = updated;
    _commentController.selection = TextSelection.collapsed(
      offset: before.length + insert.length,
    );
    _hideMentions();
  }

  Future<void> _startVoiceNote() async {
    if (_isRecording) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required.')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'panel_comment_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    _recordingTimer?.cancel();
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds += 1);
    });
    setState(() {
      _isRecording = true;
      _error = null;
    });
  }

  Future<void> _stopVoiceNote() async {
    final path = await _recorder.stop();
    _recordingTimer?.cancel();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null) return;
    final bytes = await loadFileBytes(path);
    if (bytes == null) return;
    final draft = ops_repo.AttachmentDraft(
      type: 'audio',
      bytes: bytes,
      filename: p.basename(path),
      mimeType: 'audio/m4a',
      metadata: {
        'voiceNote': true,
        'durationSeconds': _recordingSeconds,
      },
    );
    await _submitVoiceNote(draft);
  }

  Future<void> _submitVoiceNote(ops_repo.AttachmentDraft draft) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(opsRepositoryProvider).addPhotoComment(
            photoId: widget.item.photoId,
            body: 'Voice note',
            voiceNote: draft,
          );
      ref.invalidate(photoCommentsProvider(widget.item.photoId));
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final commentsAsync = ref.watch(photoCommentsProvider(widget.item.photoId));
    final mentionCandidatesAsync = ref.watch(mentionCandidatesProvider);
    final mentionCandidates =
        mentionCandidatesAsync.asData?.value ?? const <ops_repo.MentionCandidate>[];
    final filteredMentions = mentionCandidates.where((candidate) {
      if (_mentionQuery.isEmpty) return true;
      final query = _mentionQuery.toLowerCase();
      return candidate.name.toLowerCase().contains(query) ||
          candidate.handle.toLowerCase().contains(query) ||
          (candidate.email?.toLowerCase().contains(query) ?? false);
    }).toList();
    final showMentions = _showMentions && filteredMentions.isNotEmpty;
    final canSend = !_isSubmitting &&
        !_isRecording &&
        _commentController.text.trim().isNotEmpty;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.98,
        builder: (context, controller) {
          final comments = commentsAsync.asData?.value ?? const <PhotoComment>[];
          final mapped = comments
              .map(
                (comment) => _mapPhotoComment(
                  comment,
                  likedIds: _likedComments,
                  formatTimestamp: _relativeTimePanel,
                ),
              )
              .toList();
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
                    child: commentsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Failed to load comments: $err',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                      data: (_) {
                        if (mapped.isEmpty) {
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
                          itemCount: mapped.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = mapped[index];
                            return _CommentItem(
                              comment: comment,
                              useBubble: true,
                              useInitials: true,
                              showMenu: true,
                              showReply: true,
                              showLikeLabel: false,
                              onToggleLike: () => _toggleLike(comment.id),
                              onReply: () => _showPanelMessage('Reply'),
                            );
                          },
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
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _error!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        if (_showMentions && mentionCandidatesAsync.isLoading)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        if (showMentions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: ListView.builder(
                              itemCount: filteredMentions.length,
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                final candidate = filteredMentions[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.alternate_email),
                                  title: Text(candidate.name),
                                  subtitle: Text('@${candidate.handle}'),
                                  onTap: () => _insertMention(candidate),
                                );
                              },
                            ),
                          ),
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF7F1D1D)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Recording... ${_formatDuration(_recordingSeconds)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white : const Color(0xFF7F1D1D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _stopVoiceNote,
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.mic_off, size: 16),
                                  label: const Text('Stop'),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  enabled: !_isRecording,
                                  onChanged: (value) {
                                    _handleTextChanged(value);
                                    setState(() {});
                                  },
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Add a comment... Use @ to mention someone',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  maxLines: 2,
                                  minLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  InkWell(
                                    onTap: canSend ? _submitComment : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: canSend
                                            ? const Color(0xFF2563EB)
                                            : isDark
                                                ? const Color(0xFF374151)
                                                : const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.send,
                                        size: 18,
                                        color: canSend
                                            ? Colors.white
                                            : isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap:
                                        _isSubmitting ? null : _startVoiceNote,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF374151)
                                            : const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.mic,
                                        size: 18,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Type @ to mention team members',
                          style: theme.textTheme.labelSmall?.copyWith(
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
    this.showMenu = false,
    this.showReply = false,
    this.showLikeLabel = true,
    this.useInitials = false,
    this.onReply,
  });

  final _PhotoComment comment;
  final VoidCallback onToggleLike;
  final bool useBubble;
  final bool showMenu;
  final bool showReply;
  final bool showLikeLabel;
  final bool useInitials;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseTextStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 14,
      color: isDark ? Colors.grey[300] : Colors.grey[700],
    );
    final mentionStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 14,
      color: const Color(0xFF3B82F6),
      fontWeight: FontWeight.w500,
    );

    final likeLabel = comment.likes > 0
        ? comment.likes.toString()
        : (showLikeLabel ? 'Like' : '');
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    comment.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.timestampLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        if (showMenu)
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, size: 16),
            splashRadius: 16,
          ),
      ],
    ),
        const SizedBox(height: 2),
        if (comment.message != null)
          RichText(
            text: TextSpan(
              children: _buildMentionSpans(
                comment.message!,
                baseTextStyle,
                mentionStyle,
              ),
            ),
          ),
        if (comment.message != null && comment.isVoiceNote)
          const SizedBox(height: 4),
        if (comment.isVoiceNote)
          _VoiceNotePlayer(durationSeconds: comment.voiceDurationSeconds ?? 0),
        const SizedBox(height: 6),
        Row(
          children: [
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
                    if (likeLabel.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        likeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: comment.isLiked
                              ? Colors.redAccent
                              : isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showReply) ...[
              const SizedBox(width: 12),
              InkWell(
                onTap: onReply,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentAvatar(
          name: comment.author,
          useInitials: useInitials,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: useBubble
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
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
  const _CommentAvatar({
    required this.name,
    required this.useInitials,
  });

  final String name;
  final bool useInitials;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (useInitials) {
      final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
      return CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF2563EB),
        child: Text(
          initial,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor:
          isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      child: Icon(
        Icons.person_outline,
        size: 16,
        color: isDark ? Colors.grey[300] : Colors.grey[600],
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor:
                  isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            durationLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
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

const List<_TeamMember> _uploadTeamMembers = [];

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
  return '0:${seconds}s';
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
      final attachmentId = attachment.id.isNotEmpty
          ? attachment.id
          : '${photo.id}-${items.length + 1}';
      final itemId = '${photo.id}-$attachmentId';
      final projectName = photo.projectId == null
          ? null
          : projectNames[photo.projectId!];
      final gps = attachment.location == null
          ? null
          : '${attachment.location!.latitude.toStringAsFixed(4)} N, '
              '${attachment.location!.longitude.toStringAsFixed(4)} W';
      items.add(
        _MediaItem(
          id: itemId,
          photoId: photo.id,
          attachmentId: attachmentId,
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
          capturedAt: capturedAt,
          duration: attachment.metadata?['duration']?.toString(),
        ),
      );
    }
  }
  items.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  return items;
}

String _relativeTime(DateTime date) {
  final now = DateTime.now();
  final delta = now.difference(date);
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inMinutes < 60) {
    final minutes = delta.inMinutes;
    return '$minutes minute${minutes == 1 ? '' : 's'} ago';
  }
  if (delta.inHours < 24) {
    final hours = delta.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }
  if (delta.inDays < 7) {
    final days = delta.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
  return DateFormat('MMM d').format(date);
}

String _relativeTimeShort(DateTime date) {
  final delta = DateTime.now().difference(date);
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

String _relativeTimePanel(DateTime date) {
  final delta = DateTime.now().difference(date);
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  return DateFormat.yMd().format(date);
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
