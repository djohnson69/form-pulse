import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ai/ai_assist_sheet.dart';
import '../../../../core/utils/csv_utils.dart';
import '../../../../core/utils/submission_utils.dart';
import '../../../ops/data/ops_provider.dart';
import '../../../ops/data/ops_repository.dart';
import '../../data/dashboard_provider.dart';
import 'reports_page.dart';

class SubmissionDetailPage extends ConsumerStatefulWidget {
  const SubmissionDetailPage({required this.submission, super.key});

  final FormSubmission submission;

  @override
  ConsumerState<SubmissionDetailPage> createState() =>
      _SubmissionDetailPageState();
}

class _SubmissionDetailPageState
    extends ConsumerState<SubmissionDetailPage> {
  late FormSubmission _submission;
  bool _updatingStatus = false;
  String? _aiSummary;

  @override
  void initState() {
    super.initState();
    _submission = widget.submission;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _exportCsv(),
                icon: const Icon(Icons.file_download),
                label: const Text('CSV'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportCsv(label: 'Excel'),
                icon: const Icon(Icons.grid_on),
                label: const Text('Excel'),
              ),
              OutlinedButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: _openAiSummary,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI'),
              ),
              OutlinedButton.icon(
                onPressed: _openSubmitterActivity,
                icon: const Icon(Icons.person_search),
                label: const Text('Submitter activity'),
              ),
              if (_submission.location != null)
                OutlinedButton.icon(
                  onPressed: _openLocationActivity,
                  icon: const Icon(Icons.location_searching),
                  label: const Text('Location activity'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description),
              title: Text(_submission.formTitle),
              subtitle:
                  Text('Status: ${_submission.status.displayName}'),
            ),
          ),
          const SizedBox(height: 8),
          _ApprovalCard(
            status: _submission.status,
            busy: _updatingStatus,
            onApprove: () => _updateStatus(SubmissionStatus.approved),
            onReject: () => _updateStatus(SubmissionStatus.rejected),
            onRequestChanges: () =>
                _updateStatus(SubmissionStatus.requiresChanges),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(
                _submission.submittedByName ?? _submission.submittedBy,
              ),
              subtitle: Text(
                'Submitted at ${_submission.submittedAt.toLocal()}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SubmissionMetaCard(submission: _submission),
          const SizedBox(height: 12),
          Text('Fields', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._submission.data.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.checklist_rtl),
              title: Text(entry.key),
              subtitle: Text(entry.value.toString()),
            ),
          ),
          const SizedBox(height: 12),
          if (_submission.attachments?.isNotEmpty ?? false) ...[
            Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _AttachmentCarousel(attachments: _submission.attachments!),
            const SizedBox(height: 12),
          ],
          if (_aiSummary != null && _aiSummary!.isNotEmpty) ...[
            Text('AI Summary', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_aiSummary!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_submission.location != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                  '${_submission.location!.latitude}, ${_submission.location!.longitude}',
                ),
                subtitle: const Text('GPS tag • tap to open map'),
                onTap: () async {
                  final lat = _submission.location!.latitude;
                  final lng = _submission.location!.longitude;
                  final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportCsv({String label = 'CSV'}) async {
    final csv = buildSubmissionCsv(_submission);
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: 'formbridge_submission_${_submission.id}.csv',
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Form Bridge $label export',
          files: [file],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: csv));
    }
  }

  Future<void> _share(BuildContext context) async {
    final summary = StringBuffer()
      ..writeln('Submission: ${_submission.formTitle}')
      ..writeln(
        'Submitted by: ${_submission.submittedByName ?? _submission.submittedBy}',
      )
      ..writeln('Status: ${_submission.status.displayName}');
    await SharePlus.instance.share(ShareParams(text: summary.toString()));
  }

  Future<void> _openAiSummary() async {
    final result = await showModalBottomSheet<AiAssistResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiAssistSheet(
        title: 'AI Summary',
        initialText: _buildAiInput(_submission),
        initialType: 'summary',
        allowImage: false,
        allowAudio: false,
      ),
    );
    if (result == null) return;
    final output = result.outputText.trim();
    if (output.isEmpty) return;
    setState(() => _aiSummary = output);
    await _recordAiUsage(result);
  }

  Future<void> _openSubmitterActivity() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsPage(
          initialSubmittedBy: _submission.submittedBy,
        ),
      ),
    );
  }

  Future<void> _openLocationActivity() async {
    final location = _submission.location;
    if (location == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsPage(
          initialHasLocation: true,
          initialLat: location.latitude,
          initialLng: location.longitude,
          initialRadiusKm: 1.0,
        ),
      ),
    );
  }

  String _buildAiInput(FormSubmission submission) {
    final buffer = StringBuffer()
      ..writeln('Form: ${submission.formTitle}')
      ..writeln(
        'Submitted by: ${submission.submittedByName ?? submission.submittedBy}',
      )
      ..writeln('Status: ${submission.status.displayName}')
      ..writeln('Submitted at: ${submission.submittedAt.toLocal()}')
      ..writeln('Fields:');
    submission.data.forEach((key, value) {
      buffer.writeln('- $key: $value');
    });
    if (submission.location != null) {
      buffer.writeln(
        'Location: ${submission.location!.latitude}, ${submission.location!.longitude}',
      );
    }
    if (submission.attachments?.isNotEmpty ?? false) {
      buffer.writeln(
        'Attachments: ${submission.attachments!.length} items',
      );
    }
    return buffer.toString();
  }

  Future<void> _recordAiUsage(AiAssistResult result) async {
    try {
      final attachments = <AttachmentDraft>[];
      if (result.imageBytes != null) {
        attachments.add(
          AttachmentDraft(
            type: 'photo',
            bytes: result.imageBytes!,
            filename: result.imageName ?? 'ai-image',
            mimeType: result.imageMimeType ?? 'image/jpeg',
          ),
        );
      }
      if (result.audioBytes != null) {
        attachments.add(
          AttachmentDraft(
            type: 'audio',
            bytes: result.audioBytes!,
            filename: result.audioName ?? 'ai-audio',
            mimeType: result.audioMimeType ?? 'audio/m4a',
          ),
        );
      }
      await ref.read(opsRepositoryProvider).createAiJob(
            type: result.type,
            inputText: result.inputText.isEmpty ? null : result.inputText,
            outputText: result.outputText,
            inputMedia: attachments,
            metadata: {
              'source': 'submission_detail',
              'submissionId': _submission.id,
              'formId': _submission.formId,
              if (result.targetLanguage != null &&
                  result.targetLanguage!.isNotEmpty)
                'targetLanguage': result.targetLanguage,
              if (result.checklistCount != null)
                'checklistCount': result.checklistCount,
            },
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI log failed: $e')),
      );
    }
  }

  Future<void> _updateStatus(SubmissionStatus status) async {
    if (_updatingStatus) return;
    final note = await _promptForNote(status);
    setState(() => _updatingStatus = true);
    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final updated = await repo.updateSubmissionStatus(
        submissionId: _submission.id,
        status: status,
        note: note,
      );
      if (!mounted) return;
      setState(() => _submission = updated);
      ref.invalidate(dashboardDataProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as ${status.displayName}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<String?> _promptForNote(SubmissionStatus status) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add note (${status.displayName})'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional reviewer note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }
}

class _SubmissionMetaCard extends StatelessWidget {
  const _SubmissionMetaCard({required this.submission});

  final FormSubmission submission;

  @override
  Widget build(BuildContext context) {
    final inputTypes = resolveSubmissionInputTypes(submission)
        .map(submissionInputTypeLabel)
        .toList();
    final accessLevel =
        submissionAccessLevelLabel(resolveSubmissionAccessLevel(submission));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...inputTypes.map(
                  (label) => Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.lock_outline, size: 16),
                  label: Text(accessLevel),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.status,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onRequestChanges,
  });

  final SubmissionStatus status;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRequestChanges;

  @override
  Widget build(BuildContext context) {
    final isFinal = status.isFinal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approval', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy || isFinal ? null : onApprove,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || isFinal ? null : onRequestChanges,
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Request changes'),
                ),
                TextButton.icon(
                  onPressed: busy || isFinal ? null : onReject,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentCarousel extends StatefulWidget {
  const _AttachmentCarousel({required this.attachments});

  final List<MediaAttachment> attachments;

  @override
  State<_AttachmentCarousel> createState() => _AttachmentCarouselState();
}

class _AttachmentCarouselState extends State<_AttachmentCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.attachments;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final att = items[i];
              final isVideo =
                  att.type == 'video' ||
                  (att.filename?.toLowerCase().endsWith('.mp4') ?? false);
              final isPdf =
                  att.filename?.toLowerCase().endsWith('.pdf') ?? false;
              final isAudio = att.type == 'audio' ||
                  (att.filename?.toLowerCase().endsWith('.m4a') ?? false) ||
                  (att.filename?.toLowerCase().endsWith('.aac') ?? false) ||
                  (att.filename?.toLowerCase().endsWith('.mp3') ?? false) ||
                  (att.filename?.toLowerCase().endsWith('.wav') ?? false);
              final isSignature = att.type == 'signature';
              final icon = isVideo
                  ? Icons.videocam
                  : isPdf
                  ? Icons.picture_as_pdf
                  : isAudio
                  ? Icons.audiotrack
                  : isSignature
                  ? Icons.border_color
                  : Icons.photo;
              final previewable =
                  (att.type == 'photo' || isSignature) &&
                  att.url.isNotEmpty &&
                  !isPdf &&
                  !isVideo;
              return Card(
                child: InkWell(
                  onTap: () async {
                    if (previewable) {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Image.network(att.url, fit: BoxFit.cover),
                        ),
                      );
                    } else if (isVideo || isPdf || isAudio) {
                      final uri = Uri.parse(att.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (previewable)
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(att.url, fit: BoxFit.cover),
                          ),
                        )
                      else
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: Center(child: Icon(icon, size: 48)),
                                ),
                              ),
                              if (isVideo)
                                const Center(
                                  child: Icon(Icons.play_circle_fill, size: 56),
                                ),
                            ],
                          ),
                        ),
                      ListTile(
                        dense: true,
                        leading: Icon(icon),
                        title: Text(
                          att.filename ?? att.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(att.type),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            items.length,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _index
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
