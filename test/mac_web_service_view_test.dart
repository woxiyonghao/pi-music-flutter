import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_web_service_view.dart';

void main() {
  testWidgets('MacWebServiceView renders without RenderFlex overflow on narrow window',
      (WidgetTester tester) async {
    // Standard compact window size where overflow previously occurred
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: MacWebServiceView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Submodule pills
    expect(find.text('Web 服务'), findsOneWidget);
    expect(find.text('Web 远程控制'), findsOneWidget);
    expect(find.text('WiFi 局域网传歌'), findsOneWidget);

    // Verify Web Remote Control tab elements
    expect(find.text('遥控访问网址: http://192.168.0.100:8088'), findsOneWidget);

    // Switch to WiFi transfer tab
    await tester.tap(find.text('WiFi 局域网传歌'));
    await tester.pumpAndSettle();

    expect(find.text('传歌网址: http://192.168.0.100:8080'), findsOneWidget);
  });
}
