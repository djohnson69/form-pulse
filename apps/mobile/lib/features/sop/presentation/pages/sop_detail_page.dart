import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/sop_provider.dart';
import 'sop_editor_page.dart';

class SopDetailPage extends ConsumerWidget {
  const SopDetailPage({required this.document, super.key});

  final SopDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(sopVersionsProvider(document.id));
    final approvalsAsync = ref.watch(sopApprovalsProvider(document.id));
    final acknowledgementsAsync =
        ref.watch(sopAcknowledgementsProvider(document.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final versions = await ref.read(
                sopVersionsProvider(document.id).future,
              );
              final latest = versions.isEmpty ? null : versions.first;
              if (!context.mounted) return;
              final result = await navigator.push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      SopEditorPage(document: document, initialVersion: latest),
                ),
              );
              if (result == true) {
                ref.invalidate(sopDocumentsProvider);
                ref.invalidate(sopVersionsProvider(document.id));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(document: document),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Versions'),
          versionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _InlineError(error: e.toString()),
            data: (versions) {
              if (versions.isEmpty) {
                return const _EmptySection(text: 'No versions yet.');
              }
              return Column(
                children: versions
                    .map((version) => _VersionCard(version: version))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Approvals'),
          approvalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _InlineError(error: e.toString()),
            data: (approvals) {
              if (approvals.isEmpty) {
                return const _EmptySection(
                  text: 'No approvals yet. Request approval to publish.',
                );
              }
              return Column(
                children: approvals
                    .map((approval) => _ApprovalCard(approval: approval))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Acknowledgements'),
          acknowledgementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _InlineError(error: e.toString()),
            data: (acks) {
              if (acks.isEmpty) {
                return const _EmptySection(
                  text: 'No acknowledgements yet.',
                );
              }
              return Column(
                children: acks
                    .map(
                      (ack) => ListTile(
                        leading: const Icon(Icons.verified),
                        title: Text('User ${ack.userId ?? 'unknown'}'),
                        subtitle: Text(_formatDate(ack.acknowledgedAt)),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _ActionRow(document: document),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.document});

  final SopDocument document;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.title, style: Theme.of(context).textTheme.titleLarge),
            if ((document.summary ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(document.summary!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: 'Status', value: document.status),
                if ((document.category ?? '').isNotEmpty)
                  _InfoChip(label: 'Category', value: document.category!),
                if ((document.currentVersion ?? '').isNotEmpty)
                  _InfoChip(
                    label: 'Current',
                    value: document.currentVersion!,
                  ),
              ],
            ),
            if (document.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: document.tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.document});

  final SopDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final versions = await ref.read(
              sopVersionsProvider(document.id).future,
            );
            final latest = versions.isEmpty ? null : versions.first;
            if (!context.mounted) return;
            final result = await navigator.push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    SopEditorPage(document: document, initialVersion: latest),
              ),
            );
            if (result == true) {
              ref.invalidate(sopDocumentsProvider);
              ref.invalidate(sopVersionsProvider(document.id));
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('New version'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final repo = ref.read(sopRepositoryProvider);
            final versions = await ref.read(
              sopVersionsProvider(document.id).future,
            );
            final versionId = versions.isNotEmpty ? versions.first.id : null;
            await repo.requestApproval(document: document, versionId: versionId);
            ref.invalidate(sopApprovalsProvider(document.id));
            ref.invalidate(sopDocumentsProvider);
          },
          icon: const Icon(Icons.approval),
          label: const Text('Request approval'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final repo = ref.read(sopRepositoryProvider);
            await repo.acknowledge(
              document: document,
              versionId: document.currentVersionId,
            );
            ref.invalidate(sopAcknowledgementsProvider(document.id));
          },
          icon: const Icon(Icons.verified_user),
          label: const Text('Acknowledge'),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.version});

  final SopVersion version;

  @override
  Widget build(BuildContext context) {
    final body = version.body ?? '';
    final snippet =
        body.length > 160 ? '${body.substring(0, 160)}...' : body;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text('Version ${version.version}'),
        subtitle: Text('${_formatDate(version.createdAt)} • $snippet'),
      ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({required this.approval});

  final SopApproval approval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = approval.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          approval.status == 'approved' ? Icons.check_circle : Icons.pending,
          color: approval.status == 'approved'
              ? Colors.green
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text('Status: ${approval.status}'),
        subtitle: Text(_formatDate(approval.requestedAt)),
        trailing: isPending
            ? Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      await ref.read(sopRepositoryProvider).updateApprovalStatus(
                            approval: approval,
                            status: 'approved',
                          );
                      ref.invalidate(sopApprovalsProvider(approval.sopId));
                      ref.invalidate(sopDocumentsProvider);
                    },
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(sopRepositoryProvider).updateApprovalStatus(
                            approval: approval,
                            status: 'rejected',
                          );
                      ref.invalidate(sopApprovalsProvider(approval.sopId));
                    },
                    child: const Text('Reject'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label • $value'));
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(error),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}
