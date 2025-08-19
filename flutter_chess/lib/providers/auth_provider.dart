import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoggedIn = false;
  String? token;
  String? username ;


  AuthProvider() {
    checkLogin();
  }

  Future<void> checkLogin() async {
    token = await ApiService.getToken();
      username = await ApiService.getUsername() ?? 'Username'; // Load saved username

    isLoggedIn = token != null;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final result = await ApiService.login(email: email, password: password);
    if (result['success'] == true && result['data']['token'] != null) {
      token = result['data']['token'];
            username = ApiService.extractUsername(result['data']) ?? 'Username'; // save username from login

      isLoggedIn = true;
      notifyListeners();
    } else {
      isLoggedIn = false;
      notifyListeners();
    }
  }

  // Future<void> signup({
  //   required String username,
  //   required String email,
  //   required String password,
  // }) async {
  //   final result = await ApiService.signup(
  //     username: username,
  //     email: email,
  //     password: password,
  //   );

  //   if (result['success'] == true) {
  //     // Signup succeeded, now login to get token
  //     await login(email: email, password: password);
  //   } else {
  //     throw Exception(result['message'] ?? 'Signup failed');
  //   }
  // }
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

  if (result['success'] == true && result['data'] != null) {
    // Signup succeeded, token and user are already saved in SharedPreferences
    token = result['data']['token']?.toString();
          this.username = ApiService.extractUsername(result['data']) ?? 'Username'; // save username from signup

    isLoggedIn = true;
    notifyListeners();
  } else {
    throw Exception(result['message'] ?? 'Signup failed');
  }
}

  Future<void> logout() async {
    await ApiService.logout();
    token = null;
        username = null;

    isLoggedIn = false;
    notifyListeners();
  }
}
