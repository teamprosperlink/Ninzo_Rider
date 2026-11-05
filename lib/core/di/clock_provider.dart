import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time. Tests override it to move the 90-second countdown.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
