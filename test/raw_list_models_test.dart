import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Raw List Gemini Models', () async {
    final envFile = File('.env');
    if (!envFile.existsSync()) {
      debugPrint('.env not found; skipping raw Gemini models test.');
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

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
    debugPrint('Querying: $url');

    final response = await http.get(url);
    debugPrint('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final models = json['models'] as List;
      final file = File('models_output.txt');
      var content = '\n\n--- AVAILABLE MODELS ---\n';
      for (var model in models) {
        if (model['supportedGenerationMethods'].contains('generateContent')) {
          content += 'NAME: ${model['name']}\n';
          content +=
              '   Short: ${model['name'].toString().replaceAll('models/', '')}\n';
          content += '-------------------------\n';
        }
      }
      content += '--- END LIST ---\n\n';
      await file.writeAsString(content);
      debugPrint('Output received and saved to models_output.txt');
    } else {
      debugPrint('Error: ${response.body}');
    }
  });
}
