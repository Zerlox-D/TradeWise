import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'auth_client.dart'; // 1. Import your new interceptor

class ApiService {
  // 2. Create a single static instance of your custom client
  static final _client = AuthClient();

  // --- PUBLIC ENDPOINTS (No token needed yet) ---

  static Future<bool> login(String username, String password) async {
    final url = Uri.parse("${AppConstants.rootUrl}/api-token-auth/");
  
    try {
      // We use standard http.post here so we don't attach old tokens
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token);
        
        print("Login successful! Token saved.");
        return true; 
      } else {
        print("Login failed. Status Code: ${response.statusCode}");
        print("Django Error Details: ${response.body}");
        return false; 
      }
    } catch (e) {
      print("Network or Server Error: $e");
      return false;
    }
  }

  static Future<bool> register(String username, String email, String password, String dob, String role) async {
    final url = Uri.parse("${AppConstants.baseUrl}/register/");
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'date_of_birth': dob,
          'role': role,
        }),
      );

      return response.statusCode == 201; 
    } catch (e) {
      print("Register Error: $e");
      return false;
    }
  }

  // --- PROTECTED ENDPOINTS (Interceptor handles the token!) ---

  static Future<List<dynamic>> getGoals() async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/");
    
    // Look how clean this is now! 
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load goals');
    }
  }

  static Future<Map<String, dynamic>?> searchMentor(String code) async {
    final url = Uri.parse("${AppConstants.baseUrl}/mentors/?code=$code"); 

    try {
      final response = await _client.get(url);

      if (response.statusCode == 200) {
        List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          return results[0]; 
        }
      }
    } catch (e) {
      print("Search Error: $e");
    }
    return null;
  }

  // Notice we changed Future<bool> to Future<String?>
  static Future<String?> sendMentorRequest(int mentorId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/mentor-links/");

    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'mentor': mentorId}), 
      );

      if (response.statusCode == 201) {
        return null; // Return null on success
      } else {
        // Decode the 400 Bad Request error from Django
        final errorData = jsonDecode(response.body);
        if (errorData.containsKey('error')) {
          return errorData['error']; // e.g., "You already have a pending or active mentor connection."
        }
        return "Failed to send request. Please try again."; 
      }
    } catch (e) {
      print("Request Error: $e");
      return "Network error. Please check your connection.";
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final url = Uri.parse('${AppConstants.baseUrl}/profile/me/');
    
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      // You might want to handle 401 Unauthorized specifically here later
      throw Exception('Failed to load profile data');
    }
  }

  // Fetches all mentor links for the logged-in user
  static Future<List<dynamic>> getMentorLinks() async {
    final url = Uri.parse("${AppConstants.baseUrl}/mentor-links/");

    try {
      final response = await _client.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Returns the list of requests
      }
    } catch (e) {
      print("Error fetching links: $e");
    }
    return [];
  }

  // MENTOR ACTION: Accept or Reject a request
  static Future<bool> respondToRequest(int linkId, String action) async {
    // action should be either 'accept' or 'reject'
    final url = Uri.parse("${AppConstants.baseUrl}/mentor-links/$linkId/respond/");
    
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'action': action}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Respond Error: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token'); // Replace 'token' with whatever key you used to save it
      
      // Optional: If you attached the token to your HTTP client headers, clear them out
      // _client.options.headers.remove('Authorization'); 
    } catch (e) {
      print("Logout Error: $e");
    }
  }

  // --- ADD THIS TO api_service.dart ---
  static Future<bool> addGoal(String title, double targetAmount, String deadline) async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/");
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'name': title,
          'target_amount': targetAmount,
          'deadline_date': deadline,
        }),
      );
      // 201 Created is the standard Django success response for POST
      return response.statusCode == 201; 
    } catch (e) {
      print("Add Goal Error: $e");
      return false;
    }
  }

  // --- ADD THESE TO api_service.dart ---

  // Update an existing goal
  static Future<bool> updateGoal(int id, String title, double targetAmount, String deadline) async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/$id/");
    try {
      final response = await _client.patch( // Use patch or put depending on your Django setup
        url,
        body: jsonEncode({
          'name': title,
          'target_amount': targetAmount,
          'deadline_date': deadline,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201; 
    } catch (e) {
      print("Update Goal Error: $e");
      return false;
    }
  }

  // Delete a goal
  static Future<bool> deleteGoal(int id) async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/$id/");
    try {
      final response = await _client.delete(url);
      return response.statusCode == 204; // 204 No Content is standard for successful deletions
    } catch (e) {
      print("Delete Goal Error: $e");
      return false;
    }
  }

  // 1. Fetch the live price preview
  static Future<double?> getLivePrice(String symbol) async {
    final url = Uri.parse("${AppConstants.baseUrl}/stock-price/$symbol/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['price']?.toDouble();
      }
    } catch (e) {
      print("Price Fetch Error: $e");
    }
    return null;
  }

  // 2. Submit the trade to your TradeRequest API
  static Future<Map<String, dynamic>> submitTrade({
    required String symbol,
    required String type, // 'BUY' or 'SELL'
    required int quantity,
    required int goalId,
    required String justification,
  }) async {
    final url = Uri.parse("${AppConstants.baseUrl}/trades/");
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'symbol': symbol,
          'transaction_type': type,
          'quantity': quantity,
          'goal': goalId,
          'justification': justification,
        }),
      );
      
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        // If your backend blocks it (e.g. Insufficient Funds), we return the exact error
        final error = jsonDecode(response.body)['error'] ?? 'Trade failed';
        return {'success': false, 'message': error};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred.'};
    }
  }

  static Future<List<dynamic>> getHoldings() async {
    final url = Uri.parse("${AppConstants.baseUrl}/holdings/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Fetch Holdings Error: $e");
    }
    return [];
  }

  // Fetch 30-day historical data for the chart
  static Future<Map<String, dynamic>?> getStockHistory(String symbol) async {
    final url = Uri.parse("${AppConstants.baseUrl}/stock-history/$symbol/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("History Fetch Error: $e");
    }
    return null;
  }

  // 1. Fetch trades (Django automatically filters this so Mentors see their students' trades)
  static Future<List<dynamic>> getTrades() async {
    final url = Uri.parse("${AppConstants.baseUrl}/trades/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Fetch Trades Error: $e");
    }
    return [];
  }

  // 2. Submit the mentor's decision on a high-risk trade
  static Future<bool> respondToTrade(int tradeId, String action, {String comment = ""}) async {
    final url = Uri.parse("${AppConstants.baseUrl}/trades/$tradeId/respond/");
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'action': action, // 'approve' or 'reject'
          'comment': comment,
        }),
      );
      return response.statusCode == 200; 
    } catch (e) {
      print("Trade Approval Error: $e");
      return false;
    }
  }

  // Fetch a student's portfolio (Mentors only)
  static Future<Map<String, dynamic>?> getStudentPortfolio(int studentId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/student-portfolio/$studentId/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Fetch Student Portfolio Error: $e");
    }
    return null;
  }

  // Fetch the 24H Market Overview data
  static Future<Map<String, dynamic>?> getMarketOverview() async {
    final url = Uri.parse("${AppConstants.baseUrl}/market-overview/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Market Overview Fetch Error: $e");
    }
    return null;
  }

  // Fetch the lightweight list of assets for the Trade Screen dropdown
  static Future<List<dynamic>> getAssets() async {
    final url = Uri.parse("${AppConstants.baseUrl}/assets/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Assets Fetch Error: $e");
    }
    return [];
  }
}