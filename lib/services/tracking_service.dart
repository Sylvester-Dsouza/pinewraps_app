import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  /// Singleton instance
  static final TrackingService _instance = TrackingService._internal();
  
  factory TrackingService() => _instance;
  
  TrackingService._internal();
  
  /// Tracks whether the request has been made already
  bool _hasRequestedPermission = false;
  
  /// Request tracking authorization and return the status
  Future<TrackingStatus> requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      // Return authorized for non-iOS platforms as they use different mechanisms
      return TrackingStatus.authorized;
    }
    
    if (_hasRequestedPermission) {
      // If we've already requested, just get the current status
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    }
    
    try {
      // Get tracking status
      final TrackingStatus status = 
          await AppTrackingTransparency.trackingAuthorizationStatus;
      
      // If not determined, request permission
      if (status == TrackingStatus.notDetermined) {
        // Wait for app to be foregrounded before showing the dialog
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      
      _hasRequestedPermission = true;
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (e) {
      debugPrint('Failed to request tracking authorization: $e');
      return TrackingStatus.notDetermined;
    }
  }
  
  /// Check if tracking is authorized
  Future<bool> isTrackingAuthorized() async {
    if (!Platform.isIOS) {
      return true; // Assume authorized for non-iOS platforms
    }
    
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    return status == TrackingStatus.authorized;
  }
}
