import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../online/di/online_di.dart';
import '../../shift/di/shift_di.dart';
import '../../stock/di/stock_di.dart';
import '../domain/usecases/refill_usecases.dart';

final startRefillUseCaseProvider = Provider(
  (ref) => StartRefill(ref.watch(shiftRepositoryProvider), ref.watch(stockRepositoryProvider)),
);
final cancelRefillUseCaseProvider = Provider((ref) => CancelRefill(ref.watch(shiftRepositoryProvider)));
final finishRefillUseCaseProvider = Provider(
  (ref) => FinishRefill(ref.watch(shiftRepositoryProvider), ref.watch(onlineRepositoryProvider)),
);
final answerRestockUseCaseProvider = Provider(
  (ref) => AnswerRestock(ref.watch(onlineRepositoryProvider), ref.watch(startRefillUseCaseProvider)),
);
