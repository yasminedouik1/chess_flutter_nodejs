import 'package:flutter/material.dart';
import 'package:flutter_chess/main_screens/bottom_navbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF2A2A5A),
        child: const Center(child: Text('Settings Screen', style: TextStyle(color: Colors.white, fontSize: 20))),
      ),
      bottomNavigationBar: MyBottomNavBar(currentIndex: 2), 

    );
  }
}