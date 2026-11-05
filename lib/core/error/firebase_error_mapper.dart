import 'package:firebase_core/firebase_core.dart';

import 'app_exception.dart';

/// Runs a Firebase call and turns its failures into [AppException]s. Used
/// by the data layer only, so the domain never sees Firebase types.
Future<T> guardFirebase<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on AppException {
    rethrow;
  } on FirebaseException catch (e) {
    throw firebaseError(e);
  }
}

AppException firebaseError(FirebaseException e) => AppException(e.code);
