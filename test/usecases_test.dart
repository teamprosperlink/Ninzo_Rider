import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/core/errors/app_exception.dart';
import 'package:ninzo_rider/domain/entities/auth_failure.dart';
import 'package:ninzo_rider/domain/entities/auth_user.dart';
import 'package:ninzo_rider/domain/entities/rider_account_info.dart';
import 'package:ninzo_rider/domain/usecases/request_login_code.dart';
import 'package:ninzo_rider/domain/usecases/restore_session.dart';
import 'package:ninzo_rider/domain/usecases/sign_out.dart';
import 'package:ninzo_rider/domain/usecases/verify_otp.dart';
import 'package:ninzo_rider/domain/entities/register_failure.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/rider_document.dart';
import 'package:ninzo_rider/domain/usecases/area_usecases.dart';
import 'package:ninzo_rider/domain/usecases/document_usecases.dart';
import 'package:ninzo_rider/domain/usecases/save_registration_details.dart';
import 'package:ninzo_rider/domain/usecases/start_registration.dart';
import 'package:latlong2/latlong.dart' show LatLng;

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

  test('SearchAreas: popular when empty, places when typed, nothing for nonsense', () async {
    final search = SearchAreas(FakeAreaRepository(), FakePlaceRepository());
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
        (await FindAreaNearMe(FakePlaceRepository(), near)()).name,
        'Yelahanka',
      );
      await expectLater(
        FindAreaNearMe(FakePlaceRepository(), FakeLocationRepository())(),
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

}

class _FixedLocation extends FakeLocationRepository {
  _FixedLocation(this.point);

  final LatLng point;

  @override
  Future<LatLng> currentPosition() async => point;
}
