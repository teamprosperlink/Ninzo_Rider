import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock_provider.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/otp_request.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/verified_sheet.dart';
import '../../../routing/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

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
    return loginStepPage(step, ref, provider: provider, onBack: onBack, onRegister: onRegister);
  }
}

/// Login: "Try again in 30 minutes".
class LoginPausedPage extends StatelessWidget {
  const LoginPausedPage({super.key, required this.onBackToLogin, this.minutes});

  final VoidCallback onBackToLogin;

  /// The server's wait (`Retry-After`) in minutes; null when it gave none.
  final int? minutes;

  @override
  Widget build(BuildContext context) {
    final minutes = this.minutes;
    if (minutes == null) return _page(AppStrings.tryAgainShortly, AppStrings.signInIsPausedShortly);
    final span = AppStrings.minutesSpan(minutes);
    return _page(AppStrings.tryAgainIn(span), AppStrings.signInIsPausedFor(span));
  }

  Widget _page(String title, String body) => RiderArtPage(
    art: const RiderArtTile(icon: Icons.hourglass_empty_rounded, iconColor: RiderColors.white),
    overline: AppStrings.takingAShortPause,
    title: title,
    titleStyle: RiderText.h3,
    body: body,
    benefits: const [AppStrings.yourAccountAndEarningsAreSafe],
    actions: [RiderButton.ghost(AppStrings.backToLogin, onPressed: onBackToLogin)],
  );
}

typedef LoginProvider = NotifierProvider<LoginViewModel, LoginState>;

String? _issueText(LoginIssue? issue) => switch (issue) {
  null => null,
  LoginIssue.invalidNumber => AppStrings.almostThereEnterAll10Digits,
  LoginIssue.notRegistered => AppStrings.thisNumberIsnTARider,
  LoginIssue.noInternet => AppStrings.waitingForInternetTurnOnMobile,
  LoginIssue.onHold => AppStrings.yourAccountIsOnHoldFor,
  LoginIssue.wrongCode => AppStrings.almostThereCheckThe6Digit,
  LoginIssue.codeExpired => AppStrings.thisCodeTimedOutTapSend,
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
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RiderBackButton(onPressed: widget.onBack),
                        const SizedBox(height: AppSizes.s24),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.s16, bottom: AppSizes.s8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Flutter sets half the spacing before the first letter; Figma doesn't.
                              Transform.translate(
                                offset: const Offset(-AppSizes.s0_6, AppSizes.s0),
                                child: Text(AppStrings.welcomeBack, style: RiderText.overlineSpaced1_2),
                              ),
                              const SizedBox(height: AppSizes.s8),
                              Text(AppStrings.logInToStartNyourShift, style: RiderText.h3),
                              const SizedBox(height: AppSizes.s8),
                              Text(
                                AppStrings.enterYourRegisteredMobileNumberWe,
                                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.s24),
                        RiderPhoneField(
                          controller: _controller,
                          focusNode: _focus,
                          tone: tone,
                          enabled: !state.busy,
                          inputFormatters: [PhoneNumberFormatter()],
                          onChanged: (text) => vm.setPhone(text.replaceAll(' ', '')),
                          onSubmitted: (_) => vm.submitPhone(),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: AppSizes.s24),
                          state.issue == LoginIssue.onHold
                              ? RiderInlineMessage.warning(message)
                              : RiderInlineMessage(message),
                        ],
                        const SizedBox(height: AppSizes.s24),
                        RiderCheckboxRow(
                          label: AppStrings.keepMeSignedInOnThis,
                          value: state.keepSignedIn,
                          onChanged: state.busy ? null : vm.setKeepSignedIn,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s16, AppSizes.s16, AppSizes.s12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.issue != LoginIssue.onHold) ...[
                        RiderButton(
                          state.issue == LoginIssue.noInternet ? AppStrings.tryAgain : AppStrings.sendCode,
                          loading: state.busy,
                          loadingLabel: AppStrings.sendingCode,
                          onPressed: state.canSendCode || state.busy
                              ? () {
                                  FocusScope.of(context).unfocus();
                                  vm.sendCode();
                                }
                              : null,
                        ),
                        const SizedBox(height: AppSizes.s12),
                      ],
                      SizedBox(
                        height: AppSizes.s36,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RiderHugText(AppStrings.newRider, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                            const SizedBox(width: AppSizes.s4),
                            RiderLink(AppStrings.register, onPressed: widget.onRegister, style: RiderText.link),
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
                        padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RiderBackButton(size: AppSizes.s48, bordered: true, softShadow: true, onPressed: editNumber),
                            const SizedBox(height: AppSizes.s24),
                            Padding(
                              padding: const EdgeInsets.only(top: AppSizes.s12, bottom: AppSizes.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppStrings.weJustSentAnSms, style: RiderText.h3),
                                  const SizedBox(height: AppSizes.s8),
                                  Text.rich(
                                    TextSpan(
                                      text: AppStrings.enterTheSixDigitSecurityCode,
                                      style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                                      children: [
                                        TextSpan(
                                          // Non-breaking spaces keep the number on one line.
                                          text: AppStrings.indiaPhoneDisplay(formatPhoneDigits(state.phone)).replaceAll(' ', ' '),
                                          style: RiderText.bodyMediumSemibold,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.s8),
                                  RiderLink(
                                    AppStrings.editNumber,
                                    onPressed: editNumber,
                                    style: RiderText.link,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSizes.s24),
                            RiderCodeBoxes(
                              length: kLoginCodeLength,
                              value: state.code,
                              error: codeError,
                              dimmed: state.busy || state.verified,
                              spread: true,
                            ),
                            if (message != null) ...[
                              const SizedBox(height: AppSizes.s24),
                              RiderInlineMessage(message, centerIcon: true),
                            ],
                            const Spacer(),
                            const SizedBox(height: AppSizes.s24),
                            RiderButton(
                              state.verified ? AppStrings.verified : AppStrings.continueLabel,
                              loading: state.busy,
                              loadingLabel: AppStrings.verifying,
                              onPressed: state.codeComplete || state.busy || state.verified ? vm.verify : null,
                            ),
                            const SizedBox(height: AppSizes.s16),
                            Center(
                              child: secondsLeft > 0
                                  ? Text(
                                      AppStrings.needANewCodeSendAgain(secondsLeft.toString().padLeft(2, AppStrings.digit0)),
                                      style: RiderText.bodyMedium,
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(AppStrings.needANewCode, style: RiderText.bodyMedium),
                                        InkWell(
                                          onTap: state.busy || state.verified ? null : vm.sendCode,
                                          child: Text(AppStrings.sendAgain, style: RiderText.bodyMedium),
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
                keyWidth: AppSizes.s100,
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
