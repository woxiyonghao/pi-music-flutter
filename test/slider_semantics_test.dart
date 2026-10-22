import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/ui/common/hifi_slider.dart';
import 'package:hide_player_flutter/ui/ipad/ipad_main_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';

// Check the serialized incremental graph, since widget semantics alone miss
// the orphan node that crashes Flutter's native accessibility bridge.
class _SemanticsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _CheckedBuilder();
}

class _CheckedBuilder extends Fake implements ui.SemanticsUpdateBuilder {
  final _builder = ui.SemanticsUpdateBuilder();
  final _updated = <int>{};
  static final nodes = <int, List<int>>{};
  static final orphans = <int>{};
  static bool hasSlider = false;

  @override
  void updateNode({
    required int id,
    required SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required Rect rect,
    required String identifier,
    required String label,
    required List<StringAttribute> labelAttributes,
    required String value,
    required List<StringAttribute> valueAttributes,
    required String increasedValue,
    required List<StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<StringAttribute> hintAttributes,
    required String tooltip,
    required TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String linkUrl = '',
    SemanticsRole role = SemanticsRole.none,
    required List<String>? controlsNodes,
    SemanticsValidationResult validationResult = SemanticsValidationResult.none,
    SemanticsHitTestBehavior hitTestBehavior = SemanticsHitTestBehavior.defer,
    required SemanticsInputType inputType,
    required Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    nodes[id] = childrenInTraversalOrder.toList();
    _updated.add(id);
    hasSlider |= flags.isSlider;
  }

  @override
  void updateCustomAction(
          {required int id,
          String? label,
          String? hint,
          int overrideId = -1}) =>
      _builder.updateCustomAction(
          id: id, label: label, hint: hint, overrideId: overrideId);

  @override
  ui.SemanticsUpdate build() {
    final reachable = <int>{};
    void visit(int id) {
      if (!reachable.add(id)) return;
      for (final child in nodes[id] ?? <int>[]) {
        visit(child);
      }
    }

    visit(0);
    orphans.addAll(_updated.where((id) => !reachable.contains(id)));
    return _builder.build();
  }
}

void main() {
  _SemanticsBinding();
  testWidgets(
      'iPad player navigation keeps the serialized accessibility tree connected',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _CheckedBuilder.nodes.clear();
    _CheckedBuilder.orphans.clear();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
        MaterialApp(theme: HifiTheme.darkTheme, home: const IpadMainView()));
    await tester.pump();
    for (final label in ['DAC', '设置', '均衡器', '调音魔棒', '所有音乐', 'DAC']) {
      final item = find.descendant(
          of: find.byType(MacSidebarWidget), matching: find.text(label));
      if (item.evaluate().isNotEmpty) {
        await tester.tap(item.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    semantics.dispose();
    expect(_CheckedBuilder.orphans, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'slider stays accessible without orphan native nodes across dialog and indicator updates',
      (tester) async {
    _CheckedBuilder.nodes.clear();
    _CheckedBuilder.orphans.clear();
    _CheckedBuilder.hasSlider = false;
    final semantics = tester.ensureSemantics();
    late BuildContext pageContext;
    var value = .5;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      pageContext = context;
      return const Scaffold(body: Text('Player'));
    })));
    await tester.pumpAndSettle();
    for (var cycle = 0; cycle < 3; cycle++) {
      showDialog<void>(
          context: pageContext,
          builder: (context) => AlertDialog(
                content: StatefulBuilder(builder: (context, setState) {
                  void change(double next) => setState(() => value = next);
                  const reproduceUnwrapped =
                      bool.fromEnvironment('HIFI_REPRO_UNWRAPPED_SLIDER');
                  return SizedBox(
                      width: 320,
                      child: reproduceUnwrapped
                          ? Slider(
                              value: value,
                              divisions: 10,
                              label: 'Volume',
                              onChanged: change)
                          : HifiSlider(
                              value: value,
                              divisions: 10,
                              label: 'Volume',
                              onChanged: change));
                }),
              ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      final before = value;
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Slider)));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await tester.pumpAndSettle();
      if (cycle == 0) expect(value, isNot(before));
      Navigator.of(pageContext).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
    expect(_CheckedBuilder.hasSlider, isTrue,
        reason: 'Slider accessibility must be preserved');
    expect(_CheckedBuilder.orphans, isEmpty,
        reason: 'Native AXTree rejects orphan serialized nodes');
  });
}
