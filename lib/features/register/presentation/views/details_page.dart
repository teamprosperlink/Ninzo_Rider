import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../auth/presentation/viewmodels/login_view_model.dart'
    show formatPhoneDigits;
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';

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
      title: 'Register',
      onBack: widget.onBack,
      bottom: [
        RiderButton(
          'Continue',
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
        const RiderStepProgress(step: 1, total: 3, label: 'Details'),
        const RegisterHeading(
          'Tell us about you',
          'Our team verifies these before your first shift.',
        ),
        RiderLabeledField(
          label: 'Full name',
          child: RiderIconField(
            icon: Icons.person_rounded,
            controller: _name,
            focusNode: _nameFocus,
            fieldKey: const Key('nameField'),
            hint: 'Full name as on Aadhaar',
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
          label: 'Mobile number',
          message: taken
              ? GestureDetector(
                  onTap: widget.onSignIn,
                  child: const RiderInlineMessage(
                    'This number is already registered. Sign in instead.',
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
            inputFormatters: [_PhoneFormatter()],
            onChanged: (text) => vm.setPhone(text.replaceAll(' ', '')),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
        RiderLabeledField(
          label: 'Your area',
          child: RiderIconField(
            key: const Key('areaField'),
            icon: Icons.pin_drop_outlined,
            value: state.area?.name,
            hint: 'Search your area',
            enabled: !state.busy,
            onTap: () {
              FocusScope.of(context).unfocus();
              vm.openArea();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RiderHugText(
                'Already registered?',
                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
              ),
              const SizedBox(width: 4),
              RiderLink(
                'Sign in',
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

/// Digits only, at most 10, shown as "98765 43210".
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = formatPhoneDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
