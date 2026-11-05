import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/profile.dart';

/// `riders/{uid}`: `createdAt`; backend: `spot.assignedAt`.
ProfileFacts profileFactsFromFirestore(Map<String, dynamic>? j) {
  final spot = (j?['spot'] as Map?)?.cast<String, dynamic>();
  return ProfileFacts(
    riderSince: (j?['createdAt'] as Timestamp?)?.toDate(),
    spotAssignedAt: (spot?['assignedAt'] as Timestamp?)?.toDate(),
  );
}

/// `riders/{uid}/notifications/{id}`: `title`, `body`, `at`.
RiderNotification riderNotificationFromFirestore(String id, Map<String, dynamic> j) => RiderNotification(
  id: id,
  title: j['title'] as String? ?? '',
  body: j['body'] as String? ?? '',
  at: (j['at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
);

/// `riders/{uid}/shifts/{yyyy-MM-dd}`: `end`, `onlineAt`, `endedAt`,
/// `today {orders, earned}`.
ShiftRecord shiftRecordFromFirestore(String id, Map<String, dynamic> j) {
  final today = (j['today'] as Map?)?.cast<String, dynamic>() ?? const {};
  return ShiftRecord(
    date: DateTime.parse(id),
    orders: (today['orders'] as num?)?.toInt() ?? 0,
    earned: (today['earned'] as num?)?.toDouble() ?? 0,
    onlineAt: (j['onlineAt'] as Timestamp?)?.toDate(),
    plannedEnd: (j['end'] as Timestamp).toDate(),
    endedAt: (j['endedAt'] as Timestamp?)?.toDate(),
  );
}
