import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_area.dart';
import '../../domain/entities/rider_document.dart';

/// Firestore shape of `areas/{id}`: `{name, city, lat, lng, popular}`.
abstract final class RiderAreaModel {
  static RiderArea fromFirestore(String id, Map<String, dynamic> j) =>
      RiderArea(
        id: id,
        name: j['name'] as String? ?? '',
        city: j['city'] as String? ?? '',
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lng'] as num?)?.toDouble(),
        popular: j['popular'] == true,
      );

  /// How an area is stored on an application.
  static Map<String, Object?> toApplication(RiderArea a) => {
    'id': a.id,
    'name': a.name,
    'city': a.city,
  };

  static RiderArea fromApplication(Object? j) {
    if (j is! Map) return const RiderArea(id: '', name: '', city: '');
    return RiderArea(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      city: j['city'] as String? ?? '',
    );
  }
}

/// Firestore shape of `riders/{uid}`:
///
/// ```
/// name, phone, area: {id, name, city},
/// status: draft | underReview | needsRetake | failed | expired | approved,
/// documents: {aadhaar: {files: {front: url, back: url}, issue: retake | nameMismatch | expired | null}, …},
/// submittedAt, welcomed,
/// hubLabel, firstShift, spot: {name, distanceKm}, onHold   ← set by the backend
/// ```
///
/// Profiles from the old KYC flow (`kycStatus`, documents as plain URLs) are
/// still read: pending → under review, rejected → failed, approved riders
/// count as welcomed.
abstract final class RiderApplicationModel {
  static RiderApplication fromFirestore(String uid, Map<String, dynamic> j) {
    final status =
        RegistrationStatus.values.asNameMap()[j['status']] ??
        switch (j['kycStatus']) {
          'approved' => RegistrationStatus.approved,
          'rejected' => RegistrationStatus.failed,
          'pending' => RegistrationStatus.underReview,
          _ => RegistrationStatus.draft,
        };
    final spot = j['spot'];
    return RiderApplication(
      uid: uid,
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      area: RiderAreaModel.fromApplication(j['area']),
      status: status,
      documents: documentsFromFirestore(j['documents']),
      submittedAt: (j['submittedAt'] as Timestamp?)?.toDate(),
      hubLabel: j['hubLabel'] as String?,
      firstShift: j['firstShift'] as String?,
      spotName: spot is Map ? spot['name'] as String? : null,
      spotDistanceKm: spot is Map
          ? (spot['distanceKm'] as num?)?.toDouble()
          : null,
      welcomed: j['welcomed'] as bool? ?? status == RegistrationStatus.approved,
      onHold: j['onHold'] == true,
    );
  }

  static Map<RiderDocument, DocumentUpload> documentsFromFirestore(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final names = RiderDocument.values.asNameMap();
    final sides = DocumentSide.values.asNameMap();
    final issues = DocumentIssue.values.asNameMap();
    final result = <RiderDocument, DocumentUpload>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      final doc = names[key];
      if (doc == null) continue;
      result[doc] = switch (value) {
        // Old KYC flow: one URL per document.
        final String url => DocumentUpload(files: {doc.sides.first: url}),
        final Map m => DocumentUpload(
          files: {
            for (final MapEntry(:key, :value)
                in ((m['files'] as Map?) ?? const {}).entries)
              if ((sides[key], value) case (final side?, final String url))
                side: url,
          },
          issue: issues[m['issue']],
        ),
        _ => const DocumentUpload(),
      };
    }
    return result;
  }

  static Map<String, Object?> documentsToFirestore(
    Map<RiderDocument, DocumentUpload> documents,
  ) => {
    for (final MapEntry(:key, :value) in documents.entries)
      key.name: {
        'files': {for (final f in value.files.entries) f.key.name: f.value},
        'issue': value.issue?.name,
      },
  };
}
