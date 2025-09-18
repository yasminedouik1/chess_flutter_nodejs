import 'package:flutter/material.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart'; // Changed from constants.dart

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true;
  bool isLoading = false;

  // Removed unused login() method
  // Future<void> login() async {
  //   setState(() => isLoading = true);
  //
  //   final currentContext = context;
  //   final result = await ApiService.login(
  //     email: emailController.text,
  //     password: passwordController.text,
  //   );
  //
  //   setState(() => isLoading = false);
  //
  //   if (result['token'] != null) {
  //     // Login successful
  //     if (!currentContext.mounted) return; // Guard against context across async gap
  //     Navigator.pushReplacement(
  //       currentContext,
  //       MaterialPageRoute(builder: (_) => const HomeScreen()),
  //     );
  //   } else {
  //     // Show error
  //     if (!currentContext.mounted) return; // Guard against context across async gap
  //     ScaffoldMessenger.of(
  //       currentContext,
  //     ).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Error')));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A2A5A), Color(0xFF1E1E3F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/chessboard.png',
                    width: 200, // set desired width
                    height: 200, // set desired height
                    fit: BoxFit.contain, // scale image inside these dimensions
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: emailController,
                    hintText: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: passwordController,
                    hintText: 'Password',
                    icon: Icons.lock,
                    obscureText: _obscureText,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26A69A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        setState(() => isLoading = true); // Set loading state
                        final auth = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        try {
                          await auth.login(
                            email: emailController.text,
                            password: passwordController.text,
                          );
                          if (auth.isLoggedIn) {
                            if (!context.mounted) return; // Guard against context across async gap
                            Navigator.pushReplacementNamed(
                              context,
                              Constants.homeScreen,
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return; // Guard against context across async gap
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                          );
                        } finally {
                          setState(() => isLoading = false); // Reset loading state
                        }
                      },

                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Don\'t have an account?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          Constants.signupScreen,
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(color: Color(0xFF26A69A)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF3A3A6A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
