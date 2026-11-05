/// One line of a restock: what the hub would pack.
class RestockLine {
  const RestockLine({required this.itemId, required this.name, required this.quantity});

  final String itemId;
  final String name;
  final int quantity;

  RestockLine withQuantity(int quantity) => RestockLine(itemId: itemId, name: name, quantity: quantity);
}

/// What the hub has when it can't pack everything (Restock 05).
class RestockShortage {
  const RestockShortage({
    required this.itemName,
    required this.asked,
    required this.canGive,
    required this.otherHubName,
    required this.otherHubKm,
    required this.otherHubHas,
  });

  final String itemName;
  final int asked;
  final int canGive;
  final String otherHubName;
  final double otherHubKm;
  final int otherHubHas;
}

enum RestockStage {
  /// Restock 01, or 04 once it has expired.
  suggested,

  /// Restock 03.
  inProgress,

  /// Restock 05.
  hubShort,
}

/// How far the hub is with a confirmed restock (Restock 03).
enum HubPacking { sent, accepted, packing, ready }

/// A restock the backend suggests while the rider is online. Firestore: the
/// `restock` field of the shift, see OnlineStatusModel.
class RestockRequest {
  const RestockRequest({
    required this.stage,
    required this.hubName,
    required this.lines,
    this.readyInMinutes,
    this.rideMinutes,
    this.expiresAt,
    this.queueSlot,
    this.arriveBy,
    this.packing = HubPacking.sent,
    this.readyAt,
    this.shortage,
  });

  final RestockStage stage;
  final String hubName;
  final List<RestockLine> lines;

  /// Restock 01.
  final int? readyInMinutes;
  final int? rideMinutes;

  /// The suggestion stops counting after this; null keeps it open.
  final DateTime? expiresAt;

  /// Restock 03.
  final int? queueSlot;
  final DateTime? arriveBy;
  final HubPacking packing;
  final DateTime? readyAt;

  /// Restock 05.
  final RestockShortage? shortage;

  RestockRequest copyWith({
    RestockStage? stage,
    String? hubName,
    List<RestockLine>? lines,
    DateTime? Function()? expiresAt,
    RestockShortage? Function()? shortage,
  }) => RestockRequest(
    stage: stage ?? this.stage,
    hubName: hubName ?? this.hubName,
    lines: lines ?? this.lines,
    readyInMinutes: readyInMinutes,
    rideMinutes: rideMinutes,
    expiresAt: expiresAt == null ? this.expiresAt : expiresAt(),
    queueSlot: queueSlot,
    arriveBy: arriveBy,
    packing: packing,
    readyAt: readyAt,
    shortage: shortage == null ? this.shortage : shortage(),
  );
}

/// The rules of a restock's quantities (Restock 02).
abstract final class RestockRules {
  /// "Your scooter holds up to 8 items."
  static const scooterHolds = 8;

  static int total(List<RestockLine> lines) => lines.fold(0, (sum, line) => sum + line.quantity);

  static bool canAdd(List<RestockLine> lines) => total(lines) < scooterHolds;

  /// A restock always asks for something.
  static bool canRemove(List<RestockLine> lines, int index) => lines[index].quantity > 0 && total(lines) > 1;

  /// A suggestion past its time (Restock 04).
  static bool isExpired(RestockRequest request, DateTime now) =>
      request.stage == RestockStage.suggested && request.expiresAt != null && !now.isBefore(request.expiresAt!);

  /// "4 Smash Burgers" (Restock 01).
  static String headline(List<RestockLine> lines) =>
      lines.where((l) => l.quantity > 0).map((l) => '${l.quantity} ${pluralName(l.name, l.quantity)}').join(', ');

  static String pluralName(String name, int quantity) => quantity == 1 ? name : '${name}s';
}
