import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/sop_provider.dart';
import 'sop_detail_page.dart';

class SopLibraryPage extends ConsumerStatefulWidget {
  const SopLibraryPage({super.key});

  @override
  ConsumerState<SopLibraryPage> createState() => _SopLibraryPageState();
}

class _SopLibraryPageState extends ConsumerState<SopLibraryPage> {
  String _query = '';
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final asyncSops = ref.watch(sopDocumentsProvider);
    final sops = asyncSops.asData?.value ?? const <SopDocument>[];
    final articles =
        sops.isNotEmpty ? _articlesFromSops(sops) : _demoArticles;
    final filteredArticles = _filterArticles(articles);
    final categories = _buildCategories(articles);
    final colors = _KnowledgeBaseColors.fromTheme(Theme.of(context));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Knowledge Base')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (asyncSops.isLoading) const LinearProgressIndicator(),
          if (asyncSops.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ErrorBanner(message: asyncSops.error.toString()),
            ),
          _Header(
            muted: colors.muted,
          ),
          const SizedBox(height: 16),
          _SearchCard(
            colors: colors,
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 16),
          _CategoriesGrid(
            categories: categories,
            selectedCategory: _selectedCategory,
            colors: colors,
            onSelected: (id) => setState(() => _selectedCategory = id),
          ),
          const SizedBox(height: 16),
          _ArticlesGrid(
            articles: filteredArticles,
            colors: colors,
            onOpen: (article) {
              if (article.document == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo article')),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SopDetailPage(document: article.document!),
                ),
              );
            },
          ),
          if (filteredArticles.isEmpty)
            _EmptyState(muted: colors.muted)
          else
            const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_KbArticle> _filterArticles(List<_KbArticle> articles) {
    final query = _query.toLowerCase();
    return articles.where((article) {
      final matchesSearch = query.isEmpty ||
          article.title.toLowerCase().contains(query) ||
          article.excerpt.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'all' ||
          article.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<_KbArticle> _articlesFromSops(List<SopDocument> sops) {
    final sorted = [...sops]
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    return [
      for (var i = 0; i < sorted.length; i++)
        _KbArticle(
          id: sorted[i].id,
          title: sorted[i].title,
          excerpt: _excerptFromSop(sorted[i]),
          category: _categoryForSop(sorted[i]),
          views: _metaInt(sorted[i].metadata, ['views', 'view_count']) ??
              (1200 - (i * 110)).clamp(120, 1600).toInt(),
          likes: _metaInt(sorted[i].metadata, ['likes', 'like_count']) ??
              (80 - (i * 6)).clamp(12, 100).toInt(),
          rating: _metaDouble(sorted[i].metadata, ['rating', 'score']) ??
              (4.7 - (i * 0.1)).clamp(3.8, 4.9),
          lastUpdated: _relativeTime(sorted[i].updatedAt ?? sorted[i].createdAt),
          document: sorted[i],
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Knowledge Base',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Find answers and learn how to use Form Bridge',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.colors, required this.onChanged});

  final _KnowledgeBaseColors colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search articles...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: colors.subtleSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({
    required this.categories,
    required this.selectedCategory,
    required this.colors,
    required this.onSelected,
  });

  final List<_KbCategory> categories;
  final String selectedCategory;
  final _KnowledgeBaseColors colors;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final aspectRatio = columns == 2 ? 1.2 : 1.1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: categories.map((category) {
            final selected = selectedCategory == category.id;
            return InkWell(
              onTap: () => onSelected(category.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? category.start : colors.border,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: category.start.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [category.start, category.end],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.title,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.count} articles',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.muted,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ArticlesGrid extends StatelessWidget {
  const _ArticlesGrid({
    required this.articles,
    required this.colors,
    required this.onOpen,
  });

  final List<_KbArticle> articles;
  final _KnowledgeBaseColors colors;
  final ValueChanged<_KbArticle> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 1.35 : 1.55,
          ),
          itemCount: articles.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final article = articles[index];
            return _ArticleCard(
              article: article,
              colors: colors,
              onTap: () => onOpen(article),
            );
          },
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.colors,
    required this.onTap,
  });

  final _KbArticle article;
  final _KnowledgeBaseColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = _categoryLabel(article.category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.tagBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    categoryLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.tagText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.muted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.title,
                  ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                article.excerpt,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatIcon(
                  icon: Icons.visibility_outlined,
                  label: article.views.toString(),
                  colors: colors,
                ),
                const SizedBox(width: 12),
                _StatIcon(
                  icon: Icons.thumb_up_outlined,
                  label: article.likes.toString(),
                  colors: colors,
                ),
                const SizedBox(width: 12),
                _StatIcon(
                  icon: Icons.star_outline,
                  label: article.rating.toStringAsFixed(1),
                  colors: colors,
                  accent: const Color(0xFFF59E0B),
                ),
                const Spacer(),
                Text(
                  article.lastUpdated,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon({
    required this.icon,
    required this.label,
    required this.colors,
    this.accent,
  });

  final IconData icon;
  final String label;
  final _KnowledgeBaseColors colors;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final iconColor = accent ?? colors.muted;
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
              ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
    final surface = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1F2937)
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 56, color: muted),
          const SizedBox(height: 12),
          Text(
            'No articles found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search term or category',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
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
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7F1D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

class _KbArticle {
  const _KbArticle({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.category,
    required this.views,
    required this.likes,
    required this.rating,
    required this.lastUpdated,
    this.document,
  });

  final String id;
  final String title;
  final String excerpt;
  final String category;
  final int views;
  final int likes;
  final double rating;
  final String lastUpdated;
  final SopDocument? document;
}

class _KbCategory {
  const _KbCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.start,
    required this.end,
    required this.count,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color start;
  final Color end;
  final int count;

  _KbCategory copyWith({int? count}) {
    return _KbCategory(
      id: id,
      name: name,
      icon: icon,
      start: start,
      end: end,
      count: count ?? this.count,
    );
  }
}

class _KnowledgeBaseColors {
  const _KnowledgeBaseColors({
    required this.background,
    required this.surface,
    required this.subtleSurface,
    required this.border,
    required this.muted,
    required this.title,
    required this.tagBackground,
    required this.tagText,
  });

  final Color background;
  final Color surface;
  final Color subtleSurface;
  final Color border;
  final Color muted;
  final Color title;
  final Color tagBackground;
  final Color tagText;

  factory _KnowledgeBaseColors.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return _KnowledgeBaseColors(
      background: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      surface: isDark ? const Color(0xFF1F2937) : Colors.white,
      subtleSurface:
          isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      border: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      muted: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      title: isDark ? Colors.white : const Color(0xFF111827),
      tagBackground:
          isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      tagText: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
    );
  }
}

List<_KbCategory> _buildCategories(List<_KbArticle> articles) {
  const base = [
    _KbCategory(
      id: 'all',
      name: 'All Articles',
      icon: Icons.menu_book_outlined,
      start: Color(0xFF3B82F6),
      end: Color(0xFF2563EB),
      count: 0,
    ),
    _KbCategory(
      id: 'getting-started',
      name: 'Getting Started',
      icon: Icons.description_outlined,
      start: Color(0xFF22C55E),
      end: Color(0xFF16A34A),
      count: 0,
    ),
    _KbCategory(
      id: 'tutorials',
      name: 'Tutorials',
      icon: Icons.play_circle_outline,
      start: Color(0xFF8B5CF6),
      end: Color(0xFF7C3AED),
      count: 0,
    ),
    _KbCategory(
      id: 'troubleshooting',
      name: 'Troubleshooting',
      icon: Icons.link,
      start: Color(0xFFF97316),
      end: Color(0xFFEA580C),
      count: 0,
    ),
  ];
  return base.map((category) {
    final count = category.id == 'all'
        ? articles.length
        : articles.where((article) => article.category == category.id).length;
    return category.copyWith(count: count);
  }).toList();
}

String _categoryForSop(SopDocument sop) {
  final raw = (sop.category ?? '').toLowerCase();
  final tags = sop.tags.map((tag) => tag.toLowerCase()).toList();
  final combined = [raw, ...tags].join(' ');
  if (combined.contains('start') || combined.contains('getting')) {
    return 'getting-started';
  }
  if (combined.contains('tutorial') || combined.contains('guide')) {
    return 'tutorials';
  }
  if (combined.contains('trouble') ||
      combined.contains('issue') ||
      combined.contains('error')) {
    return 'troubleshooting';
  }
  return 'getting-started';
}

String _categoryLabel(String id) {
  switch (id) {
    case 'getting-started':
      return 'Getting Started';
    case 'tutorials':
      return 'Tutorials';
    case 'troubleshooting':
      return 'Troubleshooting';
    default:
      return 'All Articles';
  }
}

String _excerptFromSop(SopDocument sop) {
  final summary = sop.summary?.trim();
  if (summary != null && summary.isNotEmpty) {
    return summary;
  }
  final body =
      sop.metadata?['latest_body']?.toString() ?? sop.metadata?['body']?.toString();
  if (body != null && body.trim().isNotEmpty) {
    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 120) {
      return '${cleaned.substring(0, 117)}...';
    }
    return cleaned;
  }
  return 'Learn the step-by-step process for ${sop.title.toLowerCase()}.';
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 365) {
    final years = (diff.inDays / 365).floor();
    return years == 1 ? '1 year ago' : '$years years ago';
  }
  if (diff.inDays >= 30) {
    final months = (diff.inDays / 30).floor();
    return months == 1 ? '1 month ago' : '$months months ago';
  }
  if (diff.inDays >= 7) {
    final weeks = (diff.inDays / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  if (diff.inDays >= 1) {
    return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
  }
  if (diff.inHours >= 1) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  if (diff.inMinutes >= 1) {
    return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
  }
  return 'just now';
}

int? _metaInt(Map<String, dynamic>? metadata, List<String> keys) {
  if (metadata == null) return null;
  for (final key in keys) {
    final value = metadata[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _metaDouble(Map<String, dynamic>? metadata, List<String> keys) {
  if (metadata == null) return null;
  for (final key in keys) {
    final value = metadata[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

const _demoArticles = [
  _KbArticle(
    id: '1',
    title: 'How to Submit a Form',
    excerpt: 'Learn the step-by-step process for submitting inspection forms...',
    category: 'getting-started',
    views: 1234,
    likes: 89,
    rating: 4.5,
    lastUpdated: '2 days ago',
  ),
  _KbArticle(
    id: '2',
    title: 'QR Code Scanning Best Practices',
    excerpt: 'Tips and tricks for efficiently scanning asset QR codes...',
    category: 'tutorials',
    views: 892,
    likes: 67,
    rating: 4.8,
    lastUpdated: '1 week ago',
  ),
  _KbArticle(
    id: '3',
    title: 'Cannot Access Training Module',
    excerpt: 'Common issues and solutions for training portal access...',
    category: 'troubleshooting',
    views: 756,
    likes: 45,
    rating: 4.2,
    lastUpdated: '3 days ago',
  ),
  _KbArticle(
    id: '4',
    title: 'Managing Your Team',
    excerpt: 'A complete guide for supervisors on team management...',
    category: 'tutorials',
    views: 654,
    likes: 52,
    rating: 4.6,
    lastUpdated: '5 days ago',
  ),
  _KbArticle(
    id: '5',
    title: 'Form Submission Errors',
    excerpt: 'Resolving common errors when submitting forms...',
    category: 'troubleshooting',
    views: 543,
    likes: 38,
    rating: 4.3,
    lastUpdated: '1 week ago',
  ),
  _KbArticle(
    id: '6',
    title: 'Setting Up Your Profile',
    excerpt: 'Complete your profile and customize your dashboard...',
    category: 'getting-started',
    views: 432,
    likes: 29,
    rating: 4.7,
    lastUpdated: '2 weeks ago',
  ),
];
