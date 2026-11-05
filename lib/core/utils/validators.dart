/// Form validators.
class Validators {
  static final _mobile = RegExp(r'^[6-9]\d{9}$');

  static bool isMobile(String value) => _mobile.hasMatch(value.trim());
}
