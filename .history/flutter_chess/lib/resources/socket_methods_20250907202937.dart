import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/models/player.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/waiting_lobby.dart';

class SocketMethods {
  void initGameListener(BuildContext context, WidgetRef ref) {
    ApiService.socket?.on('start_game', (data) {
      ref.read(initGameProvider.notifier).state = true;
      ref.read(whitePlayerProvider.notifier).state = Player.fromMap(data['whitePlayer']);
      ref.read(blackPlayerProvider.notifier).state = Player.fromMap(data['blackPlayer']);
      ref.read(fenProvider.notifier).updateFen(data['fen']);
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/game');
      }
    });
  }

  void movesListener(BuildContext context, WidgetRef ref) {
    ApiService.socket?.on('move', (data) {
      ref.read(fenProvider.notifier).updateFen(data['fen']);
    });
  }

  void gameOverListener(BuildContext context, WidgetRef ref) {
    ApiService.socket?.on('game_over', (data) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Game Over'),
            content: Text(data['result'] ?? 'Game ended'),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(gameProvider).reset();
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  void errorListener(BuildContext context, WidgetRef ref) {
    ApiService.socket?.on('error', (data) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'An error occurred')),
        );
      }
    });
  }

  void createRoom(String roomName, String playerId) {
    ApiService.socket?.emit('create_room', {'roomName': roomName, 'playerId': playerId});
  }

  void joinRoom(String roomId, String playerId) {
    ApiService.socket?.emit('join_room', {'roomId': roomId, 'playerId': playerId});
  }

  void move(String gameId, Map<String, String> move) {
    ApiService.socket?.emit('move', {'gameId': gameId, 'move': move});
  }

  void resign(String gameId) {
    ApiService.socket?.emit('resign', {'gameId': gameId});
  }
}

final socketMethodsProvider = Provider<SocketMethods>((ref) => SocketMethods());