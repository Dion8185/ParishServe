import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/confirmation_record_model.dart';

class ConfirmationService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all confirmation records ordered by date of confirmation descending
  static Future<List<ConfirmationRecordModel>> getConfirmationRecords() async {
    final response = await _client
        .from('confirmation_records')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => ConfirmationRecordModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Validates and inserts a manual Confirmation Record into public.confirmation_records
  static Future<ConfirmationRecordModel> insertManualConfirmationRecord(Map<String, dynamic> data) async {
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'confirmand_first_name': 'Confirmand First Name',
      'confirmand_last_name': 'Confirmand Last Name',
      'date_of_baptism': 'Date of Baptism',
      'church_baptized': 'Church of Baptism',
      'father_first_name': 'Father First Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'date_of_confirmation': 'Date of Confirmation',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
      'parish_name': 'Parish Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final bookNum = int.tryParse(data['book_number'].toString().trim());
    if (bookNum == null || bookNum < 1 || bookNum > 200) {
      throw 'Book Number must be between 1 and 200.';
    }

    final pageNum = int.tryParse(data['page_number'].toString().trim());
    if (pageNum == null || pageNum < 1 || pageNum > 100) {
      throw 'Page Number must be between 1 and 100.';
    }

    final lineNum = int.tryParse(data['line_number'].toString().trim());
    if (lineNum == null || lineNum < 1 || lineNum > 10) {
      throw 'Line Number must be between 1 and 10.';
    }

    final cleanBook = bookNum.toString();
    final cleanPage = pageNum.toString();
    final cleanLine = lineNum.toString();

    data['book_number'] = cleanBook;
    data['page_number'] = cleanPage;
    data['line_number'] = cleanLine;

    final duplicate = await _client
        .from('confirmation_records')
        .select('record_id')
        .eq('book_number', cleanBook)
        .eq('page_number', cleanPage)
        .eq('line_number', cleanLine)
        .maybeSingle();

    if (duplicate != null) {
      throw 'This Book, Page, and Line reference is already registered in the Confirmation Register.';
    }

    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = await _generateRecordId();
    }

    String? encoderId = AuthService.currentUser?.userId;
    if (encoderId == null || encoderId.isEmpty) {
      final userQuery = await _client
          .from('users')
          .select('user_id')
          .eq('account_status', true)
          .limit(1)
          .maybeSingle();
      encoderId = userQuery?['user_id'] ?? 'S26-0003';
    }
    data['encoded_by'] = encoderId;

    data['is_verified'] = false;
    data['scanned_image_url'] = null;
    data['ocr_raw_text'] = null;
    data['entry_status'] = data['entry_status'] ?? 'ORIGINAL';
    data['stipend'] = data['stipend'] ?? 0.00;

    final response = await _client
        .from('confirmation_records')
        .insert(data)
        .select()
        .single();

    return ConfirmationRecordModel.fromMap(response);
  }

  /// Updates an existing manual Confirmation Record
  static Future<ConfirmationRecordModel> updateConfirmationRecord(String recordId, Map<String, dynamic> data) async {
    final requiredFields = {
      'confirmand_first_name': 'Confirmand First Name',
      'confirmand_last_name': 'Confirmand Last Name',
      'date_of_baptism': 'Date of Baptism',
      'church_baptized': 'Church of Baptism',
      'father_first_name': 'Father First Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'date_of_confirmation': 'Date of Confirmation',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
      'parish_name': 'Parish Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // Protect physical coordinates from being altered
    data.remove('record_id');
    data.remove('book_number');
    data.remove('page_number');
    data.remove('line_number');

    final response = await _client
        .from('confirmation_records')
        .update(data)
        .eq('record_id', recordId)
        .select()
        .single();

    return ConfirmationRecordModel.fromMap(response);
  }

  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    try {
      final records = await _client
          .from('confirmation_records')
          .select('record_id')
          .like('record_id', 'CNF-$yearSuffix-%');

      int highest = 0;
      for (final item in records) {
        final id = item['record_id']?.toString() ?? '';
        final parts = id.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }

      final nextSeq = (highest + 1).toString().padLeft(4, '0');
      return 'CNF-$yearSuffix-$nextSeq';
    } catch (_) {
      final timestampSeq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'CNF-$yearSuffix-$timestampSeq';
    }
  }
}