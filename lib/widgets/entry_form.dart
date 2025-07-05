
// showDiaryForm displays a modal bottom sheet for creating or editing a diary entry.
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';


/// Shows a modal bottom sheet for creating or editing a diary entry.
/// Requires a correct PIN (12345) to save.
Future<void> showDiaryForm({
  required BuildContext context,
  DiaryEntry? existingEntry,
  required Function(DiaryEntry) onSave,
}) async {
  // Controllers for the entry fields
  final titleController = TextEditingController(text: existingEntry?.title ?? '');
  final contentController = TextEditingController(text: existingEntry?.content ?? '');
  final pinController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: MediaQuery.of(ctx).viewInsets,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Feeling (title) field
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'Feeling'),
              ),
              const SizedBox(height: 8),
              // Description/content field
              TextField(
                controller: contentController,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(height: 8),
              // PIN field (required to save)
              TextField(
                controller: pinController,
                decoration: const InputDecoration(hintText: 'Enter PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 5,
              ),
              const SizedBox(height: 16),
              // Save/Create button
              ElevatedButton(
                onPressed: () {
                  // Only allow save if PIN is correct
                  if (pinController.text == '12345') {
                    onSave(DiaryEntry(
                      id: existingEntry?.id,
                      title: titleController.text,
                      content: contentController.text,
                      date: DateTime.now().toIso8601String().split("T")[0],
                    ));
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Incorrect PIN. Please try again.')),
                    );
                  }
                },
                child: Text(existingEntry == null ? 'Create New' : 'Update'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
