import 'package:flutter_test/flutter_test.dart';

import 'package:trading_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TradingApp());

    // Verify that our welcome message is present.
    expect(find.text('Welcome to Hutzels Trading Frontend App'), findsOneWidget);
    
    // Verify that the connect button is present.
    expect(find.text('Connect to Backend'), findsOneWidget);
  });
}
