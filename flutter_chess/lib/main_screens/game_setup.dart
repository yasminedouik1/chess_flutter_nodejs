import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/game_provider.dart';

class GameSetupScreen extends HookWidget {
  const GameSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Hooks for local state management
    final whiteTimeInMinutes = useState(10);
    final blackTimeInMinutes = useState(10);
    final isPrivate = useState(false);
    final isCustomTime = useState(false);
    final selectedTime = useState('10 min');

    // Provider access
    final gameProvider = context.watch<GameProvider>();

    // Game time options
    final gameTimes = [
      'Bullet 1+0',
      'Bullet 2+0',
      'Bullet 3+0',
      'Bullet 5+0',
      'Classical 10+0',
      'Classical 30+0',
      'Custom',
    ];

    // Handle time selection
    void handleTimeSelection(String gameTime, String label) {
      isCustomTime.value = label == Constants.custom;
      selectedTime.value = gameTime.isNotEmpty ? gameTime : '10 min';
      
      if (!isCustomTime.value) {
        final time = int.parse(gameTime.split('+')[0]);
        whiteTimeInMinutes.value = time;
        blackTimeInMinutes.value = time;
      }
    }

    // Handle game creation
    Future<void> handleGameCreation() async {
      if (gameProvider.vsComputer) {
        // Create computer game
        await gameProvider.createComputerGame(
          context: context,
          whiteTime: whiteTimeInMinutes.value,
          blackTime: blackTimeInMinutes.value,
          playerColor: PlayerColor.white,
        );
      } else {
        // Create multiplayer game
        await gameProvider.createGame(
          context: context,
          whiteTime: whiteTimeInMinutes.value,
          blackTime: blackTimeInMinutes.value,
          isPrivate: isPrivate.value,
          playerColor: PlayerColor.white,
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text('Setup Game', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Time selection grid
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: gameTimes.map((gameTime) {
                final parts = gameTime.split(' ');
                final label = parts[0];
                final time = parts.length > 1 ? parts[1] : '';
                
                return GestureDetector(
                  onTap: () => handleTimeSelection(time, label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 150,
                    height: 90,
                    decoration: BoxDecoration(
                      color: selectedTime.value == time || 
                             (isCustomTime.value && label == Constants.custom)
                          ? const Color(0xFF26A69A)
                          : const Color(0xFF3A3A6A),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            time,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // Custom time controls
            if (isCustomTime.value) ...[
              const SizedBox(height: 20),
              Card(
                color: const Color(0xFF3A3A6A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'White Time',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () {
                              if (whiteTimeInMinutes.value > 1) {
                                whiteTimeInMinutes.value--;
                              }
                            },
                          ),
                          Text(
                            '${whiteTimeInMinutes.value} min', 
                            style: const TextStyle(color: Colors.white, fontSize: 16)
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => whiteTimeInMinutes.value++,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Black Time',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () {
                              if (blackTimeInMinutes.value > 1) {
                                blackTimeInMinutes.value--;
                              }
                            },
                          ),
                          Text(
                            '${blackTimeInMinutes.value} min', 
                            style: const TextStyle(color: Colors.white, fontSize: 16)
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => blackTimeInMinutes.value++,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Private game toggle (only for multiplayer)
            if (!gameProvider.vsComputer) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Private Game', style: TextStyle(color: Colors.white)),
                value: isPrivate.value,
                onChanged: (value) => isPrivate.value = value,
                activeColor: const Color(0xFF26A69A),
              ),
            ],

            const SizedBox(height: 20),

            // Create/Start Game button
            ElevatedButton(
              onPressed: gameProvider.isLoading ? null : handleGameCreation,
              child: gameProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(gameProvider.vsComputer ? 'Start Game' : 'Create Game'),
            ),
          ],
        ),
      ),
    );
  }
}