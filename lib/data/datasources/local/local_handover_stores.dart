import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/handover.dart';
import '../../../domain/repositories/handover_repository.dart';
import '../../models/handover_models.dart';

/// Handovers saved on the phone, one JSON document per rider.
class PrefsHandoverStore implements HandoverStore {
  static String _key(String uid) => 'saved_handovers/$uid';

  @override
  Future<HandoverLocalState> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null) return const HandoverLocalState();
    return HandoverLocalJson.decode((jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  @override
  Future<void> save(String uid, HandoverLocalState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(HandoverLocalJson.encode(state)));
  }
}

/// Kept in memory: the demo's shift starts afresh on each launch, so what it
/// saved must too.
class InMemoryHandoverStore implements HandoverStore {
  final _states = <String, HandoverLocalState>{};

  @override
  Future<HandoverLocalState> load(String uid) async => _states[uid] ?? const HandoverLocalState();

  @override
  Future<void> save(String uid, HandoverLocalState state) async => _states[uid] = state;
}
