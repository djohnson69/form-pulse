import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ai/ai_parsers.dart';

void main() {
  test('parseChecklistItems strips bullets and numbering', () {
    const raw = '- First item\n2) Second item\n3. Third item';
    final result = parseChecklistItems(raw);
    expect(result, ['First item', 'Second item', 'Third item']);
  });

  test('parseChecklistItems trims and deduplicates', () {
    const raw = '  Item A  \n- Item A\n* Item B\n\nItem B  ';
    final result = parseChecklistItems(raw);
    expect(result, ['Item A', 'Item B']);
  });
}
