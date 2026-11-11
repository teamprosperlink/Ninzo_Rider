import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/constants/app_keys.dart';

/// Register 01 (empty), 02 (filled) and 03 (number already registered).
class DetailsPage extends ConsumerStatefulWidget {
  const DetailsPage({
    super.key,
    required this.onBack,
    required this.onSignIn,
    required this.onContinue,
  });

  final VoidCallback onBack;

  /// "Sign in" links.
  final VoidCallback onSignIn;

  /// "Continue".
  final VoidCallback onContinue;

  @override
  ConsumerState<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends ConsumerState<DetailsPage> {
  late final _name = TextEditingController(
    text: ref.read(registerViewModelProvider).name,
  );
  late final _phone = TextEditingController(
    text: formatPhoneDigits(ref.read(registerViewModelProvider).phone),
  );
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerViewModelProvider);
    final vm = ref.read(registerViewModelProvider.notifier);
    // Keep the fields in step with values filled in by the view model.
    if (_name.text.isEmpty && state.name.isNotEmpty) _name.text = state.name;
    final phoneText = formatPhoneDigits(state.phone);
    if (_phone.text.replaceAll(' ', '') != state.phone) _phone.text = phoneText;

    final taken = state.issue == RegisterIssue.alreadyRegistered;
    final signedIn = vm.signedIn;
    return RegisterScaffold(
      title: AppStrings.register,
      onBack: widget.onBack,
      bottom: [
        RiderButton(
          AppStrings.continueLabel,
          loading: state.busy,
          onPressed: state.detailsComplete || state.busy
              ? () {
                  FocusScope.of(context).unfocus();
                  widget.onContinue();
                }
              : null,
        ),
      ],
      children: [
        const RiderStepProgress(step: AppLimits.registerDetailsStep, total: AppLimits.registerSteps, label: AppStrings.details),
        const RegisterHeading(
          AppStrings.tellUsAboutYou,
          AppStrings.ourTeamVerifiesTheseBeforeYour,
        ),
        RiderLabeledField(
          label: AppStrings.fullName,
          child: RiderIconField(
            icon: Icons.person_rounded,
            controller: _name,
            focusNode: _nameFocus,
            fieldKey: const Key(AppKeys.namefield),
            hint: AppStrings.fullNameAsOnAadhaar,
            tone: _nameFocus.hasFocus
                ? RiderFieldTone.active
                : RiderFieldTone.idle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !state.busy,
            onChanged: vm.setName,
          ),
        ),
        RiderLabeledField(
          label: AppStrings.mobileNumber,
          message: taken
              ? GestureDetector(
                  onTap: widget.onSignIn,
                  child: const RiderInlineMessage(
                    AppStrings.thisNumberIsAlreadyRegisteredSign,
                  ),
                )
              : null,
          child: RiderPhoneField(
            controller: _phone,
            focusNode: _phoneFocus,
            enabled: !state.busy && !signedIn,
            tone: taken
                ? RiderFieldTone.error
                : (_phoneFocus.hasFocus
                      ? RiderFieldTone.active
                      : RiderFieldTone.idle),
            inputFormatters: [PhoneNumberFormatter()],
            onChanged: (text) => vm.setPhone(text.replaceAll(' ', '')),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        RiderLabeledField(
          label: AppStrings.yourArea,
          child: RiderIconField(
            key: const Key(AppKeys.areafield),
            icon: Icons.pin_drop_outlined,
            value: state.area?.name,
            hint: AppStrings.searchYourArea,
            enabled: !state.busy,
            onTap: () {
              FocusScope.of(context).unfocus();
              vm.openArea();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSizes.s4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RiderHugText(
                AppStrings.alreadyRegistered,
                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
              ),
              const SizedBox(width: AppSizes.s4),
              RiderLink(
                AppStrings.signIn,
                onPressed: widget.onSignIn,
                style: RiderText.link,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

