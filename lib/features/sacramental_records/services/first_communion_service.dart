import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/first_communion_record_model.dart';

class FirstCommunionService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all first communion records ordered by reception date descending
  static Future<List<FirstCommunionRecordModel>> getFirstCommunionRecords() async {
    final response = await _client
        .from('first_communion_records')
        .select()
        .order('date_of_communion', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => FirstCommunionRecordModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Automatically generates the next sequential control number: FCM-Year-Number (e.g. FCM-2026-0001)
  static Future<String> generateNextControlNumber(int year) async {
    try {
      final records = await _client
          .from('first_communion_records')
          .select('control_number')
          .eq('year', year);

      int highest = 0;
      for (final item in records) {
        final cNo = item['control_number']?.toString() ?? '';
        // Expected format: FCM-YYYY-XXXX or similar with hyphens
        final parts = cNo.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts.last);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }

      final nextSeq = (highest + 1).toString().padLeft(4, '0');
      return 'FCM-$year-$nextSeq';
    } catch (_) {
      final fallbackSeq = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'FCM-$year-$fallbackSeq';
    }
  }

  /// Validates and inserts a manual First Communion record into public.first_communion_records
  static Future<FirstCommunionRecordModel> insertManualFirstCommunionRecord(Map<String, dynamic> data) async {
    // 1. Required fields validation
    final requiredFields = {
      'year': 'Communion Year',
      'control_number': 'Control Number',
      'communicant_first_name': 'Communicant First Name',
      'communicant_last_name': 'Communicant Last Name',
      'date_of_communion': 'Date of First Holy Communion',
      'baptism_parish': 'Church of Baptism',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final yearNum = int.tryParse(data['year'].toString().trim());
    if (yearNum == null || yearNum < 1900 || yearNum > DateTime.now().year + 1) {
      throw 'Please provide a valid communion year.';
    }
    data['year'] = yearNum;

    final controlNum = data['control_number'].toString().trim();
    data['control_number'] = controlNum;

    // 2. Duplicate control number check within the specified reception year
    final duplicate = await _client
        .from('first_communion_records')
        .select('record_id')
        .eq('year', yearNum)
        .eq('control_number', controlNum)
        .maybeSingle();

    if (duplicate != null) {
      throw 'Control Number "$controlNum" is already registered for the year $yearNum.';
    }

    // 3. Generate unique record ID (shares the same FCM-Year-Number sequence string)
    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = controlNum;
    }

    // 4. Automatic encoded_by mapping
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

    // 5. Managed defaults
    data['is_verified'] = false;
    data['scanned_image_url'] = null;

    final response = await _client
        .from('first_communion_records')
        .insert(data)
        .select()
        .single();

    return FirstCommunionRecordModel.fromMap(response);
  }
}