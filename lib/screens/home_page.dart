// HomePage displays the main diary UI, including diary entries, stats, and profile info.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/diary_entry.dart';
import '../db/sql_helper.dart';
import '../widgets/theme_switch.dart';
import 'dart:convert';
import 'drawing_screen.dart';


/// The main diary page, showing diary entries, stats, and user profile info.
class HomePage extends StatefulWidget {
  /// Whether dark mode is enabled
  final bool isDarkMode;
  /// Callback to toggle dark mode
  final ValueChanged<bool> onThemeChanged;
  /// The user's profile name
  final String profileName;
  /// The user's profile description
  final String profileDescription;
  /// Callback for profile name change (not used here)
  final ValueChanged<String> onProfileNameChanged;
  /// Callback for profile description change (not used here)
  final ValueChanged<String> onProfileDescriptionChanged;
  /// Creates a HomePage (main diary page).
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

/// State for HomePage, manages diary entries, loading, and UI state.
class _HomePageState extends State<HomePage> {
  // List of diary entries
  List<DiaryEntry> _entries = [];
  // List of flashback entries
  List<DiaryEntry> _flashbackEntries = [];
  // Whether diary entries are loading
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load diary entries on start
    _refreshDiaries().then((_) => _loadFlashback());
  }

  /// Loads diary entries from the local database.
  Future<void> _refreshDiaries() async {
    final data = await SQLHelper.getDiaries();
    setState(() {
      _entries = data;
      _isLoading = false;
    });
  }

  /// Loads flashback entries for the current date.
  Future<void> _loadFlashback() async {
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = await SQLHelper.getFlashbackEntries(currentDate);
    setState(() {
      _flashbackEntries = data;
    });
  }

  /// Shows the diary entry form as a modal bottom sheet.
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

    // Picks an image from the camera and updates the form.
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

    // Show the modal bottom sheet for the diary form
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
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
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

  /// Deletes a diary entry by id and refreshes the list.
  void _deleteDiary(int id) async {
    await SQLHelper.deleteDiary(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully deleted a diary!')));
    await _refreshDiaries();
  }

  // Removed calendar state and cleaned up calendar-related code

  /// Returns the filtered list of diary entries (all for now).
  List<DiaryEntry> get _filteredEntries => _entries;

  /// Builds the main diary page UI.
  @override
  Widget build(BuildContext context) {
    // Custom background color for diary page
    final bool isDark = widget.isDarkMode;

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
                ? const LinearGradient(
                    colors: [Color(0xFF2D1457), Color(0xFF1A093E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
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
              // Flashback memory reminder
              if (_flashbackEntries.isNotEmpty) _buildFlashbackCard(),
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
                                final isDrawing = entry.content?.startsWith('Drawing:') ?? false;
                                List<DrawingPath> drawingPaths = [];
                                if (isDrawing) {
                                  try {
                                    final jsonStr = entry.content!.substring(8);
                                    final data = jsonDecode(jsonStr) as List;
                                    drawingPaths = data.map((item) {
                                      if (item is Map) {
                                        // New format
                                        final points = (item['points'] as List).map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble())).toList();
                                        final color = Color(item['color'] as int);
                                        return DrawingPath(points: points, color: color);
                                      } else if (item is List) {
                                        // Old format
                                        final points = (item).map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble())).toList();
                                        return DrawingPath(points: points, color: Colors.black);
                                      } else {
                                        throw Exception('Invalid drawing data');
                                      }
                                    }).toList();
                                  } catch (e) {
                                    // Ignore invalid data
                                  }
                                }
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
                                      onTap: () {
                                        if (isDrawing) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (context) => DrawingScreen(existingEntry: entry)),
                                          ).then((_) => _refreshDiaries());
                                        } else {
                                          showDiaryForm(
                                            context: context,
                                            existingEntry: entry,
                                            onSave: (updated) async {
                                              if (updated.id != null) {
                                                await SQLHelper.updateDiary(updated);
                                              }
                                              await _refreshDiaries();
                                            },
                                          );
                                        }
                                      },
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
                                                      entryDate != null ? entryDate.day.toString().padLeft(2, '0') : '',
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
                                                        entry.title ?? 'Untitled',
                                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        isDrawing ? 'Drawing Entry' : entry.content ?? '',
                                                        style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (isDrawing && drawingPaths.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 8.0),
                                                          child: Container(
                                                            height: 80,
                                                            width: double.infinity,
                                                            decoration: BoxDecoration(
                                                              border: Border.all(color: Colors.grey),
                                                              borderRadius: BorderRadius.circular(8),
                                                              color: Colors.white,
                                                            ),
                                                            child: CustomPaint(
                                                              painter: DrawingPainter(drawingPaths, null),
                                                            ),
                                                          ),
                                                        ),
                                                      if (entry.tags != null && entry.tags!.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 6.0),
                                                          child: Wrap(
                                                            spacing: 6,
                                                            children: entry.tags!.map((tag) => Chip(
                                                                 label: Text(tag),
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
        backgroundColor: Colors.indigo,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- STATS SECTION HELPERS ---
  /// Builds the stats section at the top of the diary page.
  Widget _buildStatsSection() {
    final totalDiaries = _entries.length;
    final totalWords = _entries.fold<int>(0, (sum, e) {
      final contentWords = (e.content ?? '').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      final titleWords = (e.title ?? '').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      return sum + contentWords + titleWords;
    });
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

  /// Builds a circular stat widget for the stats section.
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
  /// Builds the flashback memory reminder card.
  Widget _buildFlashbackCard() {
    final randomEntry = (_flashbackEntries..shuffle()).first;
    final entryDate = DateTime.tryParse(randomEntry.date);
    final yearsAgo = DateTime.now().year - (entryDate?.year ?? DateTime.now().year);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On this day $yearsAgo year${yearsAgo != 1 ? 's' : ''} ago...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              randomEntry.title ?? 'Untitled',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              randomEntry.content ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Gets the user's profile picture URL from Firebase Storage, if available.
  Future<String?> _getProfilePicUrl() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final ref = FirebaseStorage.instance.ref().child('profile_pics/${user.uid}.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}

/// Custom painter for drawing the paths.
class DrawingPainter extends CustomPainter {
  final List<DrawingPath> completedPaths;
  final DrawingPath? currentPath;

  DrawingPainter(this.completedPaths, this.currentPath);

  @override
  void paint(Canvas canvas, Size size) {
    if (completedPaths.isEmpty && currentPath == null) return;

    // Find bounds
    double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final path in completedPaths) {
      for (final offset in path.points) {
        minX = minX < offset.dx ? minX : offset.dx;
        minY = minY < offset.dy ? minY : offset.dy;
        maxX = maxX > offset.dx ? maxX : offset.dx;
        maxY = maxY > offset.dy ? maxY : offset.dy;
      }
    }
    if (currentPath != null) {
      for (final offset in currentPath!.points) {
        minX = minX < offset.dx ? minX : offset.dx;
        minY = minY < offset.dy ? minY : offset.dy;
        maxX = maxX > offset.dx ? maxX : offset.dx;
        maxY = maxY > offset.dy ? maxY : offset.dy;
      }
    }

    final drawingWidth = maxX - minX;
    final drawingHeight = maxY - minY;
    if (drawingWidth <= 0 || drawingHeight <= 0) return;

    final scaleX = size.width / drawingWidth;
    final scaleY = size.height / drawingHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    canvas.save();
    canvas.translate(-minX * scale, -minY * scale);
    canvas.scale(scale);

    for (final path in completedPaths) {
      if (path.points.length > 1) {
        final isEraser = path.color.value == 0xFFF5F5F5 || path.color.value == 0xFF212121;
        final strokeWidth = isEraser ? 6.0 / scale : 3.0 / scale;
        final paint = Paint()
          ..color = path.color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final Path drawPath = Path();
        drawPath.moveTo(path.points[0].dx, path.points[0].dy);
        for (int i = 1; i < path.points.length; i++) {
          drawPath.lineTo(path.points[i].dx, path.points[i].dy);
        }
        canvas.drawPath(drawPath, paint);
      }
    }

    if (currentPath != null && currentPath!.points.length > 1) {
      final isEraser = currentPath!.color.value == 0xFFF5F5F5 || currentPath!.color.value == 0xFF212121;
      final strokeWidth = isEraser ? 6.0 / scale : 3.0 / scale;
      final paint = Paint()
        ..color = currentPath!.color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final Path drawPath = Path();
      drawPath.moveTo(currentPath!.points[0].dx, currentPath!.points[0].dy);
      for (int i = 1; i < currentPath!.points.length; i++) {
        drawPath.lineTo(currentPath!.points[i].dx, currentPath!.points[i].dy);
      }
      canvas.drawPath(drawPath, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
