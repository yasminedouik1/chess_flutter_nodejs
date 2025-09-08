import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:http/http.dart' as http;
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
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
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
        if (context.mounted) {
          context.read<GameProvider>().gameId = gameId;
          Navigator.pushNamed(context, Constants.gameScreen);
        }
      } else {
        if (context.mounted) {
          showSnackBar(context: context, content: data['message'] ?? 'Failed to join game');
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context: context, content: 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A5A),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.8, maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Join Game',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter Game ID or Join Code',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.gamepad, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF3A3A6A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => joinRoom(context, _idController.text),
                  child: const Text('Join'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}