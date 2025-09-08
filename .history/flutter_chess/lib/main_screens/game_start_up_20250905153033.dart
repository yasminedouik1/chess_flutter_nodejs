import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/main_screens/waiting_screen.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:provider/provider.dart';

class GameStartUpScreen extends StatefulWidget {
  const GameStartUpScreen({
    super.key,
    required this.isCustomTime,
    required this.gameTime,
  });
  final bool isCustomTime;
  final String gameTime;

  @override
  State<GameStartUpScreen> createState() => _GameStartUpScreenState();
}

class _GameStartUpScreenState extends State<GameStartUpScreen> {
  int whiteTimeInMinutes = 10;
  int blackTimeInMinutes = 10;
  bool isPrivate = false;
  int incrementalValue = 0;

  Widget _buildPlayerRow({
    required String title,
    required PlayerColor value,
    required int time,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required bool isSelected,
    required VoidCallback onSelect,
    required bool isCustom,
    required String fixedTime,
  }) {
    return Card(
      color: const Color(0xFF3A3A6A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            if (isCustom) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white),
                    onPressed: onMinus,
                  ),
                  Text(
                    '$time min',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: onPlus,
                  ),
                ],
              ),
            ] else ...[
              Text(
                fixedTime,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
            Radio<PlayerColor>(
              value: value,
              groupValue: context.watch<GameProvider>().playerColor,
              onChanged: (PlayerColor? newValue) {
                if (newValue != null) onSelect();
              },
              activeColor: const Color(0xFF26A69A),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGame(GameProvider gameProvider, AuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null || authProvider.token == null) {
      showSnackBar(context: context, content: 'Please log in to create a game');
      return;
    }

    setState(() => gameProvider.setIsLoading(value: true));

    try {
      int whiteTimeInSeconds;
      int blackTimeInSeconds;
      int increment;

      if (widget.isCustomTime) {
        if (whiteTimeInMinutes < 1 || blackTimeInMinutes < 1) {
          showSnackBar(context: context, content: 'Time must be at least 1 minute');
          return;
        }
        if (incrementalValue < 0) {
          showSnackBar(context: context, content: 'Increment cannot be negative');
          return;
        }
        whiteTimeInSeconds = whiteTimeInMinutes * 60;
        blackTimeInSeconds = blackTimeInMinutes * 60;
        increment = incrementalValue;
      } else {
        try {
          final timeStr = widget.gameTime.split(' ')[0];
          final timeInMinutes = int.parse(timeStr);
          if (timeInMinutes < 1) {
            throw Exception('Invalid game time');
          }
          whiteTimeInSeconds = timeInMinutes * 60;
          blackTimeInSeconds = timeInMinutes * 60;
          increment = 0;
        } catch (e) {
          showSnackBar(context: context, content: 'Invalid game time format');
          return;
        }
      }

      await gameProvider.createGame(
        user: user,
        whiteTime: whiteTimeInSeconds,
        blackTime: blackTimeInSeconds,
        increment: increment,
        isPrivate: isPrivate,
        context: context,
        onSuccess: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WaitingScreen()),
          );
        },
      );
    } catch (e) {
      showSnackBar(context: context, content: 'Error creating game: $e');
    } finally {
      setState(() => gameProvider.setIsLoading(value: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Setup'),
        backgroundColor: const Color(0xFF2A2A5A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPlayerRow(
              title: 'Play as White',
              value: PlayerColor.white,
              time: whiteTimeInMinutes,
              onMinus: () => setState(
                () => whiteTimeInMinutes = (whiteTimeInMinutes > 1 ? whiteTimeInMinutes - 1 : 1),
              ),
              onPlus: () => setState(() => whiteTimeInMinutes++),
              isSelected: gameProvider.playerColor == PlayerColor.white,
              onSelect: () => gameProvider.setPlayerColor(player: 0),
              isCustom: widget.isCustomTime,
              fixedTime: widget.gameTime,
            ),
            const SizedBox(height: 16),
            _buildPlayerRow(
              title: 'Play as Black',
              value: PlayerColor.black,
              time: blackTimeInMinutes,
              onMinus: () => setState(
                () => blackTimeInMinutes = (blackTimeInMinutes > 1 ? blackTimeInMinutes - 1 : 1),
              ),
              onPlus: () => setState(() => blackTimeInMinutes++),
              isSelected: gameProvider.playerColor == PlayerColor.black,
              onSelect: () => gameProvider.setPlayerColor(player: 1),
              isCustom: widget.isCustomTime,
              fixedTime: widget.gameTime,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Private Game',
                style: TextStyle(color: Colors.white),
              ),
              value: isPrivate,
              onChanged: (value) => setState(() => isPrivate = value),
              activeColor: const Color(0xFF26A69A),
            ),
            const SizedBox(height: 16),
            if (widget.isCustomTime)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Increment (s): ',
                    style: TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white),
                    onPressed: () => setState(() {
                      incrementalValue = incrementalValue > 0 ? incrementalValue - 1 : 0;
                    }),
                  ),
                  Text(
                    '$incrementalValue',
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => setState(() => incrementalValue++),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: gameProvider.isLoading
                  ? null
                  : () => _createGame(gameProvider, authProvider),
              child: gameProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Game'),
            ),
          ],
        ),
      ),
    );
  }
}