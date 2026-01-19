import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../ops/data/ops_provider.dart';

class BeforeAfterPhotosPage extends ConsumerStatefulWidget {
  const BeforeAfterPhotosPage({super.key});

  @override
  ConsumerState<BeforeAfterPhotosPage> createState() => _BeforeAfterPhotosPageState();
}

class _BeforeAfterPhotosPageState extends ConsumerState<BeforeAfterPhotosPage> {
  int _selectedIndex = 0;
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(projectPhotosProvider(null));
    final comparisons = _buildComparisons(photosAsync.asData?.value ?? const []);
    final hasData = comparisons.isNotEmpty;
    if (_selectedIndex >= comparisons.length) {
      _selectedIndex = 0;
    }
    final current = hasData ? comparisons[_selectedIndex] : null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          final maxWidth =
              constraints.maxWidth > 1280 ? 1280.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                children: [
                  _buildHeader(context, isDark),
                  if (photosAsync.isLoading) const LinearProgressIndicator(),
                  if (photosAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ErrorBanner(message: photosAsync.error.toString()),
                    ),
                  const SizedBox(height: 24),
                  if (!hasData && !photosAsync.isLoading)
                    _buildEmptyState(context, isDark)
                  else if (hasData)
                    LayoutBuilder(
                      builder: (context, inner) {
                        final isWide = inner.maxWidth >= 960;
                        final listSection = _buildComparisonList(
                          context,
                          comparisons,
                          isDark,
                        );
                        final viewerSection = _buildComparisonViewer(
                          context,
                          current!,
                          borderColor,
                        );
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 1, child: listSection),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: viewerSection),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            listSection,
                            const SizedBox(height: 24),
                            viewerSection,
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  _buildTipBanner(context, isDark),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before & After Photos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: isWide ? 30 : 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Visual progress tracking with side-by-side comparisons',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No comparisons yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tag project photos with metadata: { comparisonId: <id>, stage: before/after } to see them here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Add Project Photos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonList(
    BuildContext context,
    List<_ComparisonItem> comparisons,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final selectedBackground = isDark
        ? const Color(0xFF3B82F6).withOpacity(0.12)
        : const Color(0xFFEFF6FF);
    final hoverColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparisons (${comparisons.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
        ),
        const SizedBox(height: 12),
        ...comparisons.asMap().entries.map((entry) {
          final index = entry.key;
          final comparison = entry.value;
          final isSelected = index == _selectedIndex;
          final background =
              isSelected
                  ? selectedBackground
                  : (isDark ? const Color(0xFF1F2937) : Colors.white);
          final border =
              isSelected ? const Color(0xFF3B82F6) : borderColor;
          final progressLabel =
              (comparison.progress ?? '').trim().isEmpty ? '--' : comparison.progress!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: border),
              ),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedIndex = index;
                  _sliderPosition = 0.5;
                }),
                borderRadius: BorderRadius.circular(12),
                hoverColor: hoverColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comparison.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: $progressLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${DateFormat.yMd().format(comparison.before.capturedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'To ${DateFormat.yMd().format(comparison.after.capturedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildComparisonViewer(
    BuildContext context,
    _ComparisonItem current,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressLabel =
        (current.progress ?? '').trim().isEmpty ? '--' : current.progress!;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 14,
      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
    );
    final secondaryButtonStyle = FilledButton.styleFrom(
      backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
      foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
    final primaryButtonStyle = FilledButton.styleFrom(
      backgroundColor: const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          current.location ?? 'Project site',
                          style: metaStyle,
                        ),
                      ],
                    ),
                    Text(
                      '• Progress: $progressLabel',
                      style: metaStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      onTapDown: (details) {
                        final position =
                            details.localPosition.dx / constraints.maxWidth;
                        setState(
                          () => _sliderPosition = position.clamp(0.0, 1.0),
                        );
                      },
                      onHorizontalDragUpdate: (details) {
                        final position =
                            details.localPosition.dx / constraints.maxWidth;
                        setState(
                          () => _sliderPosition = position.clamp(0.0, 1.0),
                        );
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              current.after.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _ComparisonFallback(),
                            ),
                          ),
                          Positioned.fill(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: _sliderPosition,
                                child: Image.network(
                                  current.before.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const _ComparisonFallback(),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: constraints.maxWidth * _sliderPosition - 2,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 4,
                              color: Colors.white,
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.compare_arrows,
                                    size: 20,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 16,
                            left: 16,
                            child: _CornerLabel(label: 'BEFORE'),
                          ),
                          const Positioned(
                            top: 16,
                            right: 16,
                            child: _CornerLabel(label: 'AFTER'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateLabel(
                        label: 'Before Date',
                        date: current.before.capturedAt,
                        iconColor: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DateLabel(
                        label: 'After Date',
                        date: current.after.capturedAt,
                        iconColor: const Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: secondaryButtonStyle,
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Download'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: secondaryButtonStyle,
                        onPressed: () {},
                        icon: const Icon(Icons.share_outlined, size: 16),
                        label: const Text('Share Link'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: primaryButtonStyle,
                      onPressed: () {},
                      icon: const Icon(Icons.zoom_in, size: 16),
                      label: const Text('Full Screen'),
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

  Widget _buildTipBanner(BuildContext context, bool isDark) {
    final textColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF3B82F6).withOpacity(0.12)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3B82F6).withOpacity(0.3)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: textColor,
                    ),
                children: [
                  TextSpan(
                    text: 'Tip: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'Drag the slider left and right to compare before and after photos. '
                        'All photos include GPS coordinates and timestamps for documentation.',
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

class _CornerLabel extends StatelessWidget {
  const _CornerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({
    required this.label,
    required this.date,
    required this.iconColor,
  });

  final String label;
  final DateTime date;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              DateFormat.yMd().format(date),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: isDark ? Colors.grey[100] : Colors.grey[900],
              ),
            ),
          ],
        ),
      ],
    );
  }
}



class _ComparisonSide {
  const _ComparisonSide({
    required this.url,
    required this.capturedAt,
  });

  final String url;
  final DateTime capturedAt;
}

class _ComparisonItem {
  const _ComparisonItem({
    required this.id,
    required this.title,
    required this.before,
    required this.after,
    this.location,
    this.progress,
  });

  final String id;
  final String title;
  final _ComparisonSide before;
  final _ComparisonSide after;
  final String? location;
  final String? progress;
}

List<_ComparisonItem> _buildComparisons(List<ProjectPhoto> photos) {
  final pairs = <String, Map<String, ProjectPhoto>>{};
  for (final photo in photos) {
    final meta = photo.metadata ?? {};
    final stageRaw = (meta['stage'] ?? meta['position'] ?? meta['type'])?.toString().toLowerCase();
    if (stageRaw != 'before' && stageRaw != 'after') continue;
    final comparisonId = (meta['comparisonId'] ?? meta['pairId'] ?? photo.projectId ?? photo.id).toString();
    final bucket = pairs.putIfAbsent(comparisonId, () => {});
    final stage = stageRaw!;
    bucket[stage] = photo;
  }

  final items = <_ComparisonItem>[];
  for (final entry in pairs.entries) {
    final beforePhoto = entry.value['before'];
    final afterPhoto = entry.value['after'];
    if (beforePhoto == null || afterPhoto == null) continue;
    final beforeAttachment = beforePhoto.attachments?.firstWhere(
      (a) => a.type == 'photo',
      orElse: () => beforePhoto.attachments?.first ??
          MediaAttachment(
            id: 'temp',
            type: 'photo',
            url: '',
            capturedAt: beforePhoto.createdAt,
          ),
    );
    final afterAttachment = afterPhoto.attachments?.firstWhere(
      (a) => a.type == 'photo',
      orElse: () => afterPhoto.attachments?.first ??
          MediaAttachment(
            id: 'temp',
            type: 'photo',
            url: '',
            capturedAt: afterPhoto.createdAt,
          ),
    );
    if (beforeAttachment == null || afterAttachment == null) continue;
    final location = beforePhoto.metadata?['location']?.toString() ??
        afterPhoto.metadata?['location']?.toString();
    final progress = afterPhoto.metadata?['progress']?.toString();
    items.add(
      _ComparisonItem(
        id: entry.key,
        title: afterPhoto.title ?? beforePhoto.title ?? 'Project Comparison',
        before: _ComparisonSide(
          url: beforeAttachment.url,
          capturedAt: beforeAttachment.capturedAt,
        ),
        after: _ComparisonSide(
          url: afterAttachment.url,
          capturedAt: afterAttachment.capturedAt,
        ),
        location: location,
        progress: progress,
      ),
    );
  }
  items.sort((a, b) => b.after.capturedAt.compareTo(a.after.capturedAt));
  return items;
}

class _ComparisonFallback extends StatelessWidget {
  const _ComparisonFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: ColoredBox(
        color: scheme.surfaceVariant,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
          size: 32,
        ),
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
