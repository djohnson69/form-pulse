import 'dart:convert';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/ai/ai_job_runner.dart';
import '../../../../core/ai/ai_providers.dart';
import '../../../../core/utils/file_bytes_loader.dart';
import '../../data/ops_provider.dart';
import '../../data/ops_repository.dart';

const _aiPurple500 = Color(0xFFA855F7);
const _aiPurple600 = Color(0xFF9333EA);
const _aiPurple400 = Color(0xFFC084FC);

class AiToolsPage extends ConsumerStatefulWidget {
  const AiToolsPage({super.key});

  static const int _maxAiMediaBytes = 8 * 1024 * 1024;

  @override
  ConsumerState<AiToolsPage> createState() => _AiToolsPageState();
}

class _AiToolsPageState extends ConsumerState<AiToolsPage> {
  final TextEditingController _inputController = TextEditingController();
  final List<_AiAttachment> _attachments = [];
  String _activeTab = _aiTabs.first.id;
  String _output = '';
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 1024;
          final isMedium = constraints.maxWidth >= 768;
          final horizontalPadding = isMedium ? 24.0 : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              32,
            ),
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildTabs(context),
              const SizedBox(height: 16),
              if (isLarge)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildInputCard(context)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildOutputCard(context)),
                  ],
                )
              else ...[
                _buildInputCard(context),
                const SizedBox(height: 16),
                _buildOutputCard(context),
              ],
              const SizedBox(height: 16),
              _buildFeaturesGrid(context, isWide: isMedium),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 28, color: _aiPurple500),
            const SizedBox(width: 10),
            Text(
              'AI-Powered Tools',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Generate reports, captions, translations, and summaries using artificial intelligence',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }


  Widget _buildTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final inactive = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _aiTabs.map((tab) {
          final selected = tab.id == _activeTab;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _activeTab = tab.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _aiPurple600 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 16,
                    color: selected ? Colors.white : inactive,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : inactive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final helperColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final dashedColor = isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: _aiPurple500),
                const SizedBox(width: 8),
                Text(
                  'Input Data',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Photos, Videos, or Enter Notes',
              style: theme.textTheme.labelLarge?.copyWith(color: labelColor),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickFiles,
              child: _DashedBorder(
                color: dashedColor,
                radius: 12,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 44,
                        color: helperColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click to upload or drag and drop',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: helperColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Photos, videos, PDFs, or documents',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: helperColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_attachments.length, (index) {
                  final attachment = _attachments[index];
                  return Chip(
                    label: Text(attachment.name),
                    onDeleted: () => _removeAttachment(index),
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Voice Notes or Text Input',
              style: theme.textTheme.labelLarge?.copyWith(color: labelColor),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Add voice notes, descriptions, or context...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: helperColor,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _aiPurple500),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAiContent,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating ? 'Generating with AI...' : 'Generate AI Content',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: _aiPurple600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _aiPurple400,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final helperColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final outputTextColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    final cardBackground = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: _aiPurple500),
                const SizedBox(width: 8),
                Text(
                  'AI-Generated Output',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_output.isNotEmpty)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 500),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _output,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: outputTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _copyOutput(context),
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFF3F4F6),
                            foregroundColor: isDark
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Copy to Clipboard'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _exportOutput(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _aiPurple600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save & Export'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI-generated content will appear here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: helperColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload files or add notes, then click Generate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: helperColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context, {required bool isWide}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2937) : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final bodyColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isWide ? 3 : 1,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isWide ? 2.6 : 3.0,
      children: _features.map((feature) {
        return Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(feature.icon, color: _aiPurple500),
              const SizedBox(height: 8),
              Text(
                feature.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                feature.description,
                style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }


  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final errors = <String>[];
    final newAttachments = <_AiAttachment>[];

    for (final file in result.files) {
      final bytes = file.bytes ??
          (file.path != null ? await loadFileBytes(file.path!) : null);
      if (bytes == null) {
        errors.add('Unable to read ${file.name}.');
        continue;
      }
      if (bytes.length > AiToolsPage._maxAiMediaBytes) {
        errors.add('${file.name} exceeds 8MB.');
        continue;
      }
      final mimeType = file.extension == null
          ? 'application/octet-stream'
          : _guessMimeType('.${file.extension}') ?? 'application/octet-stream';
      newAttachments.add(
        _AiAttachment(
          name: file.name,
          bytes: bytes,
          mimeType: mimeType,
        ),
      );
    }

    if (newAttachments.isNotEmpty) {
      setState(() => _attachments.addAll(newAttachments));
    }

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join(' '))),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _generateAiContent() async {
    final runner = _resolveAiService(ref);
    if (runner == null) {
      _showMessage('AI service unavailable. Check your configuration.');
      return;
    }

    final tab = _aiTabs.firstWhere((tab) => tab.id == _activeTab);
    final input = _inputController.text.trim();
    final image = _attachments.firstWhere(
      (attachment) => attachment.mimeType.startsWith('image/'),
      orElse: () => _AiAttachment.empty(),
    );
    final audio = _attachments.firstWhere(
      (attachment) => attachment.mimeType.startsWith('audio/'),
      orElse: () => _AiAttachment.empty(),
    );

    setState(() {
      _isGenerating = true;
      _output = '';
    });

    try {
      final output = await runner.runJob(
        type: tab.jobType,
        inputText: input.isEmpty ? null : input,
        imageBytes: image.bytes.isEmpty ? null : image.bytes,
        audioBytes: audio.bytes.isEmpty ? null : audio.bytes,
        audioMimeType: audio.bytes.isEmpty ? null : audio.mimeType,
        targetLanguage: tab.jobType == 'translation' ? 'Spanish' : null,
        checklistCount: tab.jobType == 'checklist_builder' ? 8 : null,
      );

      await ref.read(opsRepositoryProvider).createAiJob(
            type: tab.jobType,
            inputText: input.isEmpty ? null : input,
            outputText: output,
            inputMedia: _attachments
                .map(
                  (attachment) => AttachmentDraft(
                    type: _attachmentType(attachment.mimeType),
                    bytes: attachment.bytes,
                    filename: attachment.name,
                    mimeType: attachment.mimeType,
                    metadata: {'source': 'ai_tools'},
                  ),
                )
                .toList(),
            metadata: {
              'source': 'ai_tools',
              'tab': tab.id,
            },
          );

      if (!mounted) return;
      setState(() {
        _output = output;
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _copyOutput(BuildContext context) async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    _showMessage('Output copied to clipboard.');
  }

  Future<void> _exportOutput(BuildContext context) async {
    if (_output.isEmpty) return;
    try {
      final bytes = Uint8List.fromList(utf8.encode(_output));
      final filename = 'ai-output-${DateTime.now().toIso8601String()}.txt';
      await ref.read(opsRepositoryProvider).createExportJobWithFile(
            type: 'ai_output',
            format: 'txt',
            filename: filename,
            bytes: bytes,
            metadata: {
              'source': 'ai_tools',
              'tab': _activeTab,
            },
          );
      _showMessage('Export ready in Exports.');
    } catch (error) {
      _showMessage('Failed to export: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  AiJobRunner? _resolveAiService(WidgetRef ref) {
    try {
      return ref.read(aiJobRunnerProvider);
    } catch (e, st) {
      developer.log('AiToolsPage get AI runner failed',
          error: e, stackTrace: st, name: 'AiToolsPage._getAiRunner');
      return null;
    }
  }
}

class _AiAttachment {
  const _AiAttachment({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  factory _AiAttachment.empty() => _AiAttachment(
        name: '',
        bytes: Uint8List(0),
        mimeType: '',
      );
}

class _AiTab {
  const _AiTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.jobType,
  });

  final String id;
  final String label;
  final IconData icon;
  final String jobType;
}

class _AiFeature {
  const _AiFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _aiTabs = [
  _AiTab(
    id: 'reports',
    label: 'Field Reports',
    icon: Icons.description_outlined,
    jobType: 'field_report',
  ),
  _AiTab(
    id: 'captions',
    label: 'Photo Captions',
    icon: Icons.photo_camera_outlined,
    jobType: 'photo_caption',
  ),
  _AiTab(
    id: 'translate',
    label: 'Translation',
    icon: Icons.translate,
    jobType: 'translation',
  ),
  _AiTab(
    id: 'checklists',
    label: 'Checklists',
    icon: Icons.checklist_outlined,
    jobType: 'checklist_builder',
  ),
  _AiTab(
    id: 'summaries',
    label: 'Progress Summary',
    icon: Icons.trending_up,
    jobType: 'progress_recap',
  ),
];

const _features = [
  _AiFeature(
    icon: Icons.description_outlined,
    title: 'Smart Reports',
    description: 'Generate detailed field reports from photos and notes',
  ),
  _AiFeature(
    icon: Icons.photo_camera_outlined,
    title: 'Auto Captions',
    description: 'AI analyzes photos and creates descriptive captions',
  ),
  _AiFeature(
    icon: Icons.translate,
    title: 'Multi-Language',
    description: 'Translate reports into 50+ languages instantly',
  ),
  _AiFeature(
    icon: Icons.checklist_outlined,
    title: 'Checklist Builder',
    description: 'AI creates custom checklists based on project type',
  ),
  _AiFeature(
    icon: Icons.trending_up,
    title: 'Progress Analytics',
    description: 'Automated summaries with insights and predictions',
  ),
  _AiFeature(
    icon: Icons.auto_awesome,
    title: 'Daily Logs',
    description: 'AI compiles daily activities into formatted logs',
  ),
];

String _attachmentType(String mimeType) {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType.startsWith('audio/')) return 'audio';
  if (mimeType.startsWith('video/')) return 'video';
  return 'file';
}

String? _guessMimeType(String filename) {
  final ext = p.extension(filename).toLowerCase();
  switch (ext) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.heic':
      return 'image/heic';
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.m4a':
      return 'audio/m4a';
    case '.mp3':
      return 'audio/mpeg';
    case '.wav':
      return 'audio/wav';
    case '.ogg':
      return 'audio/ogg';
    default:
      return null;
  }
}

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = dashWidth;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
