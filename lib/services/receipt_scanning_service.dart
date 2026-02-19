import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service for scanning receipts by sending images to backend
/// Backend handles Gemini API integration and returns structured data
class ReceiptScanningService {
  static const String baseUrl = 'https://undiyal-backend-8zqj.onrender.com';

  /// Scan receipt image by sending it to backend
  /// Backend handles Gemini API integration
  /// Returns extracted data: amount, merchant, date, category, etc.
  static Future<Map<String, dynamic>?> scanReceipt(String imagePath) async {
    debugPrint('=== RECEIPT SCANNING DEBUG START ===');
    
    try {
      // 1. Check file existence
      final file = File(imagePath);
      debugPrint('ReceiptScanning: Image path: $imagePath');
      
      if (!await file.exists()) {
        debugPrint('ReceiptScanning: ERROR - Image file does not exist at path: $imagePath');
        return null;
      }

      // 2. Read image file
      final imageBytes = await file.readAsBytes();
      final imageSizeKB = (imageBytes.length / 1024).round();
      debugPrint('ReceiptScanning: Image size: ${imageSizeKB}KB');

      // 3. Prepare multipart request to backend
      final uri = Uri.parse('$baseUrl/test-gemini');
      debugPrint('ReceiptScanning: Sending request to: $uri');
      
      var request = http.MultipartRequest('POST', uri);
      
      // Add the image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'receipt.jpg',
        ),
      );
      
      debugPrint('ReceiptScanning: Multipart request prepared');

      // 4. Send request
      debugPrint('ReceiptScanning: Sending POST request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ReceiptScanning: ERROR - Request timeout after 30 seconds');
          throw Exception('Request timeout');
        },
      );
      
      // Convert streamed response to regular response
      final response = await http.Response.fromStream(streamedResponse);

      // 6. Process response
      debugPrint('ReceiptScanning: Response received');
      debugPrint('ReceiptScanning: Status Code: ${response.statusCode}');
      debugPrint('ReceiptScanning: Response Headers: ${response.headers}');
      debugPrint('ReceiptScanning: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('ReceiptScanning: JSON parsing successful');
          debugPrint('ReceiptScanning: Parsed data keys: ${data.keys.toList()}');
          
          final result = _parseGeminiResponse(data);
          debugPrint('ReceiptScanning: Parsing complete, extracted data: $result');
          debugPrint('=== RECEIPT SCANNING DEBUG END (SUCCESS) ===');
          return result;
        } catch (e) {
          debugPrint('ReceiptScanning: ERROR - JSON parsing failed: $e');
          debugPrint('ReceiptScanning: Raw response: ${response.body}');
          return null;
        }
      } else {
        debugPrint('ReceiptScanning: ERROR - HTTP ${response.statusCode}');
        debugPrint('ReceiptScanning: Error response: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          debugPrint('ReceiptScanning: Parsed error: $errorData');
        } catch (e) {
          debugPrint('ReceiptScanning: Could not parse error response as JSON');
        }
        
        debugPrint('=== RECEIPT SCANNING DEBUG END (HTTP ERROR) ===');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('ReceiptScanning: ERROR - Exception occurred: $e');
      debugPrint('ReceiptScanning: Stack trace: $stackTrace');
      debugPrint('=== RECEIPT SCANNING DEBUG END (EXCEPTION) ===');
      return null;
    }
  }

  /// Parse Gemini API response into structured data
  static Map<String, dynamic> _parseGeminiResponse(Map<String, dynamic> data) {
    debugPrint('ReceiptScanning: Parsing Gemini response...');
    debugPrint('ReceiptScanning: Raw response data: $data');
    
    // The backend returns a 'result' field with the Gemini text response
    String geminiText = '';
    if (data.containsKey('result')) {
      geminiText = data['result'].toString();
      debugPrint('ReceiptScanning: Found result field: "$geminiText"');
    } else {
      debugPrint('ReceiptScanning: No result field found in response');
      return _getDefaultResult();
    }
    
    // Check if the response is already structured JSON (if backend is updated)
    try {
      final jsonResponse = jsonDecode(geminiText);
      if (jsonResponse is Map<String, dynamic>) {
        debugPrint('ReceiptScanning: Response is structured JSON, parsing directly');
        return _parseStructuredResponse(jsonResponse);
      }
    } catch (e) {
      // Not JSON, continue with text parsing
      debugPrint('ReceiptScanning: Response is text, parsing with regex');
    }
    
    // Parse the text response to extract structured data
    return _parseTextResponse(geminiText);
  }

  /// Parse structured JSON response (if backend is updated to use structured prompts)
  static Map<String, dynamic> _parseStructuredResponse(Map<String, dynamic> jsonData) {
    double? amount;
    String merchant = '';
    String category = 'Others';
    DateTime? date;
    String paymentMethod = 'Cash';

    // Extract from structured response
    if (jsonData.containsKey('total_amount') || jsonData.containsKey('amount') || jsonData.containsKey('total')) {
      final amountStr = (jsonData['total_amount'] ?? jsonData['amount'] ?? jsonData['total'] ?? '').toString();
      amount = double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), ''));
    }

    if (jsonData.containsKey('merchant_name') || jsonData.containsKey('business_name') || jsonData.containsKey('merchant')) {
      merchant = (jsonData['merchant_name'] ?? jsonData['business_name'] ?? jsonData['merchant'] ?? '').toString();
    }

    if (jsonData.containsKey('date')) {
      final dateStr = jsonData['date'].toString();
      date = _parseDate(dateStr);
    }

    if (jsonData.containsKey('category')) {
      category = jsonData['category'].toString();
    }

    if (jsonData.containsKey('payment_method')) {
      paymentMethod = jsonData['payment_method'].toString();
    }

    return {
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'date': date ?? DateTime.now(),
      'paymentMethod': paymentMethod,
      'confidence': 0.9, // High confidence for structured data
      'rawText': jsonData.toString(),
    };
  }

  /// Parse text response using improved regex patterns
  static Map<String, dynamic> _parseTextResponse(String geminiText) {
    double? amount;
    String merchant = '';
    String category = 'Others';
    DateTime? date;
    String paymentMethod = 'Cash';

    // Try to extract amount using multiple regex patterns for Indian receipts
    final amountPatterns = [
      RegExp(r'total\s*:?\s*₹?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'₹\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'rs\.?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'amount\s*:?\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'(\d+(?:,\d{3})*\.\d{2})', caseSensitive: false), // Any decimal amount
    ];
    
    for (final pattern in amountPatterns) {
      final matches = pattern.allMatches(geminiText);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final parsedAmount = double.tryParse(amountStr);
        if (parsedAmount != null && parsedAmount > 0) {
          // Take the largest amount found (likely the total)
          if (amount == null || parsedAmount > amount) {
            amount = parsedAmount;
          }
        }
      }
    }
    debugPrint('ReceiptScanning: Extracted amount: $amount');

    // Try to extract merchant name with better patterns
    final merchantPatterns = [
      RegExp(r'^([A-Z][A-Za-z\s&]+(?:Softwares?|Solutions?|Services?|Pvt\.?\s*Ltd\.?|Ltd\.?|Inc\.?|Corp\.?))', multiLine: true),
      RegExp(r'([A-Z][A-Za-z\s&]{3,30})\s*(?:A/\d+|Ph\.|Phone|Email|TAX)', caseSensitive: false),
      RegExp(r'(?:merchant|store|shop|company|business)\s*:?\s*([^\n,]+)', caseSensitive: false),
      RegExp(r'^([A-Z][A-Za-z\s&]{5,})', multiLine: true), // Any capitalized name at start of line
    ];
    
    for (final pattern in merchantPatterns) {
      final match = pattern.firstMatch(geminiText);
      if (match != null) {
        final extractedMerchant = match.group(1)?.trim() ?? '';
        if (extractedMerchant.isNotEmpty && extractedMerchant.length > merchant.length) {
          merchant = extractedMerchant;
        }
      }
    }
    debugPrint('ReceiptScanning: Extracted merchant: "$merchant"');

    // Try to extract date with Indian date formats
    final datePatterns = [
      RegExp(r'(\d{1,2}[-/]\w{3}[-/]\d{4})', caseSensitive: false), // 21-Feb-2020
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})', caseSensitive: false), // 21/02/2020
      RegExp(r'(?:date|dt)\s*:?\s*(\d{1,2}[-/]\w{3}[-/]\d{4})', caseSensitive: false),
      RegExp(r'(?:date|dt)\s*:?\s*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})', caseSensitive: false),
    ];
    
    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(geminiText);
      if (match != null) {
        final dateStr = match.group(1) ?? '';
        date = _parseDate(dateStr);
        if (date != null) break;
      }
    }

    // Try to extract category based on keywords and business type
    final categoryKeywords = {
      'Food & Drink': ['restaurant', 'cafe', 'dining', 'meal', 'lunch', 'dinner', 'breakfast', 'food', 'hotel', 'dhaba'],
      'Groceries': ['grocery', 'supermarket', 'market', 'vegetables', 'fruits', 'milk', 'kirana', 'provision'],
      'Transport': ['taxi', 'uber', 'ola', 'bus', 'train', 'metro', 'fuel', 'petrol', 'diesel', 'transport'],
      'Shopping': ['shopping', 'mall', 'store', 'clothes', 'fashion', 'garments', 'shirt', 'electronics', 'amazon', 'flipkart', 'retail'],
      'Entertainment': ['movie', 'cinema', 'game', 'entertainment', 'netflix', 'spotify', 'theatre'],
      'Healthcare': ['hospital', 'doctor', 'medicine', 'pharmacy', 'medical', 'clinic', 'health'],
      'Services': ['software', 'services', 'solutions', 'consulting', 'repair', 'maintenance'],
      'Education': ['school', 'college', 'university', 'education', 'training', 'course', 'tuition'],
    };

    final lowerText = geminiText.toLowerCase();
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          category = entry.key;
          debugPrint('ReceiptScanning: Detected category: "$category" (keyword: "$keyword")');
          break;
        }
      }
      if (category != 'Others') break;
    }

    // Try to extract payment method
    if (lowerText.contains('card') || lowerText.contains('credit') || lowerText.contains('debit')) {
      paymentMethod = 'Card';
    } else if (lowerText.contains('upi') || lowerText.contains('paytm') || lowerText.contains('gpay') || lowerText.contains('phonepe')) {
      paymentMethod = 'UPI';
    } else if (lowerText.contains('cash')) {
      paymentMethod = 'Cash';
    }
    debugPrint('ReceiptScanning: Detected payment method: "$paymentMethod"');

    final result = {
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'date': date ?? DateTime.now(),
      'paymentMethod': paymentMethod,
      'confidence': amount != null ? 0.8 : 0.3, // Higher confidence if amount was found
      'rawText': geminiText, // Include raw text for debugging
    };
    
    debugPrint('ReceiptScanning: Final parsed result: $result');
    return result;
  }

  /// Parse date string with multiple format support
  static DateTime? _parseDate(String dateStr) {
    debugPrint('ReceiptScanning: Parsing date: "$dateStr"');
    
    try {
      // Handle different date formats
      if (dateStr.contains(RegExp(r'[A-Za-z]'))) {
        // Handle formats like "21-Feb-2020"
        final parts = dateStr.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final monthStr = parts[1].toLowerCase();
          final year = int.parse(parts[2]);
          
          final monthMap = {
            'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
            'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
          };
          
          final month = monthMap[monthStr.substring(0, 3)];
          if (month != null) {
            final parsedDate = DateTime(year, month, day);
            debugPrint('ReceiptScanning: Successfully parsed date: $parsedDate');
            return parsedDate;
          }
        }
      } else {
        // Handle numeric formats like "21/02/2020"
        final parts = dateStr.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final fullYear = year < 100 ? 2000 + year : year;
          final parsedDate = DateTime(fullYear, month, day);
          debugPrint('ReceiptScanning: Successfully parsed date: $parsedDate');
          return parsedDate;
        }
      }
    } catch (e) {
      debugPrint('ReceiptScanning: Failed to parse date "$dateStr": $e');
    }
    
    return null;
  }

  /// Return default result when parsing fails
  static Map<String, dynamic> _getDefaultResult() {
    return {
      'amount': null,
      'merchant': '',
      'category': 'Others',
      'date': DateTime.now(),
      'paymentMethod': 'Cash',
      'confidence': 0.0,
    };
  }
}
