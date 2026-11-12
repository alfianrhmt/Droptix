import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'core/widgets/widgets.dart';
import 'features/gallery/component_gallery_screen.dart';

void main() {
  runApp(const DroptixApp());
}

class DroptixApp extends StatelessWidget {
  const DroptixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CountdownTimerProvider(
      child: MaterialApp(
        title: 'Droptix',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const ComponentGalleryScreen(),
      ),
    );
  }
}
