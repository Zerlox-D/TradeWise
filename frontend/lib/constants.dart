import 'package:flutter/foundation.dart';

class AppConstants {
  static const String tokenKey = 'auth_token'; 

  // --- Network Configuration ---

  static const String _webUrl = "http://127.0.0.1:8000";
  static const String _mobileUrl = "http://192.168.1.34:8000";

  // Get the root URL (used for things like the login endpoint)
  static String get rootUrl {
    return kIsWeb ? _webUrl : _mobileUrl;
  }

  // Get the base API URL (used for your standard endpoints)
  static String get baseUrl {
    return kIsWeb ? "$_webUrl/api" : "$_mobileUrl/api";
  }
}