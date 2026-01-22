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
  });


}