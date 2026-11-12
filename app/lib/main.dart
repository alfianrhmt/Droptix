import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'core/widgets/app_background.dart';

void main() {
  runApp(const DroptixApp());
}

class DroptixApp extends StatelessWidget {
  const DroptixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Droptix',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppBackground(
        child: Scaffold(
          body: Center(
            child: Text('Droptix'),
          ),
        ),
      ),
    );
  }
}
