/// Takes or picks a document photo. Returns the local file path, or null
/// when the rider cancels.
abstract interface class PhotoSource {
  /// Opens the camera ([selfie]: the front camera). Throws a
  /// RegisterFailure (cameraDenied) when camera access is refused.
  Future<String?> takePhoto({bool selfie = false});

  Future<String?> pickFromGallery();
}
