
// ProfileScreen displays and allows editing of the user's profile information.
// It supports view-only and edit modes, and requires certain fields to be filled before continuing.
import 'package:flutter/material.dart';

/// The profile screen for viewing and editing user profile information.
class ProfileScreen extends StatefulWidget {
  /// The user's display name (profile name)
  final String displayName;
  /// The user's profile description
  final String description;
  /// The user's age
  final String age;
  /// The user's preferences
  final String preferences;
  /// Whether the profile must be saved before continuing
  final bool requireSave;
  /// Callback to save the profile (name, description, age, preferences)
  final Future<void> Function(String, String, String, String) onSave;
  /// Callback to continue to the diary page
  final Future<void> Function() onContinue;
  /// Whether the profile is currently in editing mode
  final bool isEditing;
  /// Callback to enter editing mode
  final VoidCallback onEdit;
  /// Callback to cancel editing mode
  final VoidCallback onCancelEdit;

  /// Creates a profile screen.
  const ProfileScreen({
    super.key,
    required this.displayName,
    required this.description,
    required this.age,
    required this.preferences,
    required this.requireSave,
    required this.onSave,
    required this.onContinue,
    required this.isEditing,
    required this.onEdit,
    required this.onCancelEdit,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// State for ProfileScreen, manages controllers and edit/view logic.
class _ProfileScreenState extends State<ProfileScreen> {
  // Controllers for the profile fields
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _ageController;
  late TextEditingController _prefsController;
  // Whether the profile is currently being edited
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial values
    _nameController = TextEditingController(text: widget.displayName);
    _descController = TextEditingController(text: widget.description);
    _ageController = TextEditingController(text: widget.age);
    _prefsController = TextEditingController(text: widget.preferences);
    _editing = widget.requireSave || widget.isEditing;
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers with current values
    _nameController.text = widget.displayName;
    _descController.text = widget.description;
    _ageController.text = widget.age;
    _prefsController.text = widget.preferences;
    _editing = widget.requireSave || widget.isEditing;
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _nameController.dispose();
    _descController.dispose();
    _ageController.dispose();
    _prefsController.dispose();
    super.dispose();
  }

  /// Called when the user taps Save. Validates and triggers onSave callback.
  Future<void> _onSave() async {
    debugPrint('_onSave called');
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final age = _ageController.text.trim();
    final prefs = _prefsController.text.trim();
    debugPrint('name: $name, age: $age, prefs: $prefs');
    if (name.isEmpty || age.isEmpty || prefs.isEmpty) {
      debugPrint('validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    debugPrint('calling onSave');
    try {
      await widget.onSave(name, desc, age, prefs);
      debugPrint('onSave success');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
      setState(() => _editing = false);
    } catch (e) {
      debugPrint('onSave error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  /// Builds the profile screen UI.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile heading
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              // Name field
              TextField(
                controller: _nameController,
                enabled: _editing,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Description field
              TextField(
                controller: _descController,
                enabled: _editing,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Age field
              TextField(
                controller: _ageController,
                enabled: _editing,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Preferences field
              TextField(
                controller: _prefsController,
                enabled: _editing,
                decoration: const InputDecoration(
                  labelText: 'Preferences',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              // Save/cancel or edit button
              if (_editing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _onSave,
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 16),
                    if (!widget.requireSave)
                      OutlinedButton(
                        onPressed: widget.onCancelEdit,
                        child: const Text('Cancel'),
                      ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: widget.onEdit,
                  child: const Text('Edit'),
                ),
              const SizedBox(height: 24),
              // Continue to diary button
              ElevatedButton(
                onPressed: widget.onContinue,
                child: const Text('Continue to Diary'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
