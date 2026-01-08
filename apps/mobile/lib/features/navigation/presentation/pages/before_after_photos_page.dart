import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BeforeAfterPhotosPage extends StatefulWidget {
  const BeforeAfterPhotosPage({super.key});

  @override
  State<BeforeAfterPhotosPage> createState() => _BeforeAfterPhotosPageState();
}

class _BeforeAfterPhotosPageState extends State<BeforeAfterPhotosPage> {
  int _selectedIndex = 0;
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final comparisons = _comparisons;
    final current = comparisons[_selectedIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(context, isDark),
                  const SizedBox(height: 16),
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
                        current,
                        borderColor,
                      );
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 320, child: listSection),
                            const SizedBox(width: 16),
                            Expanded(child: viewerSection),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          listSection,
                          const SizedBox(height: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before & After Photos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Visual progress tracking with side-by-side comparisons',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildComparisonList(
    BuildContext context,
    List<_ComparisonItem> comparisons,
    bool isDark,
  ) {
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparisons (${comparisons.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ...comparisons.asMap().entries.map((entry) {
          final index = entry.key;
          final comparison = entry.value;
          final isSelected = index == _selectedIndex;
          final background = isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
              : Theme.of(context).colorScheme.surface;
          final border = isSelected
              ? const Color(0xFF2563EB)
              : borderColor;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedIndex = index;
              _sliderPosition = 0.5;
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comparison.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black87)
                              : null,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${comparison.progress}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFF1D4ED8))
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From ${DateFormat.yMd().format(comparison.beforeDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFF1D4ED8))
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'To ${DateFormat.yMd().format(comparison.afterDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFF1D4ED8))
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                  ),
                ],
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Location: ${current.location}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Progress: ${current.progress}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
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
                  return GestureDetector(
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
                            current.afterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _ImageFallback(),
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: _sliderPosition,
                              child: Image.network(
                                current.beforeUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _ImageFallback(),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: constraints.maxWidth * _sliderPosition - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: Colors.white,
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.all(6),
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
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: _CornerLabel(label: 'BEFORE'),
                        ),
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: _CornerLabel(label: 'AFTER'),
                        ),
                      ],
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
                        date: current.beforeDate,
                        iconColor: const Color(0xFF3B82F6),
                      ),
                    ),
                    Expanded(
                      child: _DateLabel(
                        label: 'After Date',
                        date: current.afterDate,
                        iconColor: const Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share Link'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.zoom_out_map, size: 18),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.2)
            : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1D4ED8).withOpacity(0.4)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Text(
        'Tip: drag the slider left and right to compare before and after photos. All photos include GPS coordinates and timestamps for documentation.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1D4ED8),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
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
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              DateFormat.yMd().format(date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[100] : Colors.grey[900],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonItem {
  const _ComparisonItem({
    required this.id,
    required this.title,
    required this.beforeUrl,
    required this.afterUrl,
    required this.beforeDate,
    required this.afterDate,
    required this.location,
    required this.progress,
  });

  final int id;
  final String title;
  final String beforeUrl;
  final String afterUrl;
  final DateTime beforeDate;
  final DateTime afterDate;
  final String location;
  final String progress;
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

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

final List<_ComparisonItem> _comparisons = [
  _ComparisonItem(
    id: 1,
    title: 'Foundation Work - Building A',
    beforeUrl:
        'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800',
    afterUrl:
        'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=800',
    beforeDate: DateTime(2025, 11, 15),
    afterDate: DateTime(2025, 12, 20),
    location: 'Main Site - GPS: 40.7128 N, 74.0060 W',
    progress: '85%',
  ),
  _ComparisonItem(
    id: 2,
    title: 'Site Cleanup - Zone B',
    beforeUrl:
        'https://images.unsplash.com/photo-1581094271901-8022df4466f9?w=800',
    afterUrl:
        'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=800',
    beforeDate: DateTime(2025, 12, 1),
    afterDate: DateTime(2025, 12, 22),
    location: 'Zone B - GPS: 40.7580 N, 73.9855 W',
    progress: '100%',
  ),
  _ComparisonItem(
    id: 3,
    title: 'Equipment Installation',
    beforeUrl:
        'https://images.unsplash.com/photo-1590650516494-0c8e4a4dd67e?w=800',
    afterUrl:
        'https://images.unsplash.com/photo-1597289357-b8e1b0ac37b2?w=800',
    beforeDate: DateTime(2025, 12, 10),
    afterDate: DateTime(2025, 12, 23),
    location: 'Warehouse - GPS: 40.7489 N, 73.9680 W',
    progress: '95%',
  ),
];
