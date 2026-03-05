import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Phone number utility for getting device phone number
class PhoneUtil {
  static const MethodChannel _channel = MethodChannel('com.safetrip/device');

  /// Get phone number from device
  /// Returns null if permission denied or phone number not available
  static Future<String?> getPhoneNumber() async {
    try {
      if (Platform.isAndroid) {
        // Check and request permission first
        final hasPermission = await hasPhonePermission();
        if (!hasPermission) {
          debugPrint('[PhoneUtil] Requesting phone permission...');
          final granted = await requestPhonePermission();
          if (!granted) {
            debugPrint('[PhoneUtil] Phone permission denied by user');
            return null;
          }
          debugPrint('[PhoneUtil] Phone permission granted');
        }
        
        // Get phone number from native code
        final phoneNumber = await _channel.invokeMethod<String>('getPhoneNumber');
        return phoneNumber;
      } else if (Platform.isIOS) {
        // iOS: Phone number access is restricted
        // Return null and use random generation
        return null;
      }
    } catch (e) {
      debugPrint('[PhoneUtil] Error getting phone number: $e');
      return null;
    }
    return null;
  }

  /// Check if phone permission is granted
  static Future<bool> hasPhonePermission() async {
    if (Platform.isAndroid) {
      // Check READ_PHONE_STATE (for Android 9 and below)
      final phoneState = await Permission.phone.isGranted;
      
      // For Android 10+, also check READ_PHONE_NUMBERS
      // Note: permission_handler may not have direct support for READ_PHONE_NUMBERS
      // So we check phone permission which should cover both
      return phoneState;
    }
    return false;
  }

  /// Request phone permission
  /// For Android 10+, requests both READ_PHONE_STATE and READ_PHONE_NUMBERS via native code
  static Future<bool> requestPhonePermission() async {
    if (Platform.isAndroid) {
      try {
        // Try native code first (handles READ_PHONE_NUMBERS for Android 10+)
        final permissionStatus = await _channel.invokeMethod<String>('requestPhonePermission');
        
        if (permissionStatus == 'granted') {
          return true;
        }
        
        // If native request returns 'pending', wait for user response
        if (permissionStatus == 'pending') {
          // Wait for user to respond to permission dialog
          // Check permission status after a delay
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 300));
            if (await hasPhonePermission()) {
              return true;
            }
          }
          return false;
        }
        
        // If native code fails or returns something else, use permission_handler as fallback
        debugPrint('[PhoneUtil] Native permission request failed, using permission_handler');
        final phoneStatus = await Permission.phone.request();
        return phoneStatus.isGranted;
      } catch (e) {
        debugPrint('[PhoneUtil] Error requesting permission via native: $e');
        // Fallback to permission_handler
        final phoneStatus = await Permission.phone.request();
        return phoneStatus.isGranted;
      }
    }
    return false;
  }
}

