import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../widgets/order_timeline.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Order #${order.orderNumber}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Order Status Timeline
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OrderTimeline(order: order),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Order Summary
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.quantity}x',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.variant != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.variant!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  if (item.cakeWriting != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Message: ${item.cakeWriting}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              'AED ${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  _buildPriceRow('Subtotal', order.subtotal),
                  if (order.discount > 0) _buildPriceRow('Discount', -order.discount),
                  if (order.deliveryFee > 0) _buildPriceRow('Delivery Fee', order.deliveryFee),
                  if (order.pointsValue > 0) _buildPriceRow('Points Redeemed', -order.pointsValue),
                  const SizedBox(height: 8),
                  _buildPriceRow('Total', order.total, isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Customer Details
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Phone', order.customerPhone),
                  if (order.isGift) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Gift Message', order.giftMessage ?? ''),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Delivery/Pickup Details
            if (order.deliveryType == DeliveryMethod.DELIVERY)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (order.deliveryDate != null)
                      _buildInfoRow('Delivery Date', DateFormat('dd MMM yyyy').format(order.deliveryDate!)),
                    if (order.deliverySlot != null)
                      _buildInfoRow('Delivery Slot', order.deliverySlot!),
                    if (order.shippingAddress != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.shippingAddress!.street}\n'
                        '${order.shippingAddress!.apartment}\n'
                        '${order.shippingAddress!.city}, ${order.shippingAddress!.emirate}\n'
                        '${order.shippingAddress!.country}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    if (order.deliveryInstructions != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Instructions', order.deliveryInstructions!),
                    ],
                  ],
                ),
              )
            else if (order.deliveryType == DeliveryMethod.PICKUP)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Pickup Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (order.pickupDate != null)
                      _buildInfoRow('Pickup Date', DateFormat('dd MMM yyyy').format(order.pickupDate!)),
                    if (order.pickupTimeSlot != null)
                      _buildInfoRow('Pickup Time', order.pickupTimeSlot!),
                    const SizedBox(height: 12),
                    const Text(
                      'Store Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pinewraps Store\n'
                      'Maid Road - Jumeirah - Jumeirah 1\n'
                      'Dubai, United Arab Emirates\n'
                      '+971 54 404 4864',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Payment Information
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Payment Method',
                    order.paymentMethod.split('.').last.replaceAll('_', ' '),
                  ),
                  _buildInfoRow(
                    'Payment Status',
                    order.paymentStatus.name,
                    valueColor: _getPaymentStatusColor(order.paymentStatus),
                  ),
                  if (order.paymentId != null)
                    _buildInfoRow('Payment ID', order.paymentId!),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            'AED ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.CAPTURED:
        return Colors.green;
      case PaymentStatus.PENDING:
        return Colors.orange;
      case PaymentStatus.FAILED:
        return Colors.red;
      case PaymentStatus.REFUNDED:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
