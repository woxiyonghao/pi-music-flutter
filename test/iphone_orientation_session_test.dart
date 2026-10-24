import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_main_view.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_landscape_view.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_portrait_view.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final orientationCalls = <List<String>>[];

  setUp(() {
    orientationCalls.clear();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientationCalls.add(List<String>.from(call.arguments as List));
      }
      return null;
    });
  });
  tearDown(() => binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('orientation choice is first frame while startup is pending',
      (tester) async {
    setSize(tester, const Size(390, 844));
    final startup = Completer<void>();
    await tester.pumpWidget(
        MaterialApp(home: IphoneMainView(initialize: () => startup.future)));
    expect(find.text('请选择显示操作模式'), findsOneWidget);
    expect(find.byType(IphonePortraitView), findsNothing);
    expect(find.byType(IphoneLandscapeView), findsNothing);
    await tester.tap(find.text('进入纯音系统'));
    await tester.pump();
    expect(find.text('正在启动播放器'), findsOneWidget);
    expect(orientationCalls.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight'
    ]);
    // Disposing while initialization is pending must not enter the main UI.
    await tester.pumpWidget(const SizedBox.shrink());
    startup.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'portrait choice stays locked through resume and resets on a new session',
      (tester) async {
    setSize(tester, const Size(390, 844));
    final startup = Completer<void>();
    await tester.pumpWidget(
        MaterialApp(home: IphoneMainView(initialize: () => startup.future)));
    await tester.tap(find.text('竖屏模式 (便携纯音流媒体)'));
    await tester.tap(find.text('进入纯音系统'));
    await tester.pump();
    expect(orientationCalls.last, ['DeviceOrientation.portraitUp']);
    final lockedCalls = orientationCalls.length;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('请选择显示操作模式'), findsNothing);
    expect(orientationCalls.length, lockedCalls);
    await tester.pumpWidget(const SizedBox.shrink());
    startup.complete();
    await tester.pump();
    final newStartup = Completer<void>();
    await tester.pumpWidget(
        MaterialApp(home: IphoneMainView(initialize: () => newStartup.future)));
    expect(find.text('请选择显示操作模式'), findsOneWidget);
    expect(
        orientationCalls.last,
        containsAll([
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight'
        ]));
    await tester.pumpWidget(const SizedBox.shrink());
    newStartup.complete();
    await tester.pump();
  });

  testWidgets('startup orientation dialog fits landscape and small phones',
      (tester) async {
    setSize(tester, const Size(667, 320));
    await tester.pumpWidget(const MaterialApp(home: IphoneMainView()));
    await tester.pump();
    expect(find.text('进入纯音系统'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
