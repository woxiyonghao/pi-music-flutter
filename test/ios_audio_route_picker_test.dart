import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/ui/common/ios_audio_route_picker.dart';

void main() {
  testWidgets('iOS output selector mounts the registered native route picker',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform_views, null);
    });

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: IosAudioRoutePicker()),
    ));
    await tester.pump();
    expect(find.text('系统音频输出'), findsOneWidget);
    expect(tester.getSize(find.byType(UiKitView)), const Size(44, 44));
    final create = calls.singleWhere((call) => call.method == 'create');
    expect((create.arguments as Map)['viewType'], 'hifi/audio_route_picker');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls.where((call) => call.method == 'dispose'), hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
