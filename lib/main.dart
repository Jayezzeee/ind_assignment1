
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

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

class _AuthGateState extends State<AuthGate> {
  int _selectedIndex = 0;
  String? _profileName;
  String? _profileDescription;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    // Only load profile after login
    debugPrint('AuthGateState initState');
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('_loadProfile called. user: \\${user?.uid}');
    if (user == null) {
      setState(() {
        _profileName = null;
        _profileDescription = null;
        _loadingProfile = false;
      });
      debugPrint('_loadProfile: user is null, resetting profile state');
      return;
    }
    setState(() => _loadingProfile = true);
    try {
      final ref = FirebaseDatabase.instance.ref('profiles/${user.uid}');
      debugPrint('_loadProfile: about to get snapshot with 5s timeout');
      final snapshot = await ref.get().timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('_loadProfile: ERROR - Database read timed out!');
        throw Exception('Database read timed out');
      });
      debugPrint('_loadProfile: snapshot.exists = \${snapshot.exists}, value = \${snapshot.value}, type = \${snapshot.value?.runtimeType}');
      if (snapshot.exists && snapshot.value != null) {
        final raw = snapshot.value;
        String name = '';
        String desc = '';
        if (raw is Map) {
          // Defensive: try both dynamic and String keys
          name = raw['name']?.toString() ?? raw['name'.toString()]?.toString() ?? '';
          desc = raw['description']?.toString() ?? raw['description'.toString()]?.toString() ?? '';
        } else if (raw is String) {
          name = raw;
        } else {
          debugPrint('_loadProfile: Unexpected data type: \\${raw.runtimeType}');
        }
        setState(() {
          _profileName = name;
          _profileDescription = desc;
          _loadingProfile = false;
        });
        debugPrint('_loadProfile: loaded name=\${_profileName}, desc=\${_profileDescription}');
      } else {
        setState(() {
          _profileName = '';
          _profileDescription = '';
          _loadingProfile = false;
        });
        debugPrint('_loadProfile: no profile found, set empty');
      }
    } catch (e, st) {
      debugPrint('_loadProfile: error: \${e.toString()}');
      debugPrint('_loadProfile: stacktrace: \${st.toString()}');
      setState(() {
        _profileName = '';
        _profileDescription = '';
        _loadingProfile = false;
      });
    }
  }

  Future<void> _saveProfile(String name, String desc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('profiles/${user.uid}');
    await ref.set({
      'name': name,
      'description': desc,
    });
    setState(() {
      _profileName = name;
      _profileDescription = desc;
    });
    // Ensure navigation happens after state update
    Future.microtask(() {
      if (mounted) setState(() => _selectedIndex = 1);
    });
    debugPrint('_saveProfile: saved name=\${name}, desc=\${desc}, _selectedIndex=\${_selectedIndex}');
  }

  void _onTabTapped(int idx) {
    if (idx == 1 && (_profileName == null || _profileName!.isEmpty)) return;
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('AuthGateState build: _profileName=\${_profileName}, _loadingProfile=\${_loadingProfile}, _selectedIndex=\${_selectedIndex}');
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('StreamBuilder: connectionState=\${snapshot.connectionState}, hasData=\${snapshot.hasData}');
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Memory Diary'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  setState(() {
                    _profileName = null;
                    _profileDescription = null;
                    _selectedIndex = 0;
                    _loadingProfile = false; // Force reload after next login
                  });
                  debugPrint('Logout pressed, state reset');
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              // Profile page (first)
              ProfileScreen(
                displayName: _profileName ?? '',
                description: _profileDescription ?? '',
                onNameChanged: (name) {},
                onDescriptionChanged: (desc) {},
                requireSave: _profileName == null || _profileName!.isEmpty,
                onSave: _saveProfile,
                onContinue: () {
                  if (mounted) setState(() => _selectedIndex = 1);
                },
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
            onTap: _onTabTapped,
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

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Widget child;
  const SplashScreen({super.key, required this.onFinish, required this.child});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

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
