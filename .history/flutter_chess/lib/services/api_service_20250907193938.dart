import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_chess/models/user.dart';

class ApiService {
  static const String baseUrl = 'http://your-backend-url.com/api'; // Replace with your backend URL
  static IO.Socket? socket;

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
      maxAttempts: 3,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', data['token']);
      return data;
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'email': email, 'password': password}),
      ),
      maxAttempts: 3,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', data['token']);
      return data;
    }
    throw Exception(data['message'] ?? 'Sign up failed');
  }

  static Future<Map<String, dynamic>> getUser({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to fetch user');
  }

  static Future<void> initializeSocket(String token) async {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token},
    });
    socket?.connect();
  }

  static void joinGameRoom(String gameId) {
    socket?.emit('join_game', {'gameId': gameId});
  }

  static void emitMove(String gameId, String move) {
    socket?.emit('move', {'gameId': gameId, 'move': move});
  }

  static void disposeSocket() {
    socket?.disconnect();
    socket = null;
  }
}