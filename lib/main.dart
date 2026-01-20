
// main.dart is the entry point and main navigation/state logic for the Memory Diary app.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/drawing_screen.dart';
import 'services/notification_service.dart';
import 'services/encryption_service.dart';


/// App entry point. Initializes Firebase and runs the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseDatabase.instance.databaseURL = 'https://diary-be14e-default-rtdb.asia-southeast1.firebasedatabase.app';
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    // Continue without Firebase? But probably not.
    rethrow;
  }
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }
  runApp(const AppRoot());
}

/// Root widget for the app, manages dark mode and launches splash/main app.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

/// State for AppRoot, manages dark mode state.
class _AppRootState extends State<AppRoot> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Diary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: isDarkMode ? Brightness.dark : Brightness.light),
        useMaterial3: true,
      ),
      home: SplashScreen(
        onFinish: () => setState(() {}),
        child: MemoryDiaryApp(
          isDarkMode: isDarkMode,
          onThemeChanged: (val) => setState(() => isDarkMode = val),
        ),
      ),
    );
  }
}



/// Passes dark mode and theme change callback to the authentication gate.
class MemoryDiaryApp extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  const MemoryDiaryApp({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      isDarkMode: isDarkMode,
      onThemeChanged: onThemeChanged,
    );
  }
}



/// Handles authentication, profile loading/saving, navigation, and state for the main app.
class AuthGate extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  const AuthGate({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

/// State for AuthGate, manages navigation, profile state, and auth logic.
class _AuthGateState extends State<AuthGate> {
  int _selectedIndex = 0;
  String? _profileName;
  String? _profileDescription;
  String? _profileAge;
  String? _profilePreferences;
  bool _loadingProfile = false;
  bool _editingProfile = false;
  bool _biometricEnabled = false;
  bool _authenticatingBiometric = false;
  static bool _hasAuthenticated = false; // Prevent multiple auth attempts
  bool _flashbackNotificationsEnabled = false;
  bool _stealthModeEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Sends a verification email to the user (not used in current flow).
  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the current user from Firebase Auth.
  Future<void> _reloadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.reload();
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadFlashbackSetting();
    _loadStealthSetting();
    // Only load profile after login
    debugPrint('AuthGateState initState');
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
    // Schedule if enabled
    if (_flashbackNotificationsEnabled) {
      await NotificationService().scheduleDailyFlashbackReminder();
    }
  }

  /// Loads the stealth mode setting from SharedPreferences.
  Future<void> _loadStealthSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stealthModeEnabled = prefs.getBool('stealth_mode_enabled') ?? false;
    });
  }

  /// Safely decrypts data, falling back to plain text if decryption fails.
  Future<String> _safeDecrypt(String data) async {
    try {
      return await EncryptionService().decryptData(data);
    } catch (e) {
      return data; // Assume it's plain text
    }
  }

  /// Authenticates the user using biometrics.
  Future<void> _authenticateBiometric() async {
    debugPrint('_authenticateBiometric called');
    setState(() => _authenticatingBiometric = true);
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      debugPrint('canCheckBiometrics: $canCheck');
      if (!canCheck) {
        // If biometrics not available, skip
        setState(() => _authenticatingBiometric = false);
        return;
      }
      // Check if any biometrics are enrolled
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('availableBiometrics: $availableBiometrics');
      if (availableBiometrics.isEmpty) {
        // No biometrics enrolled, skip
        setState(() => _authenticatingBiometric = false);
        return;
      }
      debugPrint('calling authenticate');
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Memory Diary',
        options: const AuthenticationOptions(biometricOnly: false),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint('biometric timeout');
        // If timeout, allow access
        return true;
      });
      debugPrint('authenticated: $authenticated');
      if (!authenticated) {
        // Instead of logout, show warning and allow access
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed. Access granted with warning.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      // On error, allow access
    } finally {
      setState(() => _authenticatingBiometric = false);
    }
  }

  /// Loads the user's profile from SharedPreferences.
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('_loadProfile called. user: ${user?.uid}');
    if (user == null) {
      setState(() {
        _profileName = null;
        _profileDescription = null;
        _profileAge = null;
        _profilePreferences = null;
        _loadingProfile = false;
      });
      debugPrint('_loadProfile: user is null, resetting profile state');
      return;
    }
    setState(() => _loadingProfile = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final name = sp.getString('profile_name') ?? '';
      final desc = sp.getString('profile_description') ?? '';
      final age = sp.getString('profile_age') ?? '';
      final prefsStr = sp.getString('profile_preferences') ?? '';
      setState(() {
        _profileName = name;
        _profileDescription = desc;
        _profileAge = age;
        _profilePreferences = prefsStr;
        _loadingProfile = false;
      });
      debugPrint('_loadProfile: loaded name=$name, desc=$desc, age=$age, prefs=$prefsStr');
    } catch (e, st) {
      debugPrint('_loadProfile: error: ${e.toString()}');
      debugPrint('_loadProfile: stacktrace: ${st.toString()}');
      setState(() {
        _profileName = '';
        _profileDescription = '';
        _profileAge = '';
        _profilePreferences = '';
        _loadingProfile = false;
      });
    }
  }

  /// Saves the user's profile to SharedPreferences (temporarily, until database is fixed).
  Future<void> _saveProfile(String name, String desc, String age, String preferences) async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('_saveProfile called with name=$name, desc=$desc, age=$age, prefs=$preferences');
    if (user == null) {
      debugPrint('_saveProfile: No user logged in');
      throw Exception('Not logged in. Please log in again.');
    }
    // Prevent saving empty or incomplete profiles
    if (name.trim().isEmpty) {
      debugPrint('_saveProfile: Refusing to save empty name for user: ${user.uid}');
      throw Exception('Name cannot be empty.');
    }
    // Save to SharedPreferences instead of Firebase
    final sp = await SharedPreferences.getInstance();
    await sp.setString('profile_name', name);
    await sp.setString('profile_description', desc);
    await sp.setString('profile_age', age);
    await sp.setString('profile_preferences', preferences);
    debugPrint('_saveProfile: Saved to SharedPreferences');

    setState(() {
      _profileName = name;
      _profileDescription = desc;
      _profileAge = age;
      _profilePreferences = preferences;
      _loadingProfile = false;
    });
    debugPrint('_saveProfile: saved successfully');
  }

  /// Builds the main UI, including conditional navigation, bottom navigation, and app bar actions.
  @override
  Widget build(BuildContext context) {
    debugPrint('AuthGate build called');
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('StreamBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          // Not logged in
          if (_profileName != null || _profileDescription != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _profileName = null;
                _profileDescription = null;
                _selectedIndex = 0;
              });
              debugPrint('User logged out, reset profile state');
            });
          }
          return LoginScreen(
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
          );
        }
        // Removed email verification check after login
        // User is logged in, load profile if not loaded
        if (_biometricEnabled && !_authenticatingBiometric && !_loadingProfile && !_hasAuthenticated) {
          debugPrint('Biometric enabled, authenticating in background...');
          _hasAuthenticated = true; // Set flag to prevent re-auth
          // Authenticate in background without blocking UI
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure UI is ready
            if (mounted) {
              await _authenticateBiometric();
            }
          });
        }
        if (_profileName == null && !_loadingProfile) {
          debugPrint('User logged in, loading profile...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadProfile();
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (_loadingProfile) {
          debugPrint('Still loading profile...');
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Profile is now optional
        // Removed force back to profile if incomplete

        return Scaffold(
          appBar: AppBar(
            title: Text(_stealthModeEnabled ? 'Secure Notes' : 'Memory Diary'),
            actions: [
              IconButton(
                icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                tooltip: 'Toggle Dark Mode',
                onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
              ),
              if (_selectedIndex == 0 && !_editingProfile)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  tooltip: 'Logout',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  setState(() {
                    _editingProfile = false;
                  });
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        displayName: _profileName ?? '',
                        description: _profileDescription ?? '',
                        age: _profileAge ?? '',
                        preferences: _profilePreferences ?? '',
                        isDarkMode: widget.isDarkMode,
                        onThemeChanged: widget.onThemeChanged,
                        onSave: (name, desc, age, prefs) async {
                          await _saveProfile(name, desc, age, prefs);
                        },
                        onLogout: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _selectedIndex == 0 ? Column(
            children: [
              Expanded(
                child: ProfileScreen(
                  key: ValueKey('profile_$_profileName$_profileDescription$_profileAge$_profilePreferences'),
                  displayName: _profileName ?? '',
                  description: _profileDescription ?? '',
                  age: _profileAge ?? '',
                  preferences: _profilePreferences ?? '',
                  requireSave: false,
                  onSave: (name, desc, age, prefs) async {
                    await _saveProfile(name, desc, age, prefs);
                  },
                  onContinue: () async {
                    if (mounted) setState(() => _selectedIndex = 1);
                  },
                  isEditing: _editingProfile,
                  onEdit: () {
                    setState(() {
                      _editingProfile = true;
                    });
                  },
                  onCancelEdit: () {
                    setState(() {
                      _editingProfile = false;
                    });
                  },
                ),
              ),
              if (!_editingProfile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 44),
                    ),
                  ),
                ),
            ],
          ) : HomePage(
            key: ValueKey('home_$_profileName$_profileDescription'),
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
            profileName: _profileName ?? '',
            profileDescription: _profileDescription ?? '',
            onProfileNameChanged: (_) {},
            onProfileDescriptionChanged: (_) {},
          ),
          floatingActionButton: _selectedIndex == 1 ? FloatingActionButton(
            heroTag: 'fab_drawing',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DrawingScreen()),
              );
            },
            tooltip: 'Add Drawing Entry',
            child: const Icon(Icons.brush),
          ) : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (idx) {
              setState(() => _selectedIndex = idx);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Diary'),
            ],
          ),
        );
      },
    );
  }
}

/// Splash screen shown briefly on app launch.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Widget child;
  const SplashScreen({super.key, required this.onFinish, required this.child});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// State for SplashScreen, manages splash duration and transition.
class _SplashScreenState extends State<SplashScreen> {
  static const splashDuration = Duration(milliseconds: 300); // Shorter splash
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Finish immediately for debugging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _finished = true);
      widget.onFinish();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_finished) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Memory Diary...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
