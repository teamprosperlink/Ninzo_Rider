/// One side (photo) of a document, e.g. the front of the Aadhaar card.
enum DocumentSide { front, back, photo }

/// The documents a new rider adds (Register 04). The scooter is electric and
/// provided by Ninzo, so every rider adds the same five.
enum RiderDocument {
  aadhaar(
    label: 'Aadhaar card',
    hint: 'Front and back',
    name: 'Aadhaar card',
    sides: [DocumentSide.front, DocumentSide.back],
  ),
  drivingLicence(
    label: 'Driving licence',
    hint: 'Front side, valid',
    name: 'driving licence',
    renewName: 'licence',
    sides: [DocumentSide.front],
  ),
  vehicleRc(
    label: 'Vehicle RC',
    hint: 'Registration certificate',
    name: 'vehicle RC',
    renewName: 'RC',
    sides: [DocumentSide.photo],
  ),
  selfie(
    label: 'Selfie photo',
    hint: 'Clear, no helmet',
    name: 'selfie photo',
    sides: [DocumentSide.photo],
  ),
  bank(
    label: 'Bank account or UPI',
    hint: 'For weekly payouts',
    name: 'bank details',
    sides: [DocumentSide.photo],
  );

  const RiderDocument({
    required this.label,
    required this.hint,
    required this.name,
    this.renewName,
    required this.sides,
  });

  /// "Aadhaar card".
  final String label;

  /// "Front and back".
  final String hint;

  /// Used in sentences: "a clearer photo of your driving licence".
  final String name;

  /// "Add your renewed licence".
  final String? renewName;

  /// Photos needed, in order.
  final List<DocumentSide> sides;

  /// Photo screen title: "Aadhaar card · Front", or just "Selfie photo".
  String title(DocumentSide side) => switch (side) {
    DocumentSide.front => '$label · Front',
    DocumentSide.back => '$label · Back',
    DocumentSide.photo => label,
  };
}

/// Why the review team sent a document back.
enum DocumentIssue {
  /// The photo is unclear: take it again (Register 11, 12).
  retake,

  /// The name doesn't match the one the rider entered (Register 12).
  nameMismatch,

  /// The document has expired (Register 13).
  expired,
}

/// What the rider has uploaded for one document, and the review result.
class DocumentUpload {
  const DocumentUpload({this.files = const {}, this.issue});

  /// Download URL of each uploaded side.
  final Map<DocumentSide, String> files;
  final DocumentIssue? issue;

  DocumentUpload withFile(DocumentSide side, String url) =>
      DocumentUpload(files: {...files, side: url}, issue: issue);

  /// A fresh upload of every side clears the review issue.
  DocumentUpload cleared() => DocumentUpload(files: files);
}
