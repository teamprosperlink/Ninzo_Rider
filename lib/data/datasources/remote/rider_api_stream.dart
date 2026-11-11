import 'dart:convert';
import 'dart:io';

import '../../../core/api/api_endpoints.dart';
import 'rider_api_client.dart';

/// The rider's live channel (`wss://…/riders/me/stream`): `offer` and
/// `order_state` messages, and a heartbeat whose `seq` says the state moved.
/// The first message is `{"type":"auth","token":…}`, within 5 seconds.
/// Ends when the socket closes; the session connects again.
Stream<Map<String, dynamic>> riderLiveStream(RiderApiClient client) async* {
  final token = (await client.tokens.read())?.access;
  if (token == null) return;
  final base = await client.baseUrl();
  final url = base.replaceFirst(RegExp('^http'), 'ws') + RiderApiEndpoints.stream;
  final socket = await WebSocket.connect(url);
  socket.add(jsonEncode({'type': 'auth', 'token': token}));
  try {
    await for (final message in socket) {
      if (message is! String) continue;
      final json = jsonDecode(message);
      if (json is Map<String, dynamic>) yield json;
    }
  } finally {
    await socket.close();
  }
}
