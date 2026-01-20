import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A simple freehand drawing canvas screen. The saved drawing is captured
/// as a PNG and the resulting file path is returned to the caller via
/// Navigator.pop(context, savedPath).
class DrawingCanvasScreen extends StatefulWidget {
  const DrawingCanvasScreen({super.key});

  @override
  State<DrawingCanvasScreen> createState() => _DrawingCanvasScreenState();
}

class _DrawingCanvasScreenState extends State<DrawingCanvasScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];
  Color _penColor = Colors.black;
  double _penSize = 4.0;

  Future<String?> _saveToImage() async {
    try {
      final renderObject = _boundaryKey.currentContext?.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) return null;
      final boundary = renderObject;
      final ui.Image image = await boundary.toImage(pixelRatio: ui.window.devicePixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();

      final dir = Directory.systemTemp; // Use system temp so no external package required
      final name = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving drawing: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: () {
              if (_points.isNotEmpty) {
                setState(() {
                  // Remove last stroke (until a null)
                  int i = _points.length - 1;
                  while (i >= 0 && _points[i] != null) {
                    _points.removeAt(i);
                    i--;
                  }
                  // Remove the separator null too
                  if (i >= 0 && _points.isNotEmpty) _points.removeAt(i);
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear',
            onPressed: () => setState(() => _points.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: () async {
              final path = await _saveToImage();
              if (path != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drawing saved')));
                Navigator.of(context).pop(path);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save drawing')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: GestureDetector(
                onPanStart: (details) => setState(() => _points.add(details.localPosition)),
                onPanUpdate: (details) => setState(() => _points.add(details.localPosition)),
                onPanEnd: (_) => setState(() => _points.add(null)),
                child: CustomPaint(
                  painter: _DrawingPainter(points: _points, color: _penColor, strokeWidth: _penSize),
                  child: Container(color: Theme.of(context).scaffoldBackgroundColor),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                const Text('Brush:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 12,
                    value: _penSize,
                    onChanged: (v) => setState(() => _penSize = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.circle, color: Colors.black),
                  onPressed: () => setState(() => _penColor = Colors.black),
                ),
                IconButton(
                  icon: const Icon(Icons.circle, color: Colors.red),
                  onPressed: () => setState(() => _penColor = Colors.red),
                ),
                IconButton(
                  icon: const Icon(Icons.circle, color: Colors.blue),
                  onPressed: () => setState(() => _penColor = Colors.blue),
                ),
                IconButton(
                  icon: const Icon(Icons.circle, color: Colors.green),
                  onPressed: () => setState(() => _penColor = Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;
  _DrawingPainter({required this.points, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      final p = points[i];
      final n = points[i + 1];
      if (p != null && n != null) {
        canvas.drawLine(p, n, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => oldDelegate.points != points;
}
