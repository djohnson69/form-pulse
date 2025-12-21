List<String> parseChecklistItems(String raw) {
  final lines = raw.split(RegExp(r'\r?\n'));
  final items = <String>[];
  final seen = <String>{};
  final bulletPattern = RegExp('^([\\-\\*]|\\u2022)\\s+');
  final numberPattern = RegExp(r'^\d+[\.|\)]\s*');

  for (final line in lines) {
    var cleaned = line.trim();
    if (cleaned.isEmpty) continue;
    cleaned = cleaned.replaceFirst(bulletPattern, '');
    cleaned = cleaned.replaceFirst(numberPattern, '');
    cleaned = cleaned.trim();
    if (cleaned.isEmpty) continue;
    final key = cleaned.toLowerCase();
    if (!seen.add(key)) continue;
    items.add(cleaned);
  }

  return items;
}
