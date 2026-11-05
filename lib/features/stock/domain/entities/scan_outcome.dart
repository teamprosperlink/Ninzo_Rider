import 'stock.dart';

/// What happened to a scanned code.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// On the scooter (Stock 02). With [offline], it waits to sync (Stock 13, 14).
class ScanAdded extends ScanOutcome {
  const ScanAdded(this.item, {this.offline = false});

  final StockItem item;
  final bool offline;
}

/// Not a label of ours, or not in today's load (Stock 04).
class ScanNotOnList extends ScanOutcome {
  const ScanNotOnList();
}

/// This very portion was scanned before (Stock 10).
class ScanAlreadyScanned extends ScanOutcome {
  const ScanAlreadyScanned(this.item);

  final StockItem item;
}

/// Another portion of an item whose count is already complete (Stock 11).
class ScanOverLoad extends ScanOutcome {
  const ScanOverLoad(this.item);

  final StockItem item;
}

/// The lot is past its expiry time (Stock 07).
class ScanLotExpired extends ScanOutcome {
  const ScanLotExpired(this.item, this.lot, this.now);

  final StockItem item;
  final StockLot lot;
  final DateTime now;
}

/// The lot got too warm (Stock 08).
class ScanLotTooWarm extends ScanOutcome {
  const ScanLotTooWarm(this.item, this.lot);

  final StockItem item;
  final StockLot lot;
}
