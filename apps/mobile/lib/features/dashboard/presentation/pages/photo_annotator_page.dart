import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../widgets/drawing_canvas.dart';

class PhotoAnnotatorPage extends StatefulWidget {
  const PhotoAnnotatorPage({
    super.key,
    required this.imageBytes,
    this.title,
  });

  final Uint8List imageBytes;
  final String? title;

  @override
  State<PhotoAnnotatorPage> createState() => _PhotoAnnotatorPageState();
}

class _PhotoAnnotatorPageState extends State<PhotoAnnotatorPage> {
  final DrawingController _controller = DrawingController();
  ui.Image? _image;
  Size _canvasSize = Size.zero;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadImage() {
    ui.decodeImageFromList(widget.imageBytes, (image) {
      if (!mounted) return;
      setState(() => _image = image);
    });
  }

  Future<void> _save() async {
    if (_image == null || _controller.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one annotation')),
      );
      return;
    }
    setState(() => _saving = true);

    final image = _image!;
    final imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final canvasSize = _canvasSize.width > 0 && _canvasSize.height > 0
        ? _canvasSize
        : imageSize;
    final scaleX = imageSize.width / canvasSize.width;
    final scaleY = imageSize.height / canvasSize.height;

    final scaledStrokes = _controller.strokes.map((stroke) {
      final points = stroke.points
          .map((p) => Offset(p.dx * scaleX, p.dy * scaleY))
          .toList();
      return DrawingStroke(
        points: points,
        color: stroke.color,
        width: stroke.width * scaleX,
      );
    }).toList();

    final bytes = await renderDrawingToPng(
      size: imageSize,
      strokes: scaledStrokes,
      background: image,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, bytes);
  }

  void _setColor(Color color) {
    setState(() => _controller.color = color);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Annotate photo'),
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
        child: image == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ratio = image.width / image.height;
                        var width = constraints.maxWidth;
                        var height = width / ratio;
                        if (height > constraints.maxHeight) {
                          height = constraints.maxHeight;
                          width = height * ratio;
                        }
                        _canvasSize = Size(width, height);
                        return Center(
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(widget.imageBytes, fit: BoxFit.cover),
                                DrawingBoard(controller: _controller),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Text('Color'),
                        const SizedBox(width: 8),
                        _ColorDot(
                          color: Colors.red,
                          selected: _controller.color == Colors.red,
                          onTap: () => _setColor(Colors.red),
                        ),
                        _ColorDot(
                          color: Colors.yellow,
                          selected: _controller.color == Colors.yellow,
                          onTap: () => _setColor(Colors.yellow),
                        ),
                        _ColorDot(
                          color: Colors.blue,
                          selected: _controller.color == Colors.blue,
                          onTap: () => _setColor(Colors.blue),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _controller.clear,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
