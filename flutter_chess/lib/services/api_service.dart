import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class ApiService {
  static const String baseUrl =
      'http://10.0.2.2:5000/api'; // Adjust if needed (emulator localhost)
  static socket_io.Socket? socket;

  // Save JWT and user data
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
        (user?['id'] ??
        user?['_id'] ??
        data['_id'] ??
        data['id'] ??
        data['userId']);
    return candidate?.toString();
  }

  // Extract username safely
  static String? _extractUsername(dynamic data) {
    if (data == null) return null;
    final user = data['user'];
    return user?['username']?.toString() ?? data['username']?.toString();
  }

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

    if (response.statusCode == 200 || response.statusCode == 201) {
      final userId = _extractUserId(data);
      final savedUsername = _extractUsername(data) ?? username;

      if (userId != null) {
        await saveUser(
          userId,
          '',
          savedUsername,
        ); // Save empty token if none provided
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Signup response missing user id',
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

  print('Login API status: ${response.statusCode}');
  print('Login API body: ${response.body}');

  final data = _safeDecode(response.body);

  if (response.statusCode == 200) {
    final token = data['token']?.toString();
    final userId = _extractUserId(data);
    final savedUsername = _extractUsername(data) ?? email; // Fallback to email if username is null

    print('Extracted token: $token');
    print('Extracted userId: $userId');
    print('Extracted username: $savedUsername');

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

  // PvP Game Methods
  static Future<String> createGame({
    required String token,
    required int whiteTime,
    required int blackTime,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'whiteTime': whiteTime, 'blackTime': blackTime}),
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      return data['gameId'];
    } else {
      throw Exception(data['message'] ?? 'Failed to create game');
    }
  }

  static Future<List<dynamic>> getAvailableGames(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/available'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch available games');
    }
  }

  static Future<Map<String, dynamic>> joinGame({
    required String token,
    required String gameId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/join'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to join game');
    }
  }

  static void initSocket(String gameId) {
    socket = socket_io.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();
    socket!.emit('join_game', gameId);
  }

  static void disposeSocket() {
    socket?.disconnect();
    socket = null;
  }
}
