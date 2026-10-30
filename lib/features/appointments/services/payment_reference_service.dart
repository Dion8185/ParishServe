import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/payment_reference_model.dart';

class PaymentReferenceImportResult {
  final int totalParsed;
  final int insertedCount;
  final int duplicateCount;
  final List<String> errors;

  const PaymentReferenceImportResult({
    required this.totalParsed,
    required this.insertedCount,
    required this.duplicateCount,
    this.errors = const [],
  });

  int get successCount => insertedCount;
}

class PaymentReferenceService {
  PaymentReferenceService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Normalizes reference numbers for comparison (removes spaces, dashes, and special characters)
  static String normalizeRef(String ref) {
    return ref.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim().toUpperCase();
  }

  /// Fetches payment references with status and search filtering
  static Future<List<PaymentReferenceModel>> getReferences({
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('payment_references').select();

      if (statusFilter != null && statusFilter.toLowerCase() != 'all') {
        query = query.eq('status', statusFilter.toLowerCase());
      }

      final response = await query.order('created_at', ascending: false);
      var list = (response as List)
          .map((row) => PaymentReferenceModel.fromMap(row as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = normalizeRef(searchQuery);
        list = list.where((item) {
          final norm = normalizeRef(item.referenceNumber);
          return norm.contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('[PaymentReferenceService] Error fetching references: $e');
      return [];
    }
  }

  /// Direct compatibility alias for manage_payment_references_dialog.dart
  static Future<List<PaymentReferenceModel>> fetchPaymentReferences({
    String? statusFilter,
    String? searchQuery,
  }) {
    return getReferences(statusFilter: statusFilter, searchQuery: searchQuery);
  }

  /// Adds a verified GCash payment reference with duplicate checking and robust error handling
  static Future<PaymentReferenceModel> addReference({
    required String referenceNumber,
    required double amount,
    DateTime? paymentDate,
    String paymentMethod = 'GCash',
  }) async {
    final cleanRef = referenceNumber.trim();
    if (cleanRef.isEmpty) {
      throw 'Reference number is required.';
    }
    if (amount <= 0) {
      throw 'Amount must be greater than zero.';
    }

    final currentUserId = AuthService.currentUser?.userId;

    final payload = {
      'reference_number': cleanRef,
      'amount': amount,
      'payment_date': (paymentDate ?? DateTime.now()).toIso8601String(),
      'payment_method': paymentMethod.trim().isEmpty ? 'GCash' : paymentMethod.trim(),
      'status': 'unused',
      if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _client
          .from('payment_references')
          .insert(payload)
          .select()
          .single();

      return PaymentReferenceModel.fromMap(res);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw 'Reference number "$cleanRef" is already registered in the parish ledger.';
      }
      throw e.message;
    } catch (e) {
      debugPrint('[PaymentReferenceService] Error adding reference: $e');
      rethrow;
    }
  }

  /// Direct compatibility alias for manage_payment_references_dialog.dart
  static Future<PaymentReferenceModel> addPaymentReference({
    required String referenceNumber,
    required double amount,
    DateTime? paymentDate,
    String paymentMethod = 'GCash',
  }) {
    return addReference(
      referenceNumber: referenceNumber,
      amount: amount,
      paymentDate: paymentDate,
      paymentMethod: paymentMethod,
    );
  }

  /// Finds an existing unused payment reference matching a reference number and optional amount
  static Future<PaymentReferenceModel?> findMatchingReference({
    required String referenceNumber,
    double? expectedAmount,
  }) async {
    final targetNorm = normalizeRef(referenceNumber);
    if (targetNorm.isEmpty) return null;

    try {
      final res = await _client
          .from('payment_references')
          .select()
          .order('created_at', ascending: false);

      for (final row in res as List) {
        final model = PaymentReferenceModel.fromMap(row as Map<String, dynamic>);
        final candidateNorm = normalizeRef(model.referenceNumber);

        if (candidateNorm == targetNorm ||
            (candidateNorm.length >= 10 && targetNorm.contains(candidateNorm)) ||
            (targetNorm.length >= 10 && candidateNorm.contains(targetNorm))) {
          if (expectedAmount != null && expectedAmount > 0) {
            if ((model.amount - expectedAmount).abs() < 0.01) {
              return model;
            }
          } else {
            return model;
          }
        }
      }
    } catch (e) {
      debugPrint('[PaymentReferenceService] Error finding matching reference: $e');
    }
    return null;
  }

  /// Marks a reference as used by a specific Mass Intention or Transaction
  static Future<void> markAsUsed({
    required String referenceId,
    required String intentionId,
    String? transactionId,
  }) async {
    try {
      await _client.from('payment_references').update({
        'status': 'used',
        'used_in_intention_id': intentionId,
        if (transactionId != null) 'used_in_transaction_id': transactionId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('reference_id', referenceId);
    } catch (e) {
      debugPrint('[PaymentReferenceService] Error marking reference as used: $e');
      rethrow;
    }
  }

  /// Releases a reference back to 'unused' status when an intention is rejected or cancelled
  static Future<void> releaseReference(String referenceId) async {
    try {
      await _client.from('payment_references').update({
        'status': 'unused',
        'used_in_intention_id': null,
        'used_in_transaction_id': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('reference_id', referenceId);
    } catch (e) {
      debugPrint('[PaymentReferenceService] Error releasing reference: $e');
    }
  }

  /// Deletes an unused payment reference entry
  static Future<void> deleteReference(String referenceId) async {
    try {
      await _client
          .from('payment_references')
          .delete()
          .eq('reference_id', referenceId);
    } catch (e) {
      debugPrint('[PaymentReferenceService] Error deleting reference: $e');
      rethrow;
    }
  }

  /// Direct compatibility alias for manage_payment_references_dialog.dart
  static Future<void> deletePaymentReference(String referenceId) {
    return deleteReference(referenceId);
  }

  /// Flexible bulk importer supporting both CSV string content and List of Map entries
  static Future<PaymentReferenceImportResult> bulkImportPaymentReferences(dynamic data) async {
    if (data is String) {
      return importFromCsv(data);
    }

    if (data is List) {
      int total = 0;
      int inserted = 0;
      int duplicates = 0;
      final List<String> errorList = [];
      final currentUserId = AuthService.currentUser?.userId;

      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is! Map) continue;

        total++;
        final rawRef = (item['reference_number'] ??
            item['referenceNumber'] ??
            item['reference_no'] ??
            item['ref_no'])
            ?.toString()
            .trim() ??
            '';
        if (rawRef.isEmpty) continue;

        final rawAmt = item['amount'] ?? item['stipend_amount'] ?? item['total_amount'];
        final double amt = rawAmt != null
            ? (double.tryParse(rawAmt
            .toString()
            .replaceAll('₱', '')
            .replaceAll('P', '')
            .replaceAll(',', '')
            .trim()) ??
            0.0)
            : 0.0;

        DateTime? date;
        final rawDate = item['payment_date'] ?? item['paymentDate'] ?? item['date'];
        if (rawDate != null) {
          date = DateTime.tryParse(rawDate.toString().trim());
        }
        date ??= DateTime.now();

        final method = (item['payment_method'] ?? item['paymentMethod'])?.toString().trim();

        try {
          await _client.from('payment_references').insert({
            'reference_number': rawRef,
            'amount': amt,
            'payment_date': date.toIso8601String(),
            'payment_method': (method != null && method.isNotEmpty) ? method : 'GCash',
            'status': 'unused',
            if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          inserted++;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            duplicates++;
          } else {
            errorList.add('Item ${i + 1}: ${e.message}');
          }
        } catch (err) {
          errorList.add('Item ${i + 1}: $err');
        }
      }

      return PaymentReferenceImportResult(
        totalParsed: total,
        insertedCount: inserted,
        duplicateCount: duplicates,
        errors: errorList,
      );
    }

    return const PaymentReferenceImportResult(
      totalParsed: 0,
      insertedCount: 0,
      duplicateCount: 0,
    );
  }

  /// Imports payment references from CSV text
  static Future<PaymentReferenceImportResult> importFromCsv(String csvContent) async {
    final lines = const LineSplitter().convert(csvContent);
    int total = 0;
    int inserted = 0;
    int duplicates = 0;
    final List<String> errorList = [];

    final currentUserId = AuthService.currentUser?.userId;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (i == 0 && (line.toLowerCase().contains('reference') || line.toLowerCase().contains('ref'))) {
        continue;
      }

      final parts = line.split(',');
      if (parts.isEmpty) continue;

      total++;
      final rawRef = parts[0].replaceAll('"', '').trim();
      if (rawRef.isEmpty) continue;

      double amt = 0.0;
      if (parts.length > 1) {
        amt = double.tryParse(parts[1].replaceAll('"', '').replaceAll('₱', '').replaceAll('P', '').trim()) ?? 0.0;
      }

      DateTime? date;
      if (parts.length > 2) {
        date = DateTime.tryParse(parts[2].replaceAll('"', '').trim());
      }
      date ??= DateTime.now();

      try {
        await _client.from('payment_references').insert({
          'reference_number': rawRef,
          'amount': amt,
          'payment_date': date.toIso8601String(),
          'payment_method': 'GCash',
          'status': 'unused',
          if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        inserted++;
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          duplicates++;
        } else {
          errorList.add('Line ${i + 1}: ${e.message}');
        }
      } catch (err) {
        errorList.add('Line ${i + 1}: $err');
      }
    }

    return PaymentReferenceImportResult(
      totalParsed: total,
      insertedCount: inserted,
      duplicateCount: duplicates,
      errors: errorList,
    );
  }

  /// Exports references to CSV format with UTF-8 BOM
  static String exportToCsv(List<PaymentReferenceModel> references) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM
    buffer.writeln('Reference Number,Amount (PHP),Payment Date,Status,Intention ID,Transaction ID');

    for (final r in references) {
      final ref = '"${r.referenceNumber.replaceAll('"', '""')}"';
      final amt = r.amount.toStringAsFixed(2);
      final date = r.formattedDate;
      final st = r.status.toUpperCase();
      final intent = r.usedInIntentionId ?? '';
      final tx = r.usedInTransactionId ?? '';
      buffer.writeln('$ref,$amt,$date,$st,$intent,$tx');
    }

    return buffer.toString();
  }
}