import 'package:flutter/cupertino.dart';

import 'screens/home.dart';

class PantryApp extends StatelessWidget {
  const PantryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Pantry',
      theme: const CupertinoThemeData(
        primaryColor: Color(0xFF2D6A4F),
        barBackgroundColor: Color(0xFFF2F4F6),
        scaffoldBackgroundColor: Color(0xFFF7F8FA),
      ),
      home: const PantryHomePage(),
    );
  }
}
