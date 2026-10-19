import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
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
    expect(find.textContaining('遥控访问网址: http://'), findsOneWidget);

    // Switch to WiFi transfer tab
    await tester.tap(find.text('WiFi 局域网传歌'));
    await tester.pumpAndSettle();

    expect(find.textContaining('传歌网址: http://'), findsOneWidget);
  });

  testWidgets('MacWebServiceView hides Git OTA update module on iPad and iPhone', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 768,
            child: MacWebServiceView(platform: HifiPlatformType.ipad),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 移动端无 Git 命令行环境，严禁显示系统在线 OTA 升级
    expect(find.textContaining('【系统在线 OTA 升级】'), findsNothing);
    expect(find.textContaining('当前设备: iPad 移动数播'), findsOneWidget);
  });

  testWidgets('MacWebServiceView shows Git OTA update module on Mac and Pi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 768,
            child: MacWebServiceView(platform: HifiPlatformType.mac),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 桌面端 Mac 与树莓派具备 Git 环境，正常呈现系统在线 OTA 升级
    expect(find.textContaining('【系统在线 OTA 升级】'), findsOneWidget);
    expect(find.textContaining('当前设备: macOS 桌面工作台'), findsOneWidget);
  });
}
