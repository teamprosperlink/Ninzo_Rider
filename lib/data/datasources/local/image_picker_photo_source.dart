import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../domain/entities/register_failure.dart';
import '../../../domain/repositories/photo_source.dart';

/// Document photos from the system camera or gallery, scaled down so each
/// upload stays under the rider API's 700 KB a photo.
class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto({bool selfie = false}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted && !status.isLimited) {
      throw const RegisterFailure(RegisterFailureKind.cameraDenied);
    }
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1400,
      imageQuality: 70,
    );
    return file?.path;
  }

  @override
  Future<String?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 70,
    );
    return file?.path;
  }
}
