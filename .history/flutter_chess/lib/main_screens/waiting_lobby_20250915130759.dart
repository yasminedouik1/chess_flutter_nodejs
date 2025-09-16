import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../constants.dart';

class WaitingLobby extends StatefulWidget {
  const WaitingLobby({Key? key}) : super(key: key);

  @override
  State<WaitingLobby> createState() => _WaitingLobbyState();
}

class _WaitingLobbyState extends State<WaitingLobby> {
  @override
  void dispose() {
    // Cancel the game when the widget is disposed
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.gameId.isNotEmpty) {
      gameProvider.cancelGame(context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // User is trying to go back, cancel the game
          await gameProvider.cancelGame(context);
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
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
            if (gameProvider.joinCode.isNotEmpty)
              Text(
                'Join Code: ${gameProvider.joinCode}',
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 10),
            Text(
              'Share this code with your friend to join the game',
              style: const TextStyle(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                await gameProvider.cancelGame(context);
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Constants.homeScreen,
                    (route) => false,
                  );
                }
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}