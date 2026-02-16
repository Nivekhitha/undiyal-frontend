import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/app_init_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }
  
  // Initialize app services (SMS detection, notifications, etc.)
  await AppInitService.initialize();

  runApp(const UndiyalApp());
}
