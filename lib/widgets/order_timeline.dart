import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';

class OrderTimeline extends StatelessWidget {
  final Order order;

  const OrderTimeline({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusHistory = order.statusHistory.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statusHistory.length,
      itemBuilder: (context, index) {
        final status = statusHistory[index];
        final isLast = index == statusHistory.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(status.status),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy h:mm a').format(status.updatedAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (status.notes != null && status.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          status.notes!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.PENDING:
        return 'Order Placed';
      case OrderStatus.PENDING_PAYMENT:
        return 'Payment Pending';
      case OrderStatus.PROCESSING:
        return 'Order Processing';
      case OrderStatus.READY_FOR_PICKUP:
        return 'Ready for Pickup';
      case OrderStatus.OUT_FOR_DELIVERY:
        return 'Out for Delivery';
      case OrderStatus.DELIVERED:
        return 'Order Delivered';
      case OrderStatus.CANCELLED:
        return 'Order Cancelled';
      case OrderStatus.COMPLETED:
        return 'Order Completed';
      case OrderStatus.REFUNDED:
        return 'Order Refunded';
      default:
        return 'Unknown Status';
    }
  }

  Color _getStatusColor(OrderStatus status) {
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
