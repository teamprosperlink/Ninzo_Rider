import 'dart:async';

import 'package:http/http.dart' as http;

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
/// `active`). It has no field for the name, area or document photos, so those
/// stay on the phone until it does. Sending the documents starts the
/// verification (`POST /riders/me/verification/start`, by hand until
/// DigiLocker) and uploads each photo to the `upload_url` it returns; the
/// review result comes from `GET /riders/me/verification`.
///
/// An applicant who hasn't given their details yet has no application, so
/// Register asks for them; an active rider is approved and goes to Home.
class ApiRegistrationRepository implements RegistrationRepository {
  ApiRegistrationRepository(this._session, {http.Client? client}) : _client = client ?? http.Client();

  final RiderApiSession _session;
  final http.Client _client;
  bool _verificationAsked = false;
  String? _phone;

  /// What the phone keeps for [uid]: name, area, document photos, submitted, welcomed.
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
    final name = _kept['name'] as String?;
    // An applicant gives their details first (Register 01).
    if (applicant && name == null) return null;
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
      name: (rider['name'] as String?) ?? name ?? '',
      phone: _phone ?? '',
      area: _area() ??
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
      welcomed: !applicant && (_kept['name'] == null || _kept['welcomed'] == true),
      onHold: status == 'suspended',
    );
  }

  RiderArea? _area() {
    final a = _kept['area'] as Map<String, dynamic>?;
    if (a == null) return null;
    return RiderArea(
      id: a['id'] as String? ?? '',
      name: a['name'] as String? ?? '',
      city: a['city'] as String? ?? '',
      latitude: (a['lat'] as num?)?.toDouble(),
      longitude: (a['lng'] as num?)?.toDouble(),
    );
  }

  /// The photos kept on the phone, with the review's issue on the document it concerns.
  Map<RiderDocument, DocumentUpload> _documents(DocumentIssue? issue) {
    final kept = (_kept['documents'] as Map<String, dynamic>?) ?? const {};
    final flagged = issue == null ? null : (issue == DocumentIssue.expired ? RiderDocument.drivingLicence : RiderDocument.aadhaar);
    return {
      for (final document in RiderDocument.values)
        if (kept[document.name] != null || document == flagged)
          document: DocumentUpload(
            files: {
              for (final MapEntry(:key, :value) in ((kept[document.name] as Map?) ?? const {}).entries)
                DocumentSide.values.byName(key as String): value as String,
            },
            issue: document == flagged && _kept['submitted'] != true ? issue : null,
          ),
    };
  }

  @override
  Future<void> saveDetails({
    required String uid,
    required String phone,
    required String name,
    required RiderArea area,
  }) => _save(uid, {
    'name': name,
    'area': {'id': area.id, 'name': area.name, 'city': area.city, 'lat': area.latitude, 'lng': area.longitude},
  });

  /// Kept on the phone until "Send for review" uploads it.
  @override
  Future<String> uploadPhoto({
    required String uid,
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  }) async => filePath;

  @override
  Future<void> saveDocuments(String uid, Map<RiderDocument, DocumentUpload> documents) => _save(uid, {
    'documents': {
      for (final MapEntry(:key, :value) in documents.entries)
        key.name: {for (final MapEntry(key: side, value: path) in value.files.entries) side.name: path},
    },
  });

  /// Starts the verification and uploads every photo to its `upload_url`.
  @override
  Future<void> submit(String uid) async {
    await _load(uid);
    final Map<String, dynamic> start;
    try {
      start = await _session.api.startVerification({'method': 'manual_upload'});
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    final url = start['upload_url'] as String?;
    if (url == null) throw const AppException('no_upload_url');
    final documents = (_kept['documents'] as Map<String, dynamic>?) ?? const {};
    final token = (await _session.api.client.tokens.read())?.access;
    for (final MapEntry(key: document, value: sides) in documents.entries) {
      for (final MapEntry(key: side, value: path) in (sides as Map).entries) {
        final request = http.MultipartRequest('POST', Uri.parse(url))
          ..fields['document'] = document
          ..fields['side'] = side as String
          ..files.add(await http.MultipartFile.fromPath('file', path as String));
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        final response = await _client.send(request);
        if (response.statusCode >= 300) throw AppException('upload_${response.statusCode}');
      }
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

/// Profile 04–06 from the rider API: the shift's start is when the spot was
/// assigned, the last 7 days come from `GET /riders/me/earnings?date=` and
/// what the phone kept of each day, and the notifications are what the
/// server told this rider (each shift's spot, each suggested move).
class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._session);

  final RiderApiSession _session;

  static const _days = 7;

  @override
  Stream<ProfileFacts> watchFacts(String uid) => _session.watch(
    () => ProfileFacts(
      spotAssignedAt: RiderApiSession.parseTime((_session.state?['shift'] as Map<String, dynamic>?)?['started_at']),
    ),
  );

  @override
  Stream<List<RiderNotification>> watchNotifications(String uid) => _session.watch(
    () => [
      for (final note in _session.notes)
        RiderNotification(
          id: note['id'] as String,
          title: note['title'] as String? ?? '',
          body: note['body'] as String? ?? '',
          at: RiderApiSession.parseTime(note['at']) ?? _session.clock(),
        ),
    ],
  );

  @override
  Stream<List<ShiftRecord>> watchShifts(String uid) async* {
    final records = <ShiftRecord>[];
    for (var ago = 0; ago < _days; ago++) {
      final date = _session.indiaDateAgo(ago);
      final day = ago == 0 ? _session.day : await _session.dayOn(date);
      Map<String, dynamic>? money;
      try {
        money = await _session.api.getEarnings(date: date);
      } on RiderApiException {
        money = null;
      }
      final orders = (money?['orders'] as num?)?.toInt() ?? 0;
      final onlineAt = RiderApiSession.parseTime(day['onlineAt']);
      if (orders == 0 && onlineAt == null) continue;
      final parts = date.split('-').map(int.parse).toList();
      final start = DateTime(parts[0], parts[1], parts[2]);
      records.add(
        ShiftRecord(
          date: start,
          orders: orders,
          earned: ApiOnlineRepository.rupeesOf(money?['total']),
          // Orders on a day this phone kept nothing of: no online time known.
          onlineAt: onlineAt ?? start,
          plannedEnd: RiderApiSession.parseTime(day['shiftEnd']) ?? start.add(const Duration(days: 1)),
          endedAt: onlineAt == null ? start : RiderApiSession.parseTime(day['endedAt']),
        ),
      );
    }
    yield records;
  }
}
