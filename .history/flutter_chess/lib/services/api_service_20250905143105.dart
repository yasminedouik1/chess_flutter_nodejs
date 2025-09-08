import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

  static String? _extractUserId(dynamic data) {
    if (data == null) return null;
    final user = data['user'];
    final dynamic candidate = (user?['id'] ?? user?['_id'] ?? data['_id'] ?? data['id'] ?? data['userId']);
    return candidate?.toString();
  }

  static String? _extractUsername(dynamic data) {
    if (data == null) return null;
    final user = data['user'];
    return user?['username']?.toString() ?? data['username']?.toString();
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

    print('Signup API status: ${response.statusCode}');
    print('Signup API body: ${response.body}');

    final data = _safeDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final userId = _extractUserId(data);
      final username = _extractUsername(data) ?? username;
      if (userId != null && data['token'] != null) {
        await saveUser(userId, data['token'], username);
      }
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to signup');
    }
  }

  static Future<Map<String, dynamic>> createGame({
    required String token,
    required int whiteTime,
    required int blackTime,
    required int increment,
    required bool isPrivate,
  }) async {
    if (whiteTime <= 0 || blackTime <= 0 || increment < 0) {
      throw Exception('Invalid time settings');
    }
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/games'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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

    print('CreateGame API status: ${response.statusCode}');
    print('CreateGame API body: ${response.body}');

    final data = _safeDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data['gameId'] == null) {
        throw Exception('Game ID not returned');
      }
      joinGameRoom(data['gameId']);
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to create game');
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

    print('GetAvailableGames API status: ${response.statusCode}');
    print('GetAvailableGames API body: ${response.body}');

    if (response.statusCode == 200) {
      return _safeDecode(response.body);
    } else {
      throw Exception(_safeDecode(response.body)['message'] ?? 'Failed to fetch games');
    }
  }

  static Future<Map<String, dynamic>> joinGame({
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

    print('JoinGame API status: ${response.statusCode}');
    print('JoinGame API body: ${response.body}');

    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      joinGameRoom(data['gameId']);
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to join game');
    }
  }

  static Future<Map<String, dynamic>> joinGameByCode({
    required String joinCode,
    required String token,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/games/join-by-code'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'joinCode': joinCode}),
      ),
      maxAttempts: maxRetries,
    );

    print('JoinGameByCode API status: ${response.statusCode}');
    print('JoinGameByCode API body: ${response.body}');

    final data = _safeDecode(response.body);
    if (response.statusCode == 200) {
      joinGameRoom(data['gameId']);
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to join game by code');
    }
  }

  static Future<void> cancelGame({
    required String token,
    required String gameId,
  }) async {
    final response = await retry(
      () => http.post(
        Uri.parse('$baseUrl/games/cancel/$gameId'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      maxAttempts: maxRetries,
    );

    print('CancelGame API status: ${response.statusCode}');
    print('CancelGame API body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(_safeDecode(response.body)['message'] ?? 'Failed to cancel game');
    }
  }

  static Future<Map<String, dynamic>> updateUser({
    required String token,
    required String userId,
    String? username,
    String? email,
    String? password,
    File? image,
  }) async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/users/$userId'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (username != null) request.fields['username'] = username;
    if (email != null) request.fields['email'] = email;
    if (password != null) request.fields['password'] = password;
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final response = await request.send();
    final responseString = await response.stream.bytesToString();
    final data = _safeDecode(responseString);

    print('UpdateUser API status: ${response.statusCode}');
    print('UpdateUser API body: $responseString');

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to update user');
    }
  }

  static void initializeSocket(String token) {
    socket = socket_io.io('http://10.0.2.2:5000', {
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Authorization': 'Bearer $token'},
    });
    socket!.connect();
    socket!.onConnect((_) => print('Socket connected'));
    socket!.onConnectError((data) => print('Socket connection error: $data'));
    socket!.onError((data) => print('Socket error: $data'));
  }

  static void joinGameRoom(String gameId) {
    socket?.emit('join_game', gameId);
  }

  static void disposeSocket() {
    socket?.disconnect();
    socket = null;
  }
}