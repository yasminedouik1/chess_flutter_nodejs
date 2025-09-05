import 'package:flutter_chess/providers/game_provider.dart';
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