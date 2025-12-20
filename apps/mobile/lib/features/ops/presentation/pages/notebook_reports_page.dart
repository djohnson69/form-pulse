import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/ops_provider.dart';

class NotebookReportsPage extends ConsumerWidget {
  const NotebookReportsPage({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(notebookReportsProvider(projectId));
    return Scaffold(
      appBar: AppBar(title: const Text('Notebook Reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New report'),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('No reports yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(report.title),
                  subtitle: Text('${report.pageIds.length} pages'),
                  trailing: report.fileUrl == null
                      ? const Icon(Icons.warning_amber)
                      : IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () async {
                            final url = report.fileUrl;
                            if (url == null) return;
                            await launchUrl(Uri.parse(url));
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final pagesAsync = await ref.read(notebookPagesProvider(projectId).future);
    if (!context.mounted) return;
    final selected = <String>{};
    bool isSaving = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create report',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Report title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pagesAsync.isEmpty)
                    const Text('No notebook pages available.')
                  else
                    SizedBox(
                      height: 240,
                      child: ListView(
                        children: pagesAsync.map((page) {
                          final checked = selected.contains(page.id);
                          return CheckboxListTile(
                            title: Text(page.title),
                            value: checked,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selected.add(page.id);
                                } else {
                                  selected.remove(page.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty ||
                                selected.isEmpty) {
                              return;
                            }
                            setState(() => isSaving = true);
                            final bytes = await _buildPdf(
                              titleController.text.trim(),
                              pagesAsync
                                  .where((p) => selected.contains(p.id))
                                  .toList(),
                            );
                            await ref.read(opsRepositoryProvider).createNotebookReport(
                                  title: titleController.text.trim(),
                                  projectId: projectId,
                                  pageIds: selected.toList(),
                                  pdfBytes: bytes,
                                );
                            if (context.mounted) Navigator.of(context).pop(true);
                          },
                    child: Text(isSaving ? 'Saving...' : 'Generate report'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    titleController.dispose();
    if (result == true) {
      ref.invalidate(notebookReportsProvider(projectId));
    }
  }

  Future<Uint8List> _buildPdf(String title, List<NotebookPage> pages) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(title, style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 12),
            ...pages.map(
              (page) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(page.title,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  if ((page.body ?? '').isNotEmpty) pw.Text(page.body!),
                  pw.SizedBox(height: 12),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return doc.save();
  }
}
