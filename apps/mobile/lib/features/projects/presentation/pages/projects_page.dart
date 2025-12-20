import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/projects_provider.dart';
import 'project_detail_page.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  String _search = '';
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Projects Load Error',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load projects.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${e.toString()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.invalidate(projectsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
      data: (projects) {
        final labels = projects
            .expand((p) => p.labels)
            .toSet()
            .where((label) => label.trim().isNotEmpty)
            .toList()
          ..sort();
        final filtered = _applyFilters(projects);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(projectsProvider);
            await ref.read(projectsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSearchField(),
              const SizedBox(height: 12),
              if (labels.isNotEmpty) _buildLabelFilters(labels),
              if (labels.isNotEmpty) const SizedBox(height: 16),
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'No projects found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a project to start tracking photos, notes, and progress.',
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((project) => _ProjectCard(project: project)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search projects',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
    );
  }

  Widget _buildLabelFilters(List<String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _selectedLabel == null,
          onSelected: (_) => setState(() => _selectedLabel = null),
        ),
        ...labels.map(
          (label) => FilterChip(
            label: Text(label),
            selected: _selectedLabel == label,
            onSelected: (_) => setState(() => _selectedLabel = label),
          ),
        ),
      ],
    );
  }

  List<Project> _applyFilters(List<Project> projects) {
    return projects.where((project) {
      final matchesSearch = _search.isEmpty ||
          project.name.toLowerCase().contains(_search) ||
          (project.description?.toLowerCase().contains(_search) ?? false);
      final matchesLabel = _selectedLabel == null ||
          project.labels.contains(_selectedLabel);
      return matchesSearch && matchesLabel;
    }).toList();
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.folder_open),
        title: Text(project.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((project.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(project.description!),
              ),
            if (project.labels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: project.labels
                      .map(
                        (label) => Chip(
                          label: Text(label),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
        trailing: Icon(
          project.status == 'archived' ? Icons.archive : Icons.chevron_right,
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProjectDetailPage(project: project),
            ),
          );
          ref.invalidate(projectsProvider);
        },
      ),
    );
  }
}
