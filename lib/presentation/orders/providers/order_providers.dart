import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';

/// Handovers the rider left behind at a gate without signal sync by themselves
/// when signal returns, wherever the rider is. Watched by the rider's root.
final handoverSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final sync = ref.watch(syncSavedHandoversUseCaseProvider);
  ref.watch(checkSignalUseCaseProvider)().then((online) {
    if (online) sync(uid);
  });
  final subscription = ref.watch(watchSignalUseCaseProvider)().listen((online) {
    if (online) sync(uid);
  });
  ref.onDispose(subscription.cancel);
});
