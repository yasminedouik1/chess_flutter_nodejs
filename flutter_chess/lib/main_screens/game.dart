import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'dart:math';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/service/assets_manager.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

final BoardTheme blackWhiteTheme = BoardTheme(
  lightSquare: Colors.white,
  darkSquare: const Color.fromARGB(255, 194, 194, 194),
  check: Colors.red,
  checkmate: const Color.fromARGB(255, 222, 119, 8),
  previous: const Color.fromARGB(255, 145, 193, 233),
  selected: const Color.fromARGB(255, 88, 196, 110),
  premove: const Color.fromARGB(255, 124, 124, 124),
);

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    gameProvider.resetGame(newGame: false, context: context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onMove(Move move) async {
    final gameProvider = context.read<GameProvider>();
    bool result = gameProvider.makeSquaresMove(move);
    if (result) {
      await gameProvider.setSquaresState().whenComplete(() {
        if (gameProvider.player == Squares.white) {
          gameProvider.pauseWhitesTimer();
          startTimer(isWhiteTimer: false, onNewGame: () {});
        } else {
          gameProvider.pauseBlacksTimer();
          startTimer(isWhiteTimer: true, onNewGame: () {});
        }
      });
    }
    if (gameProvider.state.state == PlayState.theirTurn &&
        !gameProvider.aiThinking) {
      gameProvider.setAiThinking(true);
      await Future.delayed(
        Duration(milliseconds: Random().nextInt(2000) + 500),
      );
      gameProvider.game.makeRandomMove();
      gameProvider.setAiThinking(false);
      await gameProvider.setSquaresState().whenComplete(() {
        if (gameProvider.player == Squares.white) {
          gameProvider.pauseBlacksTimer();
          startTimer(isWhiteTimer: true, onNewGame: () {});
        } else {
          gameProvider.pauseWhitesTimer();
          startTimer(isWhiteTimer: false, onNewGame: () {});
        }
      });
    }
    await Future.delayed(const Duration(milliseconds: 500));
    checkGameOverListener();
  }

  void checkGameOverListener() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.gameOverListener(context: context, onNewGame: () {});
  }

  void startTimer({required bool isWhiteTimer, required Function onNewGame}) {
    final gameProvider = context.read<GameProvider>();
    if (isWhiteTimer) {
      gameProvider.startWhitesTime(context: context, onNewGame: onNewGame);
    } else {
      gameProvider.startBlacksTime(context: context, onNewGame: onNewGame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    return WillPopScope(
      onWillPop: () async {
        bool? leave = await _showExitConfirmDialog(context);
        if (leave != null && leave) {
          gameProvider.pauseWhitesTimer();
          gameProvider.pauseBlacksTimer();
          await Future.delayed(const Duration(milliseconds: 200));
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Constants.homeScreen,
              (route) => false,
            );
          }
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2A2A5A),
          title: const Text(
            'ChessBoard',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              onPressed: () {
                gameProvider.resetGame(newGame: true, context: context);
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
            IconButton(
              onPressed: () => gameProvider.flipTheBoard(),
              icon: const Icon(Icons.rotate_left, color: Colors.white),
            ),
          ],
        ),
        body: Consumer<GameProvider>(
          builder: (context, value, child) {
            String whitesTimer = getTimerToDisplay(
              gameProvider: gameProvider,
              isUser: gameProvider.player == Squares.white,
            );
            String blacksTimer = getTimerToDisplay(
              gameProvider: gameProvider,
              isUser: gameProvider.player == Squares.black,
            );
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: AssetImage(AssetsManager.user2Icon),
                      backgroundColor: const Color(0xFF3A3A6A),
                    ),
                    title: const Text(
                      'user102',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Rating: 3000',
                      style: TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      gameProvider.isHumanWhite ? blacksTimer : whitesTimer,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    tileColor: const Color(0xFF3A3A6A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: BoardController(
                      state: gameProvider.flipBoard
                          ? gameProvider.state.board.flipped()
                          : gameProvider.state.board,
                      playState: gameProvider.state.state,
                      pieceSet: PieceSet.merida(),
                      theme: blackWhiteTheme,
                      moves: gameProvider.state.moves,
                      onMove: _onMove,
                      onPremove: _onMove,
                      markerTheme: MarkerTheme(
                        empty: MarkerTheme.dot,
                        piece: MarkerTheme.corners(),
                      ),
                      promotionBehaviour: PromotionBehaviour.autoPremove,
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: AssetImage(AssetsManager.userIcon),
                      backgroundColor: const Color(0xFF3A3A6A),
                    ),
                    title: const Text(
                      'user257',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Rating: 1200',
                      style: TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      gameProvider.isHumanWhite ? whitesTimer : blacksTimer,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    tileColor: const Color(0xFF3A3A6A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<bool?> _showExitConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Game?', textAlign: TextAlign.center),
        content: const Text(
          'Are you sure to leave this game?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
