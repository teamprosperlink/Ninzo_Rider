import '../../core/constants/app_strings.dart';
/// One side (photo) of a document, e.g. the front of the Aadhaar card.
enum DocumentSide { front, back, photo }

/// The documents a new rider adds (Register 04). The scooter is electric and
/// provided by Ninzo, so every rider adds the same five.
enum RiderDocument {
  aadhaar(
    label: AppStrings.aadhaarCard,
    hint: AppStrings.frontAndBack,
    name: AppStrings.aadhaarCard,
    sides: [DocumentSide.front, DocumentSide.back],
  ),
  drivingLicence(
    label: AppStrings.drivingLicence,
    hint: AppStrings.frontSideValid,
    name: AppStrings.drivingLicence2,
    renewName: AppStrings.licence,
    sides: [DocumentSide.front],
  ),
  vehicleRc(
    label: AppStrings.vehicleRc,
    hint: AppStrings.registrationCertificate,
    name: AppStrings.vehicleRc2,
    renewName: AppStrings.textRc,
    sides: [DocumentSide.photo],
  ),
  selfie(
    label: AppStrings.selfiePhoto,
    hint: AppStrings.clearNoHelmet,
    name: AppStrings.selfiePhoto2,
    sides: [DocumentSide.photo],
  ),
  bank(
    label: AppStrings.bankAccountOrUpi,
    hint: AppStrings.forWeeklyPayouts,
    name: AppStrings.bankDetails,
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
    DocumentSide.front => AppStrings.front(label),
    DocumentSide.back => AppStrings.back2(label),
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
