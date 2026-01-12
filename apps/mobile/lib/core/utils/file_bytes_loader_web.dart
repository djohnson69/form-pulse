import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> loadFileBytes(String path) async {
  if (path.isEmpty) return null;
  try {
    if (path.startsWith('data:')) {
      return _decodeDataUrl(path);
    }
    final response = await html.HttpRequest.request(
      path,
      responseType: 'arraybuffer',
    );
    final buffer = response.response;
    if (buffer is ByteBuffer) {
      return Uint8List.view(buffer);
    }
  } catch (_) {
    return null;
  }
  return null;
}

Uint8List? _decodeDataUrl(String url) {
  final commaIndex = url.indexOf(',');
  if (commaIndex == -1) return null;
  final meta = url.substring(0, commaIndex);
  final data = url.substring(commaIndex + 1);
  if (meta.contains('base64')) {
    return base64Decode(data);
  }
  return Uint8List.fromList(utf8.encode(Uri.decodeFull(data)));
}
