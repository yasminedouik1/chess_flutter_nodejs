import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:provider/provider.dart';

class AvailableGamesScreen extends StatefulWidget {
  const AvailableGamesScreen({super.key});

  @override
  State<AvailableGamesScreen> createState() => _AvailableGamesScreenState();
}

class _AvailableGamesScreenState extends State<AvailableGamesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GameProvider>().fetchAvailableGames(context);
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final games = gameProvider.availableGames;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text('Available Games', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: games.isEmpty
          ? const Center(child: Text('No games available', style: TextStyle(color: Colors.white)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Card(
                  color: const Color(0xFF3A3A6A),
                  child: ListTile(
                    title: Text(
                      '${game['creatorName']} (${game['creatorRating']})',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Time: ${game['whiteTime'] ~/ 60} min',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => gameProvider.joinGame(
                        context,
                        game['gameId'],
                        context.read<AuthProvider>().userId!,
                      ),
                      child: const Text('Join'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}