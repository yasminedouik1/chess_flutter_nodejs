import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../constants.dart';

class WaitingLobby extends StatelessWidget {
  final String gameId;

  const WaitingLobby({Key? key, required this.gameId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A5A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Waiting for Opponent...',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Game ID: $gameId',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            if (gameProvider.isPrivate)
              Text(
                'Join Code: ${gameProvider.joinCode}',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Constants.homeScreen,
                  (route) => false,
                );
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}