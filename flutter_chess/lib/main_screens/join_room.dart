import 'package:flutter/material.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
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
    context.read<GameProvider>().initSocketListeners(context);
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

  void joinRoom(BuildContext context, String id) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        showSnackBar(context: context, content: 'Please log in to join a game');
        return;
      }
      
      final data = await ApiService.joinGameByCode(
        joinCode: id,
        token: token,
      );
      
      if (context.mounted) {
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
        
        // Initialize socket listeners for the joiner
        gameProvider.initSocketListeners(context);
        
        Navigator.pushNamed(context, Constants.gameScreen);
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context: context, content: 'Error: $e');
      }
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
                      onPressed: () => joinRoom(context, _idController.text),
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
                        showSnackBar(context: context, content: 'Please log in to join a game');
                      }
                    },
                    child: const Text('Join'),
                  ),
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }
}