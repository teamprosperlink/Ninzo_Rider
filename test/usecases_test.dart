import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/core/error/app_exception.dart';
import 'package:ninzo_rider/features/auth/domain/entities/auth_failure.dart';
import 'package:ninzo_rider/features/auth/domain/entities/auth_user.dart';
import 'package:ninzo_rider/features/auth/domain/entities/rider_account_info.dart';
import 'package:ninzo_rider/features/auth/domain/usecases/request_login_code.dart';
import 'package:ninzo_rider/features/auth/domain/usecases/restore_session.dart';
import 'package:ninzo_rider/features/auth/domain/usecases/sign_out.dart';
import 'package:ninzo_rider/features/auth/domain/usecases/verify_otp.dart';
import 'package:ninzo_rider/features/register/domain/entities/register_failure.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_document.dart';
import 'package:ninzo_rider/features/register/domain/usecases/area_usecases.dart';
import 'package:ninzo_rider/features/register/domain/usecases/document_usecases.dart';
import 'package:ninzo_rider/features/register/domain/usecases/save_registration_details.dart';
import 'package:ninzo_rider/features/register/domain/usecases/start_registration.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:ninzo_rider/features/orders/domain/entities/delivery_stats.dart';
import 'package:ninzo_rider/features/orders/domain/entities/order.dart';
import 'package:ninzo_rider/features/orders/domain/usecases/accept_order.dart';
import 'package:ninzo_rider/features/orders/domain/usecases/deliver_order.dart';
import 'package:ninzo_rider/features/orders/domain/usecases/rank_offers.dart';
import 'package:ninzo_rider/features/orders/domain/usecases/watch_open_orders.dart';

import 'fakes.dart';

void main() {
  Matcher throwsKind(AuthFailureKind kind) =>
      throwsA(isA<AuthFailure>().having((e) => e.kind, 'kind', kind));

  test(
    'RequestLoginCode checks the number, then the rider account, and adds +91',
    () async {
      final auth = FakeAuthRepository();
      final directory = FakeRiderDirectory();
      final request = RequestLoginCode(auth, directory);
      await expectLater(
        request('12345'),
        throwsKind(AuthFailureKind.invalidNumber),
      );
      await expectLater(
        request('1234567890'),
        throwsKind(AuthFailureKind.invalidNumber),
      );

      directory.result = null;
      await expectLater(
        request('9876543210'),
        throwsKind(AuthFailureKind.notRegistered),
      );

      directory.result = const RiderAccountInfo(onHold: true);
      await expectLater(
        request('9876543210'),
        throwsKind(AuthFailureKind.onHold),
      );

      directory.failure = AuthFailureKind.noInternet;
      await expectLater(
        request('9876543210'),
        throwsKind(AuthFailureKind.noInternet),
      );

      directory
        ..failure = null
        ..result = const RiderAccountInfo(
          hubLabel: 'Hub 2 · Yelahanka',
          shiftStart: '11:00 AM',
        );
      final sent = await request(' 9876543210 ');
      expect(
        sent.account?.shiftSummary,
        'Your shift at Hub 2 · Yelahanka starts at 11:00 AM.',
      );
      await auth.verifyOtp(verificationId: 'v', code: testOtp);
      expect(auth.user.value?.phone, '+919876543210');
    },
  );

  test('VerifyOtp needs 6 digits and remembers "Keep me signed in"', () async {
    final session = FakeSessionRepository();
    final auth = FakeAuthRepository();
    final verify = VerifyOtp(auth, session);
    await expectLater(
      verify(verificationId: 'v', code: '123'),
      throwsKind(AuthFailureKind.wrongCode),
    );
    await RequestLoginCode(auth, FakeRiderDirectory())('9876543210');
    await verify(verificationId: 'v', code: testOtp, keepSignedIn: false);
    expect(session.keep, isFalse);
    expect(session.was, isTrue);
  });

  test('RestoreSession signs out riders who were not kept signed in, and reports ended sessions', () async {
    final auth = FakeAuthRepository();
    final session = FakeSessionRepository();
    final restore = RestoreSession(auth, session);

    expect(await restore(), isFalse); // first launch

    auth.user.value = const AuthUser(uid: 'u1', phone: '+919876543210');
    session.keep = false;
    expect(await restore(), isTrue);
    expect(auth.user.value, isNull);

    // Signing out yourself is not an ended session.
    auth.user.value = const AuthUser(uid: 'u1', phone: '+919876543210');
    session.was = true;
    await SignOut(auth, session)();
    expect(await restore(), isFalse);
  });

  test('DeliverOrder checks the code length, then the code', () async {
    final deliver = DeliverOrder(FakeOrderRepository());
    final order = testOrder();

    await expectLater(
      deliver(order, '12'),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      deliver(order, '0000'),
      throwsA(isA<AppException>()),
    );
    await deliver(order, ' $testDeliveryCode ');
  });

  test('AcceptOrder fails when another rider was faster', () {
    final rider = Fakes().riderApplication(RegistrationStatus.approved);
    expect(
      AcceptOrder(FakeOrderRepository())(testOrder(), rider: rider),
      throwsA(isA<AppException>()),
    );
  });

  test('RankOffers drops skipped and far orders, nearest first', () {
    final near = testOrder(id: 'near');
    final far = Order(
      id: 'far',
      orderNumber: '1',
      restaurant: const OrderContact(
        name: 'Far',
        phone: '',
        address: '',
        point: LatLng(28.70, 77.30),
      ),
      customer: customer,
      items: const [],
      total: 0,
      paymentMode: PaymentMode.prepaid,
      riderFee: 20,
      status: OrderStatus.ready,
      createdAt: DateTime.now(),
    );
    const rank = RankOffers();

    final offers = rank(
      [far, near, testOrder(id: 'skipped')],
      from: riderPoint,
      skipped: {'skipped'},
    );
    expect(offers.map((o) => o.order.id), ['near']);
    expect(offers.single.kmToRestaurant, lessThan(0.1));

    // Without a position nothing can be ruled out by distance.
    expect(rank([far, near]).length, 2);
  });

  test('WatchOpenOrders leaves out abandoned orders', () async {
    final now = DateTime.now();
    final repo = FakeOrderRepository()
      ..open.value = [testOrder(id: 'a'), testOrder(id: 'b')];
    final later = now.add(WatchOpenOrders.maxAge + const Duration(minutes: 1));
    final fresh = WatchOpenOrders(
      repo,
      () => later.subtract(const Duration(minutes: 2)),
    );
    final stale = WatchOpenOrders(repo, () => later);
    expect((await fresh().first).length, 2);
    expect(await stale().first, isEmpty);
  });

  test('StartRegistration stops at a number that is already a rider, else signs in without a code', () async {
    final auth = FakeAuthRepository();
    final directory = FakeRiderDirectory();
    final start = StartRegistration(directory, auth);
    Matcher failsWith(RegisterFailureKind kind) =>
        throwsA(isA<RegisterFailure>().having((e) => e.kind, 'kind', kind));
    await expectLater(
      start('12345'),
      failsWith(RegisterFailureKind.invalidNumber),
    );
    await expectLater(
      start('9876543210'),
      failsWith(RegisterFailureKind.alreadyRegistered),
    );
    expect(auth.user.value, isNull);
    directory.result = null;
    await start('9876543210');
    expect(auth.user.value?.phone, '+919876543210');
  });

  test('SaveRegistrationDetails needs a name and an area, and saves the profile too', () async {
    final registration = FakeRegistrationRepository();
    final users = FakeUserRepository();
    final save = SaveRegistrationDetails(registration, users);
    await expectLater(
      save(
        uid: 'u1',
        phone: '+919876543210',
        name: '  ',
        area: testAreas.first,
      ),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      save(uid: 'u1', phone: '+919876543210', name: 'Ravi', area: null),
      throwsA(isA<AppException>()),
    );
    await save(
      uid: 'u1',
      phone: '+919876543210',
      name: ' Ravi   Kumar ',
      area: testAreas.first,
    );
    expect(registration.application.value?.name, 'Ravi Kumar');
    expect(registration.application.value?.status, RegistrationStatus.draft);
    expect(users.user.value?.name, 'Ravi Kumar');
  });

  test('SearchAreas: popular when empty, matches with prefixes first, nothing for nonsense', () async {
    final search = SearchAreas(FakeAreaRepository());
    expect((await search('')).map((a) => a.name), [
      'Yelahanka', 'Bagalur', 'Jakkur', 'Hebbal', 'Devanahalli', 'Kogilu', //
    ]);
    expect((await search('yel')).map((a) => a.name), [
      'Yelahanka',
      'Yelahanka New Town',
      'Yelahanka Old Town',
      'Yelahanka Satellite Town', //
    ]);
    expect(await search('Xyz'), isEmpty);
  });

  test(
    'FindAreaNearMe picks the nearest area, or says there is none near',
    () async {
      final near = _FixedLocation(const LatLng(13.1010, 77.5960));
      expect(
        (await FindAreaNearMe(FakeAreaRepository(), near)()).name,
        'Yelahanka',
      );
      await expectLater(
        FindAreaNearMe(FakeAreaRepository(), FakeLocationRepository())(),
        throwsA(
          isA<RegisterFailure>().having(
            (e) => e.kind,
            'kind',
            RegisterFailureKind.noAreaNearby,
          ),
        ),
      );
    },
  );

  test(
    'Uploading the last side clears the issue; submitting needs every document',
    () async {
      final registration = FakeRegistrationRepository();
      final a = Fakes().riderApplication(RegistrationStatus.draft);
      registration.application.value = a.copyWith(
        documents: {
          ...a.documents,
          RiderDocument.aadhaar: const DocumentUpload(
            issue: DocumentIssue.retake,
          ),
        },
      );
      final submit = SubmitForReview(registration);
      await expectLater(
        submit(registration.application.value!),
        throwsA(isA<AppException>()),
      );

      final upload = UploadDocumentPhoto(registration);
      await upload(
        registration.application.value!,
        document: RiderDocument.aadhaar,
        side: DocumentSide.front,
        filePath: 'f.jpg',
      );
      expect(
        registration.application.value!.documents[RiderDocument.aadhaar]!.issue,
        DocumentIssue.retake,
      );
      await upload(
        registration.application.value!,
        document: RiderDocument.aadhaar,
        side: DocumentSide.back,
        filePath: 'b.jpg',
      );
      expect(
        registration.application.value!.isAdded(RiderDocument.aadhaar),
        isTrue,
      );

      await submit(registration.application.value!);
      expect(
        registration.application.value!.status,
        RegistrationStatus.underReview,
      );
    },
  );

  test('Stats count cash to hand over and pick out one day', () {
    final day = DateTime(2026, 1, 1, 12);
    final stats = DeliveryStats.onDay([
      testOrder(
        pickedUpAt: day,
        deliveredAt: day.add(const Duration(seconds: 60)),
      ),
      testOrder(
        paymentMode: PaymentMode.prepaid,
        pickedUpAt: day,
        deliveredAt: day.add(const Duration(seconds: 60)),
      ),
      testOrder(pickedUpAt: day, deliveredAt: day.add(const Duration(days: 1))),
    ], day);
    expect(stats.deliveries, 2);
    expect(stats.cashCollected, 249);
    expect(stats.earnings, 50);
  });
}

class _FixedLocation extends FakeLocationRepository {
  _FixedLocation(this.point);

  final LatLng point;

  @override
  Future<LatLng> currentPosition() async => point;
}
