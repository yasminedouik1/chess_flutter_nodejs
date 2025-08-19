import 'package:flutter/material.dart';
import 'package:flutter_chess/main_screens/bottom_navbar.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF2A2A5A),
        child: const Center(child: Text('About Screen', style: TextStyle(color: Colors.white, fontSize: 20))),
      ),
     bottomNavigationBar: MyBottomNavBar(currentIndex: 1), 

    );
  }
}