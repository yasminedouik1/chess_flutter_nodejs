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
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    // Initialize socket listeners and start waiting timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('WaitingLobby: Initializing socket listeners and timer');
      gameProvider.initSocketListeners(context);
      gameProvider.startWaitingTimer(context: context);
    });
  }

  @override
  void dispose() {
    final gameProvider = context.read<GameProvider>();
    print('WaitingLobby: Disposing, cancelling game and timer');
    if (gameProvider.gameId.isNotEmpty) {
      gameProvider.cancelGame(context);
    }
    gameProvider._waitingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          print('WaitingLobby: Pop invoked, cancelling game');
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
              Text(
                'Time Left: ${gameProvider.waitingText} s',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 20),
              if (gameProvider.joinCode.isNotEmpty)
                Text(
                  'Join Code: ${gameProvider.joinCode}',
                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 10),
              if (gameProvider.joinCode.isNotEmpty)
                const Text(
                  'Share this code with your friend to join the game',
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  print('WaitingLobby: Cancel button pressed');
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