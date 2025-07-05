import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/diary_entry.dart';
import '../db/sql_helper.dart';
import '../widgets/theme_switch.dart';


class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String profileName;
  final String profileDescription;
  final ValueChanged<String> onProfileNameChanged;
  final ValueChanged<String> onProfileDescriptionChanged;
  const HomePage({
    super.key,
    this.isDarkMode = false,
    required this.onThemeChanged,
    required this.profileName,
    required this.profileDescription,
    required this.onProfileNameChanged,
    required this.onProfileDescriptionChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshDiaries();
  }

  Future<void> _refreshDiaries() async {
    final data = await SQLHelper.getDiaries();
    setState(() {
      _entries = data;
      _isLoading = false;
    });
  }

  // Inline add form state
  final _addTitleController = TextEditingController();
  final _addContentController = TextEditingController();
  final _addFormKey = GlobalKey<FormState>();
  bool _adding = false;

  Future<void> _addDiaryInline() async {
    if (!(_addFormKey.currentState?.validate() ?? false)) return;
    setState(() => _adding = true);
    final entry = DiaryEntry(
      title: _addTitleController.text.trim(),
      content: _addContentController.text.trim(),
      date: DateTime.now().toIso8601String(),
    );
    await SQLHelper.createDiary(entry);
    _addTitleController.clear();
    _addContentController.clear();
    setState(() => _adding = false);
    await _refreshDiaries();
  }

  // Diary entry form dialog (bottom sheet, not full screen)
  void showDiaryForm({
    required BuildContext context,
    DiaryEntry? existingEntry,
    required Future<void> Function(DiaryEntry) onSave,
  }) {
    final titleController = TextEditingController(text: existingEntry?.title ?? '');
    final contentController = TextEditingController(text: existingEntry?.content ?? '');
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = existingEntry != null
        ? DateTime.tryParse(existingEntry.date) ?? DateTime.now()
        : DateTime.now();
    String selectedMood = existingEntry?.mood ?? '';
    List<String> selectedTags = List<String>.from(existingEntry?.tags ?? []);
    String? imagePath = existingEntry?.imagePath;
    final List<Map<String, String>> moods = [
      {"emoji": "😄", "value": "happy"},
      {"emoji": "🙂", "value": "meh"},
      {"emoji": "😢", "value": "sad"},
      {"emoji": "😡", "value": "angry"},
      {"emoji": "😎", "value": "rad"},
    ];
    final List<String> presetTags = ["Personal", "Work", "Travel", "Study", "Food", "Plant"];
    final tagController = TextEditingController();

    void pickImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked != null) {
        imagePath = picked.path;
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
        showDiaryForm(
          context: context,
          existingEntry: DiaryEntry(
            id: existingEntry?.id,
            title: titleController.text,
            content: contentController.text,
            date: selectedDate.toIso8601String(),
            mood: selectedMood,
            tags: selectedTags,
            imagePath: imagePath,
          ),
          onSave: onSave,
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existingEntry == null ? 'Add Diary Entry' : 'Edit Diary Entry',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  // Mood/emote picker
                  Text("How are you feeling today?", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: moods.map((m) => GestureDetector(
                      onTap: () => setModalState(() => selectedMood = m["value"]!),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: selectedMood == m["value"] ? Colors.indigo : Colors.grey[200],
                            child: Text(m["emoji"]!, style: const TextStyle(fontSize: 24)),
                          ),
                          if (selectedMood == m["value"])
                            Text("Rad" == m["value"] ? "Rad" : m["value"]!.substring(0,1).toUpperCase() + m["value"]!.substring(1), style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                        ],
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Tag picker
                  Text("Choose a tag for your entry!", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...presetTags.map((tag) => FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (selected) => setModalState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        }),
                      )),
                      ActionChip(
                        label: const Text("Add your own tag!"),
                        onPressed: () async {
                          final tag = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Add Tag"),
                              content: TextField(
                                controller: tagController,
                                decoration: const InputDecoration(hintText: "Enter tag name"),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, tagController.text.trim()), child: const Text("Add")),
                              ],
                            ),
                          );
                          if (tag != null && tag.isNotEmpty) {
                            setModalState(() {
                              selectedTags.add(tag);
                            });
                          }
                          tagController.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Camera/image picker
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: pickImage,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Take Picture"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                      if (imagePath != null) ...[
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(imagePath!), width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => setModalState(() => imagePath = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title/content/date
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Title required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    minLines: 3,
                    maxLines: 6,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Content required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date: \\${selectedDate.year}-\\${selectedDate.month.toString().padLeft(2, '0')}-\\${selectedDate.day.toString().padLeft(2, '0')}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            selectedDate = picked;
                            Navigator.of(context).pop();
                            showDiaryForm(
                              context: context,
                              existingEntry: DiaryEntry(
                                id: existingEntry?.id,
                                title: titleController.text,
                                content: contentController.text,
                                date: selectedDate.toIso8601String(),
                                mood: selectedMood,
                                tags: selectedTags,
                                imagePath: imagePath,
                              ),
                              onSave: onSave,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final newEntry = DiaryEntry(
                              id: existingEntry?.id,
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                              date: selectedDate.toIso8601String(),
                              mood: selectedMood,
                              tags: selectedTags,
                              imagePath: imagePath,
                            );
                            await onSave(newEntry);
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteDiary(int id) async {
    await SQLHelper.deleteDiary(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully deleted a diary!')));
    await _refreshDiaries();
  }

  // Removed calendar state and cleaned up calendar-related code

  List<DiaryEntry> get _filteredEntries => _entries;

  @override
  Widget build(BuildContext context) {
    // Custom background color for diary page
    final bool isDark = widget.isDarkMode;
    final Color diaryBgColor = isDark
        ? const Color(0xFF2D1457) // deep purple for dark mode
        : const Color(0xFFE3F0FF); // light blue for light mode

    return Scaffold(
      appBar: AppBar(
        title: const Text("Diary"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ThemeSwitch(isDarkMode: widget.isDarkMode, onChanged: widget.onThemeChanged),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    colors: [Color(0xFF2D1457), Color(0xFF1A093E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Color(0xFFE3F0FF), Color(0xFFB3D8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Column(
            children: [
              // Add Memory Diary title
              const SizedBox(height: 8),
              Text(
                'Memory Diary',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              // Small user profile section
              FutureBuilder<String?>(
                future: _getProfilePicUrl(),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                              ? NetworkImage(imageUrl)
                              : null,
                          child: (imageUrl == null || imageUrl.isEmpty)
                              ? Icon(Icons.person, color: isDark ? Colors.white : Colors.black, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.profileName.isNotEmpty ? widget.profileName : 'User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Big date and stats at the top
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatsSection(),
                  ],
                ),
              ),
              // Diary entries list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshDiaries,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredEntries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book, size: 80, color: isDark ? Colors.white24 : Colors.black26),
                                  const SizedBox(height: 16),
                                  Text('No diary entries yet!', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 18)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                              itemCount: _filteredEntries.length,
                              itemBuilder: (ctx, i) {
                                final entry = _filteredEntries[i];
                                final entryDate = DateTime.tryParse(entry.date);
                                final moodEmoji = {
                                  "happy": "😄",
                                  "meh": "🙂",
                                  "sad": "😢",
                                  "angry": "😡",
                                  "rad": "😎",
                                }[entry.mood] ?? "";
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Material(
                                    elevation: 1,
                                    borderRadius: BorderRadius.circular(18),
                                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.92),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => showDiaryForm(
                                        context: context,
                                        existingEntry: entry,
                                        onSave: (updated) async {
                                          if (updated.id != null) {
                                            await SQLHelper.updateDiary(updated);
                                          }
                                          await _refreshDiaries();
                                        },
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(18.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Date and mood
                                                Column(
                                                  children: [
                                                    Text(
                                                      entryDate != null ? '${entryDate.day.toString().padLeft(2, '0')}' : '',
                                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.cyanAccent : Colors.indigo),
                                                    ),
                                                    Text(
                                                      entryDate != null ? DateFormat('MMM').format(entryDate) : '',
                                                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
                                                    ),
                                                    if (moodEmoji.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4.0),
                                                        child: Text(moodEmoji, style: const TextStyle(fontSize: 22)),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(width: 18),
                                                // Main content
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        entry.title,
                                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        entry.content,
                                                        style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (entry.tags.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 6.0),
                                                          child: Wrap(
                                                            spacing: 6,
                                                            children: entry.tags.map((tag) => Chip(
                                                              label: Text(tag),
                                                              backgroundColor: isDark ? Colors.deepPurple[700] : Colors.indigo[50],
                                                              labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.cyanAccent : Colors.indigo),
                                                            )).toList(),
                                                          ),
                                                        ),
                                                      if (entry.imagePath != null && entry.imagePath!.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 8.0),
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(12),
                                                            child: Image.file(
                                                              File(entry.imagePath!),
                                                              width: 120,
                                                              height: 120,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.delete_outline, color: isDark ? Colors.red[200] : Colors.redAccent),
                                                  onPressed: () => _deleteDiary(entry.id!),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDiaryForm(
          context: context,
          onSave: (entry) async {
            await SQLHelper.createDiary(entry);
            await _refreshDiaries();
          },
        ),
        child: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- STATS SECTION HELPERS ---
  Widget _buildStatsSection() {
    final totalDiaries = _entries.length;
    final totalWords = _entries.fold<int>(0, (sum, e) => sum + e.content.split(RegExp(r'\s+')).length + e.title.split(RegExp(r'\s+')).length);
    final positive = _entries.where((e) => e.mood == 'happy' || e.mood == 'rad').length;
    final negative = _entries.where((e) => e.mood == 'sad' || e.mood == 'angry').length;
    final bool isDark = widget.isDarkMode;
    final Color mainTextColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    return Column(
      children: [
        const Icon(Icons.menu_book, size: 32, color: Colors.brown),
        Text(
          '$totalDiaries',
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: mainTextColor),
        ),
        Text('Total Diaries', style: TextStyle(fontSize: 18, color: mainTextColor)),
        if (totalDiaries == 0)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text('You need to write your first diary.', style: TextStyle(color: subTextColor)),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCircle(Icons.remove_red_eye, totalWords, 'Total Words', Colors.brown, isDark),
            _buildStatCircle(Icons.sentiment_dissatisfied, negative, 'Negative', Colors.redAccent, isDark),
            _buildStatCircle(Icons.sentiment_satisfied, positive, 'Positive', Colors.green, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCircle(IconData icon, int value, String label, Color color, bool isDark) {
    final Color textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                value: value > 0 ? 1.0 : 0.0,
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
                backgroundColor: color.withOpacity(0.1),
              ),
            ),
            Icon(icon, color: color, size: 28),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }

  // Add this method to _HomePageState:
  Future<String?> _getProfilePicUrl() async {
    try {
      final user = await FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final ref = FirebaseStorage.instance.ref().child('profile_pics/${user.uid}.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
