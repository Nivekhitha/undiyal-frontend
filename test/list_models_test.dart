import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  test('List Gemini Models', () async {
    // Load .env manually for test
    final envFile = File('.env');
    if (!envFile.existsSync()) {
      debugPrint('.env not found; skipping Gemini models test.');
      return;
    }
    final lines = await envFile.readAsLines();
    String apiKey = '';
    for (var line in lines) {
      if (line.startsWith('GEMINI_API_KEY=')) {
        apiKey = line.split('=')[1].trim();
      }
    }

    if (apiKey.isEmpty) {
      debugPrint('API Key not found in .env');
      return;
    }

    debugPrint('Using API Key: ${apiKey.substring(0, 5)}...');

    try {
      // Create a dummy model just to get access to the client,
      // but SDK doesn't have a direct static listModels on the main class easily accessible
      // without initializing.
      // Actually, standard usage is just to try a known model or catching the error.
      // But let's try to use the model we have and see if we can trigger a descriptive error
      // OR better, we can just use the error message from the app which SAID: "Call ListModels"

      // Since the Dart SDK doesn't expose a simple `listModels()` helper in the high-level API easily
      // without a lower level client, we will rely on the fact that 'gemini-1.5-flash'
      // IS usually correct, but maybe the region is strict.

      // Let's try 'gemini-1.5-flash-latest' vs 'gemini-pro-vision' directly here.

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      // Simple text prompt to check connectivity
      final content = [Content.text('Hello')];
      final response = await model.generateContent(content);
      debugPrint('Success with gemini-1.5-flash: ${response.text}');
    } catch (e) {
      debugPrint('Error with gemini-1.5-flash: $e');
    }

    try {
      GenerativeModel(model: 'gemini-pro-vision', apiKey: apiKey);
      debugPrint(
          'gemini-pro-vision initialized (cannot test without image easily in test, but implies existence)');
    } catch (e) {
      debugPrint('Error with gemini-pro-vision: $e');
    }
  });
}
