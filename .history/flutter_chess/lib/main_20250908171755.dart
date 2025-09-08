import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/main_screens/about.dart';
import 'package:flutter_chess/main_screens/game.dart';
import 'package:flutter_chess/main_screens/gameTime.dart';
import 'package:flutter_chess/main_screens/home.dart';
import 'package:flutter_chess/main_screens/join_room.dart';
import 'package:flutter_chess/main_screens/login_screen.dart';
import 'package:flutter_chess/main_screens/profile_screen.dart';
import 'package:flutter_chess/main_screens/settings.dart';
import 'package:flutter_chess/main_screens/signup_screen.dart';
import 'package:flutter_chess/main_screens/play_vs_friend.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF26A69A),
          secondary: const Color(0xFF26A69A),
          background: const Color(0xFF2A2A5A),
          surface: const Color(0xFF3A3A6A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF2A2A5A),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF26A69A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ),
      initialRoute: authProvider.isLoggedIn
          ? Constants.homeScreen
          : Constants.loginScreen,
      routes: {
        Constants.loginScreen: (context) => const LoginScreen(),
        Constants.signupScreen: (context) => const SignupScreen(),
        Constants.homeScreen: (context) => const HomeScreen(),
        Constants.gameScreen: (context) => const GameScreen(),
        Constants.aboutScreen: (context) => const AboutScreen(),
        Constants.settingScreen: (context) => const SettingsScreen(),
        Constants.gameTimeScreen: (context) => const GameTimeScreen(),
        Constants.profileScreen: (context) => const ProfileScreen(),
        Constants.playVsFriendScreen: (context) => const PlayVsFriendScreen(),
                Constants.joinRoomScreen: (context) => const JoinRoomScreen(),

      },
    );
  }
}
