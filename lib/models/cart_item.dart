import 'product.dart';

class CartItem {
  final String id;
  final Product product;
  final String? selectedSize;
  final String? selectedFlavour;
  final String? cakeText;
  final int quantity;
  final double price;

  CartItem({
    required this.id,
    required this.product,
    this.selectedSize,
    this.selectedFlavour,
    this.cakeText,
    required this.quantity,
    required this.price,
  });

  double get totalPrice => price * quantity;

  CartItem copyWith({
    String? id,
    Product? product,
    String? selectedSize,
    String? selectedFlavour,
    String? cakeText,
    int? quantity,
    double? price,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedFlavour: selectedFlavour ?? this.selectedFlavour,
      cakeText: cakeText ?? this.cakeText,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': product.id,
      'selectedSize': selectedSize,
      'selectedFlavour': selectedFlavour,
      'cakeText': cakeText,
      'quantity': quantity,
      'price': price,
    };
  }
}
