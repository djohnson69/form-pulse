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
  String? _selectedCategory;
  final Set<String> _selectedTags = {};
  String? _selectedIndustry;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      'All',
      ...widget.forms.map((f) => f.category ?? 'Other'),
    };
    final allTags =
        widget.forms.expand((f) => f.tags ?? const <String>[]).toSet()
          ..add('all');
    final industries = <String>{
      'All',
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
    };

    final filtered = widget.forms.where((form) {
      final matchesCategory =
          _selectedCategory == null ||
          _selectedCategory == 'All' ||
          (_selectedCategory == (form.category ?? 'Other'));
      final query = _searchController.text.toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          form.title.toLowerCase().contains(query) ||
          form.description.toLowerCase().contains(query) ||
          (form.tags ?? []).any((t) => t.toLowerCase().contains(query));
      final matchesTags =
          _selectedTags.isEmpty ||
          (form.tags != null &&
              form.tags!.any((t) => _selectedTags.contains(t)));
      final matchesIndustry =
          _selectedIndustry == null || _selectedIndustry == 'All'
          ? true
          : (form.tags ?? []).any(
              (t) => t.toLowerCase() == _selectedIndustry!.toLowerCase(),
            );
      return matchesCategory && matchesSearch && matchesTags && matchesIndustry;
    }).toList();

    final grouped = <String, List<FormDefinition>>{};
    for (final form in filtered) {
      final key = form.category ?? 'Other';
      grouped.putIfAbsent(key, () => []).add(form);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Template Gallery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search templates',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: industries.map((ind) {
              final selected = _selectedIndustry == null
                  ? ind == 'All'
                  : _selectedIndustry == ind;
              return ChoiceChip(
                label: Text(ind),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedIndustry = ind == 'All' ? null : ind;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final selected = _selectedCategory == null
                  ? cat == 'All'
                  : _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = cat == 'All' ? null : cat;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTags.map((tag) {
              if (tag == 'all') return const SizedBox.shrink();
              final selected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text('#$tag'),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No templates match your filters.'),
            )
          else
            ...grouped.entries.map((entry) {
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
