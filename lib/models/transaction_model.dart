class Transaction {
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
    this.type = 'expense', // Default to expense
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final merchantValue = (json['merchant'] ?? json['merchant_name'] ?? json['business_name'] ?? 'Unknown').toString();
    final categoryValue = (json['category'] ?? json['merchant_type'] ?? 'Others').toString();
    final dateValue = (json['date'] ?? json['invoice_date'] ?? json['created_at'] ?? '').toString();
    final paymentMethodValue = (json['paymentMethod'] ?? json['payment_mode'] ?? json['payment_method'] ?? 'Other').toString();

    return Transaction(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      merchant: merchantValue,
      category: categoryValue,
      date: DateTime.tryParse(dateValue) ?? DateTime.now(),
      paymentMethod: paymentMethodValue,
      status: json['status'] ?? 'completed',
      receiptUrl: (json['receiptUrl'] ?? json['receipt_url'])?.toString(),
      isRecurring: json['isRecurring'] ?? false,
      isAutoDetected: json['isAutoDetected'] ?? false,
      referenceNumber: json['referenceNumber'],
      confidenceScore: (json['confidenceScore'] is num) ? (json['confidenceScore'] as num).toDouble() : null,
      type: json['type'] ?? 'expense',
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