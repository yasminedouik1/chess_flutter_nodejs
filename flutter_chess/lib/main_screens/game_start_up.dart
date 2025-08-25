import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPlayerRow(
                  title: 'Play as White',
                  value: PlayerColor.white,
                  time: whiteTimeInMinutes,
                  onMinus: () => setState(() => whiteTimeInMinutes = (whiteTimeInMinutes > 1 ? whiteTimeInMinutes - 1 : 1)),
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
                  onMinus: () => setState(() => blackTimeInMinutes = (blackTimeInMinutes > 1 ? blackTimeInMinutes - 1 : 1)),
                  onPlus: () => setState(() => blackTimeInMinutes++),
                  isSelected: gameProvider.playerColor == PlayerColor.black,
                  onSelect: () => gameProvider.setPlayerColor(player: 1),
                  isCustom: widget.isCustomTime,
                  fixedTime: widget.gameTime,
                ),
                const SizedBox(height: 24),
                if (gameProvider.vsComputer) ...[
                  const Text(
                    'Game Difficulty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildDifficultyButton(
                        title: 'Easy',
                        value: GameDifficulty.easy,
                        selected: gameProvider.gameDifficulty == GameDifficulty.easy,
                        onTap: () => gameProvider.setGameDifficulty(level: 1),
                      ),
                      _buildDifficultyButton(
                        title: 'Medium',
                        value: GameDifficulty.medium,
                        selected: gameProvider.gameDifficulty == GameDifficulty.medium,
                        onTap: () => gameProvider.setGameDifficulty(level: 2),
                      ),
                      _buildDifficultyButton(
                        title: 'Hard',
                        value: GameDifficulty.hard,
                        selected: gameProvider.gameDifficulty == GameDifficulty.hard,
                        onTap: () => gameProvider.setGameDifficulty(level: 3),
                      ),
                    ],
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      gameProvider.waitingText,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: gameProvider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF26A69A)))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFF26A69A),
                            elevation: 4,
                          ),
                          onPressed: () => playGame(gameProvider: gameProvider),
                          child: const Text(
                            'Play',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
      color: const Color(0xFF2E2E50),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.white : Colors.transparent, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: PlayerColorRadioButton(
                title: title,
                value: value,
                groupValue: isSelected ? value : null,
                onChanged: (_) => onSelect(),
              ),
            ),
            isCustom
                ? BuildCustomTime(
                    time: time.toString(),
                    onLeftArrowClicked: onMinus,
                    onRightArrowClicked: onPlus,
                  )
                : Container(
                    height: 40,
                    width: 80,
                    decoration: BoxDecoration(
                      border: Border.all(width: 0.5, color: Colors.white54),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black26,
                    ),
                    child: Center(
                      child: Text(
                        fixedTime,
                        style: const TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton({
    required String title,
    required GameDifficulty value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: selected ? const Color(0xFF26A69A) : const Color(0xFF3A3A6A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? Colors.white : Colors.white30, width: 1),
        ),
      ),
    );
  }

  void playGame({required GameProvider gameProvider}) async {
    if (widget.isCustomTime) {
      if (whiteTimeInMinutes <= 0 || blackTimeInMinutes <= 0) {
        showSnackBar(context: context, content: 'Time must be greater than 0');
        return;
      }
      gameProvider.setIsLoading(value: true);
      await gameProvider.setGameTime(
        newSavedWhitesTime: whiteTimeInMinutes.toString(),
        newSavedBlacksTime: blackTimeInMinutes.toString(),
      );
      if (gameProvider.vsComputer) {
        gameProvider.setIsLoading(value: false);
        Navigator.pushNamed(context, Constants.gameScreen);
      } else {
        final user = context.read<AuthProvider>().user;
        if (user == null) {
          showSnackBar(context: context, content: 'Please log in to play online');
          gameProvider.setIsLoading(value: false);
          return;
        }
        await gameProvider.searchGame(
          user: user,
          onSuccess: () {
            gameProvider.setIsLoading(value: false);
          },
          onFail: (error) {
            gameProvider.setIsLoading(value: false);
            showSnackBar(context: context, content: error);
          }, context: context,
        );
      }
    } else {
      try {
        final parts = widget.gameTime.split('+');
        if (parts.length != 2) {
          throw const FormatException('Invalid game time format');
        }
        final String gameTime = parts[0];
        final String incrementalTime = parts[1];
        int gameTimeInt = int.parse(gameTime);
        int incrementalTimeInt = int.parse(incrementalTime);
        if (gameTimeInt <= 0) {
          throw const FormatException('Game time must be greater than 0');
        }
        if (incrementalTimeInt < 0) {
          throw const FormatException('Incremental time cannot be negative');
        }
        gameProvider.setIncrementalValue(value: incrementalTimeInt);
        gameProvider.setIsLoading(value: true);
        await gameProvider.setGameTime(
          newSavedWhitesTime: gameTime,
          newSavedBlacksTime: gameTime,
        );
        if (gameProvider.vsComputer) {
          gameProvider.setIsLoading(value: false);
          Navigator.pushNamed(context, Constants.gameScreen);
        } else {
          final user = context.read<AuthProvider>().user;
          if (user == null) {
            showSnackBar(context: context, content: 'Please log in to play online');
            gameProvider.setIsLoading(value: false);
            return;
          }
          await gameProvider.searchGame(
            user: user,
            onSuccess: () {
              gameProvider.setIsLoading(value: false);
            },
            onFail: (error) {
              gameProvider.setIsLoading(value: false);
              showSnackBar(context: context, content: error);
            }, context: context,
          );
        }
      } catch (e) {
        showSnackBar(context: context, content: 'Invalid game time format');
      }
    }
  }
}