import 'package:flutter/material.dart';

class ThemeSwitch extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;
  const ThemeSwitch({super.key, required this.isDarkMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.light_mode),
        Switch(
          value: isDarkMode,
          onChanged: onChanged,
        ),
        const Icon(Icons.dark_mode),
      ],
    );
  }
}
