
// main.dart is the entry point and main navigation/state logic for the Memory Diary app.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';


/// App entry point. Initializes Firebase and runs the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
    // Only load profile after login
    debugPrint('AuthGateState initState');
  }

  /// Loads the user's profile from Firebase Realtime Database and updates state.
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('_loadProfile called. user: \\${user?.uid}');
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
      final ref = FirebaseDatabase.instance.ref('profiles/${user.uid}');
      debugPrint('_loadProfile: about to get snapshot with 2s timeout');
      final snapshot = await ref.get().timeout(const Duration(seconds: 2), onTimeout: () {
        debugPrint('_loadProfile: ERROR - Database read timed out!');
        throw Exception('Database read timed out');
      });
      debugPrint('_loadProfile: snapshot.exists = ${snapshot.exists}, value = ${snapshot.value}, type = ${snapshot.value?.runtimeType}');
      if (snapshot.exists && snapshot.value != null) {
        final raw = snapshot.value;
        String name = '';
        String desc = '';
        String age = '';
        String prefs = '';
        if (raw is Map) {
          name = raw['name']?.toString() ?? '';
          desc = raw['description']?.toString() ?? '';
          age = raw['age']?.toString() ?? '';
          prefs = raw['preferences']?.toString() ?? '';
        } else if (raw is String) {
          name = raw;
        }
        setState(() {
          _profileName = name;
          _profileDescription = desc;
          _profileAge = age;
          _profilePreferences = prefs;
          _loadingProfile = false;
        });
      } else {
        setState(() {
          _profileName = '';
          _profileDescription = '';
          _profileAge = '';
          _profilePreferences = '';
          _loadingProfile = false;
        });
      }
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

  /// Saves the user's profile to Firebase Realtime Database, updates state, and shows a SnackBar on success or error.
  Future<void> _saveProfile(String name, String desc, String age, String prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('_saveProfile: No user logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not logged in. Please log in again.')),
        );
      }
      return;
    }
    // Prevent saving empty or incomplete profiles
    if (name.trim().isEmpty) {
      debugPrint('_saveProfile: Refusing to save empty name for user: \\${user.uid}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name cannot be empty.')),
        );
      }
      return;
    }
    final ref = FirebaseDatabase.instance.ref('profiles/${user.uid}');
    debugPrint('_saveProfile: Saving for user: \\${user.uid}, name=$name, desc=$desc, age=$age, prefs=$prefs');
    try {
      await ref.set({
        'name': name,
        'description': desc,
        'age': age,
        'preferences': prefs,
      });
    } catch (e, st) {
      debugPrint('_saveProfile: error: $e');
      debugPrint('_saveProfile: stacktrace: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
      return;
    }
    await _loadProfile();
    if (mounted) {
      setState(() {
        _selectedIndex = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
    }
    debugPrint('_saveProfile: saved name=$name, desc=$desc, age=$age, prefs=$prefs, _selectedIndex=$_selectedIndex');
  }

  /// Handles bottom navigation bar taps, prevents navigation to diary if profile is incomplete.
  void _onTabTapped(int idx) {
    if (idx == 1 && (_profileName == null || _profileName!.isEmpty)) return;
    setState(() => _selectedIndex = idx);
  }

  /// Builds the main UI, including swipe navigation (PageView), bottom navigation, and app bar actions.
  @override
  Widget build(BuildContext context) {
    debugPrint('AuthGateState build: _profileName={_profileName}, _loadingProfile={_loadingProfile}, _selectedIndex={_selectedIndex}');
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('StreamBuilder: connectionState={snapshot.connectionState}, hasData={snapshot.hasData}');
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

        // Prevent navigation to diary if profile is not present or incomplete
        bool profileComplete = _profileName != null && _profileName!.isNotEmpty && _profileAge != null && _profileAge!.isNotEmpty && _profilePreferences != null && _profilePreferences!.isNotEmpty;
        if (_selectedIndex == 1 && !profileComplete) {
          // Force user back to profile page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = 0);
          });
        }

        // --- SWIPE FEATURE: PageView for swipe navigation ---
        return Scaffold(
          appBar: AppBar(
            title: const Text('Memory Diary'),
            actions: [
              IconButton(
                icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                tooltip: 'Toggle Dark Mode',
                onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
              ),
              if (_selectedIndex == 0 && !_editingProfile && profileComplete)
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
                          Navigator.of(context).pop();
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
          body: PageView(
            controller: PageController(initialPage: _selectedIndex),
            onPageChanged: (idx) {
              // Prevent navigation to diary if profile is incomplete
              if (idx == 1 && !profileComplete) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please complete and save your profile before accessing the diary.')),
                );
                if (mounted) setState(() => _selectedIndex = 0);
                return;
              }
              setState(() => _selectedIndex = idx);
            },
            children: [
              // Profile page (first)
              Column(
                children: [
                  Expanded(
                    child: ProfileScreen(
                      displayName: _profileName ?? '',
                      description: _profileDescription ?? '',
                      age: _profileAge ?? '',
                      preferences: _profilePreferences ?? '',
                      requireSave: !profileComplete,
                      onSave: (name, desc, age, prefs) {
                        _saveProfile(name, desc, age, prefs);
                      },
                      onContinue: () async {
                        if (profileComplete) {
                          if (mounted) setState(() => _selectedIndex = 1);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please complete and save your profile before continuing.')),
                          );
                        }
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
                  if (!_editingProfile && profileComplete)
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
              ),
              // Diary page (second)
              HomePage(
                isDarkMode: widget.isDarkMode,
                onThemeChanged: widget.onThemeChanged,
                profileName: _profileName ?? '',
                profileDescription: _profileDescription ?? '',
                onProfileNameChanged: (_) {},
                onProfileDescriptionChanged: (_) {},
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (idx) {
              // Prevent navigation to diary if profile is incomplete
              if (idx == 1 && !profileComplete) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please complete and save your profile before accessing the diary.')),
                );
                return;
              }
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
  static const splashDuration = Duration(milliseconds: 700); // Shorter splash
  @override
  void initState() {
    super.initState();
    Future.delayed(splashDuration, widget.onFinish);
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(splashDuration),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              // Fallback to a CircularProgressIndicator if the Lottie asset is missing
              child: CircularProgressIndicator(),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}
