import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/features/auth/screens/auth_screen.dart';
import 'package:flutter_chess/features/auth/screens/sign_in_screen.dart';
import 'package:flutter_chess/features/auth/screens/sign_up_screen.dart';
import 'package:flutter_chess/features/auth/screens/email_verification.dart';
import 'package:flutter_chess/screen/main_menu_screen.dart';
import 'package:flutter_chess/screen/create_room.dart';
import 'package:flutter_chess/screen/join_room.dart';
import 'package:flutter_chess/game_board.dart';
import 'package:flutter_chess/providers/auth_provider.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  String initialRoute = AuthScreen.routeName;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    checkAuth();
    super.initState();
  }

  Future<void> checkAuth() async {
    final authProvider = ref.read(AuthProvider as ProviderListenable);
    final user = await authProvider.getUserData();

    Future.delayed(Duration.zero, () {
      if (user != null) {
        navigatorKey.currentState?.pushReplacementNamed(MainMenuScreen.routeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chess',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(31, 202, 200, 200),
      ),
      navigatorKey: navigatorKey,
      routes: {
        AuthScreen.routeName: (context) => const AuthScreen(),
        SignInScreen.routeName: (context) => const SignInScreen(),
        SignUpScreen.routeName: (context) => const SignUpScreen(),
        MainMenuScreen.routeName: (context) => const MainMenuScreen(),
        CreateRoomScreen.routeName: (context) => const CreateRoomScreen(),
        JoinRoomScreen.routeName: (context) => const JoinRoomScreen(),
        GameBoard.routeName: (context) => const GameBoard(),
        EmailVerification.routeName: (context) => const EmailVerification(),
      },
      initialRoute: initialRoute,
    );
  }
}