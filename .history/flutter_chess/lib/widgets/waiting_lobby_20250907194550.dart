import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/providers/game_provider.dart';

class WaitingLobby extends ConsumerWidget {
  final String gameId;

  const WaitingLobby({Key? key, required this.gameId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Waiting for opponent to join room: $gameId'),
          ],
        ),
      ),
    );
  }
}