import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

// This custom client intercepts all requests
class AuthClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Grab the token from storage
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    // 2. If we have a token, inject it into the headers
    if (token != null) {
      request.headers['Authorization'] = 'Token $token';
    }

    // 3. Ensure we always tell Django we are speaking JSON
    request.headers['Content-Type'] = 'application/json';

    // 4. Send the modified request on its way
    return _inner.send(request);
  }
}
