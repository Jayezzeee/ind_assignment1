
// SettingsScreen allows the user to edit their profile, toggle dark mode, and logout.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../services/notification_service.dart';

/// The settings screen for editing user profile, toggling dark mode, and logging out.
class SettingsScreen extends StatefulWidget {
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
  final Future<void> Function(String, String, String, String) onSave;
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State for SettingsScreen.
class _SettingsScreenState extends State<SettingsScreen> {
  bool _saving = false;
  bool _biometricEnabled = false;
  bool _canCheckBiometric = false;
  bool _flashbackNotificationsEnabled = false;
  bool _stealthModeEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _checkBiometric();
    _loadFlashbackSetting();
    _loadStealthSetting();
  }

  /// Loads the biometric setting from SharedPreferences.
  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  /// Loads the flashback notifications setting from SharedPreferences.
  Future<void> _loadFlashbackSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _flashbackNotificationsEnabled = prefs.getBool('flashback_notifications_enabled') ?? false;
    });
  }

  /// Loads the stealth mode setting from SharedPreferences.
  Future<void> _loadStealthSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stealthModeEnabled = prefs.getBool('stealth_mode_enabled') ?? false;
    });
  }

  /// Checks if biometric authentication is available.
  Future<void> _checkBiometric() async {
    bool canCheck = await _localAuth.canCheckBiometrics;
    setState(() {
      _canCheckBiometric = canCheck;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Controllers for the profile fields
    final nameController = TextEditingController(text: widget.displayName);
    final descController = TextEditingController(text: widget.description);
    final ageController = TextEditingController(text: widget.age);
    final prefsController = TextEditingController(text: widget.preferences);
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
              value: widget.isDarkMode,
              onChanged: widget.onThemeChanged,
            ),
            const Divider(),
            // Toggle for biometric authentication
            if (_canCheckBiometric)
              SwitchListTile(
                title: const Text('Enable Biometric Authentication'),
                subtitle: const Text('Require fingerprint or face ID to access the app'),
                value: _biometricEnabled,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('biometric_enabled', value);
                  setState(() {
                    _biometricEnabled = value;
                  });
                },
              ),
            if (!_canCheckBiometric)
              const ListTile(
                title: Text('Biometric Authentication'),
                subtitle: Text('Not available on this device'),
                enabled: false,
              ),
            const Divider(),
            // Toggle for flashback notifications
            SwitchListTile(
              title: const Text('Flashback Notifications'),
              subtitle: const Text('Receive daily reminders to check past memories'),
              value: _flashbackNotificationsEnabled,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('flashback_notifications_enabled', value);
                setState(() {
                  _flashbackNotificationsEnabled = value;
                });
                if (value) {
                  await NotificationService().scheduleDailyFlashbackReminder();
                } else {
                  await NotificationService().cancelAllNotifications();
                }
              },
            ),
            const Divider(),
            // Toggle for stealth mode
            SwitchListTile(
              title: const Text('Stealth Mode'),
              subtitle: const Text('Hide the app identity for privacy'),
              value: _stealthModeEnabled,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('stealth_mode_enabled', value);
                setState(() {
                  _stealthModeEnabled = value;
                });
              },
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
              onPressed: _saving ? null : () async {
                final name = nameController.text.trim();
                final age = ageController.text.trim();
                final prefs = prefsController.text.trim();
                if (name.isEmpty || age.isEmpty || prefs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields: Name, Age, Preferences.')),
                  );
                  return;
                }
                if (_saving) return;
                setState(() => _saving = true);
                try {
                  await widget.onSave(
                    name,
                    descController.text.trim(),
                    age,
                    prefs,
                  );
                  // Success
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile saved!')),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  // Error, don't pop
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save profile: $e')),
                  );
                } finally {
                  setState(() => _saving = false);
                }
              },
              child: _saving ? const CircularProgressIndicator() : const Text('Save Profile'),
            ),
            const SizedBox(height: 24),
            // Logout button
            ElevatedButton(
              onPressed: widget.onLogout,
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
