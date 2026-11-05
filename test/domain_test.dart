import 'package:flutter_test/flutter_test.dart';

import 'package:ninzo_rider/core/utils/formatters.dart';
import 'package:ninzo_rider/core/utils/validators.dart';
import 'package:ninzo_rider/features/orders/domain/entities/order.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_document.dart';
import 'package:ninzo_rider/features/orders/domain/entities/delivery_stats.dart';

import 'fakes.dart';

void main() {
  test('Only accepted and picked-up orders are active', () {
    expect(OrderStatus.values.where((s) => s.isActive), [
      OrderStatus.accepted,
      OrderStatus.pickedUp,
    ]);
  });

  test('Deadline is 90 seconds after pickup; on time means within it', () {
    final pickup = DateTime(2026, 1, 1, 12);
    expect(testOrder().deadline, isNull);
    expect(
      testOrder(pickedUpAt: pickup).deadline,
      pickup.add(const Duration(seconds: 90)),
    );

    final fast = testOrder(
      pickedUpAt: pickup,
      deliveredAt: pickup.add(const Duration(seconds: 90)),
    );
    final slow = testOrder(
      pickedUpAt: pickup,
      deliveredAt: pickup.add(const Duration(seconds: 91)),
    );
    expect(fast.deliveredOnTime, isTrue);
    expect(slow.deliveredOnTime, isFalse);
    expect(slow.deliveryTime, const Duration(seconds: 91));
  });

  test('Stats sum fees and count on-time deliveries', () {
    final pickup = DateTime(2026, 1, 1, 12);
    final stats = DeliveryStats.of([
      testOrder(
        pickedUpAt: pickup,
        deliveredAt: pickup.add(const Duration(seconds: 60)),
      ),
      testOrder(
        pickedUpAt: pickup,
        deliveredAt: pickup.add(const Duration(seconds: 120)),
      ),
    ]);
    expect(stats.earnings, 50);
    expect(stats.deliveries, 2);
    expect(stats.onTimePercent, 50);
    expect(const DeliveryStats().onTimePercent, 100);
  });

  test('A document counts as added with every side and no open issue', () {
    final a = Fakes().riderApplication(RegistrationStatus.draft);
    expect(a.allAdded, isTrue);
    const front = DocumentUpload(files: {DocumentSide.front: 'f'});
    final flagged = a.copyWith(
      documents: {
        ...a.documents,
        RiderDocument.aadhaar: front,
        RiderDocument.selfie: DocumentUpload(
          files: a.documents[RiderDocument.selfie]!.files,
          issue: DocumentIssue.retake,
        ),
      },
    );
    expect(flagged.isAdded(RiderDocument.aadhaar), isFalse);
    expect(flagged.addedCount, 3);
    expect(flagged.issues.single.$1, RiderDocument.selfie);
    expect(
      RiderDocument.aadhaar.title(DocumentSide.back),
      'Aadhaar card · Back',
    );
    expect(RiderDocument.selfie.title(DocumentSide.photo), 'Selfie photo');
  });

  test('Formatters', () {
    expect(clock(90), '1:30');
    expect(clock(-5), '0:05');
    expect(distance(0.35), '350 m');
    expect(distance(1.24), '1.2 km');
    expect(rupees(25), '₹25');
    expect(phoneNumber('+919876543210'), '+91 98765 43210');
    expect(phoneNumber('+14155550100'), '+14155550100');
    expect(plural(1, 'delivery', 'deliveries'), '1 delivery');
    expect(plural(3, 'delivery', 'deliveries'), '3 deliveries');
  });

  test('Validators', () {
    expect(Validators.isMobile('9876543210'), isTrue);
    expect(Validators.isMobile('1234567890'), isFalse);
  });
}
