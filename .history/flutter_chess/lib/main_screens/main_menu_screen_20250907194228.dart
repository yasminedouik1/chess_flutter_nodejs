import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/screen/create_room.dart';
import 'package:flutter_chess/screen/join_room.dart';
import 'package:flutter_chess/game_board.dart';
import 'package:flutter_chess/utils.dart';
import 'package:flutter_chess/responsive/responsive.dart';
import 'package:flutter_chess/providers/game_provider.dart';

class MainMenuScreen extends ConsumerWidget {
  static const String routeName = '/main-menu';

  const MainMenuScreen({Key? key}) : super(key: key);

  void navigateToCreateRoom(BuildContext context) {
    Navigator.pushNamed(context, CreateRoomScreen.routeName);
  }

  void navigateToJoinRoom(BuildContext context) {
    Navigator.pushNamed(context, JoinRoomScreen.routeName);
  }

  void startVsComputer(BuildContext context, WidgetRef ref) {
    ref.read(gameProvider).setVsComputer(true);
    Navigator.pushNamed(context, GameBoard.routeName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    return Responsive(
      child: Scaffold(
        backgroundColor: bgColor,
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: const BoxDecoration(boxShadow: [
                    BoxShadow(
                      color: Color.fromARGB(255, 5, 75, 8),
                      blurRadius: 0,
                      spreadRadius: 0,
                    )
                  ]),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Image.asset(
                      'assets/images/chessBackground1.png',
                      fit: size.width > 500 ? BoxFit.cover : BoxFit.contain,
                      width: double.infinity,
                      height: size.width > 500 ? size.height * 0.4 : size.height * 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      " Play Chess ",
                      style: TextStyle(
                        fontSize: 25,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.yellow, blurRadius: 10)],
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB(255, 8, 135, 157),
                          blurRadius: 5,
                          spreadRadius: 3,
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => navigateToCreateRoom(context),
                      style: ElevatedButton.styleFrom(
                        elevation: 10,
                        backgroundColor: const Color.fromARGB(255, 194, 197, 175),
                        minimumSize: const Size(double.infinity, 60),
                      ),
                      child: const Text(
                        "Create Room",
                        style: TextStyle(
                          fontSize: 23,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.yellow, blurRadius: 2)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB(255, 8, 135, 157),
                          blurRadius: 5,
                          spreadRadius: 3,
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => navigateToJoinRoom(context),
                      style: ElevatedButton.styleFrom(
                        elevation: 10,
                        backgroundColor: const Color.fromARGB(255, 194, 197, 175),
                        minimumSize: const Size(double.infinity, 60),
                      ),
                      child: const Text(
                        "Join Room",
                        style: TextStyle(
                          fontSize: 23,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.yellow, blurRadius: 2)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB(255, 8, 135, 157),
                          blurRadius: 5,
                          spreadRadius: 3,
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => startVsComputer(context, ref),
                      style: ElevatedButton.styleFrom(
                        elevation: 10,
                        backgroundColor: const Color.fromARGB(255, 194, 197, 175),
                        minimumSize: const Size(double.infinity, 60),
                      ),
                      child: const Text(
                        "Play vs Computer",
                        style: TextStyle(
                          fontSize: 23,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.yellow, blurRadius: 2)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}