import 'package:flutter/material.dart';

// Custom progress bar component for displaying download progress
class ProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height; // Height of the progress bar
  final Color backgroundColor; // Background color of the progress bar
  final Color progressColor; // Color of the progress indicator
  final bool showPercentage; // Whether to show percentage text
  final TextStyle? textStyle; // TextStyle for percentage text
  
  const ProgressBar({
    Key? key,
    required this.progress,
    this.height = 8.0,
    this.backgroundColor = Colors.grey,
    this.progressColor = Colors.blue,
    this.showPercentage = false,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation will be added later
    return Container();
  }
}