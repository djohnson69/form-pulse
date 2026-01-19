import 'package:flutter/material.dart';
import '../../data/partners_repository.dart';
import 'messages_page.dart';

class ThreadDetailPage extends StatelessWidget {
  const ThreadDetailPage({required this.preview, super.key});

  final MessageThreadPreview preview;

  @override
  Widget build(BuildContext context) {
    return MessagesPage(
      initialThreadId: preview.thread.id,
      showOnlyThread: true,
    );
  }
}
