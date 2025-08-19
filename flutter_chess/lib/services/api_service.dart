import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  // Save JWT and user ID
  static Future<void> saveUser(
    String userId,
    String token,
    String username,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('username', username);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  // Safe JSON decode
  static dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  // Extract userId safely
  static String? _extractUserId(dynamic data) {
    if (data == null) return null;
    final user = data['user'];
    final dynamic candidate =
        (user?['id'] ?? user?['_id'] ?? data['_id'] ?? data['id']);
    return candidate?.toString();
  }

  static String? _extractUsername(dynamic data) {
    if (data == null) return null;
    final user = data['user'];
    return user?['username']?.toString();
  }

  static String? extractUsername(dynamic data) {
    return _extractUsername(data);
  }

  // Signup
  // Signup
  static Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    print('Signup API status: ${response.statusCode}');
    print('Signup API body: ${response.body}');

    final data = _safeDecode(response.body);

    // Accept both 200 and 201 as success
    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = data['token']?.toString();
      final userId = _extractUserId(data);
      final savedUsername = _extractUsername(data) ?? username;

      if (token != null && userId != null) {
        await saveUser(userId, token, savedUsername);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Signup response missing token or user id',
          'data': data,
        };
      }
    }

    return {
      'success': false,
      'status': response.statusCode,
      'message': data['message'] ?? 'Signup failed',
      'data': data,
    };
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _safeDecode(response.body);

    if (response.statusCode == 200) {
      final token = data['token'] as String?;
      final userId = _extractUserId(data);
      final savedUsername = _extractUsername(data) ?? '';

      if (token != null && userId != null) {
        await saveUser(userId, token, savedUsername);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Login response missing token or user id',
          'data': data,
        };
      }
    }

    return {
      'success': false,
      'status': response.statusCode,
      'message': data['message'] ?? 'Login failed',
      'data': data,
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
  }
}
