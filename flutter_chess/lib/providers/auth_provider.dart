import 'package:flutter/material.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:flutter_chess/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool isLoggedIn = false;
  String? _token;

  UserModel? get user => _user;
  String? get token => _token;
  String? get username => _user?.username;

  AuthProvider() {
    checkLogin();
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

Future<void> login({
  required String email,
  required String password,
}) async {
  final result = await ApiService.login(email: email, password: password);
  if (result['success'] == true) {
    _token = await ApiService.getToken();
    final fetchedUsername = await ApiService.getUsername() ?? email; // Fallback to email
    _user = UserModel(
      uid: await ApiService.getUserId() ?? '',
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

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    _token = null;
    notifyListeners();
  }
}