import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusBadge({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusText(),
        style: TextStyle(
          color: _getStatusColor(),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (status) {
      case OrderStatus.PENDING:
        return 'Pending';
      case OrderStatus.PENDING_PAYMENT:
        return 'Pending Payment';
      case OrderStatus.PROCESSING:
        return 'Processing';
      case OrderStatus.READY_FOR_PICKUP:
        return 'Ready for Pickup';
      case OrderStatus.OUT_FOR_DELIVERY:
        return 'Out for Delivery';
      case OrderStatus.DELIVERED:
        return 'Delivered';
      case OrderStatus.CANCELLED:
        return 'Cancelled';
      case OrderStatus.COMPLETED:
        return 'Completed';
      case OrderStatus.REFUNDED:
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case OrderStatus.PENDING:
      case OrderStatus.PENDING_PAYMENT:
        return Colors.orange;
      case OrderStatus.PROCESSING:
      case OrderStatus.READY_FOR_PICKUP:
      case OrderStatus.OUT_FOR_DELIVERY:
        return Colors.blue;
      case OrderStatus.DELIVERED:
      case OrderStatus.COMPLETED:
        return Colors.green;
      case OrderStatus.CANCELLED:
      case OrderStatus.REFUNDED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
