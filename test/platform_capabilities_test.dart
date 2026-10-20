import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/services/ota_update_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_system_settings_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_web_service_view.dart';

void main() {
  for (final platform in HifiPlatformType.values) {
    final desktop = [HifiPlatformType.mac, HifiPlatformType.window,
      HifiPlatformType.linux, HifiPlatformType.pi].contains(platform);

    testWidgets('$platform only exposes its allowed power and OTA controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        MacSystemSettingsView(platform: platform))));
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('系统操作与电源控制'),
        platform == HifiPlatformType.pi ? findsOneWidget : findsNothing);
      expect(PlatformHelper.supportsGitOta(platform), desktop);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        MacWebServiceView(platform: platform))));
      await tester.pumpAndSettle();
      final ota = find.textContaining('【系统在线 OTA 升级】', skipOffstage: false);
      expect(ota, desktop ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('all desktop OTA commands use the complete Release packaging scripts', () {
    expect(OtaUpdateService.releaseBuildCommand(TargetPlatform.macOS),
      ['zsh', 'scripts/build_mac.sh']);
    expect(OtaUpdateService.releaseBuildCommand(TargetPlatform.linux),
      ['bash', 'scripts/build_linux.sh']);
    expect(OtaUpdateService.releaseBuildCommand(TargetPlatform.windows),
      contains('scripts/build_windows.ps1'));
    expect(OtaUpdateService.releaseBuildCommand(TargetPlatform.iOS), isNull);
    expect(OtaUpdateService.releaseBuildCommand(TargetPlatform.android), isNull);
  });
}
