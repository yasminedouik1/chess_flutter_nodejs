import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:provider/provider.dart';
import 'package:stockfish/stockfish.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Stockfish? _stockfish;

  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    gameProvider.resetGame(newGame: false, context: context);
    if (!gameProvider.vsComputer) {
      ApiService.joinGameRoom(gameProvider.gameId);
      gameProvider.startWhitesTime(context: context, onNewGame: () {});
      _setupSocketListeners();
    } else {
      _stockfish = Stockfish(); // Initialize Stockfish
    }
  }

  @override
  void dispose() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.pauseWhitesTimer();
    gameProvider.pauseBlacksTimer();
    if (!gameProvider.vsComputer) {
      ApiService.disposeSocket();
    }
    _stockfish?.dispose(); // Dispose Stockfish
    super.dispose();
  }

  void _setupSocketListeners() {
    final gameProvider = context.read<GameProvider>();
    ApiService.socket?.on('move_made', (data) {
      if (mounted) {
        gameProvider.handleOpponentMove(
          context: context,
          fen: data['fen'],
          move: data['move'],
          isWhitesTurn: data['isWhitesTurn'],
        );
      }
    });
    ApiService.socket?.on('game_over', (data) {
      if (mounted) {
        gameProvider.handleGameOver(
          context: context,
          result: data['result'],
          reason: data['reason'],
          winnerSide: data['winnerSide'],
        );
      }
    });
    ApiService.socket?.on('draw_offered', (data) {
      if (mounted) {
        gameProvider.setDrawOffered(by: data['offeredBy']);
        showSnackBar(context: context, content: 'Draw offered by ${data['offeredBy']}');
      }
    });
    ApiService.socket?.on('rematch_offered', (data) {
      if (mounted) {
        gameProvider.setRematchOffered(by: data['offeredBy']);
        showSnackBar(context: context, content: 'Rematch offered by ${data['offeredBy']}');
      }
    });
  }

  void _onMove(String sanMove) async {
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.vsComputer) {
      bool result = gameProvider.makeMove(sanMove);
      if (result) {
        await gameProvider.setBoardState().whenComplete(() {
          if (gameProvider.player == BoardColor.white) {
            gameProvider.pauseWhitesTimer();
            gameProvider.startBlacksTime(context: context, onNewGame: () {});
          } else {
            gameProvider.pauseBlacksTimer();
            gameProvider.startWhitesTime(context: context, onNewGame: () {});
          }
        });
        if (gameProvider.game.turn == (gameProvider.player == BoardColor.white ? chess.Color.BLACK : chess.Color.WHITE) && !gameProvider.aiThinking) {
          gameProvider.setAiThinking(true);
          final fen = gameProvider.game.fen;
          await _stockfish?.setPosition(fen);
          final bestMove = await _stockfish?.getBestMove(level: gameProvider.gameLevel);
          if (bestMove != null && context.mounted) {
            gameProvider.makeMove(bestMove);
            await gameProvider.setBoardState().whenComplete(() {
              if (gameProvider.player == BoardColor.white) {
                gameProvider.pauseBlacksTimer();
                gameProvider.startWhitesTime(context: context, onNewGame: () {});
              } else {
                gameProvider.pauseWhitesTimer();
                gameProvider.startBlacksTime(context: context, onNewGame: () {});
              }
            });
          }
          gameProvider.setAiThinking(false);
        }
      }
    } else {
      await gameProvider.playMove(context: context, sanMove: sanMove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(gameProvider.vsComputer ? 'Vs Computer' : 'Vs ${gameProvider.opponentName}'),
        actions: [
          if (!gameProvider.vsComputer)
            IconButton(
              icon: const Icon(Icons.flag),
              onPressed: () => gameProvider.resign(context),
            ),
          if (gameProvider.drawOfferedBy != null)
            IconButton(
              icon: const Icon(Icons.handshake),
              onPressed: () => gameProvider.acceptDraw(context),
            ),
          if (gameProvider.drawOfferedBy == null)
            IconButton(
              icon: const Icon(Icons.handshake_outlined),
              onPressed: () => gameProvider.offerDraw(context),
            ),
          if (gameProvider.game.game_over)
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: () => gameProvider.offerRematch(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ChessBoard(
                controller: gameProvider.boardController,
                boardColor: BoardColor.brown,
                onMove: _onMove,
                enableUserMoves: gameProvider.game.turn == (gameProvider.isHumanWhite ? chess.Color.WHITE : chess.Color.BLACK),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'White: ${gameProvider.whitesTime.inMinutes}:${(gameProvider.whitesTime.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                Text(
                  'Black: ${gameProvider.blacksTime.inMinutes}:${(gameProvider.blacksTime.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}