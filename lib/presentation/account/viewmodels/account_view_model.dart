import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/presentation/base_view_model.dart';
import '../../../injection_container.dart';
import '../../online/providers/online_providers.dart';

/// Logout.
class AccountViewModel extends BaseViewModel {
  /// Not allowed while an order is on its way.
  Future<bool> signOut() => run(() async {
        if (ref.read(onlineStatusProvider).value?.activeOrderId != null) {
          throw const AppException();
        }
        await ref.read(signOutUseCaseProvider)();
      });
}

final accountViewModelProvider = NotifierProvider<AccountViewModel, AsyncValue<void>>(AccountViewModel.new);
