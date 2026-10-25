import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The native picker changes the system media route; device cards only report
/// the current route and must not pretend to select a USB port themselves.
class IosAudioRoutePicker extends StatelessWidget {
  const IosAudioRoutePicker({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('系统音频输出',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            height: 44,
            child: defaultTargetPlatform == TargetPlatform.iOS
                ? const UiKitView(viewType: 'hifi/audio_route_picker')
                : const Icon(Icons.airplay_rounded, color: Colors.white70),
          ),
        ],
      );
}
