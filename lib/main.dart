import 'package:flutter/material.dart';
import 'app.dart';
import 'utils/logging/log_manager.dart';

void main() {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging system
  LogManager();
  
  // Run the application
  runApp(const MyApp());
}