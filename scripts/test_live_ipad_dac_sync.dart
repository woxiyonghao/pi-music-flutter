import 'dart:convert';
import 'dart:io';

void main() async {
  print('Testing DAC Remote Control & Live Sync on iPad (192.168.0.177:8088)...');
  final ws = await WebSocket.connect('ws://192.168.0.177:8088');

  final dacMessages = <Map<String, dynamic>>[];
  final sub = ws.listen((data) {
    if (data is String) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        if (json['type'] == 'dac') {
          dacMessages.add(json);
        }
      } catch (_) {}
    }
  });

  await Future.delayed(const Duration(milliseconds: 300));
  print('Initial DAC State received: chip=${dacMessages.last['selected_chip']}, name=${dacMessages.last['dac_name']}');

  // 1. Switch DAC chip to ES9038PRO (1)
  print('1. Switching DAC chip to ES9038PRO (chip: 1)...');
  ws.add(jsonEncode({'action': 'set_dac_chip', 'chip': 1}));
  await Future.delayed(const Duration(milliseconds: 400));
  print('   -> Updated chip: ${dacMessages.last['selected_chip']} (${dacMessages.last['dac_name']})');
  assert(dacMessages.last['selected_chip'] == 1);
  assert(dacMessages.last['dac_name'] == 'ES9038PRO');

  // 2. Set DAC PCM Filter to 2 (快速线性)
  print('2. Setting ESS pcm_filter to 2 (快速线性)...');
  ws.add(jsonEncode({'action': 'set_dac_param', 'key': 'pcm_filter', 'val': 2}));
  await Future.delayed(const Duration(milliseconds: 400));
  print('   -> Updated pcm_filter: ${dacMessages.last['params']['pcm_filter']}');
  assert(dacMessages.last['params']['pcm_filter'] == 2);

  // 3. Switch DAC chip to AK4499EX (2)
  print('3. Switching DAC chip to AK4499EX (chip: 2)...');
  ws.add(jsonEncode({'action': 'set_dac_chip', 'chip': 2}));
  await Future.delayed(const Duration(milliseconds: 400));
  print('   -> Updated chip: ${dacMessages.last['selected_chip']} (${dacMessages.last['dac_name']})');
  assert(dacMessages.last['selected_chip'] == 2);
  assert(dacMessages.last['dac_name'] == 'AK4499EX');

  // 4. Set AKM sound color to 1 (通透)
  print('4. Setting AKM akm_color to 1 (通透)...');
  ws.add(jsonEncode({'action': 'set_dac_param', 'key': 'akm_color', 'val': 1}));
  await Future.delayed(const Duration(milliseconds: 400));
  print('   -> Updated akm_color: ${dacMessages.last['params']['akm_color']}');
  assert(dacMessages.last['params']['akm_color'] == 1);

  // 5. Restore back to Apple Direct (0)
  print('5. Restoring back to Apple Direct (0)...');
  ws.add(jsonEncode({'action': 'set_dac_chip', 'chip': 0}));
  await Future.delayed(const Duration(milliseconds: 400));
  assert(dacMessages.last['selected_chip'] == 0);

  await sub.cancel();
  await ws.close();
  print('🎉 LIVE iPad DAC WebSocket Bidirectional Sync PASSED 100%!');
}
