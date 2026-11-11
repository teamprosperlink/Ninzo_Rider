import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/intro_repository.dart';

class PrefsIntroRepository implements IntroRepository {
  static const _permissionsSeen = 'intro.permissionsSeen';

  @override
  Future<bool> permissionsSeen() async => (await SharedPreferences.getInstance()).getBool(_permissionsSeen) ?? false;

  @override
  Future<void> markPermissionsSeen() async => (await SharedPreferences.getInstance()).setBool(_permissionsSeen, true);
}
