import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/auth_failure.dart';
import '../../../domain/entities/otp_request.dart';
import '../../../domain/entities/rider_account_info.dart';
import '../providers/auth_state_providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_numbers.dart';
import '../../intro/viewmodels/intro_flow_view_model.dart';

/// Which login screen shows.
enum LoginStep {
  /// Login 01–03, 12–16.
  phone,

  /// Login 04–09, 11.
  code,

  /// Login 10 "Try again in 30 minutes".
  paused,
}

/// Problem shown on the phone or code screen.
enum LoginIssue { invalidNumber, notRegistered, noInternet, onHold, wrongCode, codeExpired }

class LoginState {
  const LoginState({
    this.step = LoginStep.phone,
    this.phone = '',
    this.keepSignedIn = true,
    this.busy = false,
    this.issue,
    this.code = '',
    this.request,
    this.account,
    this.resendAt,
    this.verified = false,
  });

  final LoginStep step;

  /// Digits typed after +91.
  final String phone;
  final bool keepSignedIn;

  /// Sending the code (Login 15) or checking it (Login 07).
  final bool busy;
  final LoginIssue? issue;

  /// Digits typed on the keypad.
  final String code;
  final OtpRequest? request;
  final RiderAccountInfo? account;

  /// When "Send again" becomes available; null when it already is.
  final DateTime? resendAt;

  /// Signed in; "Verified!" shows (Login 09).
  final bool verified;
  bool get canSendCode => Validators.isMobile(phone) && !busy;
  bool get codeComplete => code.length == kLoginCodeLength;
  bool get canVerify => codeComplete && !busy && !verified;

  /// Seconds until "Send again" (0 = available now).
  int resendSecondsLeft(DateTime now) {
    final at = resendAt;
    if (at == null) return 0;
    final left = at.difference(now).inMilliseconds;
    return left <= 0 ? 0 : (left / AppLimits.millisPerSecond).ceil();
  }

  /// "Your mobile number is verified." plus the shift when known.
  String get verifiedMessage => [AppStrings.yourMobileNumberIsVerified, ?account?.shiftSummary].join(' ');

  LoginState copyWith({
    LoginStep? step,
    String? phone,
    bool? keepSignedIn,
    bool? busy,
    LoginIssue? Function()? issue,
    String? code,
    OtpRequest? request,
    RiderAccountInfo? Function()? account,
    DateTime? Function()? resendAt,
    bool? verified,
  }) => LoginState(
    step: step ?? this.step,
    phone: phone ?? this.phone,
    keepSignedIn: keepSignedIn ?? this.keepSignedIn,
    busy: busy ?? this.busy,
    issue: issue == null ? this.issue : issue(),
    code: code ?? this.code,
    request: request ?? this.request,
    account: account == null ? this.account : account(),
    resendAt: resendAt == null ? this.resendAt : resendAt(),
    verified: verified ?? this.verified,
  );
}

/// Phone number → SMS code → Verified, with every error state in the design.
class LoginViewModel extends Notifier<LoginState> {
  @override
  LoginState build() {
    // From Register: its number, straight on to the code.
    final phone = ref.read(introFlowProvider).codeFor;
    if (phone == null) return const LoginState();
    Future.microtask(() {
      if (ref.mounted) sendCode();
    });
    return LoginState(phone: phone);
  }

  DateTime _now() => ref.read(clockProvider)();

  void setPhone(String digits) {
    if (digits == state.phone) return;
    final invalid = digits.length == AppLimits.phoneDigits && !Validators.isMobile(digits);
    state = state.copyWith(phone: digits, issue: () => invalid ? LoginIssue.invalidNumber : null);
  }

  /// Keyboard "done": flags an incomplete number.
  void submitPhone() {
    if (state.canSendCode) {
      sendCode();
    } else if (state.phone.isNotEmpty) {
      state = state.copyWith(issue: () => LoginIssue.invalidNumber);
    }
  }

  void setKeepSignedIn(bool keep) => state = state.copyWith(keepSignedIn: keep);

  /// "Send code", "Try again" (no internet) and "Send again" (resend).
  Future<void> sendCode() async {
    if (!Validators.isMobile(state.phone)) {
      state = state.copyWith(issue: () => LoginIssue.invalidNumber);
      return;
    }
    final resending = state.step == LoginStep.code;
    state = state.copyWith(busy: true, issue: () => null);
    // Keep the login screen up if the phone verifies itself while sending.
    ref.read(loginHoldProvider.notifier).hold(true);
    try {
      final result = await ref.read(requestLoginCodeUseCaseProvider)(
        state.phone,
        previous: resending ? state.request : null,
      );
      if (!ref.mounted) return;
      if (result.otp.isAutoVerified) {
        await ref.read(verifyOtpUseCaseProvider).signedIn(keepSignedIn: state.keepSignedIn);
        if (!ref.mounted) return;
        state = state.copyWith(busy: false, account: () => result.account, verified: true);
        return;
      }
      state = state.copyWith(
        step: LoginStep.code,
        busy: false,
        code: '',
        request: result.otp,
        account: () => result.account,
        resendAt: () => _now().add(AppDurations.resendCooldown),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      ref.read(loginHoldProvider.notifier).hold(false);
      _fail(e);
    }
  }

  void addDigit(String d) {
    if (state.busy || state.verified || state.code.length >= kLoginCodeLength) return;
    final keepIssue = state.issue == LoginIssue.codeExpired ? state.issue : null;
    state = state.copyWith(code: state.code + d, issue: () => keepIssue);
  }

  void removeDigit() {
    if (state.busy || state.verified || state.code.isEmpty) return;
    final keepIssue = state.issue == LoginIssue.codeExpired ? state.issue : null;
    state = state.copyWith(code: state.code.substring(0, state.code.length - 1), issue: () => keepIssue);
  }

  /// "Continue".
  Future<void> verify() async {
    final id = state.request?.verificationId;
    if (id == null || !state.canVerify) return;
    if (state.issue == LoginIssue.codeExpired) return;
    state = state.copyWith(busy: true, issue: () => null);
    final hold = ref.read(loginHoldProvider.notifier)..hold(true);
    try {
      await ref.read(verifyOtpUseCaseProvider)(verificationId: id, code: state.code, keepSignedIn: state.keepSignedIn);
      if (ref.mounted) state = state.copyWith(busy: false, verified: true);
    } on Object catch (e) {
      hold.hold(false);
      if (ref.mounted) _fail(e);
    }
  }

  void _fail(Object e) {
    final kind = e is AuthFailure ? e.kind : AuthFailureKind.unknown;
    if (kind == AuthFailureKind.tooManyAttempts) {
      state = state.copyWith(step: LoginStep.paused, busy: false, code: '', issue: () => null);
      return;
    }
    final issue = switch (kind) {
      AuthFailureKind.invalidNumber => LoginIssue.invalidNumber,
      AuthFailureKind.notRegistered => LoginIssue.notRegistered,
      AuthFailureKind.onHold => LoginIssue.onHold,
      AuthFailureKind.noInternet => LoginIssue.noInternet,
      AuthFailureKind.wrongCode => LoginIssue.wrongCode,
      AuthFailureKind.codeExpired => LoginIssue.codeExpired,
      // No frame for this: back to the step as it was.
      _ => null,
    };
    state = state.copyWith(
      busy: false,
      issue: () => issue,
      // An expired code can be replaced straight away.
      resendAt: issue == LoginIssue.codeExpired ? () => null : null,
    );
  }

  /// "Edit number", the code screen's back arrow, and "Back to login".
  void editNumber() {
    ref.read(loginHoldProvider.notifier).hold(false);
    state = LoginState(phone: state.phone, keepSignedIn: state.keepSignedIn);
  }

  /// "Start shift" (or closing "Verified!"): let the app move on.
  void finish() => ref.read(loginHoldProvider.notifier).hold(false);
}

final loginViewModelProvider = NotifierProvider.autoDispose<LoginViewModel, LoginState>(LoginViewModel.new);

/// Ticks every second while the code screen counts down to "Send again".
final secondTickerProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream.periodic(AppDurations.seconds1, (i) => i),
);
