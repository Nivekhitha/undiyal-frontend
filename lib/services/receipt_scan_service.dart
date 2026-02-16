import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

/// Simple wrapper for calling Gemini/OpenAI-like OCR for receipt scanning.
/// The user will paste an API key into `setApiKey` or set the `GEMINI_API_KEY`
/// environment variable. This is intentionally minimal; expand as needed.
class ReceiptScanService {
  // Default placeholder API key. Replace with your real key in code
  // or call `ReceiptScanService.setApiKey("YOUR_REAL_KEY")` at startup.
  static String _apiKey = 'YOUR_API_KEY';
  // Default endpoint - can be overridden if needed
  static String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static String _model = 'gemini-3';

  /// Set API key at runtime (user will paste this key)
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Optionally set model name (e.g. 'gemini-3')
  static void setModel(String model) {
    _model = model;
  }

  /// Optionally set endpoint for chat/completion requests
  static void setEndpoint(String endpoint) {
    _endpoint = endpoint;
  }

  /// Scan a receipt image file and return parsed text (raw) and optionally
  /// structured result. This example returns the raw OCR text.
  static Future<Map<String, dynamic>> scanReceiptFromFile(File image) async {
    // If the API key is still the placeholder or empty, try loading from
    // a local .env file under the key `GEMINI_API_KEY` (or `RECEIPT_API_KEY`).
    if (_apiKey.isEmpty || _apiKey == 'YOUR_API_KEY') {
      try {
        await dotenv.dotenv.load(fileName: '.env');
        final envKey = dotenv.dotenv.env['GEMINI_API_KEY'] ?? dotenv.dotenv.env['RECEIPT_API_KEY'];
        if (envKey != null && envKey.isNotEmpty) {
          _apiKey = envKey;
        }
      } catch (_) {
        // ignore errors loading .env
      }
    }

    if (_apiKey.isEmpty || _apiKey == 'YOUR_API_KEY') {
      throw Exception('API key not set. Set GEMINI_API_KEY in .env or call ReceiptScanService.setApiKey()');
    }

    // Default: call the chat/completions endpoint by embedding image as base64
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse(_endpoint);
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a helpful assistant that extracts structured data from receipt images.\nRespond ONLY with a JSON object containing keys: merchant, amount, date (ISO 8601 or YYYY-MM-DD), and raw_text. Do not add any explanatory text.'
        },
        {
          'role': 'user',
          'content': 'Here is a base64-encoded image of the receipt: "data:image/jpeg;base64,$base64Image"\nExtract merchant name, total amount, and date from the receipt and output as JSON.'
        }
      ],
      'temperature': 0.0,
      'max_tokens': 800,
    });

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      try {
        final Map<String, dynamic> json = jsonDecode(resp.body);
        return {'success': true, 'data': json};
      } catch (e) {
        return {'success': true, 'data': resp.body};
      }
    } else {
      return {'success': false, 'status': resp.statusCode, 'body': resp.body};
    }
  }
}
