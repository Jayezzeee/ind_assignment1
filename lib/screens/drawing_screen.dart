// DrawingScreen allows users to create visual diary entries through sketching.
// It provides options to save the drawing as a diary entry with a title.
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../db/sql_helper.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

/// Represents a drawing path with points and color.
class DrawingPath {
  List<Offset> points;
  Color color;
  DrawingPath({required this.points, required this.color});
}

/// The drawing screen for creating visual diary entries.
class DrawingScreen extends StatefulWidget {
  /// Creates a drawing screen.
  final DiaryEntry? existingEntry;
  const DrawingScreen({super.key, this.existingEntry});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

/// State for DrawingScreen, manages the drawing paths and UI.
class _DrawingScreenState extends State<DrawingScreen> {
  // List of completed paths
  final List<DrawingPath> _completedPaths = [];
  // Current path being drawn
  DrawingPath? _currentPath;
  // Current selected color
  Color _currentColor = Colors.black;
  // Controller for title input
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _titleController.text = widget.existingEntry!.title ?? '';
      if (widget.existingEntry!.content != null && widget.existingEntry!.content!.startsWith('Drawing:')) {
        try {
          final jsonStr = widget.existingEntry!.content!.substring(8);
          final data = jsonDecode(jsonStr) as List;
          setState(() {
            _completedPaths.addAll(data.map((item) {
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
            }).toList());
          });
        } catch (e) {
          // Ignore invalid data
        }
      }
    }
  }

  /// Builds a color selection button.
  Widget _colorButton(Color color, {bool isEraser = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isEraser ? Colors.red : (_currentColor == color ? Colors.white : Colors.transparent),
            width: 3,
          ),
        ),
        child: isEraser ? const Icon(Icons.clear, color: Colors.red, size: 20) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eraserColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Drawing',
            onPressed: () async {
              if (_completedPaths.isNotEmpty && _titleController.text.trim().isNotEmpty) {
                // Serialize paths to JSON
                final drawingData = jsonEncode(_completedPaths.map((path) => {
                  'points': path.points.map((o) => {'dx': o.dx, 'dy': o.dy}).toList(),
                  'color': path.color.value,
                }).toList());
                final entry = DiaryEntry(
                  id: widget.existingEntry?.id,
                  title: _titleController.text.trim(),
                  content: 'Drawing:$drawingData', // Prefix to identify as drawing
                  date: widget.existingEntry?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                );
                if (widget.existingEntry != null) {
                  await SQLHelper.updateDiary(entry);
                } else {
                  await SQLHelper.createDiary(entry);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Drawing saved to diary!')),
                  );
                  Navigator.of(context).pop();
                }
              } else if (_titleController.text.trim().isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title.')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please draw something before saving.')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Drawing',
            onPressed: () {
              setState(() {
                _completedPaths.clear();
                _currentPath = null;
              });
            },
          ),
        ],
      ),
      body: Container(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Drawing Title',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            // Color picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  _colorButton(Colors.black),
                  _colorButton(Colors.red),
                  _colorButton(Colors.blue),
                  _colorButton(Colors.green),
                  _colorButton(Colors.yellow),
                  _colorButton(Colors.purple),
                  _colorButton(Colors.orange),
                  _colorButton(eraserColor, isEraser: true), // Use canvas background color
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentPath = DrawingPath(points: [details.localPosition], color: _currentColor);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentPath?.points.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    if (_currentPath != null) {
                      _completedPaths.add(_currentPath!);
                      _currentPath = null;
                    }
                  });
                },
                child: CustomPaint(
                  painter: DrawingPainter(_completedPaths, _currentPath),
                  size: Size.infinite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        final strokeWidth = isEraser ? 10.0 / scale : 5.0 / scale;
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
      final strokeWidth = isEraser ? 10.0 / scale : 5.0 / scale;
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