import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chess/main_screens/bottom_navbar.dart';
import 'package:flutter_chess/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _image;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _usernameController.text = auth.username ?? '';
    _emailController.text = auth.user?.email ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    final token = auth.token;
    if (userId == null || token == null) {
      final currentContext = context; // Capture context
      if (!currentContext.mounted) return; // Guard against context across async gap
      ScaffoldMessenger.of(currentContext).showSnackBar(const SnackBar(content: Text('Please log in to update profile')));
      return;
    }

    try {
      final updatedUser = await ApiService.updateUser(
        token: token,
        userId: userId,
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        image: _image,
      );
      await auth.updateUser(UserModel.fromJson(updatedUser));
      setState(() {
        _isEditing = false;
        _image = null;
        _passwordController.clear();
      });
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      ScaffoldMessenger.of(currentContext).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
    } catch (e) {
      final currentContext = context;
      if (!currentContext.mounted) return; // Guard against context across async gap
      ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final username = auth.username ?? 'Username';
    final email = auth.user?.email ?? 'Email';
    final rating = auth.user?.playerRating ?? 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF2A2A5A),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.cancel : Icons.edit, color: Colors.white),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : NetworkImage(auth.user?.image ?? 'https://via.placeholder.com/150') as ImageProvider,
                ),
              ),
              const SizedBox(height: 20),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF26A69A)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF26A69A)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'New Password (optional)',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white70),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF26A69A)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                        onPressed: _saveChanges,
                        child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rating: $rating',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await auth.logout();
                    final currentContext = context; // Capture context
                    if (!currentContext.mounted) return; // Guard against context across async gap
                    Navigator.pushReplacementNamed(
                      currentContext,
                      Constants.loginScreen,
                    );
                  },
                  child: const Text(
                    'Disconnect',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MyBottomNavBar(currentIndex: 3),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}



// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_chess/main_screens/bottom_navbar.dart';
// import 'package:provider/provider.dart';
// import 'package:image_picker/image_picker.dart';
// import '../constants.dart';
// import '../providers/auth_provider.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   File? _image;

//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//       // TODO: upload the image to your backend here if needed
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = Provider.of<AuthProvider>(context); // Only declare once
//     final username = auth.username ?? 'Username';   // Use provider username

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Profile'),
//         backgroundColor: const Color(0xFF2A2A5A),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             GestureDetector(
//               onTap: _pickImage,
//               child: CircleAvatar(
//                 radius: 50,
//                 backgroundImage: _image != null
//                     ? FileImage(_image!)
//                     : const AssetImage('assets/images/profile.png') as ImageProvider,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               username, // Display username from provider
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//             const SizedBox(height: 40),
//             SizedBox(
//               width: 200,
//               height: 50,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.redAccent,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 onPressed: () async {
//                   await auth.logout();
//                   Navigator.pushReplacementNamed(
//                     context,
//                     Constants.loginScreen,
//                   );
//                 },
//                 child: const Text(
//                   'Disconnect',
//                   style: TextStyle(fontSize: 18, color: Colors.white),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: const MyBottomNavBar(currentIndex: 3),
//     );
//   }
// }
