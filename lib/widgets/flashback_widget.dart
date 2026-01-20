import 'dart:async';
import 'package:flutter/material.dart';
import '../db/sql_helper.dart';
import '../models/diary_entry.dart';

class FlashbackWidget extends StatefulWidget {
  final Duration interval;
  const FlashbackWidget({super.key, this.interval = const Duration(seconds: 15)});

  @override
  State<FlashbackWidget> createState() => _FlashbackWidgetState();
}

class _FlashbackWidgetState extends State<FlashbackWidget> {
  Timer? _timer;
  DiaryEntry? _current;
  List<DiaryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    _entries = await SQLHelper.getDiaries();
    if (_entries.isNotEmpty) _chooseRandom();
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _chooseRandom());
    setState(() {});
  }

  void _chooseRandom() {
    if (_entries.isEmpty) return;
    final idx = DateTime.now().millisecondsSinceEpoch % _entries.length;
    setState(() => _current = _entries[idx]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: ListTile(
        title: Text(current.title ?? 'Untitled'),
        subtitle: Text(
          current.content != null && current.content!.length > 120
              ? '${current.content!.substring(0, 120)}...'
              : (current.content ?? ''),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () {
            // show full entry
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(current.title ?? 'Untitled'),
                content: SingleChildScrollView(child: Text(current.content ?? '')),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            );
          },
        ),
      ),
    );
  }
}
