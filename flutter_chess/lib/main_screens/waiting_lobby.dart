import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart'; // Removed as it did not resolve the issue
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../constants.dart';
// import 'package:flutter/services.dart'; // Potentially needed for PopInvokedResult if not in material.dart

class WaitingLobby extends StatefulWidget {
  const WaitingLobby({super.key}); // Use super.key

  @override
  State<WaitingLobby> createState() => _WaitingLobbyState();
}

class _WaitingLobbyState extends State<WaitingLobby> {
  // Timer? _pollingTimer; // Removed polling timer

  @override
  void initState() {
    super.initState();
    // Initialize socket listeners in GameProvider
    context.read<GameProvider>().initSocketListeners(context);
    context.read<GameProvider>().startWaitingTimer(context: context);
    // _startPolling(); // Removed polling call

    // Add listener for game status changes
    context.read<GameProvider>().addListener(_gameStatusListener);
  }

  void _gameStatusListener() {
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.isPlaying) {
      // If a player has joined, navigate to the game screen
      _navigateToGameScreen();
    }
  }

  void _navigateToGameScreen() {
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Constants.gameScreen,
        (route) => false,
      );
    }
  }

  // Removed _startPolling method
  // void _startPolling() {
  //   _pollingTimer?.cancel(); // Cancel any existing timer
  //   _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
  //     // Periodically check for opponent joined status
  //     await context.read<GameProvider>().checkOpponentJoined(context);
  //   });
  // }

  @override
  void dispose() {
    // _pollingTimer?.cancel(); // Cancel polling timer when leaving the lobby
    context.read<GameProvider>().removeListener(_gameStatusListener); // Remove the listener
    // Cancel the game when the widget is disposed
    final gameProvider = context.read<GameProvider>();
    gameProvider.waitingTimer?.cancel(); // Cancel the waiting timer
    if (gameProvider.gameId.isNotEmpty && !gameProvider.isPlaying && gameProvider.isManuallyCancelling) { // Only cancel if explicitly marked
      gameProvider.cancelGame(context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        // Handle the async operations in a non-blocking way if didPop is true
        if (didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final currentContext = context; // Capture context
            if (!currentContext.mounted) return;
            final gameProvider = currentContext.read<GameProvider>();
            gameProvider.setIsManuallyCancelling(true);
            await gameProvider.cancelGame(currentContext);
            if (currentContext.mounted) {
              Navigator.pushNamedAndRemoveUntil(currentContext, Constants.homeScreen, (route) => false);
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2A2A5A),
        body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Waiting for Opponent...',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (gameProvider.joinCode.isNotEmpty)
              Text(
                'Join Code: ${gameProvider.joinCode}',
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 10),
            Text(
              'Share this code with your friend to join the game',
              style: const TextStyle(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Consumer<GameProvider>(
              builder: (context, gameProvider, child) {
                return Text(
                  'Time left: ${gameProvider.waitingText} seconds',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                );
              },
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                gameProvider.setIsManuallyCancelling(true); // Set flag to true
                await gameProvider.cancelGame(context);
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Constants.homeScreen,
                    (route) => false,
                  );
                }
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}