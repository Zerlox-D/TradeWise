import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'auth_client.dart';

class ApiService {
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

        debugPrint("Login successful! Token saved.");
        return true;
      } else {
        debugPrint("Login failed. Status Code: ${response.statusCode}");
        debugPrint("Django Error Details: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Network or Server Error: $e");
      return false;
    }
  }

  static Future<bool> register(
    String username,
    String email,
    String password,
    String dob,
    String role,
  ) async {
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
      debugPrint("Register Error: $e");
      return false;
    }
  }

  // --- PROTECTED ENDPOINTS (Interceptor handles the token!) ---

  static Future<List<dynamic>> getGoals() async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/");

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
      debugPrint("Search Error: $e");
    }
    return null;
  }

  static Future<String?> sendMentorRequest(int mentorId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/mentor-links/");

    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'mentor': mentorId}),
      );

      if (response.statusCode == 201) {
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        if (errorData.containsKey('error')) {
          return errorData['error'];
        }
        return "Failed to send request. Please try again.";
      }
    } catch (e) {
      debugPrint("Request Error: $e");
      return "Network error. Please check your connection.";
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final url = Uri.parse('${AppConstants.baseUrl}/profile/me/');

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load profile data');
    }
  }

  static Future<List<dynamic>> getMentorLinks() async {
    final url = Uri.parse("${AppConstants.baseUrl}/mentor-links/");

    try {
      final response = await _client.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching links: $e");
    }
    return [];
  }

  static Future<bool> respondToRequest(int linkId, String action) async {
    final url = Uri.parse(
      "${AppConstants.baseUrl}/mentor-links/$linkId/respond/",
    );

    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'action': action}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Respond Error: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }

  static Future<bool> addGoal(
    String title,
    double targetAmount,
    String deadline,
  ) async {
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
      return response.statusCode == 201;
    } catch (e) {
      debugPrint("Add Goal Error: $e");
      return false;
    }
  }

  static Future<bool> updateGoal(
    int id,
    String title,
    double targetAmount,
    String deadline,
  ) async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/$id/");
    try {
      final response = await _client.patch(
        url,
        body: jsonEncode({
          'name': title,
          'target_amount': targetAmount,
          'deadline_date': deadline,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Update Goal Error: $e");
      return false;
    }
  }

  static Future<bool> deleteGoal(int id) async {
    final url = Uri.parse("${AppConstants.baseUrl}/goals/$id/");
    try {
      final response = await _client.delete(url);
      return response.statusCode == 204;
    } catch (e) {
      debugPrint("Delete Goal Error: $e");
      return false;
    }
  }

  static Future<double?> getLivePrice(String symbol) async {
    final url = Uri.parse("${AppConstants.baseUrl}/stock-price/$symbol/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['price']?.toDouble();
      }
    } catch (e) {
      debugPrint("Price Fetch Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>> submitTrade({
    required String symbol,
    required String type,
    required int quantity,
    required int goalId,
    required String justification,
    String? riskLevel,
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
          'risk_level': riskLevel,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
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
      debugPrint("Fetch Holdings Error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getStockHistory(String symbol) async {
    final url = Uri.parse("${AppConstants.baseUrl}/stock-history/$symbol/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> getTrades() async {
    final url = Uri.parse("${AppConstants.baseUrl}/trades/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Fetch Trades Error: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getTradeUnlockRequests() async {
    final url = Uri.parse("${AppConstants.baseUrl}/trade-unlock-requests/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Fetch Unlock Requests Error: $e");
    }
    return [];
  }

  static Future<String?> requestTradeUnlock() async {
    final url = Uri.parse("${AppConstants.baseUrl}/trade-unlock-requests/");
    try {
      final response = await _client.post(url, body: jsonEncode({}));
      if (response.statusCode == 201) {
        return null;
      }

      final body = jsonDecode(response.body);
      return body['error'] ?? 'Unable to submit unlock request.';
    } catch (e) {
      debugPrint("Request Unlock Error: $e");
      return 'Network error. Please try again.';
    }
  }

  static Future<bool> respondToTradeUnlockRequest(
    int requestId,
    String action, {
    String comment = "",
  }) async {
    final url = Uri.parse(
      "${AppConstants.baseUrl}/trade-unlock-requests/$requestId/respond/",
    );
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'action': action, 'comment': comment}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Respond Unlock Request Error: $e");
      return false;
    }
  }

  static Future<bool> respondToTrade(
    int tradeId,
    String action, {
    String comment = "",
  }) async {
    final url = Uri.parse("${AppConstants.baseUrl}/trades/$tradeId/respond/");
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'action': action, 'comment': comment}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Trade Approval Error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getStudentPortfolio(
    int studentId,
  ) async {
    final url = Uri.parse(
      "${AppConstants.baseUrl}/student-portfolio/$studentId/",
    );
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Fetch Student Portfolio Error: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getMarketOverview() async {
    final url = Uri.parse("${AppConstants.baseUrl}/market-overview/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Market Overview Fetch Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> getAssets() async {
    final url = Uri.parse("${AppConstants.baseUrl}/assets/");
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Assets Fetch Error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getAIRiskAssessment(
    String symbol,
  ) async {
    final url = Uri.parse("${AppConstants.baseUrl}/ai-risk-assessment/");
    try {
      final response = await _client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'symbol': symbol}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("AI Risk API Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("Network Error: $e");
    }
    return null;
  }

  // --- MENTOR QUIZ ENGINE ---

  static Future<Map<String, dynamic>?> draftMentorQuiz(int studentId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/draft/$studentId/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Failed to draft AI Quiz. Status: ${response.statusCode}");
        debugPrint("Error Details: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Network Error Drafting Quiz: $e");
      return null;
    }
  }

  static Future<bool> publishMentorQuiz(
    int quizId,
    List<dynamic> questions,
  ) async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/publish/$quizId/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'questions': questions}),
      );

      if (response.statusCode == 200) {
        debugPrint("Quiz published successfully!");
        return true;
      } else {
        debugPrint("Failed to publish Quiz. Status: ${response.statusCode}");
        debugPrint("Error Details: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Network Error Publishing Quiz: $e");
      return false;
    }
  }

  // --- STUDENT QUIZ ENGINE ---

  static Future<Map<String, dynamic>?> getStudentPendingQuiz() async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/pending/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("Network Error fetching quiz: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> submitStudentQuiz(
    int quizId,
    Map<String, String> answers,
  ) async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/submit/$quizId/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'answers': answers}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Failed to submit quiz. Status: ${response.statusCode}");
        debugPrint("Error Details: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Network Error submitting quiz: $e");
      return null;
    }
  }

  static Future<List<dynamic>?> getMentorQuizzes() async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/mentor/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getMentorQuizDetail(int quizId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/mentor/$quizId/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> unlockStudentAccount(int quizId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/unlock/$quizId/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Token $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>?> getStudentQuizzes() async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/student/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getStudentQuizDetail(int quizId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/quiz/student/$quizId/");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }
}
