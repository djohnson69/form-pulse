import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SubmissionDetailPage extends StatelessWidget {
  const SubmissionDetailPage({required this.submission, super.key});

  final FormSubmission submission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _export('csv'),
                icon: const Icon(Icons.file_download),
                label: const Text('CSV'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _export('pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description),
              title: Text(submission.formTitle),
              subtitle: Text('Status: ${submission.status.displayName}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(submission.submittedByName ?? submission.submittedBy),
              subtitle: Text(
                'Submitted at ${submission.submittedAt.toLocal()}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Fields', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...submission.data.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.checklist_rtl),
              title: Text(entry.key),
              subtitle: Text(entry.value.toString()),
            ),
          ),
          const SizedBox(height: 12),
          if (submission.attachments?.isNotEmpty ?? false) ...[
            Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _AttachmentCarousel(attachments: submission.attachments!),
            const SizedBox(height: 12),
          ],
          if (submission.location != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                  '${submission.location!.latitude}, ${submission.location!.longitude}',
                ),
                subtitle: const Text('GPS tag • tap to open map'),
                onTap: () async {
                  final lat = submission.location!.latitude;
                  final lng = submission.location!.longitude;
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

  void _export(String type) async {
    final base = ApiConstants.baseUrlDev;
    final uri = Uri.parse('$base/api/submissions/export.$type');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share(BuildContext context) async {
    final csv = Uri.parse(
      '${ApiConstants.baseUrlDev}/api/submissions/export.csv',
    ).toString();
    final pdf = Uri.parse(
      '${ApiConstants.baseUrlDev}/api/submissions/export.pdf',
    ).toString();
    final summary = StringBuffer()
      ..writeln('Submission: ${submission.formTitle}')
      ..writeln(
        'Submitted by: ${submission.submittedByName ?? submission.submittedBy}',
      )
      ..writeln('Status: ${submission.status.displayName}')
      ..writeln('CSV: $csv')
      ..writeln('PDF: $pdf');
    await Share.share(summary.toString());
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
              final icon = isVideo
                  ? Icons.videocam
                  : isPdf
                  ? Icons.picture_as_pdf
                  : Icons.photo;
              final previewable =
                  att.type == 'photo' &&
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
                    } else if (isVideo || isPdf) {
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
