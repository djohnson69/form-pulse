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
                return DropdownButtonFormField<String?>(
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
                );
              },
            ),
          ),
          Expanded(
            child: photosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (photos) {
                if (photos.isEmpty) {
                  return const Center(child: Text('No gallery photos yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final count = photo.attachments?.length ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.photo),
                        title: Text(photo.title ?? 'Project photo'),
                        subtitle: Text(
                          count == 0 ? 'No media attached' : '$count attachment(s)',
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
                );
              },
            ),
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
}
