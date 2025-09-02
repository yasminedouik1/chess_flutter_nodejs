import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/providers/auth_provider.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(gameProvider.gameId);
      ApiService.socket?.on('opponent_joined', (data) {
        final game = data['game'];
        gameProvider.setOpponentData(
          opponentId: game['opponentId'],
          opponentName: game['opponentName'] ?? 'Opponent',
          opponentImage: game['opponentImage'] ?? '',
          opponentRating: game['opponentRating'] ?? 1200,
          whiteTime: game['whiteTime'],
          blackTime: game['blackTime'],
          increment: game['increment'],
        );
        gameProvider.isHumanWhite = true; // Creator is white
        // gameProvider._isPlaying = true;
        // gameProvider._waitingTimer?.cancel();
        // gameProvider.notifyListeners();
        Navigator.pushReplacementNamed(context, Constants.gameScreen, arguments: {
          'gameId': gameProvider.gameId,
          'opponentName': gameProvider.opponentName,
          'opponentRating': gameProvider.opponentRating,
        });
      });
    }
    gameProvider.startWaitingTimer(context: context);
  }

  @override
  void dispose() {
    ApiService.disposeSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Waiting for Opponent')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Waiting... (${gameProvider.waitingText})'),
            const SizedBox(height: 20),
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
    );
  }
}