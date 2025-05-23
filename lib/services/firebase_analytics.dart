import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

class FirebaseAnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logPageView({required String screenName}) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
    );
  }

  static Future<void> logAddToCart({
    required String itemId,
    required String itemName,
    required double price,
    required String currency,
  }) async {
    await _analytics.logAddToCart(
      items: [
        {
          'item_id': itemId,
          'item_name': itemName,
          'price': price,
          'currency': currency,
        },
      ],
      currency: currency,
      value: price,
    );
  }

  static Future<void> logPurchase({
    required String transactionId,
    required double value,
    required String currency,
    required List<Map<String, dynamic>> items,
  }) async {
    await _analytics.logPurchase(
      transactionId: transactionId,
      currency: currency,
      value: value,
      items: items,
    );
  }

  static Future<void> logViewItem({
    required String itemId,
    required String itemName,
    required double price,
    required String currency,
  }) async {
    await _analytics.logViewItem(
      items: [
        {
          'item_id': itemId,
          'item_name': itemName,
          'price': price,
          'currency': currency,
        },
      ],
      currency: currency,
      value: price,
    );
  }
}
