import 'package:flutter_test/flutter_test.dart';
import 'package:dementia_assist_app/main.dart';

void main() {
  testWidgets('App starts and shows chat screen', (WidgetTester tester) async {
    // Build the main app widget
    await tester.pumpWidget(const DementiaAssistApp());

    // Wait until rendering finishes
    await tester.pumpAndSettle();

    // Verify that the chat screen title appears
    expect(find.text('Chat with AI Assistant'), findsOneWidget);
  });
}
