
// SettingsScreen allows the user to edit their profile, toggle dark mode, and logout.
import 'package:flutter/material.dart';

/// The settings screen for editing user profile, toggling dark mode, and logging out.
class SettingsScreen extends StatelessWidget {
  /// The user's display name (profile name)
  final String displayName;
  /// The user's profile description
  final String description;
  /// The user's age
  final String age;
  /// The user's preferences
  final String preferences;
  /// Whether dark mode is enabled
  final bool isDarkMode;
  /// Callback to toggle dark mode
  final ValueChanged<bool> onThemeChanged;
  /// Callback to save the profile (name, description, age, preferences)
  final void Function(String, String, String, String) onSave;
  /// Callback to log out
  final VoidCallback onLogout;

  /// Creates a settings screen.
  const SettingsScreen({
    super.key,
    required this.displayName,
    required this.description,
    required this.age,
    required this.preferences,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onSave,
    required this.onLogout,
  });

  @override
  /// Builds the settings screen UI.
  @override
  Widget build(BuildContext context) {
    // Controllers for the profile fields
    final nameController = TextEditingController(text: displayName);
    final descController = TextEditingController(text: description);
    final ageController = TextEditingController(text: age);
    final prefsController = TextEditingController(text: preferences);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            // Toggle for dark mode
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: isDarkMode,
              onChanged: onThemeChanged,
            ),
            const Divider(),
            // Text field for name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            // Text field for description
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Text field for age
            TextField(
              controller: ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // Text field for preferences
            TextField(
              controller: prefsController,
              decoration: const InputDecoration(labelText: 'Preferences'),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            // Save profile button
            ElevatedButton(
              onPressed: () async {
                // Show a loading indicator while saving
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                try {
                  await Future.sync(() => onSave(
                    nameController.text.trim(),
                    descController.text.trim(),
                    ageController.text.trim(),
                    prefsController.text.trim(),
                  ));
                } finally {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Remove loading dialog
                  }
                }
              },
              child: const Text('Save Profile'),
            ),
            const SizedBox(height: 24),
            // Logout button
            ElevatedButton(
              onPressed: onLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
