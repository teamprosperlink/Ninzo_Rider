import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/repositories/stock_repository.dart';

/// Signal from the phone's network state.
class ConnectivitySignalRepository implements SignalRepository {
  final _connectivity = Connectivity();

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth);

  @override
  Future<bool> isOnline() async => _online(await _connectivity.checkConnectivity());

  @override
  Stream<bool> watchOnline() => _connectivity.onConnectivityChanged.map(_online).distinct();
}

/// Signal the demo switches by hand (the "Signal" pill on the stock screens).
class DemoSignalRepository implements SignalRepository {
  bool _online = true;
  final _changes = StreamController<bool>.broadcast();

  bool get online => _online;

  set online(bool value) {
    if (value == _online) return;
    _online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> watchOnline() => _changes.stream;

  void dispose() => _changes.close();
}
