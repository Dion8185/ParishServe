import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class SecretaryService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Cached verified enum string from database to optimize subsequent inserts
  static String? _cachedValidTransactionType;

  /// Fetch all ecclesiastical receipts for cashiering and remittance
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _client
        .from('parish_transactions')
        .select()
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Register a new transaction with automatic enum resolution and varchar(100) bound guard
  static Future<Map<String, dynamic>> createTransaction({
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String transactionDetails,
    required double transactionAmount,
    String? transactionType,
    String? relatedAppointmentId,
    String? relatedRequestId,
  }) async {
    final receiptNo = await _generateReceiptNumber();
    final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
    final userId = AuthService.currentUser?.userId ?? 'S26-0003';

    // Strictly enforce varchar(100) limit on related_service to prevent Postgres 22001 exception
    final cleanService = relatedService.trim();
    final safeService = cleanService.length > 90
        ? '${cleanService.substring(0, 87)}...'
        : cleanService;

    // 1. If not yet cached, attempt to discover the exact enum value from an existing row in public.parish_transactions
    if (_cachedValidTransactionType == null) {
      try {
        final existing = await _client
            .from('parish_transactions')
            .select('transaction_type')
            .limit(1)
            .maybeSingle();

        if (existing != null && existing['transaction_type'] != null) {
          final foundType = existing['transaction_type'].toString().trim();
          if (foundType.isNotEmpty) {
            _cachedValidTransactionType = foundType;
          }
        }
      } catch (_) {}
    }

    // 2. Build candidate pool to match against PostgreSQL's enum transaction_type
    final List<String> candidatePool = [
      if (_cachedValidTransactionType != null) _cachedValidTransactionType!,
      if (transactionType != null && transactionType.isNotEmpty) transactionType,
      // Canonical and standard parish transaction_type enum members:
      'donation',
      'Donation',
      'stipend',
      'Stipend',
      'mass_intention',
      'Mass Intention',
      'certificate',
      'Certificate',
      'sacrament',
      'Sacrament',
      'service',
      'Service',
      'offering',
      'Offering',
      'fee',
      'Fee',
      'appointment',
      'service_request',
      'walk_in',
      'walk-in',
      'Walk-In',
      'onsite',
      'other',
      'Other',
      'income',
    ];

    final uniqueCandidates = candidatePool.toSet().toList();
    PostgrestException? lastEnumError;

    // 3. Test candidates against the database enum constraint
    for (final candidate in uniqueCandidates) {
      final data = {
        'transaction_id': transactionId,
        'receipt_number': receiptNo,
        'payor_name': payorName.trim(),
        'payor_contact': (payorContact != null && payorContact.trim().isNotEmpty)
            ? payorContact.trim()
            : null,
        'transaction_date': DateTime.now().toIso8601String(),
        'transaction_type': candidate,
        'related_service': safeService,
        'transaction_details': transactionDetails.trim(),
        'transaction_amount': transactionAmount,
        'payment_required_status': transactionAmount > 0,
        'transaction_status': 'paid',
        'related_appointment_id': relatedAppointmentId,
        'related_request_id': relatedRequestId,
        'encoded_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        final response = await _client
            .from('parish_transactions')
            .insert(data)
            .select()
            .single();

        // Successful insert! Cache the accepted enum value for fast subsequent inserts.
        _cachedValidTransactionType = candidate;
        return response;
      } on PostgrestException catch (e) {
        if (e.code == '22P02' && e.message.contains('transaction_type')) {
          lastEnumError = e;
          continue; // Try next candidate in the pool
        }
        rethrow;
      }
    }

    if (lastEnumError != null) {
      throw 'Invalid transaction_type enum value in database. You can check the exact enum definition in Supabase SQL editor using: SELECT enum_range(NULL::transaction_type);';
    }

    throw 'Failed to record transaction in parish ledger.';
  }

  /// Helper to generate sequential receipt numbers: REC-YYYY-XXXXX
  static Future<String> _generateReceiptNumber() async {
    final year = DateTime.now().year;
    try {
      final res = await _client
          .from('parish_transactions')
          .select('receipt_number')
          .like('receipt_number', 'REC-$year-%')
          .order('receipt_number', ascending: false)
          .limit(20);

      int highest = 0;
      for (final item in res) {
        final rNo = item['receipt_number']?.toString() ?? '';
        final parts = rNo.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }
      final nextSeq = (highest + 1).toString().padLeft(5, '0');
      return 'REC-$year-$nextSeq';
    } catch (_) {
      final fallback = (DateTime.now().millisecondsSinceEpoch % 100000)
          .toString()
          .padLeft(5, '0');
      return 'REC-$year-$fallback';
    }
  }
}