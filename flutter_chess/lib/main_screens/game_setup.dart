import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess/app_routes.dart'; // Changed from constants.dart
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/constants/app_constants.dart'; // Added for PlayerColor

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
    final customTimeController = useTextEditingController(text: '10');

    // Provider access
    final gameProvider = context.watch<GameProvider>();

    // Game time options
    final gameTimes = [
      'Bullet 1 min',
      'Bullet 2 min',
      'Bullet 3 min',
      'Bullet 5 min',
      'Classical 10 min',
      'Classical 30 min',
      Constants.custom, // Use from app_routes
    ];

    // Handle time selection
    void handleTimeSelection(String gameTime, String label) {
      isCustomTime.value = label == Constants.custom;
      selectedTime.value = gameTime.isNotEmpty ? gameTime : '10 min';
      
      if (!isCustomTime.value) {
        final time = int.parse(gameTime.split(' ')[0]);
        whiteTimeInMinutes.value = time;
        blackTimeInMinutes.value = time;
        customTimeController.text = time.toString();
      }
    }

    // Handle game creation
    Future<void> handleGameCreation() async {
      if (selectedTime.value.isEmpty || 
          (isCustomTime.value && whiteTimeInMinutes.value <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a game time or enter a custom time.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
                      color: isCustomTime.value && label == Constants.custom
                          ? const Color.fromARGB(255, 7, 152, 137) // A distinct color for custom selected
                          : selectedTime.value == time
                              ? const Color(0xFF26A69A) // Existing selected color
                              : label == Constants.custom
                                  ?  const Color.fromARGB(255, 66, 143, 135) // Distinct color for unselected custom
                                  : const Color(0xFF3A3A6A), // Default color
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
              const SizedBox(height: 30), // Increased spacing
              Card(
                color: const Color(0xFF3A3A6A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Game Time',
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
                                blackTimeInMinutes.value = whiteTimeInMinutes.value;
                                customTimeController.text = whiteTimeInMinutes.value.toString();
                              }
                            },
                          ),
                          SizedBox(
                            width: 80, // Adjust width as needed
                            child: TextField(
                              controller: customTimeController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: InputDecoration(
                                suffixText: ' min',
                                suffixStyle: const TextStyle(color: Colors.white, fontSize: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                final newTime = int.tryParse(value);
                                if (newTime != null && newTime > 0) {
                                  whiteTimeInMinutes.value = newTime;
                                  blackTimeInMinutes.value = newTime;
                                } else if (value.isEmpty) {
                                  whiteTimeInMinutes.value = 0;
                                  blackTimeInMinutes.value = 0;
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => {
                              whiteTimeInMinutes.value++,
                              blackTimeInMinutes.value = whiteTimeInMinutes.value,
                              customTimeController.text = whiteTimeInMinutes.value.toString(),
                            },
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
              const SizedBox(height: 20), // Adjusted spacing
              SwitchListTile(
                title: const Text('Private Game', style: TextStyle(color: Colors.white)),
                value: isPrivate.value,
                onChanged: (value) => isPrivate.value = value,
                activeColor: const Color(0xFF26A69A),
              ),
            ],

            const SizedBox(height: 30), // Increased spacing
// Inside GameSetupScreen's Column, before the Create/Start Game button
if (gameProvider.vsComputer) ...[
  const SizedBox(height: 30), // Increased spacing
  Card(
    color: const Color(0xFF3A3A6A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'AI Difficulty',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Column(
            children: [
              RadioListTile<int>(
                title: const Text('Easy', style: TextStyle(color: Colors.white, fontSize: 16)),
                value: 1,
                groupValue: gameProvider.gameLevel,
                onChanged: (value) {
                  if (value != null) {
                    gameProvider.setGameDifficulty(level: value);
                  }
                },
                activeColor: const Color(0xFF26A69A),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<int>(
                title: const Text('Medium', style: TextStyle(color: Colors.white, fontSize: 16)),
                value: 2,
                groupValue: gameProvider.gameLevel,
                onChanged: (value) {
                  if (value != null) {
                    gameProvider.setGameDifficulty(level: value);
                  }
                },
                activeColor: const Color(0xFF26A69A),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<int>(
                title: const Text('Hard', style: TextStyle(color: Colors.white, fontSize: 16)),
                value: 3,
                groupValue: gameProvider.gameLevel,
                onChanged: (value) {
                  if (value != null) {
                    gameProvider.setGameDifficulty(level: value);
                  }
                },
                activeColor: const Color(0xFF26A69A),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    ),
  ),
],
            // Create/Start Game button
            SizedBox(
              width: double.infinity, // Make button full width
              height: 50, // Set a fixed height
              child: ElevatedButton(
                onPressed: gameProvider.isLoading ? null : handleGameCreation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A), // Greenish color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12), // Vertical padding
                ),
                child: gameProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        gameProvider.vsComputer ? 'Start Game' : 'Create Game',
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}