import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/models/user.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;

  User? get user => _user;
  String? get token => _token;

  Future<User?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    if (_token != null) {
      try {
        final response = await ApiService.getUser(token: _token!);
        if (response['user'] != null) {
          _user = User.fromMap(response['user']);
          notifyListeners();
          return _user;
        }
      } catch (e) {
        prefs.remove('jwt_token');
        _token = null;
      }
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await ApiService.login(email: email, password: password);
      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromMap(response['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        notifyListeners();
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp(String username, String email, String password) async {
    try {
      final response = await ApiService.signUp(username: username, email: email, password: password);
      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromMap(response['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        notifyListeners();
      } else {
        throw Exception(response['message'] ?? 'Sign up failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    notifyListeners();
  }
}