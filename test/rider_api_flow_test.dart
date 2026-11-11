import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:ninzo_rider/core/errors/app_exception.dart';
import 'package:ninzo_rider/data/datasources/local/local_handover_stores.dart';
import 'package:ninzo_rider/data/datasources/local/local_stock_stores.dart';
import 'package:ninzo_rider/data/datasources/remote/rider_api.dart';
import 'package:ninzo_rider/data/datasources/remote/rider_api_client.dart';
import 'package:ninzo_rider/data/datasources/remote/rider_api_session.dart';
import 'package:ninzo_rider/data/datasources/remote/rider_event_queue.dart';
import 'package:ninzo_rider/data/repositories/api_delivery_repository.dart';
import 'package:ninzo_rider/data/repositories/api_online_repository.dart';
import 'package:ninzo_rider/data/repositories/api_profile_repositories.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/rider_area.dart';
import 'package:ninzo_rider/domain/entities/rider_document.dart';
import 'package:ninzo_rider/data/repositories/api_route_repository.dart';
import 'package:ninzo_rider/data/repositories/api_shift_repository.dart';
import 'package:ninzo_rider/data/repositories/api_stock_repository.dart';
import 'package:ninzo_rider/domain/entities/delivery_order.dart';
import 'package:ninzo_rider/domain/entities/handover.dart';
import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/entities/order.dart' show OrderItem;
import 'package:ninzo_rider/domain/entities/problem_report.dart';
import 'package:ninzo_rider/domain/entities/restock.dart';
import 'package:ninzo_rider/domain/entities/scan_outcome.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';
import 'package:ninzo_rider/domain/entities/shift_end.dart';
import 'package:ninzo_rider/domain/entities/stock.dart';
import 'package:ninzo_rider/domain/usecases/handover_usecases.dart';
import 'package:ninzo_rider/domain/usecases/shift_end_usecases.dart';
import 'package:ninzo_rider/domain/usecases/stock_usecases.dart';

import 'fakes.dart';

class _Tokens implements RiderTokenStore {
  RiderTokens? saved = const RiderTokens(access: 'a', refresh: 'f', riderId: 'rdr_1', phone: '+919800000090');

  @override
  Future<RiderTokens?> read() async => saved;

  @override
  Future<void> write(RiderTokens tokens) async => saved = tokens;

  @override
  Future<void> clear() async => saved = null;
}

class _Fixes implements RiderFixSource {
  final controller = StreamController<RiderFix>.broadcast();

  @override
  Stream<RiderFix> fixes() => controller.stream;
}

/// The rider API as the mock server answers it, with what each test changes.
class _Server {
  final requests = <http.Request>[];
  Map<String, dynamic>? shift;
  List<Map<String, dynamic>> offers = [];
  Map<String, dynamic>? currentOrder;
  Map<String, dynamic>? restockRequest;
  List<Map<String, dynamic>> lots = [];
  List<Map<String, dynamic>> suggestions = [];
  Map<String, dynamic>? relocation;
  final errors = <String, (int, String, bool)>{};
  Map<String, dynamic> order = _order('RIDER_ACCEPTED');

  static Map<String, dynamic> _order(String state) => {
    'id': 'ord_0001',
    'offer_id': 'off_a1',
    'fencing_token': 'ft_1',
    'state': state,
    'ended_reason': null,
    'gate': {'id': 'g1', 'label': 'Main gate', 'lat': 12.9716, 'lng': 77.5946, 'entry_notes': 'Near the desk'},
    'items': [
      {'item_id': 'item_burger', 'name': 'Burger', 'qty': 2},
    ],
    'otp_available': false,
    'rider_accepted_at': '2026-11-11T06:00:00Z',
    'handed_over_at': null,
    'seq': 2,
    'timer_label': '1.5 mins',
  };

  List<Map<String, dynamic>> bodies(String path) => [
    for (final r in requests)
      if (r.url.path.endsWith(path) && r.method == 'POST') jsonDecode(r.body.isEmpty ? '{}' : r.body) as Map<String, dynamic>,
  ];

  http.Request? last(String path) => requests.lastWhere((r) => r.url.path.endsWith(path));

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path.replaceFirst('/v1', '');
    final error = errors[path];
    if (error != null) return _json(error.$1, {'code': error.$2, 'retryable': error.$3});
    return switch ((request.method, path)) {
      ('GET', '/riders/me') => _json(200, {'rider': _rider()}),
      ('PATCH', '/riders/me') => () {
        riderFields = {...riderFields, ...jsonDecode(request.body) as Map<String, dynamic>};
        return _json(200, {'rider': _rider()});
      }(),
      ('GET', '/riders/me/shift-plan') => _json(200, {'plan': plan}),
      ('POST', '/riders/me/shift-plan/reply') when plan == null => _json(404, {'code': 'not_found', 'retryable': false}),
      ('POST', '/riders/me/shift-plan/reply') => _json(200, {
        'plan': plan = {...plan!, 'stock_reply': jsonDecode(request.body)['reply'], 'replied_at': '2026-11-11T06:00:00Z'},
      }),
      ('GET', '/riders/me/notifications') => _json(200, {'notifications': notifications}),
      ('POST', '/riders/me/stock/lot_1/quarantine') => () {
        lots = [
          for (final lot in lots)
            if (lot['lot_id'] != 'lot_1') lot,
        ];
        return _json(200, {'lot_id': 'lot_1', 'quarantined_at': '2026-11-11T06:00:00Z'});
      }(),
      ('GET', '/riders/me/state') => _json(200, {
        'shift': shift,
        'offers': offers,
        'current_order': currentOrder,
        'restock_request': restockRequest,
        'seq': requests.length,
      }),
      ('GET', '/nodes') => _json(200, {
        'assigned_node_id': 'node_7',
        'nodes': [
          {'id': 'node_7', 'name': 'Node 7', 'lat': 12.97, 'lng': 77.59, 'fullness_pct': 40, ...node7Fields},
          {'id': 'node_8', 'name': 'Node 8', 'lat': 12.98, 'lng': 77.60, 'fullness_pct': 10},
        ],
        'relocation': relocation,
      }),
      ('GET', '/riders/me/stock') => _json(200, {'lots': lots}),
      ('GET', '/riders/me/earnings') => _json(200, {
        'date': request.url.queryParameters['date'],
        'orders': 1,
        'order_earnings': [
          {'order_id': 'ord_0001', 'amount': {'amount_minor': 4000, 'currency': 'INR'}},
        ],
        'incentives': {'amount_minor': 1000, 'currency': 'INR'},
        'repositioning': {'amount_minor': 2000, 'currency': 'INR'},
        'repositioning_seconds': 600,
        'total': {'amount_minor': 7000, 'currency': 'INR'},
      }),
      ('GET', '/riders/me/restock-suggestions') => _json(200, {'suggestions': suggestions}),
      ('GET', '/restock/options') => _json(200, {
        'hubs': [
          {'id': 'hub_2', 'name': 'Hub 2', ...hubFields},
        ],
        'items': [
          {'item_id': 'item_burger', 'name': 'Burger'},
        ],
      }),
      ('GET', '/orders/ord_0001') => _json(200, {'order': order}),
      ('GET', '/riders/me/offers') => _json(200, {'offers': listed}),
      ('GET', '/restock/rst_9') => _json(200, {'request': {...?restockRequest, 'slot_at': '2026-11-11T06:20:00Z'}}),
      ('POST', '/restock') => _json(201, {
        'request': restockRequest = {
          'id': 'rst_9',
          'state': 'confirmed',
          'hub': {'id': 'hub_2', 'name': 'Hub 2'},
          'items': jsonDecode(request.body)['items'],
          'slot_at': null,
          'arrive_by': null,
          'lot_numbers': [],
          'shortfall': null,
        },
      }),
      ('GET', '/orders/ord_0001/route') => _json(200, {'polyline': '_p~iF~ps|U_ulLnnqC', 'eta_source': 'estimated', 'eta_s': null}),
      ('POST', '/riders/me/verification/start') => _json(200, {'redirect_url': null, 'upload_url': 'https://upload.test/1'}),
      ('GET', '/riders/me/verification') => _json(200, {'status': verification, 'reason': null}),
      ('POST', '/riders/me/shifts/start') => _json(200, {
        'shift': shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null},
      }),
      ('POST', '/riders/me/shifts/end') => _json(200, {
        'shift': {...?shift, 'ended_at': '2026-11-11T13:00:00Z'},
      }),
      ('POST', '/riders/me/stock/scan') => () {
        lots = [
          ...lots,
          {'lot_id': 'lot_1', 'item_id': 'item_burger', 'qty': 6, 'expiry': '2026-11-11T10:00:00Z', 'temp_status': 'ok'},
        ];
        return _json(200, {
          'unit': {'lot_id': 'lot_1', 'item_id': 'item_burger', 'expiry': '2026-11-11T10:00:00Z', 'temp_status': temp},
        });
      }(),
      ('POST', '/offers/off_a1/accept') => _json(200, {'order': order = _order('RIDER_ACCEPTED')}),
      ('POST', '/offers/off_a1/decline') => _json(200, {}),
      ('POST', '/offers/off_a1/ready') => _json(200, {'order': order = _order('PACKED')}),
      ('POST', '/orders/ord_0001/call') => _json(200, {'phone': '+911140000000', 'expires_at': '2026-11-11T07:00:00Z'}),
      ('POST', '/orders/ord_0001/handover') => _json(200, {'order': order = _order('HANDED_OVER')}),
      ('POST', '/riders/me/events') when eventResult != null => _json(
        200,
        eventResult!(jsonDecode(request.body)['events'] as List),
      ),
      ('POST', '/riders/me/events') => _json(200, {
        'accepted_ids': [
          for (final e in (jsonDecode(request.body)['events'] as List)) e['event_id'],
        ],
        'rejected': [],
      }),
      ('POST', '/riders/me/location') => _json(200, {'next_ping_s': 3}),
      ('POST', '/riders/me/problems') => _json(200, {'report_id': 'rep_1'}),
      ('POST', '/riders/me/relocations/rel_1/accept') => _json(200, {}),
      ('POST', '/restock/rst_1/confirm') => _json(200, {}),
      ('POST', '/restock/rst_1/decline') => _json(200, {}),
      ('POST', '/restock/rst_1/shortfall-response') => _json(200, {}),
      _ => _json(404, {'code': 'not_found', 'retryable': false}),
    };
  });

  List<Map<String, dynamic>> listed = [];

  /// Fields a test adds to the rider and to Node 7 (the backend's #158
  /// fields); `PATCH /riders/me` adds to the rider's too.
  Map<String, dynamic> riderFields = {};
  Map<String, dynamic> node7Fields = {};
  Map<String, dynamic> hubFields = {};

  /// Today's shift plan (`GET /riders/me/shift-plan`), and the notifications.
  Map<String, dynamic>? plan;
  List<Map<String, dynamic>> notifications = [];

  Map<String, dynamic> _rider() => {
    'id': 'rdr_1',
    'name': riderStatus == 'applicant' ? null : 'Ravi',
    'status': riderStatus,
    'zone_id': 'zone_1',
    'email': null,
    'area': null,
    ...riderFields,
  };
  String riderStatus = 'active';
  String temp = 'ok';
  String verification = 'verified';
  Map<String, dynamic> Function(List<dynamic> sent)? eventResult;

  static http.Response _json(int status, Object body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

Map<String, dynamic> _offer(String id) => {
  'id': id,
  'fencing_token': 'ft_1',
  'state': 'open',
  'expires_at': '2099-01-01T00:00:00Z',
  'order_id': null,
  'gate': {'id': 'g1', 'label': 'Main gate', 'lat': 12.9716, 'lng': 77.5946, 'entry_notes': 'Near the desk'},
  'items': [
    {'item_id': 'item_burger', 'name': 'Burger', 'qty': 2},
  ],
};

void main() {
  late _Server server;
  late RiderApiSession session;
  late _Fixes fixes;
  late MemoryRiderEventStore queued;
  late StreamController<bool> signal;
  late StreamController<Map<String, dynamic>> live;
  final now = DateTime.utc(2026, 11, 11, 6);
  var later = Duration.zero;

  setUp(() {
    later = Duration.zero;
    server = _Server();
    fixes = _Fixes();
    queued = MemoryRiderEventStore();
    signal = StreamController<bool>.broadcast();
    live = StreamController<Map<String, dynamic>>.broadcast();
    session = RiderApiSession(
      RiderApi(RiderApiClient(client: server.client, tokens: _Tokens(), baseUrl: () async => 'https://api.test/v1')),
      store: MemoryRiderDayStore(),
      fixes: fixes,
      eventStore: queued,
      signal: signal.stream,
      clock: () => now.add(later),
      pollEvery: const Duration(hours: 1),
      liveStream: () => live.stream,
    );
  });

  tearDown(() => session.dispose());

  group('Shift', () {
    test('Starts at the assigned node, with nothing to request or pack', () async {
      final shifts = ApiShiftRepository(session);
      final shift = (await shifts.watchToday('rdr_1').first)!;
      expect(server.last('/nodes')!.url.queryParameters['zone_id'], 'zone_1');
      expect(shift.phase, ShiftPhase.notStarted);
      expect(shift.stockRequest, StockRequestStatus.ready);
      expect(shift.hub.name, 'Node 7');
      expect(shift.spot.point, const LatLng(12.97, 77.59));
    });

    test('Arriving at the node starts the shift there and goes on to scanning', () async {
      final shifts = ApiShiftRepository(session);
      await session.ensureLoaded();
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.headingToHub);
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.atHub);
      expect(server.bodies('/shifts/start').single, {'node_id': 'node_7'});
      expect(server.last('/shifts/start')!.headers['Idempotency-Key'], isNotNull);
      expect((await shifts.watchToday('rdr_1').first)!.phase, ShiftPhase.scanning);
    });

    test('A rider who may not start stays where they are', () async {
      server.errors['/riders/me/shifts/start'] = (409, 'rider_not_verified', false);
      final shifts = ApiShiftRepository(session);
      await session.ensureLoaded();
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.headingToHub);
      await expectLater(shifts.setPhase('rdr_1', 'd', ShiftPhase.atHub), throwsA(isA<AppException>()));
      expect((await shifts.watchToday('rdr_1').first)!.phase, ShiftPhase.headingToHub);
    });

    test('An open shift on the server picks up at scanning', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      final shift = (await ApiShiftRepository(session).watchToday('rdr_1').first)!;
      expect(shift.phase, ShiftPhase.scanning);
      expect(shift.start, DateTime.utc(2026, 11, 11, 5).toLocal());
    });

    test("Ending with an order on shows \"Can't end shift yet\"", () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.errors['/riders/me/shifts/end'] = (409, 'order_in_progress', false);
      final shifts = ApiShiftRepository(session);
      final shift = (await shifts.watchToday('rdr_1').first)!;
      final end = EndShift(shifts, ApiOnlineRepository(session), ApiShiftSessionRepository(session));
      expect(await end('rdr_1', shift, const OnlineStatus()), EndShiftResult.orderInProgress);
      server.errors.clear();
      expect(await end('rdr_1', shift, const OnlineStatus()), EndShiftResult.ended);
      expect(server.bodies('/shifts/end'), hasLength(2));
    });

    test('What was on the scooter at the end is "Returned to hub"', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.lots = [
        {'lot_code': 'L1', 'item_id': 'item_burger', 'qty': 7},
      ];
      final shifts = ApiShiftRepository(session);
      await session.ensureLoaded();
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.ended);
      server.lots = [];
      await session.refresh(full: true);
      final shift = (await shifts.watchToday('rdr_1').first)!;
      final status = await ApiOnlineRepository(session).watch('rdr_1', 'd').first;
      expect(ShiftTotals.of(shift, status, now).left, 7);
    });

    test('A failed verification starts again by hand', () async {
      server.verification = 'failed';
      await expectLater(ApiShiftSessionRepository(session).claim('rdr_1', 'd'), throwsA(isA<AppException>()));
      expect(server.bodies('/riders/me/verification/start').single, {'method': 'manual_upload'});
      expect(session.verificationNext!['upload_url'], 'https://upload.test/1');
    });

    test('Request hub to prepare asks the hub for the item running lowest', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.lots = [
        {'lot_code': 'L1', 'item_id': 'item_burger', 'qty': 3},
      ];
      final shifts = ApiShiftRepository(session);
      await session.ensureLoaded();
      await shifts.setRefill('rdr_1', 'd', refill: const RefillLoad(hubName: 'Hub 2'), round: 1, phase: ShiftPhase.atHub);
      expect(server.bodies('/v1/restock').single, {
        'hub_id': 'hub_2',
        'items': [
          {'item_id': 'item_burger', 'qty': ScooterStock.lowStockAt},
        ],
      });
      // The request is open now: a second refill asks for nothing more.
      await shifts.setRefill('rdr_1', 'd', refill: const RefillLoad(hubName: 'Hub 2'), round: 2, phase: ShiftPhase.atHub);
      expect(server.bodies('/v1/restock'), hasLength(1));
    });

    test('Only a verified rider can start riding', () async {
      final sessions = ApiShiftSessionRepository(session);
      await sessions.claim('rdr_1', 'd');
      server.verification = 'pending';
      await expectLater(sessions.claim('rdr_1', 'd'), throwsA(isA<AppException>()));
    });
  });

  group('Online', () {
    test('Open offers are the queue; Start order accepts with the fencing token', () async {
      server.offers = [_offer('off_a1')];
      final online = ApiOnlineRepository(session);
      final status = await online.watch('rdr_1', 'd').first;
      expect(status.queue.single.id, 'off_a1');
      expect(status.queue.single.number, 'A1');
      expect(status.queue.single.items, 2);
      expect(status.earned, 70);
      expect(status.earnings!.orderPay, 40);
      expect(status.earnings!.incentives, 10);
      expect(status.earnings!.repositionMinutes, 10);
      expect(server.last('/earnings')!.url.queryParameters['date'], '2026-11-11');

      await online.startOrder('rdr_1', 'd', status.queue.single);
      expect(server.bodies('/offers/off_a1/accept').single, {'fencing_token': 'ft_1'});
      final after = await online.watch('rdr_1', 'd').first;
      expect(after.activeOrderId, 'ord_0001');
      expect(after.queue, isEmpty);
    });

    test('A relocation suggestion is the nudge; taking it accepts the move', () async {
      server.relocation = {'id': 'rel_1', 'node_id': 'node_8', 'reason': '3 orders expected, nobody nearby', 'expires_at': '2099-01-01T00:00:00Z'};
      final online = ApiOnlineRepository(session);
      final nudge = (await online.watch('rdr_1', 'd').first).nudge!;
      expect(nudge.spot.name, 'Node 8');
      expect(nudge.ordersWaiting, 3);
      await online.setNudge('rdr_1', 'd', nudge.accepted(now));
      expect(server.requests.where((r) => r.url.path.endsWith('/relocations/rel_1/accept')), hasLength(1));
      expect((await online.watch('rdr_1', 'd').first).nudge!.stage, NudgeStage.accepted);
    });

    test('A restock suggestion is confirmed with the rider\'s quantities', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.suggestions = [
        {
          'id': 'rst_1',
          'expires_at': '2099-01-01T00:00:00Z',
          'hub': {'id': 'hub_2', 'name': 'Hub 2'},
          'items': [
            {'item_id': 'item_burger', 'name': 'Burger', 'qty': 4, 'filled_qty': null},
          ],
        },
      ];
      final online = ApiOnlineRepository(session);
      final restock = (await online.watch('rdr_1', 'd').first).restock!;
      expect(restock.stage, RestockStage.suggested);
      expect(restock.hubName, 'Hub 2');
      await online.setRestock(
        'rdr_1',
        'd',
        restock.copyWith(stage: RestockStage.inProgress, lines: [restock.lines.single.withQuantity(3)]),
      );
      expect(server.bodies('/restock/rst_1/confirm').single, {
        'quantity_override': [
          {'item_id': 'item_burger', 'qty': 3},
        ],
      });
    });
  });

  group('Profile', () {
    test("The rider's name, number and node come from the API; an active rider is approved", () async {
      final application = await ApiRegistrationRepository(session).watch('rdr_1').first;
      expect(application!.name, 'Ravi');
      expect(application.phone, '+919800000090');
      expect(application.status, RegistrationStatus.approved);
      expect(application.isActive, isTrue);
      expect(application.spotName, 'Node 7');
      expect(server.requests.where((r) => r.url.path.endsWith('/riders/me/verification')), hasLength(1));
    });

    test('A failed verification shows on the documents', () async {
      server.verification = 'failed';
      final application = await ApiRegistrationRepository(session).watch('rdr_1').first;
      expect(application!.status, RegistrationStatus.failed);
      expect(application.issues, isNotEmpty);
    });

    test('An applicant gives their details first; they go to PATCH /riders/me', () async {
      server.riderStatus = 'applicant';
      final registration = ApiRegistrationRepository(session);
      final seen = <RiderApplication?>[];
      final sub = registration.watch('rdr_1').listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, isNull);
      await registration.saveDetails(
        uid: 'rdr_1',
        phone: '+919800000090',
        name: 'Asha Rao',
        area: const RiderArea(id: 'a1', name: 'Yelahanka', city: 'Bengaluru', latitude: 13.1, longitude: 77.59),
      );
      await pumpEventQueue();
      final patch = server.requests.lastWhere((r) => r.method == 'PATCH');
      expect(jsonDecode(patch.body), {
        'name': 'Asha Rao',
        'area': {'name': 'Yelahanka', 'city': 'Bengaluru', 'lat': 13.1, 'lng': 77.59},
      });
      expect(patch.headers['Idempotency-Key'], isNotNull);
      expect(seen.last!.name, 'Asha Rao');
      expect(seen.last!.area.name, 'Yelahanka');
      expect(seen.last!.area.latitude, 13.1);
      expect(seen.last!.status, RegistrationStatus.draft);
      await sub.cancel();
    });

    test('An area without a place is not sent', () async {
      server.riderStatus = 'applicant';
      final registration = ApiRegistrationRepository(session);
      await registration.watch('rdr_1').first;
      await expectLater(
        registration.saveDetails(
          uid: 'rdr_1',
          phone: '+919800000090',
          name: 'Asha Rao',
          area: const RiderArea(id: 'a1', name: 'Yelahanka', city: 'Bengaluru'),
        ),
        throwsA(isA<AppException>()),
      );
      expect(server.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    test('Send for review starts the verification and uploads each photo', () async {
      server.riderStatus = 'applicant';
      final photo = File('${Directory.systemTemp.path}/ninzo_test_photo.jpg')..writeAsBytesSync([1, 2, 3]);
      final uploads = <http.BaseRequest>[];
      final registration = ApiRegistrationRepository(
        session,
        client: MockClient.streaming((request, _) async {
          uploads.add(request);
          return http.StreamedResponse(Stream.value([]), 201);
        }),
      );
      await registration.watch('rdr_1').first;
      await registration.saveDetails(
        uid: 'rdr_1',
        phone: '+919800000090',
        name: 'Asha Rao',
        area: const RiderArea(id: 'a1', name: 'Yelahanka', city: 'Bengaluru', latitude: 13.1, longitude: 77.59),
      );
      await registration.saveDocuments('rdr_1', {
        RiderDocument.selfie: DocumentUpload(files: {DocumentSide.photo: photo.path}),
      });
      await registration.submit('rdr_1');
      expect(server.bodies('/riders/me/verification/start').single, {'method': 'manual_upload'});
      expect(uploads.single.url.toString(), 'https://upload.test/1');
      final application = await registration.watch('rdr_1').first;
      expect(application!.status, RegistrationStatus.underReview);
    });

    test('Notifications come from GET /riders/me/notifications, newest first', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.notifications = [
        {'id': 'n2', 'kind': 'orders_waiting', 'title': 'Orders waiting at Node 8', 'body': 'Paid time.', 'created_at': '2026-11-11T05:30:00Z'},
        {'id': 'n1', 'kind': 'spot_assigned', 'title': 'Spot assigned · Node 7', 'body': 'Head there.', 'created_at': '2026-11-11T05:00:00Z'},
      ];
      final notes = await ApiProfileRepository(session).watchNotifications('rdr_1').first;
      expect([for (final n in notes) n.title], ['Orders waiting at Node 8', 'Spot assigned · Node 7']);
      expect(notes.last.at, DateTime.utc(2026, 11, 11, 5).toLocal());
      // The phone makes none of its own.
      server.notifications = [];
      await session.refresh(full: true);
      expect(await ApiProfileRepository(session).watchNotifications('rdr_1').first, isEmpty);
    });

    test("My shifts: each day's orders and pay from the earnings", () async {
      await session.ensureLoaded();
      await session.setDay({'onlineAt': '2026-11-11T05:30:00Z'});
      final records = await ApiProfileRepository(session).watchShifts('rdr_1').first;
      // The fake server pays 1 order, ₹70, on every day asked.
      expect(records, hasLength(7));
      expect(records.first.orders, 1);
      expect(records.first.earned, 70);
      expect(records.first.onlineAt, DateTime.utc(2026, 11, 11, 5, 30).toLocal());
      expect(records[1].endedAt, records[1].onlineAt);
    });
  });

  group('Live', () {
    test('An offer on the live stream is fetched at once', () async {
      final online = ApiOnlineRepository(session);
      final seen = <OnlineStatus>[];
      final sub = online.watch('rdr_1', 'd').listen(seen.add);
      await pumpEventQueue();
      expect(seen.last.queue, isEmpty);
      server.listed = [_offer('off_b2')];
      live.add({'type': 'offer', 'seq': 99});
      await pumpEventQueue();
      expect(server.requests.where((r) => r.url.path.endsWith('/riders/me/offers')), hasLength(1));
      expect(seen.last.queue.single.id, 'off_b2');
      await sub.cancel();
    });

    test('A heartbeat with a new seq polls the state', () async {
      final sub = ApiOnlineRepository(session).watch('rdr_1', 'd').listen((_) {});
      await pumpEventQueue();
      final before = server.requests.where((r) => r.url.path.endsWith('/riders/me/state')).length;
      live.add({'type': 'heartbeat', 'seq': 12345});
      await pumpEventQueue();
      expect(server.requests.where((r) => r.url.path.endsWith('/riders/me/state')).length, before + 1);
      await sub.cancel();
    });

    test("An open restock request shows the hub's queue slot", () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.restockRequest = {
        'id': 'rst_9',
        'state': 'hub_accepted',
        'hub': {'id': 'hub_2', 'name': 'Hub 2'},
        'items': [
          {'item_id': 'item_burger', 'name': 'Burger', 'qty': 4, 'filled_qty': null},
        ],
        'slot_at': null,
        'arrive_by': null,
      };
      final restock = (await ApiOnlineRepository(session).watch('rdr_1', 'd').first).restock!;
      expect(server.requests.where((r) => r.url.path.endsWith('/restock/rst_9')), isNotEmpty);
      expect(restock.readyAt, DateTime.utc(2026, 11, 11, 6, 20).toLocal());
    });
  });

  group('Order', () {
    late ApiOnlineRepository online;
    late ApiDeliveryRepository delivery;

    Future<DeliveryOrder> accepted() async {
      server.offers = [_offer('off_a1')];
      online = ApiOnlineRepository(session);
      delivery = ApiDeliveryRepository(session);
      await online.startOrder('rdr_1', 'd', (await online.watch('rdr_1', 'd').first).queue.single);
      return (await delivery.watchOrder('ord_0001').first)!;
    }

    test('Packs while stopped, then Ready sets off', () async {
      final order = await accepted();
      expect(order.status, DeliveryStatus.assigned);
      expect(order.gate.name, 'Main gate');
      expect(order.items.single.quantity, 2);
      expect(order.payment, OrderPayment.upi);
      await delivery.startNavigation(order.id);
      expect(server.bodies('/offers/off_a1/ready').single, {'fencing_token': 'ft_1'});
      final riding = (await delivery.watchOrder(order.id).first)!;
      expect(riding.status, DeliveryStatus.onTheWay);
      expect(riding.assignedAt, now);
    });

    test("Without Google the route is the API's", () async {
      await accepted();
      final step = await ApiRouteRepository(session).nextStep(const LatLng(38.5, -120.2), const LatLng(40.7, -120.95));
      expect(server.requests.where((r) => r.url.path.endsWith('/orders/ord_0001/route')), hasLength(1));
      expect(step.path, isNotEmpty);
      expect(step.totalKm, greaterThan(0));
    });

    test('Ready while moving is refused', () async {
      final order = await accepted();
      server.errors['/offers/off_a1/ready'] = (409, 'rider_moving', false);
      await expectLater(delivery.startNavigation(order.id), throwsA(isA<AppException>()));
    });

    test('Hands over with the OTP and the quantities', () async {
      final order = await accepted();
      final done = await delivery.completeHandover(
        HandoverRequest(
          orderId: order.id,
          proof: HandoverProof.code,
          code: '4821',
          items: const [OrderItem(name: 'Burger', quantity: 1)],
        ),
      );
      expect(done, isTrue);
      final body = server.bodies('/orders/ord_0001/handover').single;
      expect(body['otp'], '4821');
      expect(body['quantities'], [
        {'item_id': 'item_burger', 'qty': 1},
      ]);
      expect((await delivery.watchOrder(order.id).first)!.status, DeliveryStatus.delivered);
    });

    test('The shift summary counts what was sold and how long it took; times outlive a restart', () async {
      final order = await accepted();
      await delivery.startNavigation(order.id);
      later = const Duration(seconds: 90);
      await delivery.completeHandover(
        HandoverRequest(orderId: order.id, proof: HandoverProof.code, code: '4821', items: const [OrderItem(name: 'Burger', quantity: 2)]),
      );
      await pumpEventQueue();
      final status = await online.watch('rdr_1', 'd').first;
      expect(status.sold, 2);
      expect(status.averageDeliverySeconds, 90);
      // A restart forgets what was in memory; the day keeps the ride's start.
      session.rideStartedAt.clear();
      expect(session.rideStartOf(order.id), now.toLocal());
    });

    test('A wrong OTP is Handover 04', () async {
      final order = await accepted();
      server.errors['/orders/ord_0001/handover'] = (409, 'wrong_otp', false);
      final done = await delivery.completeHandover(
        HandoverRequest(orderId: order.id, proof: HandoverProof.code, code: '0000', items: const [OrderItem(name: 'Burger', quantity: 2)]),
      );
      expect(done, isFalse);
    });

    test('Without a connection the handover is saved, then sent with the event batch under the same id', () async {
      final order = await accepted();
      server.errors['/orders/ord_0001/handover'] = (503, 'service_unavailable', true);
      final store = InMemoryHandoverStore();
      final complete = CompleteHandover(delivery, store, FakeSignal(), () => now);
      final outcome = await complete.byCode('rdr_1', order, '4821', const [OrderItem(name: 'Burger', quantity: 2)]);
      expect(outcome, HandoverOutcome.savedOffline);
      final key = server.last('/orders/ord_0001/handover')!.headers['Idempotency-Key'];

      final saved = (await store.load('rdr_1')).saved.single;
      await store.save('rdr_1', HandoverLocalState(saved: [saved.asReleased()]));
      expect(await SyncSavedHandovers(delivery, store, () => now)('rdr_1'), 1);
      final event = (server.bodies('/riders/me/events').single['events'] as List).single as Map<String, dynamic>;
      expect(event['type'], 'handover');
      expect(event['event_id'], key);
      expect(event['payload'], {
        'order_id': 'ord_0001',
        'otp': '4821',
        'quantities': [
          {'item_id': 'item_burger', 'qty': 2},
        ],
      });
      expect(server.last('/riders/me/events')!.headers.containsKey('Idempotency-Key'), isFalse);
      expect((await store.load('rdr_1')).saved, isEmpty);
    });

    test("Order 04 declines the offer; the masked number is the customer's", () async {
      final order = await accepted();
      await delivery.skip(order.id, SkipReason.notSafe);
      expect(server.bodies('/offers/off_a1/decline').single, {'fencing_token': 'ft_1', 'reason': 'notSafe'});
      expect((await delivery.watchOrder(order.id).first)!.status, DeliveryStatus.skipped);

      server.currentOrder = server.order = {..._Server._order('TIMER_RUNNING')};
      await session.refresh();
      await pumpEventQueue();
      expect(session.customerPhones['ord_0001'], '+911140000000');
    });

    test('ARRIVED is at the gate, CANCELLED shows the cancellation', () async {
      await accepted();
      server.currentOrder = server.order = _Server._order('ARRIVED');
      await session.refresh();
      expect((await delivery.watchOrder('ord_0001').first)!.status, DeliveryStatus.atGate);
      server.currentOrder = null;
      server.order = _Server._order('CANCELLED');
      await session.refresh();
      expect((await delivery.watchOrder('ord_0001').first)!.status, DeliveryStatus.cancelled);
    });

    test('Problems go to the API', () async {
      await ApiProblemReportRepository(session).send(
        ProblemReport(riderId: 'rdr_1', orderId: 'ord_0001', kind: ProblemKind.gateClosed, at: now),
      );
      expect(server.bodies('/riders/me/problems').single, {'type': 'gate_closed', 'order_id': 'ord_0001'});
    });
  });

  group('Stock', () {
    late ApiStockRepository stock;
    late InMemoryStockScanStore store;
    late ProcessScan scan;

    setUp(() {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      stock = ApiStockRepository(session);
      store = InMemoryStockScanStore();
      scan = ProcessScan(stock, store, FakeSignal(), () => now, stock);
    });

    test('A scan loads the whole lot; the load is what has been scanned', () async {
      final local = await LoadStock(stock, store)('rdr_1', '2026-11-11');
      expect(local.manifest!.items, isEmpty);
      expect(local.manifest!.open, isTrue);
      final outcome = await scan('rdr_1', '2026-11-11', StockTally(local.manifest!, local.scans), 'LOT-CODE-1');
      expect(server.bodies('/riders/me/stock/scan').single, {'lot_code': 'LOT-CODE-1', 'scanned_at': '2026-11-11T06:00:00.000Z'});
      expect((outcome as ScanAdded).item.name, 'Burger');
      final saved = await store.load('rdr_1', '2026-11-11');
      final tally = StockTally(saved.manifest!, saved.scans);
      expect(tally.portionsLoaded, 6);
      expect(tally.allScanned, isTrue);
      expect(tally.waitingToSync, 0);
    });

    test('A temperature alert is the quarantine prompt; refusals are their warnings', () async {
      server.temp = 'alert';
      const empty = StockTally(StockManifest(items: [], open: true), []);
      expect(await scan('rdr_1', '2026-11-11', empty, 'LOT-CODE-1'), isA<ScanLotTooWarm>());
      server.errors['/riders/me/stock/scan'] = (409, 'lot_expired', false);
      expect(await scan('rdr_1', '2026-11-11', empty, 'LOT-CODE-2'), isA<ScanLotExpired>());
      server.errors['/riders/me/stock/scan'] = (409, 'lot_not_expected', false);
      expect(await scan('rdr_1', '2026-11-11', empty, 'LOT-CODE-3'), isA<ScanNotOnList>());
      server.errors['/riders/me/stock/scan'] = (409, 'no_open_shift', false);
      await expectLater(scan('rdr_1', '2026-11-11', empty, 'LOT-CODE-4'), throwsA(isA<AppException>()));
    });
  });

  group('Offline events', () {
    const down = (503, 'service_unavailable', true);

    test('A problem, a lot scan, a restock answer and a ping that fail are queued, then sent in order', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.suggestions = [
        {
          'id': 'rst_1',
          'expires_at': '2099-01-01T00:00:00Z',
          'hub': {'id': 'hub_2', 'name': 'Hub 2'},
          'items': [
            {'item_id': 'item_burger', 'name': 'Burger', 'qty': 4, 'filled_qty': null},
          ],
        },
      ];
      await session.ensureLoaded();
      server.errors
        ..['/riders/me/problems'] = down
        ..['/riders/me/stock/scan'] = down
        ..['/restock/rst_1/confirm'] = down
        ..['/riders/me/location'] = down
        // No signal at all: the polls and the batch don't get through either.
        ..['/riders/me/state'] = down
        ..['/riders/me/events'] = down;

      // The rider sees the report as sent.
      await ApiProblemReportRepository(session).send(
        ProblemReport(riderId: 'rdr_1', orderId: 'ord_0001', kind: ProblemKind.breakdown, at: now),
      );
      await expectLater(
        ApiStockRepository(session).scanLot('rdr_1', '2026-11-11', 'LOT-9', now),
        throwsA(isA<AppException>()),
      );
      final online = ApiOnlineRepository(session);
      final restock = (await online.watch('rdr_1', 'd').first).restock!;
      server.errors['/riders/me/restock-suggestions'] = down;
      await online.setRestock('rdr_1', 'd', restock.copyWith(stage: RestockStage.inProgress));
      expect((await online.watch('rdr_1', 'd').first).restock, isNull, reason: 'answered, waiting on the phone');
      fixes.controller.add(RiderFix(point: const LatLng(12.9, 77.5), speedMps: 2, accuracyM: 5, at: now));
      await pumpEventQueue();

      final waiting = queued.events;
      expect([for (final e in waiting) e['type']], ['problem', 'stock_scan', 'restock_confirm', 'location']);
      expect(waiting[0]['payload'], {'problem_type': 'breakdown', 'order_id': 'ord_0001'});
      expect(waiting[1]['payload'], {'lot_code': 'LOT-9'});
      expect(waiting[2]['payload'], {
        'request_id': 'rst_1',
        'quantity_override': [
          {'item_id': 'item_burger', 'qty': 4},
        ],
      });
      expect(waiting[3]['payload'], {'lat': 12.9, 'lng': 77.5, 'speed_mps': 2.0, 'accuracy_m': 5.0});
      for (final e in waiting) {
        expect(e['event_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,128}$')));
        expect(e['device_time'], isNotNull);
      }
      // The direct calls carried the event's id as their key.
      expect(server.last('/riders/me/problems')!.headers['Idempotency-Key'], waiting[0]['event_id']);
      expect(server.last('/riders/me/stock/scan')!.headers['Idempotency-Key'], waiting[1]['event_id']);
      expect(server.last('/restock/rst_1/confirm')!.headers['Idempotency-Key'], waiting[2]['event_id']);

      // Signal back: one batch, in order.
      server.errors.clear();
      signal.add(true);
      await pumpEventQueue();
      final batch = server.bodies('/riders/me/events').single['events'] as List;
      expect([for (final e in batch) e['event_id']], [for (final e in waiting) e['event_id']]);
      expect(queued.events, isEmpty);
    });

    test('Retryable rejections stay for the next try; others are dropped', () async {
      final events = session.events;
      await events.add(events.event('problem', {'problem_type': 'accident'}, id: 'ev-keep-0001'));
      await events.add(events.event('stock_scan', {'lot_code': 'L1'}, id: 'ev-drop-0002'));
      await events.add(events.event('location', {'lat': 1, 'lng': 2, 'speed_mps': 0, 'accuracy_m': 0}, id: 'ev-ok-00003'));
      server.eventResult = (sent) => {
        'accepted_ids': ['ev-ok-00003'],
        'rejected': [
          {'id': 'ev-keep-0001', 'code': 'busy', 'message': '', 'retryable': true},
          {'id': 'ev-drop-0002', 'code': 'lot_expired', 'message': '', 'retryable': false},
        ],
      };
      await events.flush();
      expect([for (final e in queued.events) e['event_id']], ['ev-keep-0001']);

      // No way through: everything waits.
      server.errors['/riders/me/events'] = down;
      await events.flush();
      expect(queued.events, hasLength(1));

      // The next poll that reaches the server sends it.
      server.errors.clear();
      server.eventResult = null;
      await session.refresh();
      expect(queued.events, isEmpty);
      expect(server.bodies('/riders/me/events'), hasLength(3));
    });

    test('A refusal is not queued', () async {
      server.errors['/riders/me/problems'] = (400, 'validation_failed', false);
      await expectLater(
        ApiProblemReportRepository(session).send(ProblemReport(riderId: 'rdr_1', kind: ProblemKind.accident, at: now)),
        throwsA(isA<AppException>()),
      );
      expect(queued.events, isEmpty);
    });

    test('Only the newest location fixes are kept', () async {
      final events = session.events;
      for (var i = 0; i < RiderEventQueue.maxLocations + 5; i++) {
        await events.add(events.event('location', {'lat': i, 'lng': 0, 'speed_mps': 0, 'accuracy_m': 0}));
      }
      await events.add(events.event('problem', {'problem_type': 'accident'}));
      final kept = await events.pending();
      expect(kept, hasLength(RiderEventQueue.maxLocations + 1));
      expect((kept.first['payload'] as Map)['lat'], 5);
      expect(kept.last['type'], 'problem');
    });
  });

  test('While a shift is open the GPS goes to the location ping', () async {
    server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
    await session.ensureLoaded();
    fixes.controller.add(RiderFix(point: const LatLng(12.9, 77.5), speedMps: 4, accuracyM: 6, at: now));
    await pumpEventQueue();
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();
    final ping = server.bodies('/riders/me/location').single;
    expect(ping, {'lat': 12.9, 'lng': 77.5, 'speed_mps': 4.0, 'accuracy_m': 6.0, 'device_time': '2026-11-11T06:00:00.000Z'});
    expect(server.last('/riders/me/location')!.headers.containsKey('Idempotency-Key'), isFalse);
    final stale = RiderApiSession.locationPing(
      RiderFix(point: const LatLng(1, 2), speedMps: 4, at: now),
      now.add(const Duration(minutes: 1)),
      stale: true,
    );
    expect(stale['speed_mps'], 0);
  });

  group("The backend's rider fields (#158)", () {
    final openShift = {
      'id': 'shf_1',
      'node_id': 'node_7',
      'started_at': '2026-11-11T05:00:00Z',
      'ended_at': null,
      'node_assigned_at': '2026-11-11T05:40:00Z',
      'scooter': {'id': 'sct_1', 'plate': 'KA01AB1234', 'battery_pct': 64},
    };

    test("The order number is the server's", () async {
      server.offers = [
        {..._offer('off_a1'), 'order_number': 'A2931'},
      ];
      final status = await ApiOnlineRepository(session).watch('rdr_1', 'd').first;
      expect(status.queue.single.number, 'A2931');
      // An order reads it the same way; a server without one falls back on the id.
      expect(apiOrderNumber({'order_number': 'B0042'}, 'ord_0001'), 'B0042');
      expect(apiOrderNumber(const {}, 'off_a1'), 'A1');
    });

    test("The shift's scooter, and the metres from the node to the hub", () async {
      server.shift = openShift;
      server.node7Fields = {'hub_distance_m': 1500};
      final shift = (await ApiShiftRepository(session).watchToday('rdr_1').first)!;
      expect(shift.scooter.plate, 'KA01AB1234');
      expect(shift.scooter.batteryPercent, 64);
      expect(shift.hubDistanceKm, 1.5);
    });

    test('Rider since is the approval; the spot was assigned at node_assigned_at', () async {
      server.shift = openShift;
      server.riderFields = {'created_at': '2025-01-05T00:00:00Z', 'approved_at': '2025-02-10T00:00:00Z'};
      final facts = await ApiProfileRepository(session).watchFacts('rdr_1').first;
      expect(facts.riderSince, DateTime.utc(2025, 2, 10).toLocal());
      expect(facts.spotAssignedAt, DateTime.utc(2026, 11, 11, 5, 40).toLocal());
    });

    test('A move counts orders_waiting', () async {
      server.relocation = {
        'id': 'rel_1',
        'node_id': 'node_8',
        'reason': 'demand',
        'expires_at': '2099-01-01T00:00:00Z',
        'orders_waiting': 5,
      };
      final nudge = (await ApiOnlineRepository(session).watch('rdr_1', 'd').first).nudge!;
      expect(nudge.ordersWaiting, 5);
    });

    test("Each stock item shows the menu item's photo", () async {
      server.shift = openShift;
      server.lots = [
        {
          'lot_id': 'lot_1',
          'item_id': 'item_burger',
          'qty': 6,
          'expiry': '2026-11-11T10:00:00Z',
          'temp_status': 'ok',
          'image_url': 'https://img.test/burger.jpg',
        },
      ];
      await session.ensureLoaded();
      final local = await LoadStock(ApiStockRepository(session), InMemoryStockScanStore())('rdr_1', '2026-11-11');
      expect(local.manifest!.items.single.image, 'https://img.test/burger.jpg');
    });

    test("A restock shows ready-in, the other hub's distance, and the refill trip goes to the hub", () async {
      server.shift = openShift;
      server.restockRequest = {
        'id': 'rst_9',
        'state': 'partial',
        'hub': {'id': 'hub_2', 'name': 'Hub 2', 'lat': 12.95, 'lng': 77.61},
        'items': [
          {'item_id': 'item_burger', 'name': 'Burger', 'qty': 4, 'filled_qty': 2},
        ],
        'slot_at': null,
        'arrive_by': null,
        'ready_in_s': 125,
        'shortfall': {
          'action': 'other_hub',
          'other_hub': {'id': 'hub_4', 'name': 'Hub 4', 'lat': 12.99, 'lng': 77.62, 'distance_m': 2300},
        },
      };
      final restock = (await ApiOnlineRepository(session).watch('rdr_1', 'd').first).restock!;
      expect(restock.readyInMinutes, 3);
      expect(restock.shortage!.otherHubName, 'Hub 4');
      expect(restock.shortage!.otherHubKm, 2.3);

      await session.setDay({'refillHub': 'Hub 2'});
      final shift = (await ApiShiftRepository(session).watchToday('rdr_1').first)!;
      expect(shift.hub.name, 'Hub 2');
      expect(shift.hub.point, const LatLng(12.95, 77.61));
    });
  });

  group('Everything from the API', () {
    Map<String, dynamic> plan({String reply = 'pending', String packing = 'not_started', String? readyAt}) => {
      'id': 'pln_1',
      'date': '2026-11-11',
      'node_id': 'node_8',
      'starts_at': '2026-11-11T07:00:00Z',
      'ends_at': '2026-11-11T15:00:00Z',
      'stock_reply': reply,
      'replied_at': reply == 'pending' ? null : '2026-11-11T05:00:00Z',
      'packing': packing,
      'ready_at': readyAt,
    };

    test("Today's plan gives the shift's times, its node and the stock request", () async {
      server.plan = plan();
      final shifts = ApiShiftRepository(session);
      var shift = (await shifts.watchToday('rdr_1').first)!;
      expect(shift.start, DateTime.utc(2026, 11, 11, 7).toLocal());
      expect(shift.end, DateTime.utc(2026, 11, 11, 15).toLocal());
      expect(shift.hub.name, 'Node 8');
      expect(shift.stockRequest, StockRequestStatus.awaitingReply);

      await shifts.replyToStockRequest('rdr_1', shift.id, StockRequestStatus.requested);
      expect(server.bodies('/shift-plan/reply').single, {'reply': 'coming'});
      shift = (await shifts.watchToday('rdr_1').first)!;
      expect(shift.stockRequest, StockRequestStatus.requested);

      await shifts.replyToStockRequest('rdr_1', shift.id, StockRequestStatus.notWorkingToday);
      expect(server.bodies('/shift-plan/reply').last, {'reply': 'not_today'});
      expect((await shifts.watchToday('rdr_1').first)!.stockRequest, StockRequestStatus.notWorkingToday);
    });

    test('The hub packs, then the stock is ready; scanning waits for it', () async {
      server.plan = plan(reply: 'coming', packing: 'packing', readyAt: '2026-11-11T06:20:00Z');
      final shifts = ApiShiftRepository(session);
      await session.ensureLoaded();
      var shift = (await shifts.watchToday('rdr_1').first)!;
      expect(shift.stockRequest, StockRequestStatus.packing);
      expect(shift.stockReadyAt, DateTime.utc(2026, 11, 11, 6, 20).toLocal());
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.headingToHub);
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.atHub);
      // The shift starts at the node, and the rider waits for the stock.
      expect(server.bodies('/shifts/start'), hasLength(1));
      expect((await shifts.watchToday('rdr_1').first)!.phase, ShiftPhase.atHub);
      server.plan = plan(reply: 'coming', packing: 'ready', readyAt: '2026-11-11T06:10:00Z');
      await session.refresh(full: true);
      shift = (await shifts.watchToday('rdr_1').first)!;
      expect(shift.stockRequest, StockRequestStatus.ready);
      expect(shift.phase, ShiftPhase.scanning);
    });

    test("The open shift's planned end wins; with no plan there is nothing to answer", () async {
      server.shift = {
        'id': 'shf_1',
        'node_id': 'node_7',
        'started_at': '2026-11-11T05:00:00Z',
        'ended_at': null,
        'planned_end_at': '2026-11-11T12:30:00Z',
        'device_id': null,
      };
      final shifts = ApiShiftRepository(session);
      final shift = (await shifts.watchToday('rdr_1').first)!;
      expect(shift.end, DateTime.utc(2026, 11, 11, 12, 30).toLocal());
      expect(shift.stockRequest, StockRequestStatus.ready);
      await shifts.replyToStockRequest('rdr_1', shift.id, StockRequestStatus.requested);
      expect(server.bodies('/shift-plan/reply'), isEmpty);
    });

    test("The order's price is the order's total", () async {
      final online = ApiOnlineRepository(session);
      server.offers = [_offer('off_a1')];
      await online.startOrder('rdr_1', 'd', (await online.watch('rdr_1', 'd').first).queue.single);
      server.order = {...server.order, 'total': {'amount_minor': 14900, 'currency': 'INR'}, 'payment_method': 'prepaid'};
      await session.fetchOrder('ord_0001');
      final order = (await ApiDeliveryRepository(session).watchOrder('ord_0001').first)!;
      expect(order.amount, 149);
      expect(order.payment, OrderPayment.upi);
    });

    test("Call hub manager rings the hub's manager_phone", () async {
      server.hubFields = {'manager_phone': '+919800000100'};
      final shift = (await ApiShiftRepository(session).watchToday('rdr_1').first)!;
      expect(shift.hub.managerPhone, '+919800000100');
    });

    test('A lot that got too warm is quarantined on the server', () async {
      server.shift = {'id': 'shf_1', 'node_id': 'node_7', 'started_at': '2026-11-11T05:00:00Z', 'ended_at': null};
      server.lots = [
        {'lot_id': 'lot_1', 'item_id': 'item_burger', 'qty': 6, 'expiry': '2026-11-11T10:00:00Z', 'temp_status': 'alert'},
      ];
      await session.ensureLoaded();
      await ApiStockRepository(session).moveToQuarantine('rdr_1', '2026-11-11', QuarantineRequest(lotId: 'lot_1', itemId: 'item_burger', at: now));
      expect(server.bodies('/riders/me/stock/lot_1/quarantine').single, {'reason': 'temperature'});
      expect(session.lots, isEmpty);
      // A refusal won't change on a retry, so the sync moves on.
      server.errors['/riders/me/stock/lot_1/quarantine'] = (409, 'lot_not_on_scooter', false);
      await ApiStockRepository(session).moveToQuarantine('rdr_1', '2026-11-11', QuarantineRequest(lotId: 'lot_1', itemId: 'item_burger', at: now));
      server.errors['/riders/me/stock/lot_1/quarantine'] = (503, 'service_unavailable', true);
      await expectLater(
        ApiStockRepository(session).moveToQuarantine('rdr_1', '2026-11-11', QuarantineRequest(lotId: 'lot_1', itemId: 'item_burger', at: now)),
        throwsA(isA<AppException>()),
      );
    });

    test('A shift started on another phone is open elsewhere; this phone sends its device', () async {
      session.api.deviceId = 'dev_mine';
      final shifts = ApiShiftRepository(session);
      await session.ensureLoaded();
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.headingToHub);
      await shifts.setPhase('rdr_1', 'd', ShiftPhase.atHub);
      expect(server.bodies('/shifts/start').single, {'node_id': 'node_7', 'device_id': 'dev_mine'});
      final elsewhere = ApiShiftSessionRepository(session);
      server.shift = {...server.shift!, 'device_id': 'dev_mine'};
      await session.refresh(full: true);
      expect(await elsewhere.openElsewhere('rdr_1', 'd'), isFalse);
      server.shift = {...server.shift!, 'device_id': 'dev_other'};
      await session.refresh(full: true);
      expect(await elsewhere.openElsewhere('rdr_1', 'd'), isTrue);
    });
  });
}

/// The rider's day in memory.
class MemoryRiderDayStore implements RiderDayStore {
  final days = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>> load(String key) async => {...?days[key]};

  @override
  Future<void> save(String key, Map<String, dynamic> day) async => days[key] = {...day};
}

/// Queued events in memory.
class MemoryRiderEventStore implements RiderEventStore {
  List<Map<String, dynamic>> events = [];

  @override
  Future<List<Map<String, dynamic>>> load() async => [...events];

  @override
  Future<void> save(List<Map<String, dynamic>> events) async => this.events = [...events];
}
