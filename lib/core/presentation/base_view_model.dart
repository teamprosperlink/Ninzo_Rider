import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base for ViewModels that run user commands. The state is the command
/// in progress (loading) or the last command's error, so views can disable
/// buttons and show failures.
abstract class BaseViewModel extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Runs [command] and records its outcome. Returns true on success.
  @protected
  Future<bool> run(Future<void> Function() command) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(command);
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}
