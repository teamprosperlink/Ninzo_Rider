import '../../../../core/error/app_exception.dart';
import '../entities/rider_application.dart';
import '../entities/rider_document.dart';
import '../repositories/photo_source.dart';
import '../repositories/registration_repository.dart';

/// Register 05 "Take photo" / "Upload from gallery". Null when cancelled.
class TakeDocumentPhoto {
  const TakeDocumentPhoto(this._source);

  final PhotoSource _source;

  Future<String?> call(RiderDocument document, {required bool fromGallery}) =>
      fromGallery
      ? _source.pickFromGallery()
      : _source.takePhoto(selfie: document == RiderDocument.selfie);
}

/// Register 06 "Use this photo": uploads it and saves it on the
/// application. Re-taking the last side of a document the team sent back
/// clears its issue.
class UploadDocumentPhoto {
  const UploadDocumentPhoto(this._repo);

  final RegistrationRepository _repo;

  Future<void> call(
    RiderApplication application, {
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  }) async {
    final url = await _repo.uploadPhoto(
      uid: application.uid,
      document: document,
      side: side,
      filePath: filePath,
    );
    var upload = (application.documents[document] ?? const DocumentUpload())
        .withFile(side, url);
    if (side == document.sides.last) upload = upload.cleared();
    await _repo.saveDocuments(application.uid, {
      ...application.documents,
      document: upload,
    });
  }
}

/// Register 07 "Submit for review": needs every document.
class SubmitForReview {
  const SubmitForReview(this._repo);

  final RegistrationRepository _repo;

  Future<void> call(RiderApplication application) async {
    final missing = RiderDocument.values.where((d) => !application.isAdded(d));
    if (missing.isNotEmpty) {
      throw const AppException();
    }
    await _repo.submit(application.uid);
  }
}

/// Register 11–13: reopens the application to retake or update documents.
class ReopenApplication {
  const ReopenApplication(this._repo);

  final RegistrationRepository _repo;

  Future<void> call(RiderApplication application) async {
    if (application.status == RegistrationStatus.draft) return;
    await _repo.reopen(application.uid);
  }
}

/// Register 10 "Got it": the rider has seen their spot; Home opens next.
class AcknowledgeApproval {
  const AcknowledgeApproval(this._repo);

  final RegistrationRepository _repo;

  Future<void> call(RiderApplication application) async {
    if (!application.isApproved) return;
    await _repo.markWelcomed(application.uid);
  }
}

class WatchRegistration {
  const WatchRegistration(this._repo);

  final RegistrationRepository _repo;

  Stream<RiderApplication?> call(String uid) => _repo.watch(uid);
}
