import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

    /*print('Signup API status: ${response.statusCode}')*/ null;
    /*print('Signup API body: ${response.body}')*/ null;

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

    /*print('Login API status: ${response.statusCode}')*/ null;
    /*print('Login API body: ${response.body}')*/ null;

    final data = _safeDecode(response.body);

    if (response.statusCode == 200) {
      final token = data['token']?.toString();
      final userId = _extractUserId(data);
      final savedUsername =
          _extractUsername(data) ??
          email; // Fallback to email if username is null

      /*print('Extracted token: $token')*/ null;
      /*print('Extracted userId: $userId')*/ null;
      /*print('Extracted username: $savedUsername')*/ null;

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

  static Future<Map<String, dynamic>> createGame({
    required String token,
    required String userId,
    required int whiteTime,
    required int blackTime,
    required bool isPrivate,
    String? joinCode,
  }) async {
    // /*print('createGame API call - token: ${token.substring(0, 10)}..., userId: $userId')*/ null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'whiteTime': whiteTime,
          'blackTime': blackTime,
          'isPrivate': isPrivate,
          'joinCode': joinCode,
        }),
      );
      // /*print('createGame API response status: ${response.statusCode}')*/ null;
      // /*print('createGame API response body: ${response.body}')*/ null;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create game');
      }
    } catch (e) {
      // /*print('Error in createGame: $e')*/ null;
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableGames(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/available'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> gamesJson = jsonDecode(response.body);
        return gamesJson.map((json) => json as Map<String, dynamic>).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch available games');
      }
    } catch (e) {
      // /*print('Error fetching available games: $e')*/ null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> joinGame({
    required String token,
    required String gameId,
    required String userId,
  }) async {
    // /*print('joinGame API call - gameId: $gameId, userId: $userId')*/ null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/join/$gameId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );
      // /*print('joinGame API response status: ${response.statusCode}')*/ null;
      // /*print('joinGame API response body: ${response.body}')*/ null;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to join game');
      }
    } catch (e) {
      // /*print('Error in joinGame: $e')*/ null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> joinGameByCode({
    required String token,
    required String joinCode,
  }) async {
    // /*print('joinGameByCode API call - joinCode: $joinCode')*/ null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/join-by-code'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'joinCode': joinCode,
        }),
      );
      // /*print('joinGameByCode API response status: ${response.statusCode}')*/ null;
      // /*print('joinGameByCode API response body: ${response.body}')*/ null;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to join game by code');
      }
    } catch (e) {
      // /*print('Error in joinGameByCode: $e')*/ null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> cancelGame({
    required String token,
    required String gameId,
  }) async {
    // /*print('cancelGame API call - gameId: $gameId')*/ null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/cancel/$gameId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      // /*print('cancelGame API response status: ${response.statusCode}')*/ null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to cancel game');
      }
    } catch (e) {
      // /*print('Error in cancelGame: $e')*/ null;
      rethrow;
    }
  }

  static Future<void> leaveGame({
    required String token,
    required String gameId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/leave/$gameId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to leave game');
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

  static Future<Map<String, dynamic>> getGameStatus({
    required String token,
    required String gameId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/$gameId/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to get game status');
      }
    } catch (e) {
      // /*print('Error getting game status: $e')*/ null;
      rethrow;
    }
  }

  static void disposeSocket() {
    socket?.disconnect();
    // /*print('Socket disconnected and set to null')*/ null;
    socket = null;
  }

  static void initializeSocket(String? token) {
    if (token == null) {
      // /*print('No token provided for socket initialization')*/ null;
      return;
    }

    final String serverUrl = 'http://10.0.2.2:5000';
    socket = socket_io.io(
      serverUrl,
      {
        'transports': ['websocket'],
        'autoConnect': false,
        'extraHeaders': {
          'Authorization': 'Bearer $token',
        },
      },
    );

    socket!.connect();
    socket!.onConnect((_) => /*print('Socket connected')*/ null);
    socket!.onConnectError((data) => /*print('Socket connection error: $data')*/ null);
    socket!.onError((data) => /*print('Socket error: $data')*/ null);
    socket!.onDisconnect((reason) => /*print('Socket disconnected: $reason')*/ null);
  }

  static void joinGameRoom(String gameId) {
    // /*print('Attempting to join game room: $gameId')*/ null;
    socket?.emit('join_game', {'gameId': gameId});
  }

  static void onOpponentJoined(
    BuildContext context,
    Function(Map<String, dynamic>) handler,
  ) {
    socket?.on('player_joined', (data) => handler(data));
  }

  static void onMoveReceived(
    BuildContext context,
    Function(Map<String, dynamic>) handler,
  ) {
    socket?.on('move', (data) => handler(data));
  }

  static void onGameOver(
    BuildContext context,
    Function(Map<String, dynamic>) handler,
  ) {
    socket?.on('game_over', (data) => handler(data));
  }

  static void onDrawOffer(
    BuildContext context,
    Function(Map<String, dynamic>) handler,
  ) {
    socket?.on('draw_offered', (data) => handler(data));
  }

  static void onDrawAccepted(
    BuildContext context,
    Function(Map<String, dynamic>) handler,
  ) {
    socket?.on('draw_accepted', (data) => handler(data));
  }

  static void onRematch(
    BuildContext context,
    Function(Map<String, dynamic>) handler,
  ) {
    socket?.on('rematch', (data) => handler(data));
  }

  static void onGameDeleted(Function(Map<String, dynamic>) handler) {
    socket?.on('game_deleted', (data) => handler(data));
  }

  static void onOpponentLeft(Function(Map<String, dynamic>) handler) {
    socket?.on('opponent_left', (data) => handler(data));
  }

  static void onGameRemoved(Function(Map<String, dynamic>) handler) {
    socket?.on('game_removed', (data) => handler(data));
  }
}
