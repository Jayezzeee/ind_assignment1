
// PasswordLockScreen is a simple lock/login screen for the Memory Diary app.
import 'package:flutter/material.dart';
import 'home_page.dart'; // Ensure this file exists and contains a HomePage class

/// A simple password lock/login screen for the Memory Diary app.
class PasswordLockScreen extends StatelessWidget {
  const PasswordLockScreen({super.key});

  /// Navigates to the HomePage, replacing the current screen.
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

  /// Builds the lock screen UI with a lock icon and a login button.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Diary Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock icon
            const Icon(Icons.lock, size: 64, color: Colors.indigo),
            const SizedBox(height: 24),
            // Login button
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
