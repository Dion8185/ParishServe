import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/conversion_record_model.dart';

class ConversionService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all conversion records ordered by date of reception descending
  static Future<List<ConversionRecordModel>> getConversionRecords() async {
    final response = await _client
        .from('conversion_records')
        .select()
        .order('date_of_reception', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => ConversionRecordModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Validates and inserts a manual Conversion record into public.conversion_records
  static Future<ConversionRecordModel> insertManualConversionRecord(Map<String, dynamic> data) async {
    // 1. Required fields validation
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'date_of_reception': 'Date of Reception into Full Communion',
      'convert_first_name': 'Convert First Name',
      'convert_last_name': 'Convert Last Name',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'witness_1_first_name': 'Witness 1 First Name',
      'witness_1_last_name': 'Witness 1 Last Name',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // 2. Physical reference limits (Canon 535)
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

    // 3. Duplicate physical reference check
    final duplicate = await _client
        .from('conversion_records')
        .select('record_id')
        .eq('book_number', cleanBook)
        .eq('page_number', cleanPage)
        .eq('line_number', cleanLine)
        .maybeSingle();

    if (duplicate != null) {
      throw 'This Book, Page, and Line reference is already registered in the Conversion Register.';
    }

    // 4. Generate unique record ID: CNV-YY-XXXX
    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = await _generateRecordId();
    }

    // 5. Automatic encoded_by mapping
    String? encoderId = AuthService.currentUser?.userId;
    if (encoderId == null || encoderId.isEmpty) {
      final defaultUser = await _client
          .from('users')
          .select('user_id')
          .eq('account_status', true)
          .limit(1)
          .maybeSingle();
      encoderId = defaultUser?['user_id'] ?? 'S26-0003';
    }
    data['encoded_by'] = encoderId;

    data['is_verified'] = false;
    data['scanned_image_url'] = null;
    data['ocr_raw_text'] = null;

    final response = await _client
        .from('conversion_records')
        .insert(data)
        .select()
        .single();

    return ConversionRecordModel.fromMap(response);
  }

  /// Updates an existing manual Conversion record in public.conversion_records
  static Future<ConversionRecordModel> updateConversionRecord(String recordId, Map<String, dynamic> data) async {
    final requiredFields = {
      'date_of_reception': 'Date of Reception into Full Communion',
      'convert_first_name': 'Convert First Name',
      'convert_last_name': 'Convert Last Name',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'witness_1_first_name': 'Witness 1 First Name',
      'witness_1_last_name': 'Witness 1 Last Name',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // Protect immutable physical coordinates from being altered
    data.remove('record_id');
    data.remove('book_number');
    data.remove('page_number');
    data.remove('line_number');

    final response = await _client
        .from('conversion_records')
        .update(data)
        .eq('record_id', recordId)
        .select()
        .single();

    return ConversionRecordModel.fromMap(response);
  }

  /// Generates sequential record ID: CNV-YY-XXXX
  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    try {
      final records = await _client
          .from('conversion_records')
          .select('record_id')
          .like('record_id', 'CNV-$yearSuffix-%');

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
      return 'CNV-$yearSuffix-$nextSeq';
    } catch (_) {
      final timestampSeq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'CNV-$yearSuffix-$timestampSeq';
    }
  }
}