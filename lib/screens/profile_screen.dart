import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final String? displayName;
  final String? description;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final bool requireSave;
  final void Function(String name, String desc)? onSave;
  final VoidCallback? onContinue;
  const ProfileScreen({
    super.key,
    this.displayName,
    this.description,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    this.requireSave = false,
    this.onSave,
    this.onContinue,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _imageFile;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.displayName ?? '';
    _descController.text = widget.description ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File file) async {
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final ref = FirebaseStorage.instance.ref().child('profile_pics/${user.uid}.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.cyan[400],
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.cyan[400],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white,
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null
                          ? const Icon(Icons.person, size: 48, color: Colors.cyan)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isUploading ? const CircularProgressIndicator() : const SizedBox.shrink(),
                  TextButton(
                    onPressed: _imageFile != null ? () async {
                      final url = await _uploadImage(_imageFile!);
                      if (url != null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
                      }
                    } : null,
                    child: const Text('Upload Picture'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 200, left: 24, right: 24),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    widget.onNameChanged(val);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'About Yourself',
                    prefixIcon: Icon(Icons.info_outline),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: widget.onDescriptionChanged,
                ),
                const Spacer(),
                if (widget.requireSave)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canSave && widget.onSave != null
                              ? () => widget.onSave!(_nameController.text.trim(), _descController.text.trim())
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (canSave)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.onSave != null) {
                                widget.onSave!(_nameController.text.trim(), _descController.text.trim());
                              }
                              // Notify parent to switch to diary page
                              if (widget.onContinue != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  widget.onContinue!();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF90CAF9), // Light blue
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                    ],
                  ),
                if (!widget.requireSave)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
