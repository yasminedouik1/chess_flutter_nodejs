import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/widgets.dart';
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
        showSnackBar(context: context, content: 'Please log in to view games');
        setState(() => isLoading = false);
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error fetching games: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || !RegExp(r'^\d{6}$').hasMatch(code)) {
      showSnackBar(context: context, content: 'Please enter a valid 6-digit code');
      return;
    }
    setState(() => isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        showSnackBar(context: context, content: 'Please log in to join a game');
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
      );
      if (context.mounted) {
        Navigator.pushReplacementNamed(
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
      showSnackBar(context: context, content: 'Error joining game: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinByGameId(String gameId) async {
    setState(() => isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        showSnackBar(context: context, content: 'Please log in to join a game');
        setState(() => isLoading = false);
        return;
      }
      final game = await retry(
        () => ApiService.joinGameById(gameId: gameId, token: token),
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
      );
      if (context.mounted) {
        Navigator.pushReplacementNamed(
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
      showSnackBar(context: context, content: 'Error joining game: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text('Join Game', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Enter 6-digit code',
                      hintStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: const OutlineInputBorder(
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
            const SizedBox(height: 16),
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
                                onPressed: isLoading ? null : () => _joinByGameId(game['gameId']),
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
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}