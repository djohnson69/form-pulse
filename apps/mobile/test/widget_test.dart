// Basic Flutter widget smoke test for Form Bridge

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FormBridgeApp()));

    // Verify that login page loads
    expect(find.text('Form Bridge'), findsOneWidget);
  });
}
