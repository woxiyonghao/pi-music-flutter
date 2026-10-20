import 'package:flutter/material.dart';

/// Keep Material Slider's indicator portal in the slider's own semantics tree.
/// Flutter 3.47 desktop can otherwise serialize an orphan accessibility node
/// during route changes and crash the native accessibility bridge.
/// https://github.com/flutter/flutter/issues/190357
class HifiSlider extends StatelessWidget {
  const HifiSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.activeColor,
    this.divisions,
    this.label,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final Color? activeColor;
  final int? divisions;
  final String? label;

  @override
  Widget build(BuildContext context) => Overlay.wrap(
        alwaysSizeToContent: true,
        clipBehavior: Clip.none,
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: activeColor,
          divisions: divisions,
          label: label,
        ),
      );
}
