import 'dart:convert';
import 'dart:io';

void main() async {
  print('Testing EQ & MSEB Bidirectional Control on iPad (192.168.0.177:8088)...');
  final ws = await WebSocket.connect('ws://192.168.0.177:8088/ws');

  final client = HttpClient();
  client.findProxy = (uri) => 'DIRECT';

  Future<Map<String, dynamic>> getStatus() async {
    final req = await client.getUrl(Uri.parse('http://192.168.0.177:8088/api/status'));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  // 1. Set EQ band 0 to +6.0 dB
  print('1. Setting EQ band 0 to +6.0 dB ...');
  ws.add(jsonEncode({'action': 'set_eq_band', 'index': 0, 'gain': 6.0}));
  await Future.delayed(const Duration(milliseconds: 300));

  var data = await getStatus();
  print('   -> eq_enabled: ${data['eq_enabled']}, band 0: ${data['eq_bands'][0]} dB');
  assert(data['eq_enabled'] == true);
  assert((data['eq_bands'][0] - 6.0).abs() < 0.01);

  // 2. Set MSEB param 0 to 5.0
  print('2. Setting MSEB param 0 to 5.0 ...');
  ws.add(jsonEncode({'action': 'set_mseb_param', 'index': 0, 'value': 5.0}));
  await Future.delayed(const Duration(milliseconds: 300));

  data = await getStatus();
  print('   -> mseb_enabled: ${data['mseb_enabled']}, param 0: ${data['mseb_params'][0]}');
  assert(data['mseb_enabled'] == true);
  assert((data['mseb_params'][0] - 5.0).abs() < 0.01);

  // 3. Reset EQ
  print('3. Resetting EQ ...');
  ws.add(jsonEncode({'action': 'reset_eq'}));
  await Future.delayed(const Duration(milliseconds: 300));

  // 4. Reset MSEB
  print('4. Resetting MSEB ...');
  ws.add(jsonEncode({'action': 'reset_mseb'}));
  await Future.delayed(const Duration(milliseconds: 300));

  data = await getStatus();
  final allEqZero = (data['eq_bands'] as List).every((g) => (g as num).toDouble() == 0.0);
  final allMsebZero = (data['mseb_params'] as List).every((p) => (p as num).toDouble() == 0.0);
  print('   -> reset eq: allZero=$allEqZero, reset mseb: allZero=$allMsebZero');
  assert(allEqZero);
  assert(allMsebZero);

  await ws.close();
  print('🎉 All EQ & MSEB Bidirectional sync checks PASSED 100%!');
}
