import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/main_screens/waiting_lobby.dart';
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
    if (user == null) {
      showSnackBar(context: context, content: 'Please log in to create a game');
      return;
    }

    setState(() => gameProvider.setIsLoading(value: true));

    try {
      if (widget.isCustomTime) {
        await gameProvider.createGame(
          whiteTime: whiteTimeInMinutes * 60,
          blackTime: blackTimeInMinutes * 60,
          isPrivate: isPrivate,
          context: context,
          onSuccess: () {
            setState(() => gameProvider.setIsLoading(value: false));
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WaitingLobby(gameId: '',)),
            );
            gameProvider.startWaitingTimer(context: context);
          },
          onFail: (error) {
            setState(() => gameProvider.setIsLoading(value: false));
            showSnackBar(context: context, content: error);
          }, playerColor: PlayerColor.white,
        );
      } else {
        final parts = widget.gameTime.split('+');
        if (parts.length != 2) {
          throw const FormatException('Invalid game time format');
        }
        final String gameTime = parts[0];
        final String incrementalTime = parts[1];
        final int gameTimeInt = int.parse(gameTime);
        final int incrementalTimeInt = int.parse(incrementalTime);
        if (gameTimeInt <= 0) {
          throw const FormatException('Game time must be greater than 0');
        }
        if (incrementalTimeInt < 0) {
          throw const FormatException('Incremental time cannot be negative');
        }
        await gameProvider.setGameTime(
          newSavedWhitesTime: gameTime,
          newSavedBlacksTime: gameTime,
        );
        gameProvider.setIncrementalValue(value: incrementalTimeInt);
        if (gameProvider.vsComputer) {
          setState(() => gameProvider.setIsLoading(value: false));
          Navigator.pushNamed(context, Constants.gameScreen);
        } else {
          await gameProvider.createGame(
            whiteTime: gameTimeInt * 60,
            blackTime: gameTimeInt * 60,
            isPrivate: isPrivate,
            context: context, playerColor: PlayerColor.white,
          );
        }
      }
    } catch (e) {
      setState(() => gameProvider.setIsLoading(value: false));
      showSnackBar(context: context, content: 'Error creating game: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text(
          'Setup Game',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 3,
        shadowColor: Colors.black54,
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          final authProvider = context.read<AuthProvider>();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPlayerRow(
                  title: 'Play as White',
                  value: PlayerColor.white,
                  time: whiteTimeInMinutes,
                  onMinus: () => setState(
                    () => whiteTimeInMinutes = (whiteTimeInMinutes > 1
                        ? whiteTimeInMinutes - 1
                        : 1),
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
                    () => blackTimeInMinutes = (blackTimeInMinutes > 1
                        ? blackTimeInMinutes - 1
                        : 1),
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
          );
        },
      ),
    );
  }
}