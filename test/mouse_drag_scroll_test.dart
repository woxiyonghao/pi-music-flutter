import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/theme/ui_config.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_scan_music_view.dart';

void main() {
  final scanTracks = List<Track>.generate(
    6,
    (index) => Track(
      id: 201 + index,
      title: '鼠标拖动曲目 ${index + 1}',
      artist: '测试音乐家',
      album: '横向滚动测试',
      filepath: '/Music/mouse-scroll-${index + 1}.dsf',
      format: AudioFormat.dsdDsf,
      sampleRate: 5644800,
      bitDepth: 1,
      durationSec: 180,
    ),
  );
  late List<Track> previousTracks;
  setUp(() {
    final library = MusicDatabaseService.instance;
    previousTracks = List<Track>.of(library.tracks);
    library.tracks
      ..clear()
      ..addAll(scanTracks);
  });

  tearDown(() {
    HifiAudioService.instance
      ..pause()
      ..stopTicker();
    MusicDatabaseService.instance.tracks
      ..clear()
      ..addAll(previousTracks);
  });

  testWidgets(
      'Default ScrollBehavior fails on mouse drag, MouseDraggableScrollBehavior succeeds',
      (WidgetTester tester) async {
    final defaultController = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ListView.builder(
              controller: defaultController,
              scrollDirection: Axis.horizontal,
              itemCount: 20,
              itemBuilder: (context, i) => Container(
                width: 150,
                color: Colors.blue,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      ),
    );

    // Try dragging with mouse on default MaterialApp
    final gestureDefault = await tester.startGesture(
      const Offset(200, 100),
      kind: PointerDeviceKind.mouse,
    );
    await gestureDefault.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gestureDefault.up();
    await tester.pump();

    // Default Flutter ignores mouse drag!
    expect(defaultController.offset, 0.0);

    // Now test with MouseDraggableScrollBehavior from UIConfig
    final customController = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const MouseDraggableScrollBehavior(),
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ListView.builder(
              controller: customController,
              scrollDirection: Axis.horizontal,
              itemCount: 20,
              itemBuilder: (context, i) => Container(
                width: 150,
                color: Colors.blue,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      ),
    );

    // Try dragging with mouse with MouseDraggableScrollBehavior
    final gestureCustom = await tester.startGesture(
      const Offset(200, 100),
      kind: PointerDeviceKind.mouse,
    );
    await gestureCustom.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gestureCustom.up();
    await tester.pump();

    // MouseDraggableScrollBehavior succeeds on mouse drag!
    expect(customController.offset, greaterThan(50.0));
  });

  testWidgets(
      'Mouse click triggers onTap, mouse drag scrolls without triggering onTap',
      (WidgetTester tester) async {
    final controller = ScrollController();
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const MouseDraggableScrollBehavior(),
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: 20,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => tappedIndex = i,
                child: Container(
                  width: 150,
                  color: Colors.blue,
                  child: Text('Item $i'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Mouse Drag starting on Item 1
    await tester.drag(find.text('Item 1'), const Offset(-120, 0),
        kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(controller.offset, greaterThan(50.0),
        reason: 'Dragging must scroll list');
    expect(tappedIndex, -1, reason: 'Dragging must not trigger onTap');
  });

  testWidgets('MacScanMusicView horizontal cards row scrolls via mouse drag',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        scrollBehavior: MouseDraggableScrollBehavior(),
        home: Scaffold(
          body: MacScanMusicView(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Find first track card under DSD-DSF
    final cardFinder = find.text(scanTracks.first.title);
    expect(cardFinder, findsOneWidget);

    final initialCenter = tester.getCenter(cardFinder);

    // Drag left by 60 pixels using mouse
    await tester.drag(cardFinder, const Offset(-60, 0),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));

    final scrolledCenter = tester.getCenter(cardFinder);
    expect(scrolledCenter.dx, lessThan(initialCenter.dx - 30),
        reason:
            'Horizontal card position must move left when dragged with mouse');
  });
}
