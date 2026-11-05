import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/base_view_model.dart';
import '../../../auth/di/auth_di.dart';
import '../../../online/presentation/providers/online_providers.dart';

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
