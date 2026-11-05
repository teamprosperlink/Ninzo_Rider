import 'dart:async';

import '../../../../core/config/demo_data.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';

/// In-memory profiles for demo mode. Sample riders (see [DemoData]) already
/// have a profile named [DemoData.riderName]; new numbers sign up.
class DemoUserRepository implements UserRepository {
  final _users = <String, AppUser>{};
  final _changes = StreamController<String>.broadcast();

  AppUser? _find(String uid) {
    final phone = '+${uid.replaceFirst('demo-', '')}';
    return _users[uid] ??
        (DemoData.isRegistered(phone) ? AppUser(uid: uid, phone: phone, name: DemoData.riderName) : null);
  }

  @override
  Stream<AppUser?> watchUser(String uid) async* {
    yield _find(uid);
    yield* _changes.stream.where((id) => id == uid).map((_) => _find(uid));
  }

  @override
  Future<void> createUser(AppUser user) async {
    _users[user.uid] = user;
    _changes.add(user.uid);
  }

  @override
  Future<void> updateProfile(String uid, {required String name, String? email}) async {
    final u = _find(uid)!;
    _users[uid] = AppUser(uid: uid, phone: u.phone, name: name, email: email);
    _changes.add(uid);
  }
}
