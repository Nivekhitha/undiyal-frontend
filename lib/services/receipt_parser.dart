class ReceiptParser {
  // Simulated receipt parsing - UI placeholder only
  static Future<Map<String, dynamic>> parseReceipt(String imagePath) async {
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    // Return empty data - force user to enter details
    // In a real app, this would use OCR
    return {
      'amount': null,
      'merchant': '',
      'category': 'Others',
      'date': DateTime.now(),
      'paymentMethod': 'Cash',
      'confidence': 0.0,
    };
  }

  static Future<Map<String, dynamic>> parseReceiptFromCamera() async {
    // Simulate camera capture and parsing
    await Future.delayed(const Duration(seconds: 2));

    return {
      'amount': null,
      'merchant': '',
      'category': 'Others',
      'date': DateTime.now(),
      'paymentMethod': 'Cash',
      'confidence': 0.0,
      'receiptImagePath': null,
    };
  }

  static List<String> suggestMerchants(String query) {
    // Common merchant suggestions
    final merchants = [
      'Starbucks',
      'McDonald\'s',
      'Amazon',
      'Walmart',
      'Target',
      'Uber',
      'Lyft',
      'Netflix',
      'Spotify',
      'Apple Store',
    ];

    if (query.isEmpty) return merchants;

    return merchants
        .where((m) => m.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  static String detectCategory(String merchant) {
    final categoryMap = {
      'starbucks': 'Food & Drink',
      'mcdonalds': 'Food & Drink',
      'amazon': 'Shopping',
      'walmart': 'Groceries',
      'target': 'Shopping',
      'uber': 'Transport',
      'lyft': 'Transport',
      'netflix': 'Entertainment',
      'spotify': 'Entertainment',
      'apple': 'Shopping',
    };

    final key = merchant.toLowerCase();
    for (var entry in categoryMap.entries) {
      if (key.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Others';
  }
}