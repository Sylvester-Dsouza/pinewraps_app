import 'package:flutter/foundation.dart';
import 'address.dart';

enum OrderStatus {
  all('All'),
  PENDING('Pending'),
  PENDING_PAYMENT('Pending Payment'),
  PROCESSING('Processing'),
  READY_FOR_PICKUP('Ready for Pickup'),
  OUT_FOR_DELIVERY('Out for Delivery'),
  DELIVERED('Delivered'),
  COMPLETED('Completed'),
  CANCELLED('Cancelled'),
  REFUNDED('Refunded');

  final String label;
  const OrderStatus(this.label);
}

enum PaymentStatus {
  PENDING,
  CAPTURED,
  FAILED,
  REFUNDED
}

enum DeliveryMethod {
  PICKUP,
  DELIVERY
}

class OrderItem {
  final String id;
  final String orderId;
  final String name;
  final String? variant;
  final List<Map<String, dynamic>> variations;
  final double price;
  final int quantity;
  final String? cakeWriting;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.name,
    this.variant,
    required this.variations,
    required this.price,
    required this.quantity,
    this.cakeWriting,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      variant: json['variant']?.toString(),
      variations: (json['variations'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      cakeWriting: json['cakeWriting']?.toString(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String customerPhone;
  final DeliveryMethod deliveryType;
  final DateTime? deliveryDate;
  final String? deliverySlot;
  final double deliveryFee;
  final String? deliveryInstructions;
  final DateTime? pickupDate;
  final String? pickupTimeSlot;
  final String? storeLocation;
  final Address? shippingAddress;
  final String? streetAddress;
  final String? apartment;
  final String? emirate;
  final String? city;
  final String? pincode;
  final String? country;
  final bool isGift;
  final String? giftMessage;
  final double subtotal;
  final double total;
  final double discount;
  final PaymentStatus paymentStatus;
  final String paymentMethod;
  final String? paymentId;
  final String? couponCode;
  final double couponDiscount;
  final String? couponId;
  final int pointsEarned;
  final int pointsRedeemed;
  final double pointsValue;
  final String? adminNotes;
  final List<OrderItem> items;
  final List<OrderStatusHistory> statusHistory;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.customerPhone,
    required this.deliveryType,
    this.deliveryDate,
    this.deliverySlot,
    required this.deliveryFee,
    this.deliveryInstructions,
    this.pickupDate,
    this.pickupTimeSlot,
    this.storeLocation,
    this.shippingAddress,
    this.streetAddress,
    this.apartment,
    this.emirate,
    this.city,
    this.pincode,
    this.country,
    required this.isGift,
    this.giftMessage,
    required this.subtotal,
    required this.total,
    required this.discount,
    required this.paymentStatus,
    required this.paymentMethod,
    this.paymentId,
    this.couponCode,
    required this.couponDiscount,
    this.couponId,
    required this.pointsEarned,
    required this.pointsRedeemed,
    required this.pointsValue,
    this.adminNotes,
    required this.items,
    required this.statusHistory,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => OrderStatus.PENDING,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      customerPhone: json['customerPhone']?.toString() ?? '',
      deliveryType: DeliveryMethod.values.firstWhere(
        (e) => e.name == (json['deliveryType'] as String?),
        orElse: () => DeliveryMethod.PICKUP,
      ),
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.parse(json['deliveryDate'] as String)
          : null,
      deliverySlot: json['deliverySlot']?.toString(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      deliveryInstructions: json['deliveryInstructions']?.toString(),
      pickupDate: json['pickupDate'] != null
          ? DateTime.parse(json['pickupDate'] as String)
          : null,
      pickupTimeSlot: json['pickupTimeSlot']?.toString(),
      storeLocation: json['storeLocation']?.toString(),
      shippingAddress: json['shippingAddress'] != null
          ? Address.fromJson(json['shippingAddress'] as Map<String, dynamic>)
          : null,
      streetAddress: json['streetAddress']?.toString(),
      apartment: json['apartment']?.toString(),
      emirate: json['emirate']?.toString(),
      city: json['city']?.toString(),
      pincode: json['pincode']?.toString(),
      country: json['country']?.toString(),
      isGift: json['isGift'] as bool? ?? false,
      giftMessage: json['giftMessage']?.toString(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == (json['paymentStatus'] as String?),
        orElse: () => PaymentStatus.PENDING,
      ),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      paymentId: json['paymentId']?.toString(),
      couponCode: json['couponCode']?.toString(),
      couponDiscount: (json['couponDiscount'] as num?)?.toDouble() ?? 0.0,
      couponId: json['couponId']?.toString(),
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      pointsValue: (json['pointsValue'] as num?)?.toDouble() ?? 0.0,
      adminNotes: json['adminNotes']?.toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((e) => OrderStatusHistory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class OrderStatusHistory {
  final String id;
  final String orderId;
  final OrderStatus status;
  final String? notes;
  final String updatedBy;
  final DateTime updatedAt;

  OrderStatusHistory({
    required this.id,
    required this.orderId,
    required this.status,
    this.notes,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => OrderStatus.PENDING,
      ),
      notes: json['notes']?.toString(),
      updatedBy: json['updatedBy']?.toString() ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
