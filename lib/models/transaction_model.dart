class Transaction {
  static String _normalizeType(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return 'expense';

    // Normalize common synonyms from backend/SMS/legacy data.
    if (v == 'credit' ||
        v == 'cr' ||
        v == 'credited' ||
        v == 'income' ||
        v == 'deposit' ||
        v == 'received') {
      return 'credit';
    }

    if (v == 'expense' ||
        v == 'debit' ||
        v == 'dr' ||
        v == 'debited' ||
        v == 'spent' ||
        v == 'payment') {
      return 'expense';
    }

    return v;
  }

  final String id;
  final double amount;
  final String merchant;
  final String category;
  final DateTime date;
  final String paymentMethod;
  final String status;
  final String? receiptUrl;
  final bool isRecurring;
  final bool isAutoDetected; // True if detected from SMS
  final String? referenceNumber; // SMS transaction reference
  final double? confidenceScore; // AI categorization confidence (0-1)
  final String type; // 'expense' or 'credit'

  Transaction({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.date,
    required this.paymentMethod,
    this.status = 'completed',
    this.receiptUrl,
    this.isRecurring = false,
    this.isAutoDetected = false,
    this.referenceNumber,
    this.confidenceScore,
    String type = 'expense', // Default to expense
  }) : type = _normalizeType(type);

  static bool _isAutoDetectedFromSource(String source) {
    final s = source.trim().toLowerCase();
    return s == 'sms' || s == 'auto' || s == 'notification';
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final merchantValue = (json['merchant'] ??
            json['merchant_name'] ??
            json['business_name'] ??
            'Unknown')
        .toString();
    final categoryValue =
        (json['category'] ?? json['merchant_type'] ?? 'Others').toString();
    final dateValue =
        (json['date'] ?? json['invoice_date'] ?? json['created_at'] ?? '')
            .toString();
    final paymentMethodValue = (json['paymentMethod'] ??
            json['payment_mode'] ??
            json['payment_method'] ??
            'Other')
        .toString();

    DateTime parsedDate = DateTime.now();
    final isoParsed = DateTime.tryParse(dateValue);
    if (isoParsed != null) {
      parsedDate = isoParsed;
    } else {
      // Handle formats like "23-09-25" or "23-09-2025"
      final m = RegExp(r'^(\d{2})-(\d{2})-(\d{2}|\d{4})$')
          .firstMatch(dateValue.trim());
      if (m != null) {
        final day = int.tryParse(m.group(1) ?? '');
        final month = int.tryParse(m.group(2) ?? '');
        final yearRaw = m.group(3) ?? '';
        int? year = int.tryParse(yearRaw);
        if (year != null && year < 100) year += 2000;
        if (day != null && month != null && year != null) {
          parsedDate = DateTime(year, month, day);
        }
      }
    }

    return Transaction(
      id: json['id']?.toString() ?? '',
      amount:
          (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      merchant: merchantValue,
      category: categoryValue,
      date: parsedDate,
      paymentMethod: paymentMethodValue,
      status: (json['status'] ?? json['paid_status'] ?? 'completed').toString(),
      receiptUrl: (json['receiptUrl'] ?? json['receipt_url'])?.toString(),
      isRecurring: json['isRecurring'] ?? false,
      isAutoDetected: json['isAutoDetected'] ??
          _isAutoDetectedFromSource(
              (json['source'] ?? json['entry_source'] ?? '').toString()),
      referenceNumber: json['referenceNumber'],
      confidenceScore: (json['confidenceScore'] is num)
          ? (json['confidenceScore'] as num).toDouble()
          : null,
      type: (json['type'] ??
              json['transaction_type'] ??
              json['transactionType'] ??
              'expense')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final isoDate = date.toIso8601String();
    return {
      'id': id,
      'amount': amount,
      // Canonical app keys
      'merchant': merchant,
      'category': category,
      'date': isoDate,
      'paymentMethod': paymentMethod,

      // Backend/legacy alias keys (harmless if backend ignores unknown fields)
      'merchant_name': merchant,
      'merchant_type': category,
      'invoice_date': isoDate,
      'payment_mode': paymentMethod,
      'status': status,
      'receiptUrl': receiptUrl,
      'receipt_url': receiptUrl,
      'isRecurring': isRecurring,
      'isAutoDetected': isAutoDetected,
      'referenceNumber': referenceNumber,
      'confidenceScore': confidenceScore,
      'type': type,
    };
  }
}
