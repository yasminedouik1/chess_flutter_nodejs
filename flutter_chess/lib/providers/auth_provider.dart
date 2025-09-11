import 'package:flutter/material.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool isLoggedIn = false;
  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  UserModel? get user => _user;
  String? get username => _user?.username;

  AuthProvider() {
    checkLogin();
  }
  void setAuthData({required String token, required String userId}) {
    _token = token;
    _userId = userId;
    notifyListeners();
  }

  void clearAuthData() {
    _token = null;
    _userId = null;
    notifyListeners();
  }

  Future<void> checkLogin() async {
    _token = await ApiService.getToken();
    final userId = await ApiService.getUserId();
    final username = await ApiService.getUsername();
    if (_token != null && userId != null && username != null) {
      _user = UserModel(
        uid: userId,
        username: username,
        email: '', // Email not stored; fetch if needed
        image: '', // Fetch if needed
        playerRating: 1200, // Fetch if needed
      );
      isLoggedIn = true;
    } else {
      isLoggedIn = false;
    }
    notifyListeners();
  }

  Future<void> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await ApiService.signup(
      username: username,
      email: email,
      password: password,
    );

    if (result['success'] == true) {
      // Signup succeeded, now login to get token
      await login(email: email, password: password);
    } else {
      throw Exception(result['message'] ?? 'Signup failed');
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await ApiService.login(email: email, password: password);
    if (result['success'] == true) {
      _token = await ApiService.getToken();
      _userId = await ApiService.getUserId();
      final fetchedUsername =
          await ApiService.getUsername() ?? email; // Fallback to email
      _user = UserModel(
        uid: _userId ?? '',
        username: fetchedUsername,
        email: email,
        image: '', // Fetch if needed
        playerRating: 1200, // Fetch if needed
      );
      isLoggedIn = true;
      notifyListeners();
    } else {
      isLoggedIn = false;
      throw Exception(result['message'] ?? 'Login failed');
    }
  }

  Future<void> updateUser(UserModel updatedUser) async {
    _user = updatedUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', updatedUser.username);
    await prefs.setString('email', updatedUser.email);
    await prefs.setString(
      'image',
      updatedUser.image,
    ); // Optionally update other fields like email or image if stored
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    _token = null;
    _userId = null;
    isLoggedIn = false;
    notifyListeners();
  }
}
