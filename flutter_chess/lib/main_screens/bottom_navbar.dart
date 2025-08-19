import 'package:flutter/material.dart';
import 'package:flutter_chess/main_screens/about.dart';
import 'package:flutter_chess/main_screens/home.dart';
import 'package:flutter_chess/main_screens/profile_screen.dart';
import 'package:flutter_chess/main_screens/settings.dart';

class MyBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const MyBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: const Color(0x00211c6a),
      selectedItemColor: const Color(0xFF26A69A),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        if (index == currentIndex) return; // Do nothing if current page
        switch (index) {
          case 0:
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            break;
          case 1:
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
            break;
          case 2:
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            break;
          case 3:
            // Profile screen example
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
