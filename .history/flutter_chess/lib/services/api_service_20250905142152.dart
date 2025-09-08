import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chess/models/user_model.dart';
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
      final savedUsername =
          _extractUsername(data) ??
          email; // Fallback to email if username is null

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
    required UserModel user,
    required int whiteTime,
    required int blackTime,
    required int increment,
    required bool isPrivate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $user.token',
      },
      body: jsonEncode({
        'whiteTime': whiteTime,
        'blackTime': blackTime,
        'increment': increment,
        'isPrivate': isPrivate,
      }),
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

  // api_service.dart
  static Future<Map<String, dynamic>> joinGame({required String gameId, required String token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/games/join/$gameId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to join game: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> joinGameByCode({required String joinCode, required String token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/games/join-by-code'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'joinCode': joinCode}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to join game by code: ${response.body}');
    }
  }
  static Future<void> deleteGame({
    required String token,
    required String gameId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/games/$gameId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel game');
    }
  }
static Future<void> cancelGame({required String gameId, required String token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/games/cancel/$gameId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel game: ${response.body}');
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

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to update user');
    }
  }

  static void disposeSocket() {
    socket?.disconnect();
    socket = null;
  }

  // api_service.dart
  static void initializeSocket(String token) {
    socket = socket_io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token},
    });
    socket?.onConnect((_) => print('Socket connected'));
    socket?.onConnectError((data) => print('Socket connect error: $data'));
  }

static void joinGameRoom(String gameId) {
    socket?.emit('join_game', gameId);
  }

  static void onOpponentJoined(
    BuildContext context,
    Function(Map<String, dynamic>) callback,
  ) {
    socket?.on('opponent_joined', (data) {
      callback(data['game']);
    });
  }


  static void onMoveReceived(Function(Map<String, dynamic>) callback) {
  socket?.on('move_made', (data) {
    callback(data);
  });
}
static void onMove(Function(Map<String, dynamic>) callback) {
  socket?.on('move', (data) {
    print("Received move: $data");
    callback(Map<String, dynamic>.from(data));
  });
}

}
