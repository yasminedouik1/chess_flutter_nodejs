import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget child;

  const Responsive({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: child),
            ),
          );
        } else {
          return child;
        }
      },
    );
  }
}