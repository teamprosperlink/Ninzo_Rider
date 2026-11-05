import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/rider_area.dart';
import '../../domain/repositories/area_repository.dart';
import '../models/rider_application_model.dart';

/// Reads `areas/{id}` (`{name, city, lat, lng, popular}`), readable before
/// sign-in. The list is small, so it's loaded once and searched on the phone.
class FirestoreAreaRepository implements AreaRepository {
  FirestoreAreaRepository(this._db);

  final FirebaseFirestore _db;
  List<RiderArea>? _cache;

  @override
  Future<List<RiderArea>> all() async {
    final cached = _cache;
    if (cached != null) return cached;
    final areas = await guardFirebase(() async {
      final snap = await _db.collection('areas').get();
      return [
        for (final d in snap.docs) RiderAreaModel.fromFirestore(d.id, d.data()),
      ];
    });
    areas.sort((a, b) => a.popular == b.popular ? 0 : (a.popular ? -1 : 1));
    return _cache = areas;
  }
}
