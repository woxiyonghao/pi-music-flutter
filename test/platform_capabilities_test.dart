import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/services/ota_update_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_web_service_view.dart';

void main() {
  for (final platform in HifiPlatformType.values) {
    final desktop = [HifiPlatformType.mac, HifiPlatformType.window,
      HifiPlatformType.linux, HifiPlatformType.pi].contains(platform);

    testWidgets('$platform only exposes its allowed OTA controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        MacWebServiceView(platform: platform))));
      await tester.pumpAndSettle();
      expect(PlatformHelper.supportsGitOta(platform), desktop);
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
