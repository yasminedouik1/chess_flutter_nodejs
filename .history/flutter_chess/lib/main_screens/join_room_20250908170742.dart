import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game_provider.dart';
import 'auth_provider.dart';
import 'user_model.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({Key? key}) : super(key: key);

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _joinCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _joinGame(GameProvider gameProvider, AuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to join a game')),
      );
      return;
    }

    final joinCode = _joinCodeController.text.trim();
    if (joinCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a join code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await gameProvider.joinGame(
        user: user,
        joinCode: joinCode,
        context: context,
        onSuccess: () {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined game successfully')),
          );
        },
        onFail: (error) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join game: $error')),
          );
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining game: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Join Game')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _joinCodeController,
              decoration: InputDecoration(
                labelText: 'Enter Join Code',
                border: OutlineInputBorder(),
              ),
              enabled: !_isLoading,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _joinGame(gameProvider, authProvider),
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:flutter_chess/providers/game_provider.dart';
// import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
// import '../constants.dart';
// import '../services/api_service.dart';
// import '../widgets/widgets.dart';

// class JoinRoomScreen extends StatefulWidget {
//   static const String routeName = '/joinRoomScreen';
//   const JoinRoomScreen({super.key});

//   @override
//   State<JoinRoomScreen> createState() => _JoinRoomScreenState();
// }

// class _JoinRoomScreenState extends State<JoinRoomScreen> {
//   final TextEditingController _idController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     // Initialize socket listeners in GameProvider
//     context.read<GameProvider>().initSocketListeners(context);
//   }

//   @override
//   void dispose() {
//     _idController.dispose();
//     super.dispose();
//   }

//   void joinRoom(BuildContext context, String id) async {
//     try {
//       final token = await ApiService.getToken();
//       final response = await http.post(
//         Uri.parse('${ApiService.baseUrl}/games/join-by-code'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({'joinCode': id}),
//       );
//       final data = jsonDecode(response.body);
//       if (response.statusCode == 200) {
//         final gameId = data['gameId'];
//         ApiService.joinGameRoom(gameId);
//         context.read<GameProvider>().gameId = gameId;
//         Navigator.pushNamed(context, Constants.gameScreen);
//       } else {
//         showSnackBar(context: context, content: data['message'] ?? 'Failed to join game');
//       }
//     } catch (e) {
//       showSnackBar(context: context, content: 'Error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     return Scaffold(
//       backgroundColor: const Color(0xFF2A2A5A),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: BoxConstraints(maxHeight: size.height * 0.8, maxWidth: 500),
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Text(
//                   'Join Game',
//                   style: TextStyle(
//                     fontSize: 28,
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 40),
//                 TextField(
//                   controller: _idController,
//                   style: const TextStyle(color: Colors.white),
//                   decoration: InputDecoration(
//                     hintText: 'Enter Game ID or Join Code',
//                     hintStyle: const TextStyle(color: Colors.white54),
//                     prefixIcon: const Icon(Icons.gamepad, color: Colors.white70),
//                     filled: true,
//                     fillColor: const Color(0xFF3A3A6A),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: () => joinRoom(context, _idController.text),
//                   child: const Text('Join'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }