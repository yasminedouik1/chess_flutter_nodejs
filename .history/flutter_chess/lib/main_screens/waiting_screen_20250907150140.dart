import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:provider/provider.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({
    super.key,
    required this.gameId,
    required this.joinCode,
    required this.isPrivate,
  });
  final String gameId;
  final String joinCode;
  final bool isPrivate;

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    final token = context.read<AuthProvider>().token;
    if (token != null && widget.gameId.isNotEmpty) {
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(widget.gameId);
      ApiService.socket?.on('player_joined', (data) {
        if (context.mounted) {
          gameProvider.setOpponentData(
            opponentId: data['opponentId'] ?? '',
            opponentName: data['opponentName'] ?? 'Opponent',
            opponentImage: data['opponentImage'] ?? '',
            opponentRating: data['opponentRating'] ?? 1200,
            whiteTime: data['whiteTime'] ?? 600,
            blackTime: data['blackTime'] ?? 600,
            increment: data['increment'] ?? 0,
            gameId: data['gameId'],
          );
          showSnackBar(
            context: context,
            content: 'Player ${data['opponentName'] ?? 'Opponent'} has joined!',
          );
          Navigator.pushReplacementNamed(
            context,
            Constants.gameScreen,
            arguments: {
              'gameId': data['gameId'],
              'opponentName': data['opponentName'] ?? 'Opponent',
              'opponentRating': data['opponentRating'] ?? 1200,
            },
          );
        }
      });
      ApiService.socket?.on('error', (data) {
        if (context.mounted) {
          showSnackBar(context: context, content: data['message'] ?? 'Error joining game');
        }
      });
      gameProvider.startWaitingTimer(context: context);
    } else {
      showSnackBar(context: context, content: 'Invalid game or user session');
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
            if (widget.isPrivate)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Share this code: ${widget.joinCode}',
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