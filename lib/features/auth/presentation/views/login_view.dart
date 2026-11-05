import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/otp_request.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/verified_sheet.dart';

/// Login 01–16: the phone screen, the code screen (with the "Verified!"
/// sheet over it) and "Try again in 30 minutes", switched by [LoginViewModel].
class LoginView extends ConsumerWidget {
  const LoginView({super.key, required this.onBack, required this.onRegister});

  /// Back arrow on the phone screen (to Welcome).
  final VoidCallback onBack;

  /// "New rider? Register".
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = loginViewModelProvider;
    final step = ref.watch(provider.select((s) => s.step));
    return switch (step) {
      LoginStep.phone => PhoneStep(provider: provider, onBack: onBack, onRegister: onRegister),
      LoginStep.code => CodeStep(provider: provider),
      LoginStep.paused => RiderArtPage(
        art: const RiderArtTile(icon: Icons.hourglass_empty_rounded, iconColor: RiderColors.white),
        overline: 'Taking a short pause',
        title: 'Try again in 30 minutes',
        titleStyle: RiderText.h3,
        body:
            'Sign-in is paused for a few minutes to keep your account safe. '
            'Come back in 30 minutes and you’re good to go.',
        benefits: const ['Your account and earnings are safe'],
        actions: [RiderButton.ghost('Back to login', onPressed: ref.read(provider.notifier).editNumber)],
      ),
    };
  }
}

typedef LoginProvider = NotifierProvider<LoginViewModel, LoginState>;

String? _issueText(LoginIssue? issue) => switch (issue) {
  null => null,
  LoginIssue.invalidNumber => 'Almost there! Enter all 10 digits, starting with 6, 7, 8 or 9.',
  LoginIssue.notRegistered => 'This number isn’t a rider account yet. Check the number, or register as a new rider.',
  LoginIssue.noInternet => 'Waiting for internet. Turn on mobile data or Wi-Fi, then tap Try again.',
  LoginIssue.onHold => 'Your account is on hold for now. We’ll message you as soon as you can ride again.',
  LoginIssue.wrongCode => 'Almost there! Check the 6-digit code and enter it again.',
  LoginIssue.codeExpired => 'This code timed out. Tap Send again for a fresh one.',
};

/// Login 01, 02, 03, 12, 13, 14, 15, 16.
class PhoneStep extends ConsumerStatefulWidget {
  const PhoneStep({super.key, required this.provider, required this.onBack, required this.onRegister});

  final LoginProvider provider;
  final VoidCallback onBack;
  final VoidCallback onRegister;

  @override
  ConsumerState<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<PhoneStep> {
  late final _controller = TextEditingController(text: formatPhoneDigits(ref.read(widget.provider).phone));
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);
    final vm = ref.read(widget.provider.notifier);
    final message = _issueText(state.issue);
    final tone = switch (state.issue) {
      LoginIssue.onHold => RiderFieldTone.warning,
      LoginIssue.invalidNumber ||
      LoginIssue.notRegistered ||
      LoginIssue.noInternet => RiderFieldTone.error,
      _ => _focus.hasFocus || state.phone.isNotEmpty ? RiderFieldTone.active : RiderFieldTone.idle,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : widget.onBack(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: riderStatusBarDark,
        child: Scaffold(
          backgroundColor: RiderColors.screen,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiderBackButton(onPressed: widget.onBack),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Flutter sets half the spacing before the first letter; Figma doesn't.
                              Transform.translate(
                                offset: const Offset(-0.6, 0),
                                child: Text('WELCOME BACK', style: RiderText.overline.copyWith(letterSpacing: 1.2)),
                              ),
                              const SizedBox(height: 8),
                              Text('Log in to start\nyour shift', style: RiderText.h3),
                              const SizedBox(height: 8),
                              Text(
                                'Enter your registered mobile number. We’ll send you a code.',
                                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        RiderPhoneField(
                          controller: _controller,
                          focusNode: _focus,
                          tone: tone,
                          enabled: !state.busy,
                          inputFormatters: [_PhoneFormatter()],
                          onChanged: (text) => vm.setPhone(text.replaceAll(' ', '')),
                          onSubmitted: (_) => vm.submitPhone(),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 24),
                          state.issue == LoginIssue.onHold
                              ? RiderInlineMessage.warning(message)
                              : RiderInlineMessage(message),
                        ],
                        const SizedBox(height: 24),
                        RiderCheckboxRow(
                          label: 'Keep me signed in on this phone',
                          value: state.keepSignedIn,
                          onChanged: state.busy ? null : vm.setKeepSignedIn,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.issue != LoginIssue.onHold) ...[
                        RiderButton(
                          state.issue == LoginIssue.noInternet ? 'Try again' : 'Send code',
                          loading: state.busy,
                          loadingLabel: 'Sending code…',
                          onPressed: state.canSendCode || state.busy
                              ? () {
                                  FocusScope.of(context).unfocus();
                                  vm.sendCode();
                                }
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 36,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RiderHugText('New rider?', style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                            const SizedBox(width: 4),
                            RiderLink('Register', onPressed: widget.onRegister, style: RiderText.link),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Digits only, at most 10, shown as "98765 43210".
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = formatPhoneDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Login 04–09, 11.
class CodeStep extends ConsumerWidget {
  const CodeStep({super.key, required this.provider, this.onBack});

  final LoginProvider provider;

  /// Back arrow and "Edit number"; defaults to back to the phone screen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    final editNumber = onBack ?? vm.editNumber;
    ref.watch(secondTickerProvider);
    final secondsLeft = state.resendSecondsLeft(ref.read(clockProvider)());
    final message = _issueText(state.issue);
    final codeError = state.issue == LoginIssue.wrongCode || state.issue == LoginIssue.codeExpired;
    final body = AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RiderBackButton(size: 48, bordered: true, softShadow: true, onPressed: editNumber),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('We just sent an SMS', style: RiderText.h3),
                                  const SizedBox(height: 8),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Enter the six digit security code we sent to ',
                                      style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                                      children: [
                                        TextSpan(
                                          // Non-breaking spaces keep the number on one line.
                                          text: '+91 ${formatPhoneDigits(state.phone)}'.replaceAll(' ', ' '),
                                          style: RiderText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  RiderLink(
                                    'Edit number',
                                    onPressed: editNumber,
                                    style: RiderText.link,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            RiderCodeBoxes(
                              length: kLoginCodeLength,
                              value: state.code,
                              error: codeError,
                              dimmed: state.busy || state.verified,
                              spread: true,
                            ),
                            if (message != null) ...[
                              const SizedBox(height: 24),
                              RiderInlineMessage(message, centerIcon: true),
                            ],
                            const Spacer(),
                            const SizedBox(height: 24),
                            RiderButton(
                              state.verified ? 'Verified' : 'Continue',
                              loading: state.busy,
                              loadingLabel: 'Verifying…',
                              onPressed: state.codeComplete || state.busy || state.verified ? vm.verify : null,
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: secondsLeft > 0
                                  ? Text(
                                      'Need a new code? Send again in 00:${secondsLeft.toString().padLeft(2, '0')}',
                                      style: RiderText.bodyMedium,
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Need a new code? ', style: RiderText.bodyMedium),
                                        InkWell(
                                          onTap: state.busy || state.verified ? null : vm.sendCode,
                                          child: Text('Send again', style: RiderText.bodyMedium),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              RiderKeypad(
                onDigit: vm.addDigit,
                onBackspace: vm.removeDigit,
                enabled: !state.busy && !state.verified,
                keyWidth: 100,
              ),
            ],
          ),
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop || state.verified ? null : editNumber(),
      child: Stack(
        children: [
          body,
          if (state.verified)
            Positioned.fill(
              child: VerifiedSheet(message: state.verifiedMessage, onDone: vm.finish),
            ),
        ],
      ),
    );
  }
}
