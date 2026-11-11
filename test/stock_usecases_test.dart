import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ninzo_rider/core/errors/app_exception.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';
import 'package:ninzo_rider/domain/usecases/shift_flow_usecases.dart';
import 'package:ninzo_rider/data/datasources/local/local_stock_stores.dart';
import 'package:ninzo_rider/domain/entities/scan_outcome.dart';
import 'package:ninzo_rider/domain/entities/stock.dart';
import 'package:ninzo_rider/domain/repositories/stock_repository.dart';
import 'package:ninzo_rider/domain/usecases/stock_usecases.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 11, 4, 14, 20);
  DateTime clock() => now;
  const uid = 'u1', shiftId = 'day';

  late FakeStockRepository repo;
  late FakeSignal signal;
  late StockScanStore store;
  late ProcessScan process;

  setUp(() {
    repo = FakeStockRepository();
    signal = FakeSignal();
    store = InMemoryStockScanStore();
    process = ProcessScan(repo, store, signal, clock);
  });

  Future<StockTally> tally() async => StockTally(testStockManifest, (await store.load(uid, shiftId)).scans);

  Future<ScanOutcome> scan(String code) async => process(uid, shiftId, await tally(), code);

  group('ScanCode', () {
    test('reads our labels only', () {
      final code = ScanCode.parse('NZ1|smash|B-2207|3')!;
      expect((code.itemId, code.lotId, code.portion), ('smash', 'B-2207', '3'));
      expect(code.raw, 'NZ1|smash|B-2207|3');
      for (final other in ['', 'hello', 'NZ1|smash|B-2207', 'XX|smash|B-2207|3', 'NZ1||B-2207|3']) {
        expect(ScanCode.parse(other), isNull, reason: other);
      }
    });
  });

  group('ProcessScan', () {
    test('adds a portion from the load', () async {
      final outcome = await scan(testCode('smash', 1));
      expect(outcome, isA<ScanAdded>().having((o) => o.offline, 'offline', false));
      expect((await tally()).count('smash'), 1);
    });

    test('rejects a label that is not ours, or an item not in the load', () async {
      expect(await scan('https://example.com'), isA<ScanNotOnList>());
      expect(await scan(testCode('dosa', 1)), isA<ScanNotOnList>());
      expect((await tally()).portionsLoaded, 0);
    });

    test('the same portion twice is a duplicate; a further portion is too many', () async {
      await scan(testCode('smash', 1));
      expect(await scan(testCode('smash', 1)), isA<ScanAlreadyScanned>());
      await scan(testCode('smash', 2));
      expect(await scan(testCode('smash', 3)), isA<ScanOverLoad>());
      expect(await scan(testCode('smash', 2)), isA<ScanAlreadyScanned>());
      expect((await tally()).count('smash'), 2);
    });

    test('an expired lot does not count', () async {
      repo.lots['old'] = StockLot(id: 'old', itemId: 'smash', expiresAt: now.subtract(const Duration(minutes: 30)));
      final outcome = await scan(testCode('smash', 1, 'old'));
      expect(outcome, isA<ScanLotExpired>().having((o) => o.now, 'now', now));
      expect((await tally()).portionsLoaded, 0);
    });

    test('a lot that got too warm does not count', () async {
      repo.lots['warm'] = const StockLot(id: 'warm', itemId: 'paneer', temperatureC: 12, maxTemperatureC: 8);
      expect(await scan(testCode('paneer', 1, 'warm')), isA<ScanLotTooWarm>());
      repo.lots['cool'] = const StockLot(id: 'cool', itemId: 'paneer', temperatureC: 8, maxTemperatureC: 8);
      expect(await scan(testCode('paneer', 1, 'cool')), isA<ScanAdded>());
    });

    test('without signal it saves the scan, checking the lots it has', () async {
      signal.online = false;
      final outcome = await scan(testCode('smash', 1));
      expect(outcome, isA<ScanAdded>().having((o) => o.offline, 'offline', true));

      final manifest = StockManifest(
        items: testStockManifest.items,
        lots: {'old': StockLot(id: 'old', itemId: 'smash', expiresAt: now.subtract(const Duration(minutes: 1)))},
      );
      expect(
        await process(uid, shiftId, StockTally(manifest, const []), testCode('fries', 1, 'old')),
        isA<ScanLotExpired>(),
      );
    });

    test('a failing lot check counts as no signal', () async {
      repo.failing = true;
      expect(await scan(testCode('smash', 1)), isA<ScanAdded>().having((o) => o.offline, 'offline', true));
      expect((await tally()).waitingToSync, 1);
    });
  });

  group('StockTally', () {
    test('counts portions and whole items', () async {
      expect((await tally()).allScanned, isFalse);
      for (final code in [
        testCode('smash', 1),
        testCode('smash', 2),
        testCode('paneer', 1),
        testCode('paneer', 2),
        testCode('fries', 1),
      ]) {
        await scan(code);
      }
      final partly = await tally();
      expect((partly.portionsLoaded, partly.portions), (5, 6));
      expect((partly.itemsLoaded, partly.items), (3, 4));
      await scan(testCode('coffee', 1));
      expect((await tally()).allScanned, isTrue);
    });
  });

  group('SaveManualCounts', () {
    test('adds what the counts add, kept to what was packed', () async {
      await scan(testCode('smash', 1));
      await SaveManualCounts(store, clock)(uid, shiftId, await tally(), {'smash': 5, 'paneer': 1, 'fries': -1});
      final t = await tally();
      expect((t.count('smash'), t.count('paneer'), t.count('fries')), (2, 1, 0));
      expect(t.scans.where((s) => s.method == ScanMethod.manual).length, 2);
    });
  });

  group('Sync and confirm', () {
    late FakeShiftRepository shifts;
    late SyncStockScans sync;
    late ConfirmStock confirm;

    Shift shift() => shifts.shift.value!;

    setUp(() {
      shifts = FakeShiftRepository();
      shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.scanning);
      sync = SyncStockScans(repo, store, RecordStockScans(shifts), clock);
      confirm = ConfirmStock(RecordStockScans(shifts), signal);
    });

    Future<StockTally> tallyFor() async => StockTally(testStockManifest, (await store.load(uid, shift().id)).scans);

    Future<void> scanAll() async {
      for (final code in [
        testCode('smash', 1),
        testCode('smash', 2),
        testCode('paneer', 1),
        testCode('paneer', 2),
        testCode('fries', 1),
        testCode('coffee', 1),
      ]) {
        await process(uid, shift().id, await tallyFor(), code);
      }
    }

    test('uploads what waits, once, and counts it on the shift', () async {
      await process(uid, shift().id, await tallyFor(), testCode('smash', 1));
      final local = await sync(uid, shift());
      expect(repo.uploaded.map((s) => s.code), [testCode('smash', 1)]);
      expect(shift().stock.scanned, 1);
      expect(local.lastSyncAt, now);
      expect(local.scans.single.synced, isTrue);
      await sync(uid, shift());
      expect(repo.uploaded.length, 1);
    });

    test('a failed sync leaves everything saved', () async {
      await process(uid, shift().id, await tallyFor(), testCode('smash', 1));
      repo.failing = true;
      await expectLater(sync(uid, shift()), throwsA(anything));
      expect((await tallyFor()).waitingToSync, 1);
      expect(shift().stock.scanned, 0);
    });

    test('sends quarantine requests', () async {
      const lot = StockLot(id: 'warm', itemId: 'paneer');
      await MoveLotToQuarantine(store, clock)(uid, shift().id, lot);
      await MoveLotToQuarantine(store, clock)(uid, shift().id, lot);
      await sync(uid, shift());
      expect(repo.quarantined, ['warm']);
      expect((await store.load(uid, shift().id)).quarantine, isEmpty);
    });

    test('Confirm needs every portion, synced, and signal', () async {
      await process(uid, shift().id, await tallyFor(), testCode('smash', 1));
      await expectLater(confirm(uid, shift(), await tallyFor()), throwsA(isA<AppException>()));

      await scanAll();
      await expectLater(confirm(uid, shift(), await tallyFor()), throwsA(isA<AppException>()), reason: 'not synced');

      await sync(uid, shift());
      signal.online = false;
      await expectLater(confirm(uid, shift(), await tallyFor()), throwsA(isA<AppException>()), reason: 'no signal');

      signal.online = true;
      await confirm(uid, shift(), await tallyFor());
      expect(shift().phase, ShiftPhase.stockLoaded);
      expect(shift().stock.scanned, 6);
      expect(await GoOnline(shifts, signal)(uid, shift()), GoOnlineResult.headToSpot);
    });
  });

  group('LoadStock', () {
    test('uses the phone’s copy without signal, and needs one the first time', () async {
      repo.failing = true;
      await expectLater(LoadStock(repo, store)(uid, shiftId), throwsA(isA<AppException>()));
      repo.failing = false;
      await LoadStock(repo, store)(uid, shiftId);
      repo.failing = true;
      final local = await LoadStock(repo, store)(uid, shiftId);
      expect(local.manifest!.items.length, 4);
    });

    test('adds scans uploaded earlier', () async {
      repo.uploaded.add(StockScan(code: testCode('smash', 1), itemId: 'smash', at: now, synced: true));
      final local = await LoadStock(repo, store)(uid, shiftId);
      expect(local.scans.single.synced, isTrue);
      final again = await LoadStock(repo, store)(uid, shiftId);
      expect(again.scans.length, 1);
    });
  });

  group('RepeatCodeFilter', () {
    test('a code held in view counts once; after a pause, again', () {
      var t = now;
      final filter = RepeatCodeFilter(() => t);
      expect(filter.accept('a'), isTrue);
      t = t.add(const Duration(seconds: 1));
      expect(filter.accept('a'), isFalse);
      expect(filter.accept('b'), isTrue);
      t = t.add(const Duration(seconds: 2));
      expect(filter.accept('a'), isFalse, reason: 'still in view');
      t = t.add(const Duration(seconds: 3));
      expect(filter.accept('a'), isTrue);
    });
  });

  group('PrefsStockScanStore', () {
    test('keeps everything across restarts, per rider and shift', () async {
      SharedPreferences.setMockInitialValues({});
      final prefsStore = PrefsStockScanStore();
      final state = StockLocalState(
        manifest: StockManifest(
          items: testStockManifest.items,
          lots: {
            'old': StockLot(id: 'old', itemId: 'smash', expiresAt: now, temperatureC: 4, maxTemperatureC: 8),
          },
        ),
        scans: [
          StockScan(code: 'a', itemId: 'smash', lotId: 'old', at: now),
          StockScan(code: 'b', itemId: 'fries', method: ScanMethod.manual, at: now, synced: true),
        ],
        quarantine: [QuarantineRequest(lotId: 'warm', itemId: 'paneer', at: now)],
        lastSyncAt: now,
      );
      await prefsStore.save(uid, shiftId, state);

      final loaded = await PrefsStockScanStore().load(uid, shiftId);
      expect(loaded.manifest!.items.map((i) => i.name), testStockManifest.items.map((i) => i.name));
      expect(loaded.manifest!.items.first.image, testStockManifest.items.first.image);
      expect(loaded.manifest!.lots['old']!.expiresAt, now);
      expect(loaded.manifest!.lots['old']!.temperatureC, 4);
      expect(loaded.scans.first.synced, isFalse);
      expect(loaded.scans.first.lotId, 'old');
      expect(loaded.scans.last.method, ScanMethod.manual);
      expect(loaded.scans.last.synced, isTrue);
      expect(loaded.quarantine.single.lotId, 'warm');
      expect(loaded.lastSyncAt, now);
      expect((await prefsStore.load('other', shiftId)).scans, isEmpty);
    });
  });
}
