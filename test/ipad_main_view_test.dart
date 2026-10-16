import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/ipad/ipad_main_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_background_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_bottom_bar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  testWidgets('IpadMainView renders sidebar, bottom bar, and background correctly', (tester) async {
    // 模拟 iPad Pro 11-inch 横屏 (1194 x 834)
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IpadMainView(),
      ),
    );
    await tester.pump();

    // 验证核心组件存在
    expect(find.byType(MacSidebarWidget), findsOneWidget);
    expect(find.byType(MacBottomBarWidget), findsOneWidget);
    expect(find.byType(MacBackgroundWidget), findsOneWidget);

    // 验证侧边栏功能导航项目
    expect(find.text('所有音乐'), findsWidgets);
    expect(find.text('均衡器'), findsOneWidget);
    expect(find.text('DAC'), findsWidgets);

    // 切换到 均衡器
    await tester.tap(find.text('均衡器'));
    await tester.pump(const Duration(milliseconds: 100));

    // 切换到 DAC
    await tester.tap(find.text('DAC').first);
    await tester.pump(const Duration(milliseconds: 100));

    // 打开新建歌单模态弹窗
    final addIcon = find.byIcon(Icons.add_rounded);
    if (addIcon.evaluate().isNotEmpty) {
      await tester.tap(addIcon.first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('新建播放列表'), findsOneWidget);

      // 取消弹窗
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('新建播放列表'), findsNothing);
    }

    await tester.pumpWidget(const SizedBox());
  });
}
