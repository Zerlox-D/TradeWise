import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TradeWiseApp());
}

class TradeWiseApp extends StatelessWidget {
  const TradeWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeWise',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}