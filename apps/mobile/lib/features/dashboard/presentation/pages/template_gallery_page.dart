import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'form_detail_page.dart';

/// Template gallery to showcase breadth across industries with search and filters.
class TemplateGalleryPage extends StatefulWidget {
  const TemplateGalleryPage({required this.forms, super.key});

  final List<FormDefinition> forms;

  @override
  State<TemplateGalleryPage> createState() => _TemplateGalleryPageState();
}

class _TemplateGalleryPageState extends State<TemplateGalleryPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  String? _selectedCategory;
  String? _selectedIndustry;
  final Set<String> _selectedTags = {};

  static const List<String> _industries = [
    'Safety',
    'Operations',
    'Audit',
    'HR',
    'Fleet',
    'Retail',
    'Healthcare',
    'Insurance',
    'Facilities',
    'Construction',
    'Quality',
    'Environmental',
    'Customer',
    'IT',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _sortedCategories();
    final tagCounts = _buildTagCounts();
    final tags = _sortedTags(tagCounts);
    final suggestions = _buildSearchSuggestions(categories, tags);

    final query = _query.trim().toLowerCase();
    final filtered = widget.forms.where((form) {
      final category = (form.category ?? 'Other').trim();
      final tagsList = form.tags ?? const <String>[];
      final matchesCategory =
          _selectedCategory == null || _selectedCategory == category;
      final matchesIndustry =
          _selectedIndustry == null ||
          tagsList.any(
            (tag) => tag.toLowerCase() == _selectedIndustry!.toLowerCase(),
          );
      final matchesSearch =
          query.isEmpty ||
          form.title.toLowerCase().contains(query) ||
          form.description.toLowerCase().contains(query) ||
          category.toLowerCase().contains(query) ||
          tagsList.any((tag) => tag.toLowerCase().contains(query));
      final matchesTags =
          _selectedTags.isEmpty ||
          tagsList.any((tag) => _selectedTags.contains(tag));
      return matchesCategory && matchesIndustry && matchesSearch && matchesTags;
    }).toList();

    final grouped = <String, List<FormDefinition>>{};
    for (final form in filtered) {
      final key = (form.category ?? 'Other').trim();
      grouped.putIfAbsent(key, () => []).add(form);
    }
    final groupedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in groupedEntries) {
      entry.value.sort((a, b) => a.title.compareTo(b.title));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Template Gallery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RawAutocomplete<String>(
            textEditingController: _searchController,
            focusNode: _searchFocusNode,
            optionsBuilder: (value) {
              final text = value.text.trim().toLowerCase();
              if (text.isEmpty) return const Iterable<String>.empty();
              return suggestions
                  .where((option) => option.toLowerCase().contains(text))
                  .take(8);
            },
            onSelected: (value) {
              final cleaned = value.startsWith('#') ? value.substring(1) : value;
              _searchController.text = cleaned;
              setState(() => _query = cleaned);
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Search templates',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 260,
                      minWidth: MediaQuery.of(context).size.width - 32,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      children: options
                          .map(
                            (option) => ListTile(
                              title: Text(option),
                              onTap: () => onSelected(option),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${filtered.length} templates',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openFilterSheet(
                  categories: categories,
                  tags: tags,
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Filters'),
              ),
              if (_hasActiveFilters())
                TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text('Clear'),
                ),
            ],
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildActiveFilterChips(),
            ),
          ],
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No templates match your filters.'),
            )
          else
            ...groupedEntries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map((form) => _TemplateCard(form: form)),
                  const SizedBox(height: 16),
                ],
              );
            }),
        ],
      ),
    );
  }

  Map<String, int> _buildTagCounts() {
    final counts = <String, int>{};
    for (final form in widget.forms) {
      for (final tag in form.tags ?? const <String>[]) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<String> _sortedCategories() {
    final categories = widget.forms
        .map((form) => (form.category ?? 'Other').trim())
        .toSet()
        .toList();
    categories.sort((a, b) => a.compareTo(b));
    return categories;
  }

  List<String> _sortedTags(Map<String, int> counts) {
    final tags = counts.keys.toList();
    tags.sort((a, b) {
      final countDiff = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      if (countDiff != 0) return countDiff;
      return a.compareTo(b);
    });
    return tags;
  }

  List<String> _buildSearchSuggestions(
    List<String> categories,
    List<String> tags,
  ) {
    final suggestions = <String>{};
    for (final form in widget.forms) {
      if (form.title.trim().isNotEmpty) {
        suggestions.add(form.title.trim());
      }
    }
    suggestions.addAll(categories);
    suggestions.addAll(tags.map((tag) => '#$tag'));
    final list = suggestions.toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];
    final query = _query.trim();
    if (query.isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('Search: $query'),
          onDeleted: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
      );
    }
    if (_selectedCategory != null) {
      chips.add(
        InputChip(
          label: Text('Category: $_selectedCategory'),
          onDeleted: () => setState(() => _selectedCategory = null),
        ),
      );
    }
    if (_selectedIndustry != null) {
      chips.add(
        InputChip(
          label: Text('Industry: $_selectedIndustry'),
          onDeleted: () => setState(() => _selectedIndustry = null),
        ),
      );
    }
    for (final tag in _selectedTags) {
      chips.add(
        InputChip(
          label: Text('#$tag'),
          onDeleted: () => setState(() => _selectedTags.remove(tag)),
        ),
      );
    }
    return chips;
  }

  bool _hasActiveFilters() {
    return _query.trim().isNotEmpty ||
        _selectedCategory != null ||
        _selectedIndustry != null ||
        _selectedTags.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _selectedCategory = null;
      _selectedIndustry = null;
      _selectedTags.clear();
    });
  }

  Future<void> _openFilterSheet({
    required List<String> categories,
    required List<String> tags,
  }) async {
    final current = _TemplateFilters(
      category: _selectedCategory,
      industry: _selectedIndustry,
      tags: _selectedTags,
    );
    final result = await showModalBottomSheet<_TemplateFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String? selectedCategory = current.category;
        String? selectedIndustry = current.industry;
        final selectedTags = {...current.tags};
        String tagQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final visibleTags = tags.where((tag) {
              if (tagQuery.trim().isEmpty) return true;
              return tag.toLowerCase().contains(tagQuery.trim().toLowerCase());
            }).toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              selectedCategory = null;
                              selectedIndustry = null;
                              selectedTags.clear();
                              tagQuery = '';
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory ?? 'All',
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: ['All', ...categories]
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedCategory = value == 'All' ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedIndustry ?? 'All',
                      decoration: const InputDecoration(
                        labelText: 'Industry',
                        border: OutlineInputBorder(),
                      ),
                      items: ['All', ..._industries]
                          .map(
                            (industry) => DropdownMenuItem(
                              value: industry,
                              child: Text(industry),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedIndustry = value == 'All' ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Filter tags',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setModalState(() {
                        tagQuery = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    if (visibleTags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No tags match your search.'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: visibleTags.map((tag) {
                          final selected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text('#$tag'),
                            selected: selected,
                            onSelected: (value) {
                              setModalState(() {
                                if (value) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _TemplateFilters(
                              category: selectedCategory,
                              industry: selectedIndustry,
                              tags: selectedTags,
                            ),
                          );
                        },
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) return;
    setState(() {
      _selectedCategory = result.category;
      _selectedIndustry = result.industry;
      _selectedTags
        ..clear()
        ..addAll(result.tags);
    });
  }
}

class _TemplateFilters {
  const _TemplateFilters({
    this.category,
    this.industry,
    Set<String>? tags,
  }) : tags = tags ?? const <String>{};

  final String? category;
  final String? industry;
  final Set<String> tags;
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.form});

  final FormDefinition form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(form.title.isNotEmpty ? form.title[0] : '?'),
        ),
        title: Text(form.title),
        subtitle: Text(form.description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FormDetailPage(form: form)),
          );
        },
      ),
    );
  }
}
