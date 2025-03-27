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
  final String? image;

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
    this.image,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing OrderItem: ${json['id']}');
      
      // Safe handling for variations
      List<Map<String, dynamic>> parsedVariations = [];
      try {
        if (json['variations'] != null) {
          final variations = json['variations'] as List<dynamic>?;
          if (variations != null) {
            for (var variation in variations) {
              if (variation is Map<String, dynamic>) {
                parsedVariations.add(variation);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing variations: $e');
      }
      
      // Safe date parsing
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        try {
          return DateTime.parse(dateValue.toString());
        } catch (e) {
          debugPrint('Error parsing date: $e');
          return null;
        }
      }
      
      final createdAt = parseDate(json['createdAt']) ?? DateTime.now();
      final updatedAt = parseDate(json['updatedAt']) ?? DateTime.now();
      
      return OrderItem(
        id: json['id']?.toString() ?? '',
        orderId: json['orderId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        variant: json['variant']?.toString(),
        variations: parsedVariations,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: json['quantity'] as int? ?? 1,
        cakeWriting: json['cakeWriting']?.toString(),
        createdAt: createdAt,
        updatedAt: updatedAt,
        image: json['image']?.toString(),
      );
    } catch (e) {
      debugPrint('Error in OrderItem.fromJson: $e');
      // Return minimal valid order item to prevent crashes
      return OrderItem(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        orderId: '',
        name: 'Unknown Item',
        variations: [],
        price: 0.0,
        quantity: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
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
  final String source;

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
    this.source = 'ONLINE',
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing order: ${json['id']}');
      
      OrderStatus orderStatus = OrderStatus.PENDING;
      try {
        final statusString = json['status']?.toString() ?? 'PENDING';
        orderStatus = OrderStatus.values.firstWhere(
          (e) => e.name == statusString,
          orElse: () => OrderStatus.PENDING,
        );
      } catch (e) {
        debugPrint('Error parsing OrderStatus: $e');
      }

      double? deliveryFee;
      try {
        deliveryFee = (json['deliveryCharge'] != null 
            ? (json['deliveryCharge'] as num).toDouble() 
            : 0.0);
      } catch (e) {
        deliveryFee = 0.0;
        debugPrint('Error parsing deliveryFee: $e');
      }

      DeliveryMethod deliveryType = DeliveryMethod.DELIVERY;
      try {
        final typeString = json['deliveryMethod']?.toString() ?? 'DELIVERY';
        deliveryType = typeString.toUpperCase() == 'PICKUP'
            ? DeliveryMethod.PICKUP
            : DeliveryMethod.DELIVERY;
      } catch (e) {
        debugPrint('Error parsing DeliveryMethod: $e');
      }
      
      // Helper function to safely parse dates
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        try {
          return DateTime.parse(dateValue.toString());
        } catch (e) {
          debugPrint('Error parsing date: $e');
          return null;
        }
      }
      
      // Handle payment status safely
      PaymentStatus paymentStatus = PaymentStatus.PENDING;
      try {
        final statusString = json['paymentStatus']?.toString();
        if (statusString != null) {
          paymentStatus = PaymentStatus.values.firstWhere(
            (e) => e.name == statusString,
            orElse: () => PaymentStatus.PENDING,
          );
        }
      } catch (e) {
        debugPrint('Error parsing PaymentStatus: $e');
      }

      // Safe handling for items
      List<OrderItem> orderItems = [];
      try {
        final itemsList = json['items'] as List<dynamic>?;
        if (itemsList != null) {
          for (var item in itemsList) {
            try {
              if (item is Map<String, dynamic>) {
                orderItems.add(OrderItem.fromJson(item));
              }
            } catch (e) {
              debugPrint('Error parsing individual order item: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing order items list: $e');
      }

      // Safe handling for status history
      List<OrderStatusHistory> history = [];
      try {
        final historyList = json['statusHistory'] as List<dynamic>?;
        if (historyList != null) {
          for (var entry in historyList) {
            try {
              if (entry is Map<String, dynamic>) {
                history.add(OrderStatusHistory.fromJson(entry));
              }
            } catch (e) {
              debugPrint('Error parsing individual status history entry: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing status history list: $e');
      }

      return Order(
        id: json['id']?.toString() ?? '',
        orderNumber: json['orderNumber']?.toString() ?? '',
        customerId: json['customerId']?.toString() ?? '',
        status: orderStatus,
        createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
        updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
        customerPhone: json['customer']?['phone']?.toString() ?? json['customerPhone']?.toString() ?? '',
        deliveryType: deliveryType,
        deliveryDate: parseDate(json['deliveryDate']),
        deliverySlot: json['deliveryTimeSlot']?.toString(),
        deliveryFee: deliveryFee ?? 0.0,
        deliveryInstructions: json['deliveryInstructions']?.toString(),
        pickupDate: parseDate(json['pickupDate']),
        pickupTimeSlot: json['pickupTimeSlot']?.toString(),
        storeLocation: json['storeLocation']?.toString(),
        streetAddress: json['streetAddress']?.toString(),
        apartment: json['apartment']?.toString(),
        emirate: json['emirate']?.toString(),
        city: json['city']?.toString(),
        pincode: json['pincode']?.toString(),
        country: json['country']?.toString() ?? 'UAE',
        isGift: json['isGift'] as bool? ?? false,
        giftMessage: json['giftMessage']?.toString(),
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: paymentStatus,
        paymentMethod: json['paymentMethod']?.toString() ?? '',
        paymentId: json['paymentId']?.toString(),
        couponCode: json['couponCode']?.toString(),
        couponDiscount: (json['couponDiscount'] as num?)?.toDouble() ?? 0.0,
        couponId: json['couponId']?.toString(),
        pointsEarned: json['pointsEarned'] as int? ?? 0,
        pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
        pointsValue: (json['pointsValue'] as num?)?.toDouble() ?? 0.0,
        adminNotes: json['adminNotes']?.toString(),
        items: orderItems,
        statusHistory: history,
        source: json['source']?.toString() ?? 'ONLINE',
      );
    } catch (e) {
      debugPrint('Error in Order.fromJson: $e');
      // Return minimal valid order to prevent crashes
      return Order(
        id: json['id']?.toString() ?? 'error-${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: json['orderNumber']?.toString() ?? 'ERROR',
        customerId: '',
        status: OrderStatus.PENDING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        customerPhone: '',
        deliveryType: DeliveryMethod.DELIVERY,
        deliveryFee: 0.0,
        isGift: false,
        subtotal: 0.0,
        total: 0.0,
        discount: 0.0,
        paymentStatus: PaymentStatus.PENDING,
        paymentMethod: '',
        couponDiscount: 0.0,
        pointsEarned: 0,
        pointsRedeemed: 0, 
        pointsValue: 0.0,
        items: [],
        statusHistory: [],
      );
    }
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
    try {
      print('Parsing status history: ${json['id']}');
      
      OrderStatus status = OrderStatus.PENDING;
      try {
        final statusString = json['status']?.toString() ?? 'PENDING';
        status = OrderStatus.values.firstWhere(
          (e) => e.name == statusString,
          orElse: () => OrderStatus.PENDING,
        );
      } catch (e) {
        debugPrint('Error parsing status in OrderStatusHistory: $e');
      }

      DateTime updatedAt = DateTime.now();
      try {
        if (json['updatedAt'] != null) {
          updatedAt = DateTime.parse(json['updatedAt'].toString());
        }
      } catch (e) {
        debugPrint('Error parsing updatedAt in OrderStatusHistory: $e');
      }

      return OrderStatusHistory(
        id: json['id']?.toString() ?? 'status-${DateTime.now().millisecondsSinceEpoch}',
        orderId: json['orderId']?.toString() ?? '',
        status: status,
        notes: json['notes']?.toString(),
        updatedBy: json['updatedBy']?.toString() ?? 'System',
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('Error in OrderStatusHistory.fromJson: $e');
      // Return a minimal valid status history to prevent crashes
      return OrderStatusHistory(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        orderId: '',
        status: OrderStatus.PENDING,
        updatedBy: 'System',
        updatedAt: DateTime.now(),
      );
    }
  }
}
