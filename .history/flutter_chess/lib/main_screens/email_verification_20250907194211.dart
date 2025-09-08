import 'package:flutter/material.dart';

class EmailVerification extends StatelessWidget {
  static const String routeName = '/email-verification';

  const EmailVerification({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification')),
      body: const Center(
        child: Text('Email verification sent. Please check your inbox.'),
      ),
    );
  }
}