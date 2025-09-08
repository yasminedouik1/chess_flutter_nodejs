import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:flutter_chess/widgets/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class JoinRoomScreen extends StatefulWidget {
  static const String routeName = '/joinRoomScreen';
  const JoinRoomScreen({super.key});

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  List<dynamic> games = [];
  bool isLoading = false;
final TextEditingController _idController = TextEditingController();
  @override
  void initState() {
    super.initState();
    context.read<GameProvider>().initSocketListeners(context);
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    setState(() => isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        final fetchedGames = await ApiService.getAvailableGames(token);
        setState(() {
          games = fetchedGames;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view games')),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || !RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to join a game')),
        );
        return;
      }
      final game = await ApiService.joinGameByCode(joinCode: code, token: token);
      final gameProvider = context.read<GameProvider>();
      gameProvider.setOpponentData(
        opponentId: game['creatorId'],
        opponentName: game['creatorName'] ?? 'Opponent',
        opponentImage: game['creatorImage'] ?? '',
        opponentRating: game['creatorRating'] ?? 1200,
        whiteTime: game['whiteTime'],
        blackTime: game['blackTime'],
        increment: game['increment'],
        gameId: game['gameId'],
      );
      gameProvider.isHumanWhite = false; // Joiner is black
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have joined the game against ${game['creatorName']}!'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pushNamed(
        context,
        Constants.gameScreen,
        arguments: {
          'gameId': game['gameId'],
          'opponentName': game['creatorName'],
          'opponentRating': game['creatorRating'],
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining game: $e')),
      );
    }
  }

  Future<void> _joinGame(String gameId) async {
    try {
      final token = context.read<AuthProvider>().token;
      final userId = context.read<AuthProvider>().user?.uid;
      if (token == null || userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to join a game')),
        );
        return;
      }
      final game = await ApiService.joinGame(gameId: gameId, token: token);
      final gameProvider = context.read<GameProvider>();
      gameProvider.setOpponentData(
        opponentId: game['creatorId'],
        opponentName: game['creatorName'] ?? 'Opponent',
        opponentImage: game['creatorImage'] ?? '',
        opponentRating: game['creatorRating'] ?? 1200,
        whiteTime: game['whiteTime'],
        blackTime: game['blackTime'],
        increment: game['increment'],
        gameId: gameId,
      );
      gameProvider.isHumanWhite = false; // Joiner is black
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have joined the game against ${game['creatorName']}!'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pushNamed(
        context,
        Constants.gameScreen,
        arguments: {
          'gameId': gameId,
          'opponentName': game['creatorName'],
          'opponentRating': game['creatorRating'],
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining game: $e')),
      );
    }
  }
void joinRoom(BuildContext context, String id) async {
    try {
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/games/join-by-code'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'joinCode': id}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final gameId = data['gameId'];
        ApiService.joinGameRoom(gameId);
        context.read<GameProvider>().gameId = gameId;
        Navigator.pushNamed(context, Constants.gameScreen);
      } else {
        showSnackBar(context: context, content: data['message'] ?? 'Failed to join game');
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Game', style: TextStyle(color: Colors.white)),
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
                  onPressed: _joinByCode,
                  child: const Text(
                    'Join',
                    style: TextStyle(color: Colors.white),
                  ),
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
                              'Game by ${game['creatorName']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Rating: ${game['creatorRating']} | Time: ${game['whiteTime']}s + ${game['increment']}s',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                              ),
                              onPressed: () => _joinGame(game['gameId']),
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