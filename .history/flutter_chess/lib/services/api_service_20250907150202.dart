import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static socket_io.Socket? socket;
  static const int maxRetries = 3;

  static Future<void> saveUser(String userId, String token, String username) async {
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

  static dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    final response = await retry(
      () => http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ),
      maxAttempts: maxRetries,
    );

    final data = _safeDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final userId = data['user']?['id']?.toString() ?? data['userId'];
      final username = data['user']?['username']?.toString() ?? data['username'];
      if (userId != null && data['token'] != null) {
        await saveUser(userId, data['token'], username);
        return data;
      }
      throw Exception('Invalid response data');
    } else {
      throw Exception(data['message'] ?? 'Failed to sign up');
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await retry(
      () => http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ),
      maxAttempts: maxRetries,
    );

    final data = _safeDecode(response.body);

    if (response.statusCode == 200) {
      final userId = data['user']?['id']?.toString() ?? data['userId'];
      final username = data['user']?['username']?.toString() ?? data['username'];
      if (userId != null && data['token'] != null) {
        await saveUser(userId, data['token'], username);
        return data;
      }
      throw Exception('Invalid response data');
    } else {
      throw Exception(data['message'] ?? 'Failed to login');
    }
  }

  static Future<List<dynamic>> getAvailableGames(String token) async {
    final response = await retry(
      () => http.get(
        Uri.parse('$baseUrl/games/available'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      maxAttempts: maxRetries,
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to fetch games');
  }

  static Future<Map<String, dynamic>> createGame({
    required String token,
    required int whiteTime,
    required int blackTime,
    required int increment,
    required bool isPrivate,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/games'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'whiteTime': whiteTime,
          'blackTime': blackTime,
          'increment': increment,
          'isPrivate': isPrivate,
        }),
      ),
      maxAttempts: maxRetries,
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to create game');
  }

  static Future<Map<String, dynamic>> joinGameByCode({
    required String joinCode,
    required String token,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/games/join-by-code'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'joinCode': joinCode}),
      ),
      maxAttempts: maxRetries,
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to join game');
  }

  static Future<Map<String, dynamic>> joinGameById({
    required String gameId,
    required String token,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/games/join/$gameId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      maxAttempts: maxRetries,
    );
    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to join game');
  }

  static Future<void> cancelGame({
    required String token,
    required String gameId,
  }) async {
    final response = await retry(
      () => http.delete(
        Uri.parse('$baseUrl/games/cancel/$gameId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      maxAttempts: maxRetries,
    );
    final data = _safeDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to cancel game');
    }
  }

  static void initializeSocket(String token) {
    socket?.disconnect();
    socket = socket_io.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });
    socket!.onConnect((_) => print('Socket connected'));
    socket!.onConnectError((data) => print('Socket connection error: $data'));
    socket!.onError((data) => print('Socket error: $data'));
  }

  static void joinGameRoom(String gameId) {
    socket?.emit('join_game', {'gameId': gameId});
  }

  static void disposeSocket() {
    socket?.disconnect();
    socket = null;
  }
}