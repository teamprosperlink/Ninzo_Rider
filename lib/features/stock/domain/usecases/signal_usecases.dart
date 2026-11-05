import '../repositories/stock_repository.dart';

/// Whether the phone has signal right now.
class CheckSignal {
  const CheckSignal(this._signal);

  final SignalRepository _signal;

  Future<bool> call() => _signal.isOnline();
}

/// Each change of signal, as it happens.
class WatchSignal {
  const WatchSignal(this._signal);

  final SignalRepository _signal;

  Stream<bool> call() => _signal.watchOnline();
}
