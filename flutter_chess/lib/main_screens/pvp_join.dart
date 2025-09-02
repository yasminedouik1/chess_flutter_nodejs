import 'package:flutter/material.dart';
import 'package:flutter_chess/constants.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/services/api_service.dart';
import 'package:provider/provider.dart';

class PvPJoinScreen extends StatefulWidget {
  @override
  _PvPJoinScreenState createState() => _PvPJoinScreenState();
}

class _PvPJoinScreenState extends State<PvPJoinScreen> {
  List<dynamic> games = [];
  bool isLoading = false;

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
        final fetchedGames = await ApiService.getAvailableGames(token);
        setState(() {
          games = fetchedGames;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please log in to view games')));
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => isLoading = false);
    }
  }

  //   Future<void> _joinGame(String gameId) async {
  //   try {
  //     final token = context.read<AuthProvider>().token;
  //     if (token != null) {
  //       final game = await ApiService.joinGame(gameId: gameId, token: token);
  //       Navigator.pushNamed(
  //         context,
  //        Constants.gameScreen,
  //         arguments: {
  //           'gameId': gameId,
  //           'opponentName': game['creatorName'], // Creator is opponent for joiner
  //           'opponentRating': game['creatorRating'],

  //         },
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Please log in to join a game')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error joining game: $e')),
  //     );
  //   }
  // }

  Future<void> _joinGame(String gameId) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        final game = await ApiService.joinGame(gameId: gameId, token: token);
        // Initialize socket for P2
        ApiService.initializeSocket(token);
        ApiService.joinGameRoom(gameId);
        // Set opponent data for P2 (creator is opponent)
        final gameProvider = context.read<GameProvider>();
        gameProvider.setOpponentData(
          opponentId: game['creatorId'],
          opponentName: game['creatorName'] ?? 'Opponent',
          opponentImage: game['creatorImage'] ?? '',
          opponentRating: game['creatorRating'] ?? 1200,
          whiteTime: game['whiteTime'],
          blackTime: game['blackTime'],
          increment: game['increment'],
        );
        gameProvider.isHumanWhite = false; // Joiner is black
        // gameProvider._gameId = gameId;
        // gameProvider._isPlaying = true;

        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have joined the game against ${game['creatorName']}!'),
          duration: Duration(seconds: 2),
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
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please log in to join a game')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error joining game: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join a Game'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchGames,
            tooltip: 'Refresh Games',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : games.isEmpty
          ? Center(child: Text('No available games'))
          : ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return ListTile(
                  title: Text('Game by ${game['creatorName']}'),
                  subtitle: Text(
                    'Rating: ${game['creatorRating']} | Time: ${game['whiteTime']}s + ${game['increment']}s',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _joinGame(game['gameId']),
                    child: Text('Join'),
                  ),
                );
              },
            ),
    );
  }
}
