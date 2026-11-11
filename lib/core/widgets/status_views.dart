import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../constants/app_durations.dart';

/// Nothing to show yet: the screen's background, as no frame draws loading.
class BlankScreen extends StatelessWidget {
  const BlankScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: RiderColors.screen);
}

/// A load failed with nothing to go back to, and no frame for it: keeps
/// showing [child] and tries again by itself, so the rider isn't stuck.
class SilentRetry extends StatefulWidget {
  const SilentRetry({super.key, required this.onRetry, this.child = const BlankScreen()});

  static const every = AppDurations.seconds5;

  final VoidCallback onRetry;
  final Widget child;

  @override
  State<SilentRetry> createState() => _SilentRetryState();
}

class _SilentRetryState extends State<SilentRetry> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(SilentRetry.every, (_) => widget.onRetry());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
