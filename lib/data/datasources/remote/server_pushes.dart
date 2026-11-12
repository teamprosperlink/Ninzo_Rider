import '../../../domain/entities/shift_push.dart';
import '../../../domain/repositories/shift_notifier.dart';
import 'push_token_source.dart';

/// The rider API's pushes (`push.rider`, `kind: notification`) that arrive
/// while the app is open, as the shift push their `notification_kind` names.
class FcmServerPushes implements ServerPushes {
  const FcmServerPushes(this._source);

  final PushTokenSource _source;

  @override
  bool get active => true;

  @override
  Stream<ShiftPush> get arrived => _source.messages
      .where((data) => data['topic'] == 'push.rider' && data['kind'] == 'notification')
      .map((data) => ShiftPush.ofServerKind(data['notification_kind']))
      .where((push) => push != null)
      .cast<ShiftPush>();
}

/// No server pushes: demo and tests, where the phone shows every push.
class NoServerPushes implements ServerPushes {
  const NoServerPushes();

  @override
  bool get active => false;

  @override
  Stream<ShiftPush> get arrived => const Stream.empty();
}
