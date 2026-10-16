import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final index = args.isNotEmpty ? int.parse(args[0]) : 0;
  print('Connecting to ws://192.168.0.177:8088/ws ...');
  final ws = await WebSocket.connect('ws://192.168.0.177:8088/ws');
  print('Playing track index $index ...');
  ws.add(jsonEncode({'action': 'play_library_index', 'index': index}));

  int count = 0;
  ws.listen((data) {
    if (data is String) {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      if (msg['type'] == 'state') {
        count++;
        print('[$count] State: playing=${msg['is_playing']}, title=${msg['title']}, time=${msg['current_time']?.toStringAsFixed(1)}/${msg['duration']?.toStringAsFixed(1)}, dev=${msg['device_name']}, sampleRate=${msg['sample_rate']}');
      }
    }
  });

  await Future.delayed(const Duration(seconds: 4));
  await ws.close();
  print('Done test.');
}
