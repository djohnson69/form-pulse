import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class DrawingStroke {
  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  final List<Offset> points;
  final Color color;
  final double width;
}

class DrawingController extends ChangeNotifier {
  DrawingController({
    Color color = Colors.red,
    double strokeWidth = 4.0,
  })  : _color = color,
        _strokeWidth = strokeWidth;

  final List<DrawingStroke> _strokes = [];
  Color _color;
  double _strokeWidth;

  List<DrawingStroke> get strokes => List.unmodifiable(_strokes);
  Color get color => _color;
  double get strokeWidth => _strokeWidth;

  set color(Color value) {
    _color = value;
    notifyListeners();
  }

  set strokeWidth(double value) {
    _strokeWidth = value;
    notifyListeners();
  }

  void startStroke(Offset point) {
    _strokes.add(
      DrawingStroke(points: [point], color: _color, width: _strokeWidth),
    );
    notifyListeners();
  }

  void appendPoint(Offset point) {
    if (_strokes.isEmpty) {
      startStroke(point);
      return;
    }
    _strokes.last.points.add(point);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }
}

class DrawingBoard extends StatelessWidget {
  const DrawingBoard({
    super.key,
    required this.controller,
    this.backgroundColor,
  });

  final DrawingController controller;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => controller.startStroke(details.localPosition),
      onPanUpdate: (details) => controller.appendPoint(details.localPosition),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _DrawingPainter(
              strokes: controller.strokes,
              backgroundColor: backgroundColor,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({
    required this.strokes,
    this.backgroundColor,
  });

  final List<DrawingStroke> strokes;
  final Color? backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor!,
      );
    }
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
        continue;
      }

      for (var i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

Future<Uint8List> renderDrawingToPng({
  required Size size,
  required List<DrawingStroke> strokes,
  ui.Image? background,
  Color backgroundColor = Colors.white,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = backgroundColor;

  canvas.drawRect(Offset.zero & size, paint);
  if (background != null) {
    canvas.drawImage(background, Offset.zero, Paint());
  }

  for (final stroke in strokes) {
    final strokePaint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.width / 2, strokePaint);
      continue;
    }

    for (var i = 0; i < stroke.points.length - 1; i++) {
      canvas.drawLine(stroke.points[i], stroke.points[i + 1], strokePaint);
    }
  }

  final picture = recorder.endRecording();
  final width = math.max(1, size.width.round());
  final height = math.max(1, size.height.round());
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
