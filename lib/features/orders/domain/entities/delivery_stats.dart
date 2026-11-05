import 'order.dart';

/// Totals over a set of delivered orders.
class DeliveryStats {
  const DeliveryStats({this.earnings = 0, this.deliveries = 0, this.onTime = 0, this.cashCollected = 0});

  factory DeliveryStats.of(Iterable<Order> orders) => DeliveryStats(
        earnings: orders.fold(0, (sum, o) => sum + o.riderFee),
        deliveries: orders.length,
        onTime: orders.where((o) => o.deliveredOnTime).length,
        cashCollected: orders.where((o) => o.collectCash).fold(0, (sum, o) => sum + o.total),
      );

  /// Stats for the orders delivered on the calendar date of [day].
  factory DeliveryStats.onDay(Iterable<Order> orders, DateTime day) => DeliveryStats.of(orders.where((o) {
        final d = o.deliveredAt ?? o.createdAt;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }));

  final double earnings;
  final int deliveries;

  /// Deliveries handed over within [Order.deliveryWindow].
  final int onTime;

  /// Cash taken from customers on cash-on-delivery orders, which the rider
  /// still has to hand over to NinzoRider.
  final double cashCollected;

  /// 0–100; 100 with no deliveries yet.
  int get onTimePercent => deliveries == 0 ? 100 : (onTime * 100 / deliveries).round();
}
