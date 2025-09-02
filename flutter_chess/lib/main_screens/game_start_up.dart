import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess/main_screens/waiting_screen.dart';

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
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDifficultyButton(
                        label: 'Easy',
                        level: 1,
                        isSelected: gameProvider.gameLevel == 1,
                        onTap: () => gameProvider.setGameDifficulty(level: 1),
                      ),
                      _buildDifficultyButton(
                        label: 'Medium',
                        level: 2,
                        isSelected: gameProvider.gameLevel == 2,
                        onTap: () => gameProvider.setGameDifficulty(level: 2),
                      ),
                      _buildDifficultyButton(
                        label: 'Hard',
                        level: 3,
                        isSelected: gameProvider.gameLevel == 3,
                        onTap: () => gameProvider.setGameDifficulty(level: 3),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                gameProvider.isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () => playGame(gameProvider: gameProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Play',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A6A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Radio<PlayerColor>(
                value: value,
                groupValue: Provider.of<GameProvider>(context).playerColor,
                onChanged: (PlayerColor? newValue) => onSelect(),
                activeColor: const Color(0xFF26A69A),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          if (isCustom) Row(
            children: [
              IconButton(
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              ),
              Text(
                '$time min',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              IconButton(
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              ),
            ],
          ) else Text(
            fixedTime,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyButton({
    required String label,
    required int level,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26A69A) : const Color(0xFF3A3A6A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white),
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
        await gameProvider.createGame(
          user: user,
          whiteTime: whiteTimeInMinutes * 60,
          blackTime: blackTimeInMinutes * 60,
          increment: gameProvider.incrementalValue,
          context: context,
          onSuccess: () {
            gameProvider.setIsLoading(value: false);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const WaitingScreen()));
            gameProvider.startWaitingTimer(context: context);
          },
          onFail: (error) {
            gameProvider.setIsLoading(value: false);
            showSnackBar(context: context, content: error);
          },
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
          await gameProvider.createGame(
            user: user,
            whiteTime: gameTimeInt * 60,
            blackTime: gameTimeInt * 60,
            increment: incrementalTimeInt,
            context: context,
            onSuccess: () {
              gameProvider.setIsLoading(value: false);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WaitingScreen()));
              gameProvider.startWaitingTimer(context: context);
            },
            onFail: (error) {
              gameProvider.setIsLoading(value: false);
              showSnackBar(context: context, content: error);
            },
          );
        }
      } catch (e) {
        showSnackBar(context: context, content: 'Invalid game time format');
      }
    }
  }
}