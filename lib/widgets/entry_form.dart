import 'package:flutter/material.dart';
import '../models/diary_entry.dart';

Future<void> showDiaryForm({
  required BuildContext context,
  DiaryEntry? existingEntry,
  required Function(DiaryEntry) onSave,
}) async {
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
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'Feeling'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(hintText: 'Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                decoration: const InputDecoration(hintText: 'Enter PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 5,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
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
