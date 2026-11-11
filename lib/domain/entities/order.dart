/// One line of an order: what and how many.
class OrderItem {
  const OrderItem({required this.name, required this.quantity});

  final String name;
  final int quantity;
}
