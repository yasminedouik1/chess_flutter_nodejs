import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:provider/provider.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      ApiService.initializeSocket(token);
      ApiService.joinGameRoom(gameProvider.gameId);
      ApiService.socket?.on('player_joined', (data) {
        final game = data;
        gameProvider.setOpponentData(
          opponentId: game['player2Id'] ?? '',
          opponentName: game['opponentName'] ?? 'Opponent',
          opponentImage: game['opponentImage'] ?? '',
          opponentRating: game['opponentRating'] ?? 1200,
          whiteTime: game['whiteTime'] ?? 600,
          blackTime: game['blackTime'] ?? 600,
          increment: game['increment'] ?? 0,
          gameId: game['gameId'],
        );
        gameProvider.isHumanWhite = true;
        if (context.mounted) {
          showSnackBar(
            context: context,
            content: 'Player ${game['opponentName'] ?? 'Opponent'} has joined the game!',
          );
          Navigator.pushReplacementNamed(context, Constants.gameScreen, arguments: {
            'gameId': gameProvider.gameId,
            'opponentName': game['opponentName'],
            'opponentRating': game['opponentRating'],
          });
        }
      });
      ApiService.socket?.on('game_updated', (data) {
        if (data['status'] == 'cancelled' && data['gameId'] == gameProvider.gameId && context.mounted) {
          gameProvider.cancelGame();
          Navigator.pushNamedAndRemoveUntil(context, Constants.homeScreen, (route) => false);
          showSnackBar(context: context, content: 'Game was cancelled');
        }
      });
      ApiService.socket?.on('error', (data) {
        if (context.mounted) {
          showSnackBar(context: context, content: data['message'] ?? 'Error in game');
        }
      });
    }
    gameProvider.startWaitingTimer(context: context);
    Future.delayed(const Duration(minutes: 10), () {
      if (context.mounted && gameProvider.gameId.isNotEmpty) {
        gameProvider.cancelGame();
        Navigator.pushNamedAndRemoveUntil(context, Constants.homeScreen, (route) => false);
        showSnackBar(context: context, content: 'No opponent joined. Game cancelled.');
      }
    });
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
      backgroundColor: const Color(0xFF1E1E3F),
      appBar: AppBar(
        title: const Text('Waiting for Opponent', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A2A5A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            await context.read<GameProvider>().cancelGame();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, Constants.homeScreen, (route) => false);
            }
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Waiting... (${gameProvider.waitingText})', style: const TextStyle(color: Colors.white)),
            if (gameProvider.isPrivate)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Share this code: ${gameProvider.joinCode}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: gameProvider.joinCode));
                        showSnackBar(context: context, content: 'Code copied to clipboard');
                      },
                      child: const Text('Copy Code', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              onPressed: () async {
                await context.read<GameProvider>().cancelGame();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, Constants.homeScreen, (route) => false);
                }
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_chess/constants.dart';
// import 'package:flutter_chess/providers/auth_provider.dart';
// import 'package:flutter_chess/providers/game_provider.dart';
// import 'package:flutter_chess/services/api_service.dart';

// class WaitingScreen extends StatefulWidget {
//   const WaitingScreen({super.key});

//   @override
//   State<WaitingScreen> createState() => _WaitingScreenState();
// }

// class _WaitingScreenState extends State<WaitingScreen> {
//   @override
//   void initState() {
//     super.initState();
//     final gameProvider = context.read<GameProvider>();
//     final token = context.read<AuthProvider>().token;
//     if (token != null) {
//       ApiService.initializeSocket(token);
//       ApiService.joinGameRoom(gameProvider.gameId);
//       ApiService.socket?.on('player_joined', (data) {
//         final game = data;
//         gameProvider.setOpponentData(
//           opponentId: game['player2Id'] ?? '',
//           opponentName: game['opponentName'] ?? 'Opponent',
//           opponentImage: game['opponentImage'] ?? '',
//           opponentRating: game['opponentRating'] ?? 1200,
//           whiteTime: game['whiteTime'] ?? 600,
//           blackTime: game['blackTime'] ?? 600,
//           increment: game['increment'] ?? 0,
//         );
//         gameProvider.isHumanWhite = true; // Creator is white
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'Player ${game['opponentName'] ?? 'Opponent'} has joined the game!',
//               ),
//               duration: const Duration(seconds: 2),
//             ),
//           );
//           Navigator.pushReplacementNamed(
//             context,
//             Constants.gameScreen,
//             arguments: {
//               'gameId': gameProvider.gameId,
//               'opponentName': game['opponentName'] ?? 'Opponent',
//               'opponentRating': game['opponentRating'] ?? 1200,
//             },
//           );
//         }
//       });
//       ApiService.socket?.on('error', (data) {
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(data['message'] ?? 'Error joining game')),
//           );
//         }
//       });
//     }
//     gameProvider.startWaitingTimer(context: context);
//   }

//   @override
//   void dispose() {
//     ApiService.disposeSocket();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final gameProvider = context.watch();
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Waiting for Opponent',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: const Color(0xFF2A2A5A),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const CircularProgressIndicator(),
//             const SizedBox(height: 20),
//             Text(
//               'Waiting... (${gameProvider.waitingText})',
//               style: const TextStyle(color: Colors.white),
//             ),
//             if (gameProvider.isPrivate)
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(
//                   'Share this code: ${gameProvider.joinCode}',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.redAccent,
//                 padding: const EdgeInsets.symmetric(
//                   vertical: 12,
//                   horizontal: 24,
//                 ),
//               ),
//               onPressed: () async {
//                 await gameProvider.cancelGame(context);
//                 if (context.mounted) {
//                   Navigator.pushNamedAndRemoveUntil(
//                     context,
//                     Constants.homeScreen,
//                     (route) => false,
//                   );
//                 }
//               },
//               child: const Text(
//                 'Cancel',
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
