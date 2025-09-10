import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/main_screens/about.dart';
import 'package:flutter_chess/main_screens/bottom_navbar.dart';
import 'package:flutter_chess/main_screens/game_setup.dart';
import 'package:flutter_chess/main_screens/play_vs_friend.dart';

import 'package:flutter_chess/main_screens/settings.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text('ChessBoard', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/chessboard.png',
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),
              SizedBox(
                width: 300,
                height: 120,
                child: buildGameType(
                  label: 'Play vs Computer',
                  icon: Icons.computer,
                  onTap: () {
                    gameProvider.setVsComputer(value: true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameSetupScreen(),
                      ),
                    );
                  },
                ),
              ),
              // const SizedBox(height: 10),
              // SizedBox(
              //   width: 300,
              //   height: 120,
              //   child: buildGameType(
              //     label: 'Play vs Friend',
              //     icon: Icons.person,
              //     onTap: () {
              //       gameProvider.setVsComputer(value: false);
              //       Navigator.push(context, MaterialPageRoute(builder: (context) => const GameTimeScreen()));
              //     },
              //   ),
              // ),
              // const SizedBox(height: 10),
              // SizedBox(
              //   width: 300,
              //   height: 120,
              //   child: buildGameType(
              //     label: 'Create PvP Game',
              //     icon: Icons.person_add,
              //     onTap: () {
              //       gameProvider.setVsComputer(value: false);
              //       Navigator.push(context, MaterialPageRoute(builder: (context) => const GameTimeScreen()));
              //     },
              //   ),
              // ),
              // const SizedBox(height: 10),
              // SizedBox(
              //   width: 300,
              //   height: 120,
              //   child: buildGameType(
              //     label: 'Join PvP Game',
              //     icon: Icons.group,
              //     onTap: () {
              //       gameProvider.setVsComputer(value: false);
              //       Navigator.push(context, MaterialPageRoute(builder: (context) => PvPJoinScreen()));
              //     },
              //   ),
              // ),
              const SizedBox(height: 10),
              SizedBox(
                width: 300,
                height: 120,
                child: buildGameType(
                  label: 'Play vs Friend',
                  icon: Icons.person,
                  onTap: () {
                    gameProvider.setVsComputer(value: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlayVsFriendScreen(),
                      ),
                    );
                  },
                ),
              ),
              // In HomeScreen build method, add to Column or similar
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  Constants.availableGamesScreen,
                ),
                child: const Text('Join Public Game'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 300,
                height: 120,
                child: buildGameType(
                  label: 'Settings',
                  icon: Icons.settings,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 300,
                height: 120,
                child: buildGameType(
                  label: 'About',
                  icon: Icons.info,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MyBottomNavBar(currentIndex: 0),
    );
  }

  Widget buildGameType({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF3A3A6A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF26A69A), size: 35),
              const SizedBox(height: 15),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
