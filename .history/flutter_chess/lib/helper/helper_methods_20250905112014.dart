import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';

String getTimerToDisplay({
  required GameProvider gameProvider,
  required bool isUser,
}) {
  final isWhitePlayer = gameProvider.player == Squares.white;
  Duration duration;
  if (isUser) {
    duration = isWhitePlayer ? gameProvider.whitesTime : gameProvider.blacksTime;
  } else {
    duration = isWhitePlayer ? gameProvider.blacksTime : gameProvider.whitesTime;
  }

  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}

void gameOverDialog({
  required BuildContext context,
  required bool timeOut,
  required bool userWon,
  required Function onNewGame,
  required String reason,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(
        timeOut ? 'Time Out' : reason == 'draw' ? 'Draw' : userWon ? 'You Won!' : 'You Lost!',
        textAlign: TextAlign.center,
      ),
      content: Text(
        timeOut
            ? 'Game ended due to time out.'
            : reason == 'draw'
                ? 'The game ended in a draw.'
                : userWon
                    ? 'Congratulations, you won by $reason!'
                    : 'You lost by $reason.',
        textAlign: TextAlign.center,
      ),
      actions: [
        if (!context.read<GameProvider>().vsComputer) ...[
          TextButton(
            onPressed: () {
              onNewGame();
              Navigator.of(context).pop();
            },
            child: const Text('Rematch'),
          ),
        ],
        TextButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Constants.homeScreen,
              (route) => false,
            );
          },
          child: const Text('Back to Home'),
        ),
      ],
    ),
  );
}

void showSnackBar({
  required BuildContext context,
  required String content,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(content),
      duration: const Duration(seconds: 3),
    ),
  );
}

final List<String> gameTimes = [
  'Bullet 1+0',
  'Bullet 2+0',
  'Bullet 3+0',
  'Bullet 4+0',
  'Bullet 5+0',
  'Bullet 1+2',
  'Bullet 2+1',
  'Classical 60+0',
  'Custom 60+0',
];