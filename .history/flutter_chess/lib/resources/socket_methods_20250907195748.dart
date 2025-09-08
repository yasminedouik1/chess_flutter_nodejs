import 'package:flutter/material.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/models/player.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/game_board.dart';

final socketMethodsProvider = Provider<SocketMethods>((ref) {
  final authProvider = ref.watch(AuthProvider as ProviderListenable);
  return SocketMethods(authProvider: authProvider, ref: ref);
});

class SocketMethods {
  final AuthProvider authProvider;
  final WidgetRef ref;

  SocketMethods({required this.authProvider, required this.ref});

  void initializeSocket() {
    final token = authProvider.token;
    if (token != null) {
      ApiService.initializeSocket(token);
    }
  }

  void createRoomSuccessListener(BuildContext context) {
    ApiService.socket?.on('room_created', (data) {
      ref.read(gameProvider).setGameData(
        gameId: data['gameId'],
        roomName: data['roomName'],
        whitePlayer: Player(id: data['whitePlayer']['id'], name: data['whitePlayer']['name']),
      );
      Navigator.pushNamed(context, GameBoard.routeName);
    });
  }

  void joinRoomSuccessListener(BuildContext context) {
    ApiService.socket?.on('joined_room', (data) {
      ref.read(gameProvider).setGameData(
        gameId: data['gameId'],
        roomName: data['roomName'],
        whitePlayer: Player(id: data['whitePlayer']['id'], name: data['whitePlayer']['name']),
        blackPlayer: data['blackPlayer'] != null
            ? Player(id: data['blackPlayer']['id'], name: data['blackPlayer']['name'])
            : null,
      );
      Navigator.pushNamed(context, GameBoard.routeName);
    });
  }

  void initGameListener(BuildContext context) {
    ApiService.socket?.on('start_game', (data) {
      ref.read(initGameProvider.notifier).state = true;
      ref.read(gameProvider).setGameData(
        gameId: data['gameId'],
        roomName: data['roomName'],
        whitePlayer: Player(id: data['whitePlayer']['id'], name: data['whitePlayer']['name']),
        blackPlayer: Player(id: data['blackPlayer']['id'], name: data['blackPlayer']['name']),
      );
    });
  }

  void movesListener(BuildContext context) {
    ApiService.socket?.on('move_made', (data) {
      final fen = makeMove(ref.read(fenProvider), data['move'], context);
      if (fen != null) {
        ref.read(fenProvider.notifier).updateFen(fen);
      }
    });
  }

  void gameOverListener(BuildContext context) {
    ApiService.socket?.on('game_over', (data) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(data['reason']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void errorListener(BuildContext context) {
    ApiService.socket?.on('error', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'An error occurred')),
      );
    });
  }

  void createRoom(String roomName) {
    final user = ref.read(userProvider);
    if (user != null) {
      ApiService.socket?.emit('create_room', {
        'roomName': roomName,
        'player': {'id': user.id, 'name': user.username},
      });
    }
  }

  void joinRoom(String roomId) {
    final user = ref.read(userProvider);
    if (user != null) {
      ApiService.socket?.emit('join_room', {
        'roomId': roomId,
        'player': {'id': user.id, 'name': user.username},
      });
    }
  }

  void move(String gameId, dynamic move) {
    ApiService.socket?.emit('move', {'gameId': gameId, 'move': move});
  }

  void resign(String gameId) {
    final user = ref.read(userProvider);
    if (user != null) {
      ApiService.socket?.emit('resign', {
        'gameId': gameId,
        'playerId': user.id,
      });
    }
  }
}