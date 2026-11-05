import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/firebase_providers.dart';
import '../../account/di/account_di.dart';
import '../../auth/di/auth_di.dart';
import '../../location/di/location_di.dart';
import '../data/repositories/demo_registration_repository.dart';
import '../data/repositories/firebase_registration_repository.dart';
import '../data/repositories/firestore_area_repository.dart';
import '../data/repositories/image_picker_photo_source.dart';
import '../domain/repositories/area_repository.dart';
import '../domain/repositories/photo_source.dart';
import '../domain/repositories/registration_repository.dart';
import '../domain/usecases/area_usecases.dart';
import '../domain/usecases/document_usecases.dart';
import '../domain/usecases/save_registration_details.dart';
import '../domain/usecases/start_registration.dart';

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => kDemoMode
      ? DemoRegistrationRepository()
      : FirebaseRegistrationRepository(
          ref.watch(firestoreProvider),
          ref.watch(firebaseStorageProvider),
        ),
);

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => kDemoMode
      ? DemoAreaRepository()
      : FirestoreAreaRepository(ref.watch(firestoreProvider)),
);

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => ImagePickerPhotoSource(),
);

final watchRegistrationUseCaseProvider = Provider(
  (ref) => WatchRegistration(ref.watch(registrationRepositoryProvider)),
);
final startRegistrationUseCaseProvider = Provider(
  (ref) => StartRegistration(
    ref.watch(riderDirectoryProvider),
    ref.watch(authRepositoryProvider),
  ),
);
final saveRegistrationDetailsUseCaseProvider = Provider(
  (ref) => SaveRegistrationDetails(
    ref.watch(registrationRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);
final searchAreasUseCaseProvider = Provider(
  (ref) => SearchAreas(ref.watch(areaRepositoryProvider)),
);
final findAreaNearMeUseCaseProvider = Provider(
  // Demo: any position finds the nearest sample area (emulators sit far away).
  (ref) => FindAreaNearMe(
    ref.watch(areaRepositoryProvider),
    ref.watch(locationRepositoryProvider),
    maxKm: kDemoMode ? double.infinity : 25,
  ),
);
final takeDocumentPhotoUseCaseProvider = Provider(
  (ref) => TakeDocumentPhoto(ref.watch(photoSourceProvider)),
);
final uploadDocumentPhotoUseCaseProvider = Provider(
  (ref) => UploadDocumentPhoto(ref.watch(registrationRepositoryProvider)),
);
final submitForReviewUseCaseProvider = Provider(
  (ref) => SubmitForReview(ref.watch(registrationRepositoryProvider)),
);
final reopenApplicationUseCaseProvider = Provider(
  (ref) => ReopenApplication(ref.watch(registrationRepositoryProvider)),
);
final acknowledgeApprovalUseCaseProvider = Provider(
  (ref) => AcknowledgeApproval(ref.watch(registrationRepositoryProvider)),
);
