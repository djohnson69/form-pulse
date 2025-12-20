import 'dart:convert';
import 'dart:io';

Future<String> loadBase64Image(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}
