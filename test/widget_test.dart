import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/main.dart';

void main() {
  testWidgets('HiFi Player App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HiFiPlayerApp());
    expect(find.byType(HiFiPlayerApp), findsOneWidget);
  });
}
