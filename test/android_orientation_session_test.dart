import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/main.dart';
import 'package:hide_player_flutter/ui/android/android_player_view.dart';
import 'package:hide_player_flutter/ui/android/widgets/android_orientation_dialog.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<List<dynamic>> requests;

  setUp(() {
    requests = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requests.add(List<dynamic>.from(call.arguments as List));
        }
        return null;
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> enter(WidgetTester tester, {bool landscape = true}) async {
    if (!landscape) {
      await tester.tap(find.text('竖屏模式 (便携纯音流媒体)'));
      await tester.pump();
    }
    await tester.tap(find.text('进入纯音系统'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('first frame offers choice while initialization is pending',
      (tester) async {
    size(tester, const Size(393, 852));
    final pending = Completer<void>();
    var readyCalls = 0;
    await tester.pumpWidget(HiFiPlayerApp(
      initialize: () => pending.future,
      onReady: () => readyCalls++,
    ));
    expect(find.byType(AndroidOrientationDialog), findsOneWidget);
    expect(find.byType(AndroidPlayerView), findsNothing);
    expect(requests.first, ['DeviceOrientation.portraitUp']);
    await enter(tester);
    expect(requests.last, ['DeviceOrientation.landscapeLeft']);
    expect(find.text('正在启动播放器'), findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(readyCalls, 1);
    expect(
        tester
            .widget<AndroidPlayerView>(find.byType(AndroidPlayerView))
            .landscape,
        isTrue);
    // Even if Android ignores the physical rotation, the player must appear.
    expect(find.text('正在切换横屏'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('portrait choice survives resize and background/resume',
      (tester) async {
    size(tester, const Size(393, 852));
    await tester.pumpWidget(const HiFiPlayerApp());
    await enter(tester, landscape: false);
    expect(requests.last, ['DeviceOrientation.portraitUp']);
    final callCount = requests.length;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(852, 393);
    await tester.pump();
    expect(
        tester
            .widget<AndroidPlayerView>(find.byType(AndroidPlayerView))
            .landscape,
        isFalse);
    expect(find.byType(AndroidOrientationDialog), findsNothing);
    expect(requests.length, callCount);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const HiFiPlayerApp());
    expect(find.byType(AndroidOrientationDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('startup failure can retry without losing the chosen mode',
      (tester) async {
    size(tester, const Size(393, 852));
    var attempts = 0;
    var readyCalls = 0;
    await tester.pumpWidget(HiFiPlayerApp(
      initialize: () async {
        if (++attempts == 1) throw StateError('engine unavailable');
      },
      onReady: () => readyCalls++,
    ));
    await tester.pump();
    await enter(tester, landscape: false);
    expect(find.text('播放器启动失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(attempts, 2);
    expect(readyCalls, 1);
    expect(
        tester
            .widget<AndroidPlayerView>(find.byType(AndroidPlayerView))
            .landscape,
        isFalse);
    expect(requests.length, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed rotation shows a recoverable error', (tester) async {
    size(tester, const Size(393, 852));
    var fail = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requests.add(List<dynamic>.from(call.arguments as List));
          if (requests.length > 1 && fail) {
            throw PlatformException(code: 'rotation_failed');
          }
        }
        return null;
      },
    );
    await tester.pumpWidget(const HiFiPlayerApp());
    await enter(tester);
    expect(find.text('屏幕方向设置失败，请重试'), findsOneWidget);
    expect(find.byType(AndroidPlayerView), findsNothing);
    fail = false;
    await enter(tester);
    expect(find.byType(AndroidPlayerView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid confirmation only sends one rotation request',
      (tester) async {
    size(tester, const Size(393, 852));
    final rotation = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requests.add(List<dynamic>.from(call.arguments as List));
          if (requests.length > 1) await rotation.future;
        }
        return null;
      },
    );
    await tester.pumpWidget(const HiFiPlayerApp());
    await tester.tap(find.text('进入纯音系统'));
    await tester.tap(find.text('进入纯音系统'));
    await tester.pump();
    expect(requests.length, 2);
    rotation.complete();
    await tester.pump();
    expect(find.byType(AndroidPlayerView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
