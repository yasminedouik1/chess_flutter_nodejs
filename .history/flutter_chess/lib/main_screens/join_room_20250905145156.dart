import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/helper/helper_methods.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:retry/retry.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  List<dynamic> games = [];
  bool isLoading = false;
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    setState(() => isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        final fetchedGames = await retry(
          () => ApiService.getAvailableGames(token),
          maxAttempts: 3,
        );
        setState(() {
          games = fetchedGames;
          isLoading = false;
        });
      } else {
        showSnackBar(context: context, content: 'Please log in to view games',duration: const Duration(seconds: 2));
        setState(() => isLoading = false);
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error fetching games: $e',duration: const Duration(seconds: 2));
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || !RegExp(r'^\d{6}$').hasMatch(code)) {
      showSnackBar(context: context, content: 'Please enter a valid 6-digit code',duration: const Duration(seconds: 2));
      return;
    }
    setState(() => isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        showSnackBar(context: context, content: 'Please log in to join a game',duration: const Duration(seconds: 2));
        setState(() => isLoading = false);
        return;
      }
      final game = await retry(
        () => ApiService.joinGameByCode(joinCode: code, token: token),
        maxAttempts: 3,
      );
      final gameProvider = context.read<GameProvider>();
      gameProvider.setOpponentData(
        opponentId: game['creatorId'] ?? '',
        opponentName: game['creatorName'] ?? 'Opponent',
        opponentImage: game['creatorImage'] ?? '',
        opponentRating: game['creatorRating'] ?? 1200,
        whiteTime: game['whiteTime'] ?? 600,
        blackTime: game['blackTime'] ?? 600,
        increment: game['increment'] ?? 0,
        gameId: game['gameId'],
      );
      gameProvider.setPlayerColor(player: 1); // Joiner is black
      showSnackBar(
        context: context,
        content: 'Joined game against ${game['creatorName'] ?? 'Opponent'}!',
        duration: const Duration(seconds: 2),
      );
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          Constants.gameScreen,
          arguments: {
            'gameId': game['gameId'],
            'opponentName': game['creatorName'] ?? 'Opponent',
            'opponentRating': game['creatorRating'] ?? 1200,
          },
        );
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error joining game: $e',duration: const Duration(seconds: 2));
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinGame(String gameId) async {
    setState(() => isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        showSnackBar(context: context, content: 'Please log in to join a game',duration: const Duration(seconds: 2));
        setState(() => isLoading = false);
        return;
      }
      final game = await retry(
        () => ApiService.joinGame(gameId: gameId, token: token),
        maxAttempts: 3,
      );
      final gameProvider = context.read<GameProvider>();
      gameProvider.setOpponentData(
        opponentId: game['creatorId'] ?? '',
        opponentName: game['creatorName'] ?? 'Opponent',
        opponentImage: game['creatorImage'] ?? '',
        opponentRating: game['creatorRating'] ?? 1200,
        whiteTime: game['whiteTime'] ?? 600,
        blackTime: game['blackTime'] ?? 600,
        increment: game['increment'] ?? 0,
        gameId: gameId,
      );
      gameProvider.setPlayerColor(player: 1); // Joiner is black
      showSnackBar(
        context: context,
        content: 'Joined game against ${game['creatorName'] ?? 'Opponent'}!',
        duration: const Duration(seconds: 2),
      );
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          Constants.gameScreen,
          arguments: {
            'gameId': gameId,
            'opponentName': game['creatorName'] ?? 'Opponent',
            'opponentRating': game['creatorRating'] ?? 1200,
          },
        );
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error joining game: $e',duration: const Duration(seconds: 2),);
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Join Game',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2A2A5A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchGames,
            tooltip: 'Refresh Games',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Game Code',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF26A69A)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26A69A),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: isLoading ? null : _joinByCode,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Join', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : games.isEmpty
                    ? const Center(
                        child: Text(
                          'No available public games',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        itemCount: games.length,
                        itemBuilder: (context, index) {
                          final game = games[index];
                          return ListTile(
                            title: Text(
                              'Game by ${game['creatorName'] ?? 'Unknown'}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Rating: ${game['creatorRating'] ?? 1200} | Time: ${game['whiteTime'] ~/ 60}m + ${game['increment']}s',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                              ),
                              onPressed: isLoading ? null : () => _joinGame(game['gameId']),
                              child: const Text(
                                'Join',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}