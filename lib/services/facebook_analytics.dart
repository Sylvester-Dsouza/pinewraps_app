import 'package:facebook_app_events/facebook_app_events.dart';

class FacebookAnalytics {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();
  static final String _appId = '455351257582005';

  static Future<void> init() async {
    await _facebookAppEvents.setAdvertiserTracking(enabled: true);
    await _facebookAppEvents.logEvent(name: 'app_launched');
  }

  static Future<void> logPageView() async {
    await _facebookAppEvents.logEvent(
      name: 'PageView',
      parameters: {
        'app_id': _appId,
      },
    );
  }

  static Future<void> logAddToCart({
    required String contentId,
    required String contentType,
    required String currency,
    required double price,
  }) async {
    await _facebookAppEvents.logAddToCart(
      id: contentId,
      type: contentType,
      currency: currency,
      price: price,
    );
  }

  static Future<void> logPurchase({
    required String contentId,
    required String contentType,
    required String currency,
    required double price,
  }) async {
    await _facebookAppEvents.logPurchase(
      amount: price,
      currency: currency,
      parameters: {
        'content_id': contentId,
        'content_type': contentType,
        'app_id': _appId,
      },
    );
  }

  static Future<void> logViewContent({
    required String contentId,
    required String contentType,
    required String currency,
    required double price,
  }) async {
    await _facebookAppEvents.logViewContent(
      id: contentId,
      type: contentType,
      currency: currency,
      price: price,
    );
  }
}
