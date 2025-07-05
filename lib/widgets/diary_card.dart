
// DiaryCard displays a single diary entry with edit and delete actions.
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';

/// A card widget for displaying a diary entry with edit and delete buttons.
class DiaryCard extends StatelessWidget {
  /// The diary entry to display
  final DiaryEntry entry;
  /// Callback when the edit button is pressed
  final VoidCallback onEdit;
  /// Callback when the delete button is pressed
  final VoidCallback onDelete;

  /// Creates a DiaryCard widget.
  const DiaryCard({super.key, required this.entry, required this.onEdit, required this.onDelete});

  /// Builds the diary card UI, showing the entry's title, content, date, and action buttons.
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ListTile(
        // Leading avatar (static image for now)
        leading: const CircleAvatar(
          backgroundImage: AssetImage('assets/images/happy.gif'),
        ),
        // Entry title
        title: Text(entry.title),
        // Entry content and date
        subtitle: Text('${entry.content}\n${entry.date}'),
        isThreeLine: true,
        // Edit and delete buttons
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
