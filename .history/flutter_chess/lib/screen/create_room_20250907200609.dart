import 'package:flutter/material.dart';
import 'package:flutter_chess/widgets/custom_button.dart';
import 'package:flutter_chess/widgets/custom_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chess/providers/game_provider.dart';
import 'package:flutter_chess/resources/socket_methods.dart';
import 'package:flutter_chess/utils.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  static const String routeName = '/create-room';

  const CreateRoomScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.read(socketMethodsProvider).createRoomSuccessListener(context);
    ref.read(socketMethodsProvider).errorListener(context);
  }

  void createRoom() {
    if (_roomNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      return;
    }
    ref.read(socketMethodsProvider).createRoom(_roomNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Create Room'),
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
                            " Create Room ",
                            style: TextStyle(
                              fontSize: 50,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              shadows: [Shadow(color: Colors.blue, blurRadius: 15)],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: CustomTextField(
                          controller: _roomNameController,
                          hintText: "Enter Room Name",
                        ),
                      ),
                      const SizedBox(height: 45),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: CustomButton(
                          onTap: createRoom,
                          text: "Create",
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