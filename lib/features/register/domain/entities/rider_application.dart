import 'rider_area.dart';
import 'rider_document.dart';

/// Where a rider's registration is. Only the review team (backend) moves an
/// application out of [underReview].
enum RegistrationStatus {
  /// Details saved; documents being added or fixed (Register 04–07).
  draft,

  /// Submitted (Register 08).
  underReview,

  /// One or more photos need taking again (Register 11).
  needsRetake,

  /// Details don't match, e.g. the name (Register 12).
  failed,

  /// A document has expired (Register 13).
  expired,

  /// Approved: hub and spot assigned (Register 09, 10).
  approved,
}

/// The rider's registration: details, area, documents and review result.
/// Firestore `riders/{uid}`.
class RiderApplication {
  const RiderApplication({
    required this.uid,
    required this.name,
    required this.phone,
    required this.area,
    this.status = RegistrationStatus.draft,
    this.documents = const {},
    this.submittedAt,
    this.hubLabel,
    this.firstShift,
    this.spotName,
    this.spotDistanceKm,
    this.welcomed = false,
    this.onHold = false,
  });

  final String uid;

  /// Full name as on Aadhaar.
  final String name;

  /// E.164, e.g. "+919876543210".
  final String phone;
  final RiderArea area;
  final RegistrationStatus status;
  final Map<RiderDocument, DocumentUpload> documents;
  final DateTime? submittedAt;

  /// Set by the backend from the area, e.g. "Hub 2 · Yelahanka".
  final String? hubLabel;

  /// Set on approval, e.g. "Tomorrow, 11:00 AM – 3:00 PM".
  final String? firstShift;

  /// The spot the system assigned, e.g. "Yelahanka Node".
  final String? spotName;
  final double? spotDistanceKm;

  /// The rider has seen "You're approved" and their spot.
  final bool welcomed;

  /// Operations paused this rider; they can't sign in (Login 16).
  final bool onHold;

  bool get isApproved => status == RegistrationStatus.approved;

  /// Approved and welcomed: the app opens on Home.
  bool get isActive => isApproved && welcomed;

  /// The scooter is electric and provided by Ninzo.
  String get vehicleLabel => 'EV scooter';

  /// Every side uploaded and no open review issue.
  bool isAdded(RiderDocument d) {
    final upload = documents[d];
    return upload != null &&
        upload.issue == null &&
        d.sides.every(upload.files.containsKey);
  }

  int get addedCount => RiderDocument.values.where(isAdded).length;

  bool get allAdded => addedCount == RiderDocument.values.length;

  /// Documents the review team sent back, in list order.
  List<(RiderDocument, DocumentIssue)> get issues => [
    for (final d in RiderDocument.values)
      if (documents[d]?.issue case final issue?) (d, issue),
  ];

  RiderApplication copyWith({
    String? name,
    RiderArea? area,
    RegistrationStatus? status,
    Map<RiderDocument, DocumentUpload>? documents,
    DateTime? submittedAt,
    bool? welcomed,
  }) => RiderApplication(
    uid: uid,
    name: name ?? this.name,
    phone: phone,
    area: area ?? this.area,
    status: status ?? this.status,
    documents: documents ?? this.documents,
    submittedAt: submittedAt ?? this.submittedAt,
    hubLabel: hubLabel,
    firstShift: firstShift,
    spotName: spotName,
    spotDistanceKm: spotDistanceKm,
    welcomed: welcomed ?? this.welcomed,
    onHold: onHold,
  );
}
