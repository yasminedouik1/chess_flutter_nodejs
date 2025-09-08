import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/assets_manager.dart';
import 'package:flutter_chess/services/api_service.dart';
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
    if (!gameProvider.vsComputer) {
      gameProvider.initSocketListeners(context);
      startTimer(isWhiteTimer: true, onNewGame: () {});
    }
  }

  @override
  void dispose() {
    context.read<GameProvider>().pauseWhitesTimer();
    context.read<GameProvider>().pauseBlacksTimer();
    if (!context.read<GameProvider>().vsComputer) {
      ApiService.disposeSocket();
    }
    super.dispose();
  }

  void _onMove(Move move) async {
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.vsComputer) {
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
      }
    } else {
      // PvP mode: Emit move to server
      bool result = gameProvider.makeSquaresMove(move);
      if (result) {
        final newFen = gameProvider.state.board.fen;
        ApiService.socket?.emit('move', {
          'gameId': gameProvider.gameId,
          'move': move.toString(),
          'isWhite': gameProvider.player == Squares.white,
          'fen': newFen,
        });
        await gameProvider.setSquaresState();
        if (gameProvider.player == Squares.white) {
          gameProvider.pauseWhitesTimer();
          startTimer(isWhiteTimer: false, onNewGame: () {});
        } else {
          gameProvider.pauseBlacksTimer();
          startTimer(isWhiteTimer: true, onNewGame: () {});
        }
      }
      }
    await Future.delayed(const Duration(milliseconds: 500));
    checkGameOverListener();
  }

  void checkGameOverListener() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.gameOverListener(
      context: context,
      onNewGame: () {
        if (!gameProvider.vsComputer) {
          gameProvider.offerRematch();
        }
      },
    );
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
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (!gameProvider.isPlaying && !gameProvider.vsComputer) {
      return WaitingLobby(gameId: gameProvider.gameId);
    }
    if (!gameProvider.vsComputer) {
      if (gameProvider.drawOffered) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Draw Offered'),
            actions: [
              TextButton(
                onPressed: gameProvider.acceptDraw,
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: gameProvider.declineDraw,
                child: const Text('Decline'),
              ),
            ],
          ),
        );
      }
      if (gameProvider.rematchOffered) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Rematch Offered'),
            actions: [
              TextButton(
                onPressed: gameProvider.acceptRematch,
                child: const Text('Accept'),
              ),
              TextButton(
                onPressed: gameProvider.declineRematch,
                child: const Text('Decline'),
              ),
            ],
          ),
        );
      }
    }
    return WillPopScope(
      onWillPop: () async {
        bool? leave = await _showExitConfirmDialog(context);
        if (leave != null && leave) {
          gameProvider.pauseWhitesTimer();
          gameProvider.pauseBlacksTimer();
          if (!gameProvider.vsComputer) {
            ApiService.socket?.emit('resign', {
              'gameId': gameProvider.gameId,
              'userId': user?.uid,
            });
            ApiService.disposeSocket();
          }
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
            if (!gameProvider.vsComputer)
              IconButton(
                onPressed: gameProvider.offerDraw,
                icon: const Icon(Icons.handshake, color: Colors.white),
                tooltip: 'Offer Draw',
              ),
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
                      backgroundImage: gameProvider.vsComputer
                          ? AssetImage(AssetsManager.user2Icon)
                          : NetworkImage(
                              gameProvider.opponentImage.isEmpty
                                  ? AssetsManager.user2Icon
                                  : gameProvider.opponentImage,
                            ),
                      backgroundColor: const Color(0xFF3A3A6A),
                    ),
                    title: Text(
                      gameProvider.vsComputer
                          ? 'Computer'
                          : gameProvider.opponentName.isEmpty
                          ? 'Opponent'
                          : gameProvider.opponentName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Rating: ${gameProvider.vsComputer ? 3000 : gameProvider.opponentRating}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      gameProvider.isHumanWhite
                          ? getTimerToDisplay(
                              gameProvider: gameProvider,
                              isUser: false,
                            )
                          : getTimerToDisplay(
                              gameProvider: gameProvider,
                              isUser: true,
                            ),
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


// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_chess/constants.dart';
// import 'package:flutter_chess/helper/helper_methods.dart';
// import 'package:flutter_chess/providers/auth_provider.dart';
// import 'package:flutter_chess/providers/game_provider.dart';
// import 'package:flutter_chess/service/assets_manager.dart';
// import 'package:flutter_chess/services/api_service.dart';
// import 'package:provider/provider.dart';
// import 'package:squares/squares.dart';

// class GameScreen extends StatefulWidget {
//   const GameScreen({super.key});

//   @override
//   State<GameScreen> createState() => _GameScreenState();
// }

// final BoardTheme blackWhiteTheme = BoardTheme(
//   lightSquare: Colors.white,
//   darkSquare: const Color.fromARGB(255, 194, 194, 194),
//   check: Colors.red,
//   checkmate: const Color.fromARGB(255, 222, 119, 8),
//   previous: const Color.fromARGB(255, 145, 193, 233),
//   selected: const Color.fromARGB(255, 88, 196, 110),
//   premove: const Color.fromARGB(255, 124, 124, 124),
// );

// class _GameScreenState extends State<GameScreen> {
//   @override
//   void initState() {
//     super.initState();
//     final gameProvider = context.read<GameProvider>();
//     gameProvider.resetGame(newGame: false, context: context);
//   }

//   @override
//   void dispose() {
//     context.read<GameProvider>().pauseWhitesTimer();
//     context.read<GameProvider>().pauseBlacksTimer();
//     if (!context.read<GameProvider>().vsComputer) {
//       ApiService.disposeSocket();
//     }
//     super.dispose();
//   }

//   void _onMove(Move move) async {
//   final gameProvider = context.read<GameProvider>();
//   if (gameProvider.vsComputer) {
//     bool result = gameProvider.makeSquaresMove(move);
//     if (result) {
//       await gameProvider.setSquaresState().whenComplete(() {
//         if (gameProvider.player == Squares.white) {
//           gameProvider.pauseWhitesTimer();
//           startTimer(isWhiteTimer: false, onNewGame: () {});
//         } else {
//           gameProvider.pauseBlacksTimer();
//           startTimer(isWhiteTimer: true, onNewGame: () {});
//         }
//       });
//       if (gameProvider.state.state == PlayState.theirTurn && !gameProvider.aiThinking) {
//         gameProvider.setAiThinking(true);
//         await Future.delayed(Duration(milliseconds: Random().nextInt(2000) + 500));
//         gameProvider.game.makeRandomMove();
//         gameProvider.setAiThinking(false);
//         await gameProvider.setSquaresState().whenComplete(() {
//           if (gameProvider.player == Squares.white) {
//             gameProvider.pauseBlacksTimer();
//             startTimer(isWhiteTimer: true, onNewGame: () {});
//           } else {
//             gameProvider.pauseWhitesTimer();
//             startTimer(isWhiteTimer: false, onNewGame: () {});
//           }
//         });
//       }
//     }
//   } else {
//     await gameProvider.playMove(context: context, move: move);
//   }
//   await Future.delayed(const Duration(milliseconds: 500));
//   checkGameOverListener();
// }

//   void checkGameOverListener() {
//     final gameProvider = context.read<GameProvider>();
//     gameProvider.gameOverListener(context: context, onNewGame: () {});
//   }

//   void startTimer({required bool isWhiteTimer, required Function onNewGame}) {
//     final gameProvider = context.read<GameProvider>();
//     if (isWhiteTimer) {
//       gameProvider.startWhitesTime(context: context, onNewGame: onNewGame);
//     } else {
//       gameProvider.startBlacksTime(context: context, onNewGame: onNewGame);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final gameProvider = context.read<GameProvider>();
//     final authProvider = context.read<AuthProvider>();
//     final user = authProvider.user;
//     if (!gameProvider.vsComputer) {
//     if (gameProvider.drawOffered) {
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text('Draw Offered'),
//           actions: [
//             TextButton(onPressed: gameProvider.acceptDraw, child: const Text('Accept')),
//             TextButton(onPressed: gameProvider.declineDraw, child: const Text('Decline')),
//           ],
//         ),
//       );
//     }
//     if (gameProvider.rematchOffered) {
//       showDialog(
//         context: context,
//         builder: (_) => AlertDialog(
//           title: const Text('Rematch Offered'),
//           actions: [
//             TextButton(onPressed: gameProvider.acceptRematch, child: const Text('Accept')),
//             TextButton(onPressed: () {}, child: const Text('Decline')),
//           ],
//         ),
//       );
//     }
//   }
//     return WillPopScope(
//       onWillPop: () async {
//         bool? leave = await _showExitConfirmDialog(context);
//         if (leave != null && leave) {
//           gameProvider.pauseWhitesTimer();
//           gameProvider.pauseBlacksTimer();
//           if (!gameProvider.vsComputer) {
//             ApiService.socket?.emit('resign', {
//               'gameId': gameProvider.gameId,
//               'userId': user?.uid,
//             });
//             ApiService.disposeSocket();
//           }
//           await Future.delayed(const Duration(milliseconds: 200));
//           if (context.mounted) {
//             Navigator.pushNamedAndRemoveUntil(
//               context,
//               Constants.homeScreen,
//               (route) => false,
//             );
//           }
//         }
//         return false;
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           backgroundColor: const Color(0xFF2A2A5A),
//           title: const Text(
//             'ChessBoard',
//             style: TextStyle(color: Colors.white),
//           ),
//           actions: [
//             IconButton(
//               onPressed: () {
//                 gameProvider.resetGame(newGame: true, context: context);
//               },
//               icon: const Icon(Icons.refresh, color: Colors.white),
//             ),
//             IconButton(
//               onPressed: () => gameProvider.flipTheBoard(),
//               icon: const Icon(Icons.rotate_left, color: Colors.white),
//             ),
//           ],
//         ),
//         body: Consumer<GameProvider>(
//           builder: (context, value, child) {
//             String whitesTimer = getTimerToDisplay(
//               gameProvider: gameProvider,
//               isUser: gameProvider.player == Squares.white,
//             );
//             String blacksTimer = getTimerToDisplay(
//               gameProvider: gameProvider,
//               isUser: gameProvider.player == Squares.black,
//             );
//             return Center(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 20),
//                   ListTile(
//                     leading: CircleAvatar(
//                       radius: 25,
//                       backgroundImage: gameProvider.vsComputer
//                           ? AssetImage(AssetsManager.user2Icon)
//                           : NetworkImage(gameProvider.opponentImage.isEmpty
//                               ? AssetsManager.user2Icon
//                               : gameProvider.opponentImage),
//                       backgroundColor: const Color(0xFF3A3A6A),
//                     ),
//                     title: Text(
//                       gameProvider.vsComputer ? 'Computer' : gameProvider.opponentName.isEmpty ? 'Opponent' : gameProvider.opponentName,
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                     subtitle: Text(
//                       'Rating: ${gameProvider.vsComputer ? 3000 : gameProvider.opponentRating}',
//                       style: const TextStyle(color: Colors.grey),
//                     ),
//                     trailing: Text(
//                       gameProvider.isHumanWhite ? blacksTimer : whitesTimer,
//                       style: const TextStyle(fontSize: 16, color: Colors.white),
//                     ),
//                     tileColor: const Color(0xFF3A3A6A),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.all(4.0),
//                     child: BoardController(
//                       state: gameProvider.flipBoard
//                           ? gameProvider.state.board.flipped()
//                           : gameProvider.state.board,
//                       playState: gameProvider.state.state,
//                       pieceSet: PieceSet.merida(),
//                       theme: blackWhiteTheme,
//                       moves: gameProvider.state.moves,
//                       onMove: _onMove,
//                       onPremove: _onMove,
//                       markerTheme: MarkerTheme(
//                         empty: MarkerTheme.dot,
//                         piece: MarkerTheme.corners(),
//                       ),
//                       promotionBehaviour: PromotionBehaviour.autoPremove,
//                     ),
//                   ),
//                   ListTile(
//                     leading: CircleAvatar(
//                       radius: 25,
//                       backgroundImage: NetworkImage(user?.image ?? AssetsManager.userIcon),
//                       backgroundColor: const Color(0xFF3A3A6A),
//                     ),
//                     title: Text(
//                       user?.username ?? 'You',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                     subtitle: Text(
//                       'Rating: ${user?.playerRating ?? 1200}',
//                       style: const TextStyle(color: Colors.grey),
//                     ),
//                     trailing: Text(
//                       gameProvider.isHumanWhite ? whitesTimer : blacksTimer,
//                       style: const TextStyle(fontSize: 16, color: Colors.white),
//                     ),
//                     tileColor: const Color(0xFF3A3A6A),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   Future<bool?> _showExitConfirmDialog(BuildContext context) {
//     return showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Leave Game?', textAlign: TextAlign.center),
//         content: const Text(
//           'Are you sure to leave this game?',
//           textAlign: TextAlign.center,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             child: const Text('Yes'),
//           ),
//         ],
//       ),
//     );
//   }
// }