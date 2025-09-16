import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_chess/main_screens/waiting_lobby.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/assets_manager.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';

class GameScreen extends HookWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider access
    final gameProvider = context.watch<GameProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    // Helper functions
    void startTimer(BuildContext context, {required bool isWhiteTimer, required Function onNewGame}) {
      if (isWhiteTimer) {
        gameProvider.startWhitesTime(context: context, onNewGame: onNewGame);
      } else {
        gameProvider.startBlacksTime(context: context, onNewGame: onNewGame);
      }
    }

    Future<void> handleComputerMove(BuildContext context, Move move) async {
      final result = gameProvider.makeSquaresMove(move);
      if (result) {
        await gameProvider.setSquaresState().whenComplete(() {
          if (gameProvider.player == Squares.white) {
            gameProvider.pauseWhitesTimer();
            startTimer(context, isWhiteTimer: false, onNewGame: () {});
          } else {
            gameProvider.pauseBlacksTimer();
            startTimer(context, isWhiteTimer: true, onNewGame: () {});
          }
        });

        if (gameProvider.state.state == PlayState.theirTurn && !gameProvider.aiThinking) {
          await gameProvider.makeAIMove(context);
        }
      }
    }

    Future<void> handleMultiplayerMove(BuildContext context, Move move) async {
      // Validate move before sending
      final legalMoves = gameProvider.state.moves;
      final isValidMove = legalMoves.any((m) => m.from == move.from && m.to == move.to && m.promo == move.promo);
      if (!isValidMove) {
        print('Invalid move attempted: $move');
        return;
      }

      final result = gameProvider.makeSquaresMove(move);
      if (result) {
        final newFen = gameProvider.getPositionFen();
        print('Sending move: $move, FEN: $newFen, isWhite: ${gameProvider.isHumanWhite}');
        
        // Send move to backend via socket
        ApiService.socket?.emit('move', {
          'gameId': gameProvider.gameId,
          'move': move.toString(),
          'isWhite': gameProvider.isHumanWhite,
          'fen': newFen,
        });
        
        // Update local state
        await gameProvider.setSquaresState();
        
        // Switch timer
        if (gameProvider.isHumanWhite) {
          gameProvider.pauseWhitesTimer();
          startTimer(context, isWhiteTimer: false, onNewGame: () {});
        } else {
          gameProvider.pauseBlacksTimer();
          startTimer(context, isWhiteTimer: true, onNewGame: () {});
        }
      } else {
        print('Move failed: $move');
      }
    }

    void checkGameOverListener(BuildContext context) {
      gameProvider.gameOverListener(
        context: context,
        onNewGame: () {
          if (!gameProvider.vsComputer) {
            gameProvider.rematch(context);
          } else {
            gameProvider.resetGame(newGame: true, context: context);
          }
        },
      );
    }

    // Handle move logic
    Future<void> onMove(Move move) async {
      print('Player attempted move: $move, PlayState: ${gameProvider.state.state}');
      if (gameProvider.state.state != PlayState.ourTurn) {
        print('Move blocked: Not player\'s turn');
        return;
      }
      if (gameProvider.vsComputer) {
        await handleComputerMove(context, move);
      } else {
        await handleMultiplayerMove(context, move);
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      checkGameOverListener(context);
    }

    // Show exit confirmation dialog
    Future<bool?> showExitConfirmDialog(BuildContext context) {
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

    // Handle exit
    Future<void> handleExit(BuildContext context) async {
      final shouldExit = await showExitConfirmDialog(context);
      if (shouldExit == true && context.mounted) {
        if (gameProvider.vsComputer) {
          gameProvider.pauseWhitesTimer();
          gameProvider.pauseBlacksTimer();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/homeScreen',
            (route) => false,
          );
        } else {
          await gameProvider.leaveGame(context);
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/homeScreen',
              (route) => false,
            );
          }
        }
      }
    }

    // Show draw offer dialog
    void showDrawOfferDialog(BuildContext context) {
      if (gameProvider.drawOfferedByOpponent) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Draw Offered'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  gameProvider.acceptDraw(context);
                },
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  gameProvider.declineDraw();
                },
                child: const Text('Decline'),
              ),
            ],
          ),
        );
      }
    }

    // Show rematch offer dialog
    void showRematchOfferDialog(BuildContext context) {
      if (gameProvider.rematchOffered) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Rematch Offered'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  gameProvider.acceptRematch();
                },
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  gameProvider.declineRematch();
                },
                child: const Text('Decline'),
              ),
            ],
          ),
        );
      }
    }

    // Initialize game on first build
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('GameScreen: Initializing, vsComputer: ${gameProvider.vsComputer}, isPlaying: ${gameProvider.isPlaying}, FEN: ${gameProvider.getPositionFen()}');
        if (gameProvider.vsComputer) {
          gameProvider.resetGame(newGame: false, context: context);
          gameProvider.initStockfish().then((_) {
            startTimer(
              context,
              isWhiteTimer: gameProvider.player == Squares.white,
              onNewGame: () {},
            );
            if (gameProvider.player == Squares.black) {
              gameProvider.makeAIMove(context);
            }
          });
        } else {
          // Ensure board state is initialized for multiplayer
          gameProvider.resetGame(newGame: false, context: context);
          gameProvider.setSquaresState().then((_) {
            // Start timer for the correct player
            startTimer(
              context,
              isWhiteTimer: gameProvider.isHumanWhite,
              onNewGame: () {},
            );
          });
        }
      });

      // Cleanup on dispose
      return () {
        print('GameScreen: Disposing');
        gameProvider.pauseWhitesTimer();
        gameProvider.pauseBlacksTimer();
        if (!gameProvider.vsComputer) {
          ApiService.disposeSocket();
        }
      };
    }, []);

    // Show dialogs when needed
    useEffect(() {
      if (gameProvider.drawOfferedByOpponent) {
        showDrawOfferDialog(context);
      }
      if (gameProvider.rematchOffered) {
        showRematchOfferDialog(context);
      }
      return null;
    }, [gameProvider.drawOfferedByOpponent, gameProvider.rematchOffered]);

    // Return waiting lobby if not playing and not vs computer
    if (!gameProvider.isPlaying && !gameProvider.vsComputer) {
      return const WaitingLobby();
    }

    // Validate board state before rendering
    if (gameProvider.state.board.board.isEmpty) {
      print('GameScreen: Warning - Empty board detected, reinitializing');
      gameProvider.resetGame(newGame: false, context: context);
      gameProvider.setSquaresState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A5A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text('Chess Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => handleExit(context),
        ),
        actions: [
          if (gameProvider.vsComputer) ...[
            IconButton(
              onPressed: () => gameProvider.resetGame(newGame: true, context: context),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
          if (!gameProvider.vsComputer) ...[
            ElevatedButton(
              onPressed: gameProvider.drawOffered ? null : () => gameProvider.offerDraw(context),
              child: const Text('Offer Draw'),
            ),
            const SizedBox(width: 10),
            if (gameProvider.drawOfferedByOpponent)
              ElevatedButton(
                onPressed: () => gameProvider.acceptDraw(context),
                child: const Text('Accept Draw'),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Opponent info (for multiplayer) or AI info (for computer)
          ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: gameProvider.vsComputer 
                  ? const AssetImage('assets/images/computer.png')
                  : NetworkImage(gameProvider.opponentImage),
              backgroundColor: const Color(0xFF3A3A6A),
            ),
            title: Text(
              gameProvider.vsComputer ? 'Computer' : gameProvider.opponentName,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              gameProvider.vsComputer 
                  ? 'AI Level: ${gameProvider.gameLevel}'
                  : 'Rating: ${gameProvider.opponentRating}',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              gameProvider.isHumanWhite
                  ? gameProvider.blacksTimeFormatted
                  : gameProvider.whitesTimeFormatted,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            tileColor: const Color(0xFF3A3A6A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // Chessboard
          Expanded(
            child: BoardController(
              state: gameProvider.state.board,
              playState: gameProvider.state.state,
              pieceSet: PieceSet.merida(),
              theme: const BoardTheme(
                lightSquare: Colors.white,
                darkSquare: Color.fromARGB(255, 194, 194, 194),
                check: Colors.red,
                checkmate: Color.fromARGB(255, 222, 119, 8),
                previous: Color.fromARGB(255, 145, 193, 233),
                selected: Color.fromARGB(255, 88, 196, 110),
                premove: Color.fromARGB(255, 124, 124, 124),
              ),
              moves: gameProvider.state.moves,
              onMove: onMove,
              markerTheme: MarkerTheme(
                empty: MarkerTheme.dot,
                piece: MarkerTheme.corners(),
              ),
              promotionBehaviour: PromotionBehaviour.autoPremove,
            ),
          ),

          // User info
          ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(
                user?.image ?? AssetsManager.userIcon,
              ),
              backgroundColor: const Color(0xFF3A3A6A),
            ),
            title: Text(
              user?.username ?? 'You',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Rating: ${user?.playerRating ?? 1200}',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              gameProvider.isHumanWhite
                  ? gameProvider.whitesTimeFormatted
                  : gameProvider.blacksTimeFormatted,
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
  }
}