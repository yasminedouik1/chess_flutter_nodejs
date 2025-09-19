import 'package:flutter/material.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:provider/provider.dart';
// import 'package:bishop/bishop.dart' as bishop;
import '../app_routes.dart'; // Changed from constants.dart
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class JoinRoomScreen extends StatefulWidget {
  static const String routeName = '/joinRoomScreen';
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _idController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize socket listeners in GameProvider
    final authProvider = context.read<AuthProvider>();
    context.read<GameProvider>().initSocketListeners(authProvider.userId, authProvider.token, context);
    // Fetch available games
    context.read<GameProvider>().fetchAvailableGames(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh available games when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().fetchAvailableGames(context);
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void joinRoom(String id) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        if (!mounted) {
          return; // Guard against context across async gap
        }
        showSnackBar(context: context, content: 'Please log in to join a game');
        return;
      }
      
      final data = await ApiService.joinGameByCode(
        joinCode: id,
        token: token,
      );
      
      if (!mounted) {
        return; // Guard against context across async gap
      }
      final gameProvider = context.read<GameProvider>();
      gameProvider.gameId = data['gameId'];
      gameProvider.setOpponentData(
        opponentId: data['creatorId'],
        opponentName: data['creatorName'],
        opponentImage: data['creatorImage'],
        opponentRating: data['creatorRating'],
        whiteTime: data['whiteTime'],
        blackTime: data['blackTime'],
        increment: data['increment'] ?? 0,
        gameId: data['gameId'],
      );
      gameProvider.isHumanWhite = false; // Joiner is black
      gameProvider.setPlayerColor(player: 1); // Black player
      gameProvider.setIsPlaying(true);

      // Initialize the game board for the joiner using the FEN from gameData
      gameProvider.setGameFromFen(data['fen']);

      // Start black's timer since the joiner is black and waiting for white's first move
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      gameProvider.startBlacksTime(context: currentContext, onNewGame: () {});
      
      // Initialize socket and join the game room
      if (ApiService.socket == null || !ApiService.socket!.connected) {
        ApiService.initializeSocket(token);
      }
      ApiService.joinGameRoom(gameProvider.gameId);
      
      // Initialize socket listeners for the joiner
      final authProvider = context.read<AuthProvider>();
      gameProvider.initSocketListeners(authProvider.userId, authProvider.token, context);
      
      if (!mounted) return;
      Navigator.pushNamed(context, Constants.gameScreen);
      
    } catch (e) {
      if (!mounted) {
        return; // Guard against context across async gap
      }
      showSnackBar(context: context, content: 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final availableGames = gameProvider.availableGames;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A5A),
        title: const Text('Join Game', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => gameProvider.fetchAvailableGames(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Manual join section
            Card(
              color: const Color(0xFF3A3A6A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Join by Code',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _idController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter 6-digit Join Code',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.gamepad, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF2A2A5A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => joinRoom(_idController.text),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Available games section
            const Text(
              'Available Public Games',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (availableGames.isEmpty)
              const Card(
                color: Color(0xFF3A3A6A),
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No public games available',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...availableGames.map((game) => Card(
                color: const Color(0xFF3A3A6A),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF26A69A),
                    child: Text(
                      game['creatorName']?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    game['creatorName'] ?? 'Unknown Player',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rating: ${game['creatorRating'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Time: ${(game['whiteTime'] ?? 0) ~/ 60} min',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      final userId = context.read<AuthProvider>().userId;
                      if (userId != null) {
                        gameProvider.joinGame(
                          context,
                          game['gameId'],
                          userId,
                        );
                      } else {
                        if (!mounted) return;
                        showSnackBar(context: context, content: 'Please log in to join a game');
                      }
                    },
                    child: const Text('Join'),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}