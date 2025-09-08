import 'package:flutter/material.dart';
import 'package:flutter_chess/main_screens/gameTime.dart';
import 'package:flutter_chess/main_screens/join_room.dart';
import 'package:flutter_chess/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class PlayVsFriendScreen extends StatelessWidget {
  const PlayVsFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Play vs Friend',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2A2A5A),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButtonCard(
                context: context,
                label: 'Create Room',
                icon: Icons.add_circle,
                onTap: () {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in to create a game')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GameTimeScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildButtonCard(
                context: context,
                label: 'Join Room',
                icon: Icons.group,
                onTap: () {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please log in to join a game')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JoinRoomScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF3A3A6A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 300,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF26A69A), size: 35),
              const SizedBox(height: 15),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}