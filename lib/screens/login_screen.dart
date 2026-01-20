
// LoginScreen provides login, sign up, and password reset functionality for the app.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';



/// The login screen for user authentication (login, sign up, password reset).
class LoginScreen extends StatefulWidget {
  /// Whether dark mode is enabled
  final bool isDarkMode;
  /// Callback to toggle dark mode
  final ValueChanged<bool> onThemeChanged;
  /// Creates a login screen.
  const LoginScreen({super.key, this.isDarkMode = false, required this.onThemeChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// State for LoginScreen, manages authentication logic and UI state.
class _LoginScreenState extends State<LoginScreen> {
  /// Handles password reset by sending a reset email.
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      if (mounted) setState(() { _error = 'Please enter your email to reset password.'; });
      return;
    }
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  // Whether to show the sign up form instead of login
  bool _showSignUp = false;

  /// Handles user sign up with email and password.
  Future<void> _signUp() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) setState(() { _showSignUp = false; });
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  // Controllers for email and password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Error message to display
  String? _error;
  // Whether an async operation is in progress
  bool _isLoading = false;

  /// Handles user login with email and password.
  Future<void> _login() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Builds the login screen UI.
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Background gradient for a modern look
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF6C3EB6), const Color(0xFF3A2066), const Color(0xFF1A093E)]
                : [const Color(0xFFb7baff), const Color(0xFFaee2f8), const Color(0xFFf8e1ff)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App heading
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Welcome to Memory Diary',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C3EB6),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Login or Sign Up title
                  Text(
                    _showSignUp ? 'Sign Up' : 'Login',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Email field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.person_outline),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 18),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Password field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        hintText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 18),
                      ),
                      obscureText: true,
                    ),
                  ),
                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(color: Color(0xFF6c63ff)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Login or Sign Up button
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _showSignUp ? _signUp : _login,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 4,
                              backgroundColor: isDark ? const Color(0xFF6C3EB6) : const Color(0xFF6c63ff),
                            ),
                            child: Text(
                              _showSignUp ? 'Sign Up' : 'Login',
                              style: const TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                  const SizedBox(height: 18),
                  // Divider and social login (UI only)
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[400])),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('or connect with', style: TextStyle(color: Colors.black54)),
                      ),
                      Expanded(child: Divider(color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Social login buttons (not implemented)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.facebook, color: Colors.white),
                        label: const Text('Facebook'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877f3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.alternate_email, color: Colors.white),
                        label: const Text('Twitter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1da1f2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Toggle between login and sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showSignUp ? 'Already have an account? ' : "Don't have account? ",
                        style: const TextStyle(color: Colors.black54),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSignUp = !_showSignUp;
                            _error = null;
                          });
                        },
                        child: Text(
                          _showSignUp ? 'Login' : 'Sign up',
                          style: const TextStyle(
                            color: Color(0xFF6c63ff),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
