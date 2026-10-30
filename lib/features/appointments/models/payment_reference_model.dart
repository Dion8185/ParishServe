class PaymentReferenceModel {
  final String referenceId;
  final String referenceNumber;
  final double amount;
  final DateTime? paymentDate;
  final String paymentMethod;
  final String status; // 'unused', 'used', 'voided', 'archived'
  final String? usedInTransactionId;
  final String? usedInIntentionId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentReferenceModel({
    required this.referenceId,
    required this.referenceNumber,
    this.amount = 0.0,
    this.paymentDate,
    this.paymentMethod = 'GCash',
    this.status = 'unused',
    this.usedInTransactionId,
    this.usedInIntentionId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isUsed => status.toLowerCase() == 'used';
  bool get isUnused => status.toLowerCase() == 'unused';

  String get formattedDate {
    if (paymentDate == null) return 'No Date';
    final d = paymentDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get formattedAmount {
    return '₱ ${amount.toStringAsFixed(2)}';
  }

  factory PaymentReferenceModel.fromMap(Map<String, dynamic> map) {
    return PaymentReferenceModel(
      referenceId: map['reference_id']?.toString() ?? '',
      referenceNumber: map['reference_number']?.toString().trim() ?? '',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      paymentDate: map['payment_date'] != null
          ? DateTime.tryParse(map['payment_date'].toString())
          : null,
      paymentMethod: map['payment_method']?.toString() ?? 'GCash',
      status: map['status']?.toString() ?? 'unused',
      usedInTransactionId: map['used_in_transaction_id']?.toString(),
      usedInIntentionId: map['used_in_intention_id']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (referenceId.isNotEmpty) 'reference_id': referenceId,
      'reference_number': referenceNumber.trim(),
      'amount': amount,
      'payment_date': paymentDate?.toIso8601String(),
      'payment_method': paymentMethod,
      'status': status,
      'used_in_transaction_id': usedInTransactionId,
      'used_in_intention_id': usedInIntentionId,
      'created_by': createdBy,
    };
  }

  PaymentReferenceModel copyWith({
    String? referenceId,
    String? referenceNumber,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? status,
    String? usedInTransactionId,
    String? usedInIntentionId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentReferenceModel(
      referenceId: referenceId ?? this.referenceId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      usedInTransactionId: usedInTransactionId ?? this.usedInTransactionId,
      usedInIntentionId: usedInIntentionId ?? this.usedInIntentionId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}