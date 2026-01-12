import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'form_fill_page.dart';

/// Form details with quick launch into the form fill experience.
class FormDetailPage extends StatelessWidget {
  const FormDetailPage({required this.form, super.key});

  final FormDefinition form;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            onPressed: () => _startForm(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    form.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(
                        icon: Icons.category,
                        label: form.category ?? 'Uncategorized',
                      ),
                      _InfoChip(
                        icon: Icons.layers,
                        label: 'Fields: ${form.fields.length}',
                      ),
                      _InfoChip(
                        icon: Icons.verified,
                        label: form.isPublished ? 'Published' : 'Draft',
                      ),
                      if (form.version != null)
                        _InfoChip(
                          icon: Icons.history,
                          label: 'v${form.version}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fields',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final field = form.fields[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(field.label),
                  subtitle: Text(field.type.displayName),
                  trailing:
                      field.isRequired ? const Text('Required') : const SizedBox(),
                );
              },
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemCount: form.fields.length,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _startForm(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Submission'),
          ),
        ),
      ),
    );
  }

  void _startForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormFillPage(form: form),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
