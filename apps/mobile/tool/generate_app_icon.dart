import 'dart:io';

import 'package:image/image.dart' as img;

final _iconBackground = img.ColorRgb8(0x11, 0x18, 0x27);

Future<void> main() async {
  const inputPath = 'assets/branding/form_bridge_logo.png';
  const outputPath = 'assets/branding/app_icon.png';
  const foregroundPath = 'assets/branding/app_icon_foreground.png';

  const canvasSize = 1024;
  const targetWidthFraction = 0.78;

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Missing input logo at $inputPath');
    exitCode = 2;
    return;
  }

  final logoBytes = await inputFile.readAsBytes();
  final decoded = img.decodeImage(logoBytes);
  if (decoded == null) {
    stderr.writeln('Unable to decode PNG at $inputPath');
    exitCode = 3;
    return;
  }

  final trimmed = img.trim(decoded, mode: img.TrimMode.transparent);
  final targetWidth = (canvasSize * targetWidthFraction).round();
  final resized = img.copyResize(trimmed, width: targetWidth);

  final dstX = ((canvasSize - resized.width) / 2).round();
  final dstY = ((canvasSize - resized.height) / 2).round();

  final foreground = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.compositeImage(
    foreground,
    resized,
    dstX: dstX,
    dstY: dstY,
  );

  final background = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.fill(background, color: _iconBackground);
  img.compositeImage(
    background,
    resized,
    dstX: dstX,
    dstY: dstY,
  );

  await File(foregroundPath).writeAsBytes(img.encodePng(foreground));
  await File(outputPath).writeAsBytes(img.encodePng(background));

  stdout.writeln('Wrote $outputPath');
  stdout.writeln('Wrote $foregroundPath');
}
