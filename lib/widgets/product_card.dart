import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product/product_details_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(productId: product.id),
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available space for details section
          final totalHeight = constraints.maxHeight;
          // Reserve 60% for image, 40% for details
          final imageHeight = totalHeight * 0.6;
          final detailsHeight = totalHeight * 0.4;
          
          return Container(
            width: width ?? double.infinity,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max, // Fill the available space
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image - Using percentage of total height
                SizedBox(
                  width: constraints.maxWidth,
                  height: imageHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      image: product.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(product.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    ),
                    child: product.imageUrl == null
                      ? const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 30,
                          ),
                        )
                      : null,
                  ),
                ),
                
                // Product Details - Using percentage of total height
                SizedBox(
                  height: detailsHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          maxLines: 2, // Allow two lines for product name
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Product Price
                        (product.categoryId.toLowerCase() == 'sets' || 
                         product.category.name.toLowerCase() == 'sets')
                        ? const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Starting From 332 Onwards",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          )
                        : Text(
                            product.getFormattedPrice(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
