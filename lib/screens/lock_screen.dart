// PasswordLockScreen is a simple lock/login screen for the Memory Diary app.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../security/biometric_auth.dart';

/// A small fallback storage used when shared_preferences is not available.
class _LocalPrefs {
  static String? _pw;
  static Future<_LocalPrefs> getInstance() async => _LocalPrefs();
  Future<String?> getString(String key) async => _pw;
  Future<void> setString(String key, String value) async {
    _pw = value;
  }
}

/// A simple password lock/login screen for the Memory Diary app.
class PasswordLockScreen extends StatefulWidget {
  const PasswordLockScreen({super.key});

  @override
  State<PasswordLockScreen> createState() => _PasswordLockScreenState();
}

class _PasswordLockScreenState extends State<PasswordLockScreen> {
  final _controller = TextEditingController();
  bool _useStealth = false;
  bool _loading = true;
  String? _stored;
  final BiometricAuth _biometric = BiometricAuth();

  @override
  void initState() {
    super.initState();
    _loadStored();
  }

  Future<void> _loadStored() async {
    final prefs = await _LocalPrefs.getInstance();
    final s = await prefs.getString('diary_password');
    setState(() {
      _stored = s;
      _loading = false;
    });

    // Try biometric unlock automatically if available
    final canBio = await _biometric.canCheckBiometricsAndEnrolled();
    if (canBio) {
      final ok = await _biometric.authenticate(reason: 'Unlock your diary with fingerprint');
      if (ok && mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _savePassword(String pass) async {
    final prefs = await _LocalPrefs.getInstance();
    await prefs.setString('diary_password', pass);
    setState(() => _stored = pass);
  }

  void _tryUnlock() {
    final val = _controller.text;
    if (_stored == null) {
      // No password set -> set it now
      if (val.trim().isEmpty) return;
      _savePassword(val.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password set')));
      Navigator.of(context).pop(true);
      return;
    }
    if (val == _stored) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong password')));
    }
  }

  Future<void> _triggerBiometric() async {
    try {
      final ok = await _biometric.authenticate(reason: 'Authenticate to unlock');
      if (ok && mounted) Navigator.of(context).pop(true);
      if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric auth failed')));
    } on PlatformException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric not available')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Diary')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_useStealth)
              const Text('Stealth Mode Active: No labels shown', style: TextStyle(color: Colors.grey)),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: _useStealth ? null : (_stored == null ? 'Set a password' : 'Enter password'),
                hintText: _useStealth ? null : '••••••',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _useStealth = !_useStealth),
                  icon: Icon(_useStealth ? Icons.visibility_off : Icons.visibility),
                  label: Text(_useStealth ? 'Stealth' : 'Normal'),
                ),
                ElevatedButton(
                  onPressed: _tryUnlock,
                  child: Text(_stored == null ? 'Set & Enter' : 'Unlock'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show biometric option if available
            FutureBuilder<bool>(
              future: _biometric.canCheckBiometricsAndEnrolled(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
                if (snap.data == true) {
                  return ElevatedButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use fingerprint'),
                    onPressed: _triggerBiometric,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
