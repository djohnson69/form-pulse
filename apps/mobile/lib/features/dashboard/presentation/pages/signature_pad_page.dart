import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/drawing_canvas.dart';

class SignatureResult {
  SignatureResult({
    required this.bytes,
    this.name,
  });

  final Uint8List bytes;
  final String? name;
}

class SignaturePadPage extends StatefulWidget {
  const SignaturePadPage({super.key, this.title});

  final String? title;

  @override
  State<SignaturePadPage> createState() => _SignaturePadPageState();
}

class _SignaturePadPageState extends State<SignaturePadPage> {
  final DrawingController _controller = DrawingController(color: Colors.black);
  final TextEditingController _nameController = TextEditingController();
  Size _canvasSize = const Size(300, 200);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final bytes = await renderDrawingToPng(
      size: _canvasSize,
      strokes: _controller.strokes,
      backgroundColor: Colors.white,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      SignatureResult(bytes: bytes, name: name.isEmpty ? null : name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Capture signature'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Signer name (optional)',
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width * 0.5;
                  _canvasSize = Size(width, height);
                  return Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DrawingBoard(
                      controller: _controller,
                      backgroundColor: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Draw your signature',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _controller.clear,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
