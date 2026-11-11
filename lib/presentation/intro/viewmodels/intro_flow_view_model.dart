import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../injection_container.dart';
import '../../../domain/entities/app_permission.dart';
import '../../../domain/usecases/permission_usecases.dart';

/// Signed-out screens, in flow-map order.
enum IntroScreen {
  /// Onboard 02.
  welcome,

  /// Onboard 03–06: one screen per [AppPermission]; location also has the
  /// "Location off" state (06).
  permission,

  /// Login 01–16.
  login,

  /// Onboard 07.
  signedOut,

  /// Register 01–03, 14–16: a new rider's details, before they sign in.
  register,
}

class IntroFlowState {
  const IntroFlowState({
    this.screen = IntroScreen.welcome,
    this.permission = AppPermission.location,
    this.locationOff = false,
    this.busy = false,
    this.register = false,
    this.codeFor,
  });

  final IntroScreen screen;

  /// Permission screen being shown.
  final AppPermission permission;

  /// Location screen in its "Turn on location to go online" state.
  final bool locationOff;

  /// Waiting for the system prompt.
  final bool busy;

  /// Registering a new rider ("New rider? Register").
  final bool register;

  /// Register's number: Login opens on its code (the rider API signs riders
  /// in only with an OTP), then Register carries on.
  final String? codeFor;

  /// Permission N of 3.
  int get step => permission.index + 1;

  IntroFlowState copyWith({
    IntroScreen? screen,
    AppPermission? permission,
    bool? locationOff,
    bool? busy,
    bool? register,
  }) => IntroFlowState(
    screen: screen ?? this.screen,
    permission: permission ?? this.permission,
    locationOff: locationOff ?? this.locationOff,
    busy: busy ?? this.busy,
    register: register ?? this.register,
  );
}

/// Restores the session at app start (while the splash shows). True when the
/// rider was signed out without asking to be, which opens "Signed out".
final appStartupProvider = FutureProvider<bool>((ref) async {
  // The launch screen counts too: 3 s in all from the tap.
  final left = ref.read(splashDurationProvider) - await ref.read(timeSinceAppStartProvider)();
  final minimum = Future<void>.delayed(left.isNegative ? Duration.zero : left);
  final sessionEnded = await ref.read(restoreSessionUseCaseProvider)();
  await minimum;
  return sessionEnded;
});

/// Welcome → permissions (first time only) → login, and "Signed out".
class IntroFlowViewModel extends Notifier<IntroFlowState> {
  @override
  IntroFlowState build() {
    final sessionEnded = ref.watch(appStartupProvider).value ?? false;
    return IntroFlowState(screen: sessionEnded ? IntroScreen.signedOut : IntroScreen.welcome);
  }

  PermissionsIntro get _intro => ref.read(permissionsIntroUseCaseProvider);

  /// "Sign in" on Welcome or Signed out.
  Future<void> signIn() => _start(register: false);

  /// "New rider? Register" on Welcome or Login: Register 01.
  Future<void> register() => _start(register: true);

  Future<void> _start({required bool register}) async {
    final showPermissions = await _intro.shouldShow();
    if (!ref.mounted) return;
    state = IntroFlowState(
      screen: showPermissions ? IntroScreen.permission : _afterPermissions(register),
      register: register,
    );
  }

  static IntroScreen _afterPermissions(bool register) => register ? IntroScreen.register : IntroScreen.login;

  /// "Allow location" / "Turn on notifications" / "Allow camera".
  Future<void> allow() async {
    final permission = state.permission;
    state = state.copyWith(busy: true);
    final result = await _request(permission);
    if (!ref.mounted) return;
    if (permission == AppPermission.location && !result.isGranted) {
      state = state.copyWith(busy: false, locationOff: true);
    } else {
      await _next();
    }
  }

  /// "Not now". Location is needed to go online, so it shows "Location off".
  Future<void> notNow() async {
    if (state.permission == AppPermission.location) {
      state = state.copyWith(locationOff: true);
    } else {
      await _next();
    }
  }

  /// "Open settings" on Location off.
  Future<void> openSettings() => ref.read(openPermissionSettingsUseCaseProvider)(state.permission);

  /// "I've turned it on": continue when location is now allowed, otherwise
  /// ask again.
  Future<void> turnedOn() async {
    state = state.copyWith(busy: true);
    final result = await _request(AppPermission.location);
    if (!ref.mounted) return;
    if (result.isGranted) {
      await _next();
    } else {
      state = state.copyWith(busy: false);
    }
  }

  /// A failed request (e.g. one already running) counts as not allowed, so
  /// the screen never stays busy.
  Future<PermissionResult> _request(AppPermission permission) async {
    try {
      return await ref.read(requestPermissionUseCaseProvider)(permission);
    } on Object {
      return PermissionResult.denied;
    }
  }

  Future<void> _next() async {
    final next = PermissionsIntro.next(state.permission);
    if (next != null) {
      state = state.copyWith(permission: next, locationOff: false, busy: false);
      return;
    }
    await _intro.finish();
    if (ref.mounted) {
      state = state.copyWith(screen: _afterPermissions(state.register), busy: false, locationOff: false);
    }
  }

  /// Back arrow on the login screen.
  void backToWelcome() => state = const IntroFlowState();

  /// Register 01 "Continue" on the rider API: the number gets an OTP on
  /// Login's code screen (Login 05); once signed in, Register carries on with
  /// the documents.
  void verifyNumber(String phone) =>
      state = IntroFlowState(screen: IntroScreen.login, register: true, codeFor: phone);

  /// The rider is no longer signed in: "Signed out" if the session ended on
  /// its own, otherwise Welcome.
  Future<void> onSignedOut() async {
    final ended = await ref.read(restoreSessionUseCaseProvider).sessionEnded();
    if (ref.mounted) state = IntroFlowState(screen: ended ? IntroScreen.signedOut : IntroScreen.welcome);
  }
}

final introFlowProvider = NotifierProvider<IntroFlowViewModel, IntroFlowState>(IntroFlowViewModel.new);
