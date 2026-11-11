import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/entities/shift_push.dart';
import '../../../core/constants/app_sizes.dart';

/// A shift push on the phone's lock screen, as Notification 01–07 draw it.
/// At runtime the real notification shows (see `LocalShiftNotifier`); this
/// renders the same content for design checks.
class ShiftPushPreview extends StatelessWidget {
  const ShiftPushPreview({
    super.key,
    required this.push,
    required this.shift,
    required this.now,
    this.detail = const PushDetail(),
  });

  final ShiftPush push;
  final Shift shift;
  final DateTime now;
  final PushDetail detail;

  @override
  Widget build(BuildContext context) {
    final content = ShiftPushContent.of(push, shift, detail: detail);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: AppSizes.s0,
                right: AppSizes.s0,
                top: AppSizes.s24,
                child: Text(
                  longDate(now),
                  textAlign: TextAlign.center,
                  style: RiderText.labelMedium.copyWith(color: RiderColors.grey),
                ),
              ),
              Positioned(
                left: AppSizes.s0,
                right: AppSizes.s0,
                top: AppSizes.s48,
                child: Text(shortClock(now), textAlign: TextAlign.center, style: RiderText.display2xl),
              ),
              Positioned(
                left: AppSizes.s16,
                right: AppSizes.s16,
                top: AppSizes.s212,
                child: RiderNotificationCard(
                  title: content.title,
                  body: content.body,
                  actions: content.actions.values.toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
