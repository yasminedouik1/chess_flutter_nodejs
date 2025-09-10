import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:provider/provider.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  int whiteTimeInMinutes = 10;
  int blackTimeInMinutes = 10;
  bool isPrivate = false;
  bool isCustomTime = false;
  String selectedTime = '10 min';

  final List<String> gameTimes = [
    'Bullet 1+0',
    'Bullet 2+0',
    'Bullet 3+0',
    'Bullet 5+0',
    'Classical 10+0',
    'Classical 30+0',
    'Custom',
  ];

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    Provider.of<AuthProvider>(context);

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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: List.generate(gameTimes.length, (index) {
                final String label = gameTimes[index].split(' ')[0];
                final String gameTime = gameTimes[index].split(' ')[1];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isCustomTime = label == Constants.custom;
                      selectedTime = gameTime.isNotEmpty ? gameTime : '10 min';
                      if (!isCustomTime) {
                        final time = int.parse(gameTime.split('+')[0]);
                        whiteTimeInMinutes = time;
                        blackTimeInMinutes = time;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 150,
                    height: 90,
                    decoration: BoxDecoration(
                      color: selectedTime == gameTime || (isCustomTime && label == Constants.custom)
                          ? const Color(0xFF26A69A)
                          : const Color(0xFF3A3A6A),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
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
                        if (gameTime.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            gameTime,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
            if (isCustomTime) ...[
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
                            onPressed: () => setState(() => whiteTimeInMinutes = whiteTimeInMinutes > 1 ? whiteTimeInMinutes - 1 : 1),
                          ),
                          Text('$whiteTimeInMinutes min', style: const TextStyle(color: Colors.white, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => setState(() => whiteTimeInMinutes++),
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
                            onPressed: () => setState(() => blackTimeInMinutes = blackTimeInMinutes > 1 ? blackTimeInMinutes - 1 : 1),
                          ),
                          Text('$blackTimeInMinutes min', style: const TextStyle(color: Colors.white, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => setState(() => blackTimeInMinutes++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Private Game', style: TextStyle(color: Colors.white)),
              value: isPrivate,
              onChanged: (value) => setState(() => isPrivate = value),
              activeColor: const Color(0xFF26A69A),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: gameProvider.isLoading
                  ? null
                  : () => gameProvider.createGame(
                        context: context,
                        whiteTime: whiteTimeInMinutes,
                        blackTime: blackTimeInMinutes,
                        isPrivate: isPrivate,
                        playerColor: PlayerColor.white, // Default to white; add UI for choice if needed
                      ),
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