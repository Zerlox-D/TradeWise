// lib/widgets/profile_icon_button.dart
import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart'; // We will create this next

class ProfileIconButton extends StatelessWidget {
  const ProfileIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.account_circle, size: 32),
      tooltip: 'Go to Profile/Dashboard',
      onPressed: () {
        // Just like React Router's history.push()
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      },
    );
  }
}
