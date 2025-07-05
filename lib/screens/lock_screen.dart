import 'package:flutter/material.dart';
import 'home_page.dart'; // Ensure this file exists and contains a HomePage class

class PasswordLockScreen extends StatelessWidget {
  const PasswordLockScreen({super.key});

  void _goToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          isDarkMode: false,
          onThemeChanged: (theme) {},
          profileName: '',
          profileDescription: '',
          onProfileNameChanged: (_) {},
          onProfileDescriptionChanged: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Diary Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.indigo),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _goToHome(context),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
