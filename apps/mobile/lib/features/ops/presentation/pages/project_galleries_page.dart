import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ops_provider.dart';
import '../../../projects/data/projects_provider.dart';
import 'photo_detail_page.dart';
import 'photo_editor_page.dart';

class ProjectGalleriesPage extends ConsumerStatefulWidget {
  const ProjectGalleriesPage({super.key});

  @override
  ConsumerState<ProjectGalleriesPage> createState() =>
      _ProjectGalleriesPageState();
}

class _ProjectGalleriesPageState extends ConsumerState<ProjectGalleriesPage> {
  String? _projectId;
  String? _tagFilter;
  String? _labelFilter;

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(projectPhotosProvider(_projectId));
    final projectsAsync = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Project Galleries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add photo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: projectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (projects) {
                final labels = projects
                    .expand((project) => project.labels)
                    .map((label) => label.trim())
                    .where((label) => label.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                return Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _projectId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by project',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All projects'),
                        ),
                        ...projects.map((project) {
                          return DropdownMenuItem<String?>(
                            value: project.id,
                            child: Text(project.name),
                          );
                        }),
                      ],
                      onChanged: (value) => setState(() => _projectId = value),
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _labelFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by project label',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All labels'),
                          ),
                          ...labels.map(
                            (label) => DropdownMenuItem<String?>(
                              value: label,
                              child: Text(label),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _labelFilter = value),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          photosAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(child: Center(child: Text('Error: $e'))),
            data: (photos) {
              final tags = photos
                  .expand((photo) => photo.tags)
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final projectLabels = {
                for (final project in (projectsAsync.asData?.value ?? const []))
                  project.id: project.labels,
              };
              final filtered = photos.where((photo) {
                if (_tagFilter != null &&
                    !photo.tags.contains(_tagFilter)) {
                  return false;
                }
                if (_labelFilter != null) {
                  final labels = projectLabels[photo.projectId] ?? const [];
                  if (!labels.contains(_labelFilter)) return false;
                }
                return true;
              }).toList();
              return Expanded(
                child: Column(
                  children: [
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonFormField<String?>(
                          initialValue: _tagFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by tag',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All tags'),
                            ),
                            ...tags.map(
                              (tag) => DropdownMenuItem<String?>(
                                value: tag,
                                child: Text(tag),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(() => _tagFilter = value),
                        ),
                      ),
                    if (tags.isNotEmpty) const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No gallery photos yet.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final photo = filtered[index];
                                final count = photo.attachments?.length ?? 0;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const Icon(Icons.photo),
                                    title: Text(photo.title ?? 'Project photo'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          count == 0
                                              ? 'No media attached'
                                              : '$count attachment(s)',
                                        ),
                                        if (photo.tags.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: photo.tags
                                                .map(
                                                  (tag) => Chip(
                                                    label: Text(_formatTag(tag)),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    isThreeLine: photo.tags.isNotEmpty,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PhotoDetailPage(photo: photo),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhotoEditorPage(projectId: _projectId),
      ),
    );
    if (result == true) {
      ref.invalidate(projectPhotosProvider(_projectId));
    }
  }

  String _formatTag(String tag) {
    switch (tag) {
      case 'before':
        return 'Before';
      case 'after':
        return 'After';
      case 'logo_sticker':
        return 'Logo sticker';
      default:
        return tag;
    }
  }
}
