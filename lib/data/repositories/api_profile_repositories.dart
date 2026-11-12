import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_area.dart';
import '../../domain/entities/rider_document.dart';
import '../../domain/repositories/area_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/registration_repository.dart';
import '../datasources/remote/rider_api_client.dart';
import '../datasources/remote/rider_api_session.dart';
import 'api_online_repository.dart';

/// Registration on the rider API.
///
/// The API signs riders in with a phone and OTP only; an account exists once
/// the operations team has added the number (status `applicant`, then
/// `active`). The name and area go to `PATCH /riders/me` and come back from
/// `GET /riders/me`. Each document photo is uploaded as it is taken
/// (`POST /riders/me/documents`), and the list of what was uploaded comes from
/// `GET /riders/me/documents`. "Send for review" starts the verification
/// (`POST /riders/me/verification/start`, by hand until DigiLocker); the review
/// result comes from `GET /riders/me/verification`.
///
/// An applicant who hasn't given their area yet has no application, so
/// Register asks for their details; an active rider is approved and goes to Home.
class ApiRegistrationRepository implements RegistrationRepository {
  ApiRegistrationRepository(this._session);

  final RiderApiSession _session;
  bool _verificationAsked = false;
  String? _phone;

  /// What the phone keeps for [uid]: where each uploaded photo is on this
  /// phone, for its preview, and which screens were seen (submitted,
  /// registered here, welcomed).
  Map<String, dynamic> _kept = {};
  String? _keptFor;

  static String _key(String uid) => 'riderApi.registration.$uid';

  Future<void> _load(String uid) async {
    if (_keptFor == uid) return;
    _kept = await _session.readKept(_key(uid));
    _keptFor = uid;
  }

  Future<void> _save(String uid, Map<String, dynamic> changes) async {
    await _load(uid);
    _kept = {..._kept, ...changes};
    await _session.writeKept(_key(uid), _kept);
  }

  @override
  Stream<RiderApplication?> watch(String uid) async* {
    _phone ??= (await _session.api.client.tokens.read())?.phone;
    await _load(uid);
    if (!_verificationAsked) {
      _verificationAsked = true;
      await _session.loadVerification();
    }
    yield* _session.watch(() => _application(uid));
  }

  RiderApplication? _application(String uid) {
    final rider = _session.rider;
    if (rider == null) return null;
    final status = rider['status'] as String?;
    final applicant = status == 'applicant';
    final area = rider['area'] as Map<String, dynamic>?;
    // An applicant gives their details first (Register 01).
    if (applicant && area == null) return null;
    final node = _session.assignedNode;
    final verification = _session.verification;
    final issue = switch (verification) {
      'failed' => DocumentIssue.nameMismatch,
      'expired' => DocumentIssue.expired,
      _ => null,
    };
    final submitted = _kept['submitted'] == true;
    return RiderApplication(
      uid: uid,
      name: rider['name'] as String? ?? '',
      phone: rider['phone'] as String? ?? _phone ?? '',
      area: _area(area) ??
          RiderArea(
            id: rider['zone_id'] as String? ?? '',
            name: node?.name ?? '',
            city: '',
            latitude: node?.point.latitude,
            longitude: node?.point.longitude,
          ),
      status: switch ((applicant, verification)) {
        (true, 'pending') => RegistrationStatus.underReview,
        (true, 'failed') when !submitted => RegistrationStatus.failed,
        (true, 'expired') when !submitted => RegistrationStatus.expired,
        (true, _) => submitted ? RegistrationStatus.underReview : RegistrationStatus.draft,
        _ when issue == DocumentIssue.expired => RegistrationStatus.expired,
        _ when issue != null => RegistrationStatus.failed,
        _ => RegistrationStatus.approved,
      },
      documents: _documents(issue),
      hubLabel: node?.name,
      spotName: node?.name,
      // A rider who registered on this phone sees "You're approved" once.
      welcomed: !applicant && (_kept['registeredHere'] != true || _kept['welcomed'] == true),
      onHold: status == 'suspended',
    );
  }

  /// The rider's `area` from the API.
  static RiderArea? _area(Map<String, dynamic>? a) {
    if (a == null) return null;
    return RiderArea(
      id: '',
      name: a['name'] as String? ?? '',
      city: a['city'] as String? ?? '',
      latitude: (a['lat'] as num?)?.toDouble(),
      longitude: (a['lng'] as num?)?.toDouble(),
    );
  }

  /// What `GET /riders/me/documents` says was uploaded, with the review's
  /// issue on the document it concerns. A photo taken on this phone shows
  /// from its file; one uploaded elsewhere has no preview here.
  Map<RiderDocument, DocumentUpload> _documents(DocumentIssue? issue) {
    final previews = (_kept['previews'] as Map<String, dynamic>?) ?? const {};
    final uploaded = <RiderDocument, Map<DocumentSide, String>>{};
    for (final doc in _session.documents) {
      final document = RiderDocument.values.asNameMap()[doc['document']];
      final side = DocumentSide.values.asNameMap()[doc['side']];
      if (document == null || side == null) continue;
      (uploaded[document] ??= {})[side] = previews['${EnumName(document).name}.${side.name}'] as String? ?? '';
    }
    final flagged = issue == null ? null : (issue == DocumentIssue.expired ? RiderDocument.drivingLicence : RiderDocument.aadhaar);
    return {
      for (final document in RiderDocument.values)
        if (uploaded[document] != null || document == flagged)
          document: DocumentUpload(
            files: uploaded[document] ?? const {},
            issue: document == flagged && _kept['submitted'] != true ? issue : null,
          ),
    };
  }

  static String _contentType(String path) => switch (path.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  @override
  Future<void> saveDetails({
    required String uid,
    required String phone,
    required String name,
    required RiderArea area,
  }) async {
    final lat = area.latitude, lng = area.longitude;
    // The API keeps an area as a place; Register's search always gives one.
    if (lat == null || lng == null) throw const AppException('area_without_place');
    try {
      await _session.updateRider({
        'name': name,
        'area': {'name': area.name, 'city': area.city, 'lat': lat, 'lng': lng},
      });
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    await _save(uid, {'registeredHere': true});
  }

  /// Uploads the photo (`POST /riders/me/documents`, base64, replacing the
  /// one before). The file stays on the phone only for its preview.
  @override
  Future<String> uploadPhoto({
    required String uid,
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    try {
      await _session.api.uploadDocument({
        'document': EnumName(document).name,
        'side': side.name,
        'content_type': _contentType(filePath),
        'data_base64': base64Encode(bytes),
      });
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    await _save(uid, {
      'previews': {...?(_kept['previews'] as Map<String, dynamic>?), '${EnumName(document).name}.${side.name}': filePath},
    });
    await _session.refreshDocuments();
    return filePath;
  }

  /// The photos are on the server already (each was uploaded when taken).
  @override
  Future<void> saveDocuments(String uid, Map<RiderDocument, DocumentUpload> documents) async {}

  /// Starts the verification (`POST /riders/me/verification/start`) for the
  /// photos already uploaded.
  @override
  Future<void> submit(String uid) async {
    await _load(uid);
    try {
      _session.verificationNext = await _session.api.startVerification({'method': 'manual_upload'});
    } on RiderApiException catch (e) {
      // Started already: it is under review.
      if (e.code != 'verification_in_progress') throw AppException(e.code);
    }
    await _save(uid, {'submitted': true});
    await _session.loadVerification();
  }

  /// Fixing what the review sent back: the documents can be sent again.
  @override
  Future<void> reopen(String uid) => _save(uid, {'submitted': false});

  @override
  Future<void> markWelcomed(String uid) => _save(uid, {'welcomed': true});
}

/// No list of areas in the rider API; Register's search uses Google Places.
class ApiAreaRepository implements AreaRepository {
  const ApiAreaRepository();

  @override
  Future<List<RiderArea>> all() async => const [];
}

/// Profile 04–06 from the rider API: when the spot was assigned and "Rider
/// since", the last 7 days from `GET /riders/me/earnings?date=` and what the
/// phone kept of each day, and the notifications from
/// `GET /riders/me/notifications`.
class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._session);

  final RiderApiSession _session;

  static const _days = 7;

  @override
  Stream<ProfileFacts> watchFacts(String uid) => _session.watch(
    () {
      final shift = _session.state?['shift'] as Map<String, dynamic>?;
      final rider = _session.rider;
      return ProfileFacts(
        // "Rider since": approval, or the account's creation before it.
        riderSince: RiderApiSession.parseTime(rider?['approved_at']) ?? RiderApiSession.parseTime(rider?['created_at']),
        // `node_assigned_at` moves with an accepted relocation; older servers have only the start.
        spotAssignedAt: RiderApiSession.parseTime(shift?['node_assigned_at']) ?? RiderApiSession.parseTime(shift?['started_at']),
      );
    },
  );

  @override
  Stream<List<RiderNotification>> watchNotifications(String uid) => _session.watch(
    () => [
      for (final note in _session.notifications)
        RiderNotification(
          id: note['id'] as String,
          title: note['title'] as String? ?? '',
          body: note['body'] as String? ?? '',
          at: RiderApiSession.parseTime(note['created_at']) ?? _session.clock(),
        ),
    ],
  );

  /// `GET /riders/me/help`.
  @override
  Stream<List<HelpArticle>> watchHelp(String uid) => _session.watch(
    () => [
      for (final a in _session.help)
        HelpArticle(id: a['id'] as String, question: a['question'] as String? ?? '', answer: a['answer'] as String? ?? ''),
    ],
  );

  /// `POST /riders/me/feedback`.
  @override
  Future<void> sendFeedback(String uid, String message) async {
    try {
      await _session.api.sendFeedback(message);
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
  }

  /// Each day's shifts (`GET /riders/me/shifts`) with that day's pay
  /// (`GET /riders/me/earnings?date=`). A day with more than one shift reads
  /// from its first online time to its last end.
  @override
  Stream<List<ShiftRecord>> watchShifts(String uid) async* {
    List<Map<String, dynamic>> shifts;
    try {
      shifts = [
        ...((await _session.api.listShifts(days: _days))['shifts'] as List? ?? const []).cast<Map<String, dynamic>>(),
      ];
    } on RiderApiException {
      shifts = _session.shiftHistory;
    }
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final shift in shifts) {
      final started = RiderApiSession.parseTime(shift['started_at']);
      if (started == null) continue;
      byDay.putIfAbsent(_session.indiaDateOf(started), () => []).add(shift);
    }
    final records = <ShiftRecord>[];
    for (var ago = 0; ago < _days; ago++) {
      final date = _session.indiaDateAgo(ago);
      final day = byDay[date];
      if (day == null) continue;
      Map<String, dynamic>? money;
      try {
        money = await _session.api.getEarnings(date: date);
      } on RiderApiException {
        money = null;
      }
      DateTime? earliest(String key) => [
        for (final s in day) ?RiderApiSession.parseTime(s[key]),
      ].fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
      DateTime? latest(String key) => [
        for (final s in day) ?RiderApiSession.parseTime(s[key]),
      ].fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      final started = earliest('started_at')!;
      final onlineAt = earliest('online_at') ?? started;
      final open = day.any((s) => s['ended_at'] == null);
      records.add(
        ShiftRecord(
          date: DateTime(started.year, started.month, started.day),
          orders: (money?['orders'] as num?)?.toInt() ?? day.fold<int>(0, (n, s) => n + ((s['orders'] as num?)?.toInt() ?? 0)),
          earned: ApiOnlineRepository.rupeesOf(money?['total']),
          onlineAt: onlineAt,
          plannedEnd: latest('planned_end_at') ?? latest('ended_at') ?? onlineAt,
          endedAt: open ? null : latest('ended_at'),
        ),
      );
    }
    yield records;
  }
}
