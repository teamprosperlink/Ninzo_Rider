import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/session_repository.dart';

class PrefsSessionRepository implements SessionRepository {
  static const _keep = 'session.keepSignedIn';
  static const _was = 'session.wasSignedIn';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<bool> keepSignedIn() async => (await _prefs).getBool(_keep) ?? true;

  @override
  Future<void> setKeepSignedIn(bool keep) async => (await _prefs).setBool(_keep, keep);

  @override
  Future<bool> wasSignedIn() async => (await _prefs).getBool(_was) ?? false;

  @override
  Future<void> setWasSignedIn(bool value) async => (await _prefs).setBool(_was, value);
}
