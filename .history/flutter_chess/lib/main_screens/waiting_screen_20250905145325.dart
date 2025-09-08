import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';

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
    if (token != null && gameProvider.gameId.isNotEmpty) {
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(gameProvider.gameId);
      ApiService.socket?.on('player_joined', (data) {
        final game = data;
        gameProvider.setOpponentData(
          opponentId: game['opponentId'] ?? '',
          opponentName: game['opponentName'] ?? 'Opponent',
          opponentImage: game['opponentImage'] ?? '',
          opponentRating: game['opponentRating'] ?? 1200,
          whiteTime: game['whiteTime'] ?? 600,
          blackTime: game['blackTime'] ?? 600,
          increment: game['increment'] ?? 0,
        );
        gameProvider.setPlayerColor(player: 0); // Creator is white
        if (context.mounted) {
          showSnackBar(
            context: context,
            content: 'Player ${game['opponentName'] ?? 'Opponent'} has joined the game!',
            duration: const Duration(seconds: 2),
          );
          Navigator.pushReplacementNamed(
            context,
            Constants.gameScreen,
            arguments: {
              'gameId': gameProvider.gameId,
              'opponentName': game['opponentName'] ?? 'Opponent',
              'opponentRating': game['opponentRating'] ?? 1200,
            },
          );
        }
      });
      ApiService.socket?.on('error', (data) {
        if (context.mounted) {
          showSnackBar(context: context, content: data['message'] ?? 'Error joining game', duration: const Duration(seconds: 2));
        }
      });
      gameProvider.startWaitingTimer(context: context);
    } else {
      showSnackBar(context: context, content: 'Invalid game or user session', duration: const Duration(seconds: 2));
      Navigator.pushNamedAndRemoveUntil(context, Constants.homeScreen, (route) => false);
    }
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
      appBar: AppBar(
        title: const Text(
          'Waiting for Opponent',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2A2A5A),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Waiting... (${gameProvider.waitingText})',
              style: const TextStyle(color: Colors.white),
            ),
            if (gameProvider.isPrivate)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Share this code: ${gameProvider.joinCode}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
              ),
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}