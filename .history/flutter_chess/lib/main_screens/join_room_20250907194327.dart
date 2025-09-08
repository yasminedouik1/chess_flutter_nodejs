import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/resources/socket_methods.dart';
import 'package:flutter_chess/utils.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  static const String routeName = '/join-room';

  const JoinRoomScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final TextEditingController _roomIdController = TextEditingController();

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.read(socketMethodsProvider).joinRoomSuccessListener(context);
    ref.read(socketMethodsProvider).errorListener(context);
  }

  void joinRoom() {
    if (_roomIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room ID')),
      );
      return;
    }
    ref.read(socketMethodsProvider).joinRoom(_roomIdController.text);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Join Room'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/chessBackground8.png',
            fit: BoxFit.cover,
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.8, maxWidth: 500),
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            " Join Room ",
                            style: TextStyle(
                              fontSize: 55,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              shadows: [Shadow(color: Colors.blue, blurRadius: 15)],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.yellow, blurRadius: 5, spreadRadius: 2)],
                        ),
                        child: TextField(
                          controller: _roomIdController,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            fillColor: Color.fromARGB(255, 194, 197, 175),
                            filled: true,
                            border: InputBorder.none,
                            hintText: "Enter Room ID",
                            hintStyle: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 45),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          color: Colors.lightGreen,
                          boxShadow: [BoxShadow(color: Color.fromARGB(255, 205, 214, 213), blurRadius: 10, spreadRadius: 0)],
                        ),
                        child: ElevatedButton(
                          onPressed: joinRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 182, 218, 37),
                            minimumSize: const Size(double.infinity, 55),
                          ),
                          child: const Text(
                            "Join Room",
                            style: TextStyle(fontSize: 18, shadows: [Shadow(color: Color.fromARGB(255, 228, 190, 133), blurRadius: 5)]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}