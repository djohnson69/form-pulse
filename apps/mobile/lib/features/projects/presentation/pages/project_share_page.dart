import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectSharePage extends StatefulWidget {
  const ProjectSharePage({super.key, required this.shareToken});

  final String shareToken;

  @override
  State<ProjectSharePage> createState() => _ProjectSharePageState();
}

class _ProjectSharePageState extends State<ProjectSharePage> {
  Project? _project;
  List<ProjectUpdate> _updates = const [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _updatesChannel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _updatesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    final response = await client.functions.invoke(
      'project-share',
      body: {'token': widget.shareToken},
    );
    if (response.status != 200) {
      setState(() {
        _loading = false;
        _error = 'Share lookup failed (${response.status}).';
      });
      return;
    }
    final data = _normalizeData(response.data);
    if (data == null) {
      setState(() {
        _loading = false;
        _error = 'No data returned.';
      });
      return;
    }
    final project = Project.fromJson(
      Map<String, dynamic>.from(data['project'] as Map),
    );
    final updates = (data['updates'] as List?)
            ?.map((row) => ProjectUpdate.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ))
            .toList() ??
        const <ProjectUpdate>[];
    setState(() {
      _project = project;
      _updates = updates;
      _loading = false;
    });
    _subscribeToUpdates(project.id);
  }

  void _subscribeToUpdates(String projectId) {
    _updatesChannel?.unsubscribe();
    final client = Supabase.instance.client;
    _updatesChannel = client.channel('shared-project-updates-$projectId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'project_updates',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'project_id',
          value: projectId,
        ),
        callback: (_) {
          if (!mounted) return;
          _load();
        },
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared Timeline')),
        body: Center(child: Text(_error!)),
      );
    }
    final project = _project;
    if (project == null) {
      return const Scaffold(
        body: Center(child: Text('Project not found.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if ((project.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(project.description!),
              ),
            if (_updates.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No shared updates yet.'),
                ),
              )
            else
              ..._updates.map(_buildUpdateCard),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard(ProjectUpdate update) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              update.title ?? _labelForType(update.type),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if ((update.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(update.body!),
            ],
            if (update.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: update.attachments
                    .map((att) => _buildAttachmentChip(att))
                    .toList(),
              ),
              const SizedBox(height: 6),
              ...update.attachments.map(_buildAttachmentMeta),
            ],
            const SizedBox(height: 8),
            Text(
              _formatDate(update.createdAt),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(MediaAttachment attachment) {
    final label = attachment.filename ?? attachment.type;
    return ActionChip(
      label: Text(label),
      avatar: Icon(_attachmentIcon(attachment)),
      onPressed: () => _openAttachment(attachment.url),
    );
  }

  IconData _attachmentIcon(MediaAttachment attachment) {
    final filename = attachment.filename?.toLowerCase() ?? '';
    if (attachment.type == 'photo' || filename.endsWith('.jpg') || filename.endsWith('.png')) {
      return Icons.photo;
    }
    if (attachment.type == 'video' || filename.endsWith('.mp4')) {
      return Icons.videocam;
    }
    if (attachment.type == 'audio' || filename.endsWith('.m4a')) {
      return Icons.audiotrack;
    }
    return Icons.attach_file;
  }

  Widget _buildAttachmentMeta(MediaAttachment attachment) {
    final details = <String>[];
    details.add('Captured ${_formatDateTime(attachment.capturedAt)}');
    if (attachment.type == 'signature') {
      details.add('Signature');
    }
    final location = attachment.location;
    if (location != null) {
      final coords =
          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
      details.add(location.address ?? coords);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        details.join(' • '),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'photo':
        return 'Photo update';
      case 'video':
        return 'Video update';
      case 'audio':
        return 'Voice note';
      case 'note':
        return 'Note';
      default:
        return 'Update';
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _normalizeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e, st) {
        developer.log('ProjectSharePage parse JSON metadata failed',
            error: e, stackTrace: st, name: 'ProjectSharePage._parseJson');
      }
    }
    return null;
  }
}
