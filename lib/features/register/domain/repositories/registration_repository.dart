import '../entities/rider_application.dart';
import '../entities/rider_area.dart';
import '../entities/rider_document.dart';

/// The signed-in rider's registration (`riders/{uid}`) and document photos.
abstract interface class RegistrationRepository {
  /// The rider's application, or null before the details are saved.
  Stream<RiderApplication?> watch(String uid);

  /// Creates or updates the details (name, number, area) of a draft
  /// application, and lists the number in the rider directory so it can
  /// sign in and can't be registered twice.
  Future<void> saveDetails({
    required String uid,
    required String phone,
    required String name,
    required RiderArea area,
  });

  /// Uploads one photo and returns its download URL.
  Future<String> uploadPhoto({
    required String uid,
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  });

  /// Saves the rider's documents (URLs and cleared issues).
  Future<void> saveDocuments(
    String uid,
    Map<RiderDocument, DocumentUpload> documents,
  );

  /// Back to [RegistrationStatus.draft] to fix documents the team sent back.
  Future<void> reopen(String uid);

  /// Sends the application for review ([RegistrationStatus.underReview]).
  Future<void> submit(String uid);

  /// The rider has seen "You're approved" and their spot.
  Future<void> markWelcomed(String uid);
}
