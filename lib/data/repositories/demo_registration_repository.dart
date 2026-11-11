import 'dart:async';

import '../../core/constants/demo_data.dart';
import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_area.dart';
import '../../domain/entities/rider_document.dart';
import '../../domain/repositories/area_repository.dart';
import '../../domain/repositories/registration_repository.dart';

/// In-memory registrations for demo mode.
///
/// Sample riders (see [DemoData]) are approved and welcomed. A new rider
/// ([DemoData.unregisteredNumber] and friends) registers, and
/// [DemoData.reviewDelay] after submitting gets a review result that depends
/// on the number: …000 approved, …001 needs a retake, …002 verification
/// failed, …003 licence expired. A fixed resubmission is approved.
class DemoRegistrationRepository implements RegistrationRepository {
  DemoRegistrationRepository({this.reviewDelay = DemoData.reviewDelay});

  final Duration reviewDelay;
  final _applications = <String, RiderApplication>{};
  final _submissions = <String, int>{};
  final _changes = StreamController<String>.broadcast();

  static final _yelahanka = DemoAreaRepository.areas.first;

  RiderApplication? _find(String uid) {
    final phone = DemoData.phoneFor(uid);
    return _applications[uid] ??
        (DemoData.isRegistered(phone) && !DemoData.isNewRider(phone)
            ? RiderApplication(
                uid: uid,
                name: DemoData.riderName,
                phone: phone,
                area: _yelahanka,
                status: RegistrationStatus.approved,
                hubLabel: DemoData.hubLabel,
                firstShift: DemoData.firstShift,
                spotName: DemoData.spotName,
                spotDistanceKm: DemoData.spotDistanceKm,
                welcomed: true,
                onHold: phone.endsWith(DemoData.onHoldNumber),
              )
            : null);
  }

  void _put(RiderApplication a) {
    _applications[a.uid] = a;
    _changes.add(a.uid);
  }

  @override
  Stream<RiderApplication?> watch(String uid) async* {
    yield _find(uid);
    yield* _changes.stream.where((id) => id == uid).map((_) => _find(uid));
  }

  @override
  Future<void> saveDetails({
    required String uid,
    required String phone,
    required String name,
    required RiderArea area,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final existing = _applications[uid];
    _put(
      existing?.copyWith(name: name, area: area) ??
          RiderApplication(
            uid: uid,
            name: name,
            phone: phone,
            area: area,
            hubLabel: DemoData.hubLabel,
          ),
    );
    DemoData.markRegistered(phone);
  }

  @override
  Future<String> uploadPhoto({
    required String uid,
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return 'demo://$uid/${document.name}_${side.name}.jpg';
  }

  @override
  Future<void> saveDocuments(
    String uid,
    Map<RiderDocument, DocumentUpload> documents,
  ) async => _put(_find(uid)!.copyWith(documents: documents));

  @override
  Future<void> reopen(String uid) async =>
      _put(_find(uid)!.copyWith(status: RegistrationStatus.draft));

  @override
  Future<void> submit(String uid) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final submitted = _find(uid)!.copyWith(
      status: RegistrationStatus.underReview,
      submittedAt: DateTime.now(),
    );
    _put(submitted);
    final round = _submissions[uid] = (_submissions[uid] ?? 0) + 1;
    Timer(reviewDelay, () => _review(uid, firstRound: round == 1));
  }

  /// The demo review team's answer.
  void _review(String uid, {required bool firstRound}) {
    final a = _find(uid);
    if (a == null || a.status != RegistrationStatus.underReview) return;
    final phone = a.phone;
    Map<RiderDocument, DocumentUpload> flag(
      Map<RiderDocument, DocumentIssue> issues,
    ) => {
      for (final d in RiderDocument.values)
        d: DocumentUpload(
          files: a.documents[d]?.files ?? const {},
          issue: issues[d],
        ),
    };
    if (firstRound && phone.endsWith(DemoData.retakeNumber)) {
      _put(
        a.copyWith(
          status: RegistrationStatus.needsRetake,
          documents: flag({RiderDocument.drivingLicence: DocumentIssue.retake}),
        ),
      );
    } else if (firstRound && phone.endsWith(DemoData.failedNumber)) {
      _put(
        a.copyWith(
          status: RegistrationStatus.failed,
          documents: flag({
            RiderDocument.aadhaar: DocumentIssue.nameMismatch,
            RiderDocument.drivingLicence: DocumentIssue.retake,
          }),
        ),
      );
    } else if (firstRound && phone.endsWith(DemoData.expiredNumber)) {
      _put(
        a.copyWith(
          status: RegistrationStatus.expired,
          documents: flag({
            RiderDocument.drivingLicence: DocumentIssue.expired,
          }),
        ),
      );
    } else {
      _put(
        RiderApplication(
          uid: a.uid,
          name: a.name,
          phone: a.phone,
          area: a.area,
          status: RegistrationStatus.approved,
          documents: flag(const {}),
          submittedAt: a.submittedAt,
          hubLabel: DemoData.hubLabel,
          firstShift: DemoData.firstShift,
          spotName: DemoData.spotName,
          spotDistanceKm: DemoData.spotDistanceKm,
        ),
      );
    }
  }

  @override
  Future<void> markWelcomed(String uid) async =>
      _put(_find(uid)!.copyWith(welcomed: true));
}

/// The sample areas from the designs (all in Bengaluru).
class DemoAreaRepository implements AreaRepository {
  static final areas = [
    for (final (id, name, popular, lat, lng) in DemoData.areas)
      RiderArea(
        id: id,
        name: name,
        city: DemoData.city,
        popular: popular,
        latitude: lat,
        longitude: lng,
      ),
  ];

  @override
  Future<List<RiderArea>> all() async => areas;
}
