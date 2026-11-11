import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../online/providers/online_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/problem_report.dart';

class ProblemReportState {
  const ProblemReportState({this.open = false, this.kind, this.sent = false, this.busy = false});

  /// Over whichever screen of the order it was opened from.
  final bool open;

  /// Problem 02 once chosen.
  final ProblemKind? kind;

  /// Problem 03.
  final bool sent;
  final bool busy;

  ProblemReportState copyWith({ProblemKind? kind, bool? sent, bool? busy, String? Function()? message}) =>
      ProblemReportState(
        open: open,
        kind: kind ?? this.kind,
        sent: sent ?? this.sent,
        busy: busy ?? this.busy,
      );
}

/// Report a problem (Problem 01–03), from the order map and the handover.
class ProblemReportViewModel extends Notifier<ProblemReportState> {
  @override
  ProblemReportState build() {
    // Each order starts without one.
    ref.watch(onlineStatusProvider.select((s) => s.value?.activeOrderId));
    return const ProblemReportState();
  }

  /// [kind] is already chosen when the screen it's opened from says what's
  /// wrong ("Can't reach customer").
  void open({ProblemKind? kind}) => state = ProblemReportState(open: true, kind: kind);

  /// Back, or "Back to order".
  void close() => state = const ProblemReportState();

  void choose(ProblemKind kind) => state = state.copyWith(kind: kind);

  /// "Send report" → Problem 03.
  Future<void> send() async {
    final orderId = ref.read(onlineStatusProvider).value?.activeOrderId;
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await ref.read(sendProblemReportUseCaseProvider)(ref.read(currentUidProvider)!, orderId, state.kind);
      if (ref.mounted) state = state.copyWith(busy: false, sent: true);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }
}

final problemReportViewModelProvider = NotifierProvider<ProblemReportViewModel, ProblemReportState>(
  ProblemReportViewModel.new,
);
