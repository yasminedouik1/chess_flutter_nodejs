import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/main_screens/waiting_screen.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
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
    if (user == null || !authProvider.isLoggedIn) {
      showSnackBar(context: context, content: 'Please log in to create a game');
      return;
    }
    setState(() => gameProvider.setLoading(true));
    try {
      final time = widget.isCustomTime ? whiteTimeInMinutes : int.parse(widget.gameTime.split(' ')[0]);
      final response = await ApiService.createGame(
        token: authProvider.token!,
        whiteTime: time * 60, // Convert to seconds
        blackTime: time * 60,
        increment: incrementalValue,
        isPrivate: isPrivate,
      );
      gameProvider.setGameData(
        gameId: response['gameId'],
        joinCode: response['joinCode'] ?? '',
        isPrivate: response['isPrivate'] ?? false,
        whiteTime: time * 60,
        blackTime: time * 60,
        increment: incrementalValue,
      );
      gameProvider.setPlayerColor(player: 0); // Creator is white
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingScreen(
              gameId: response['gameId'],
              joinCode: response['joinCode'] ?? '',
              isPrivate: response['isPrivate'] ?? false,
            ),
          ),
        );
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error creating game: $e');
    } finally {
      setState(() => gameProvider.setLoading(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final authProvider = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text(
          'Game Setup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A),
                ),
                onPressed: gameProvider.isLoading
                    ? null
                    : () => _createGame(gameProvider, authProvider),
                child: gameProvider.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Game', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}