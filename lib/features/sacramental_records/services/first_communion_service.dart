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

    final duplicate = await _client
        .from('first_communion_records')
        .select('record_id')
        .eq('year', yearNum)
        .eq('control_number', controlNum)
        .maybeSingle();

    if (duplicate != null) {
      throw 'Control Number "$controlNum" is already registered for the year $yearNum.';
    }

    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = controlNum;
    }

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

    final response = await _client
        .from('first_communion_records')
        .insert(data)
        .select()
        .single();

    return FirstCommunionRecordModel.fromMap(response);
  }

  /// Updates an existing manual First Communion record in public.first_communion_records
  static Future<FirstCommunionRecordModel> updateFirstCommunionRecord(String recordId, Map<String, dynamic> data) async {
    final requiredFields = {
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

    // Protect control number and year coordinates from being altered
    data.remove('record_id');
    data.remove('year');
    data.remove('control_number');

    final response = await _client
        .from('first_communion_records')
        .update(data)
        .eq('record_id', recordId)
        .select()
        .single();

    return FirstCommunionRecordModel.fromMap(response);
  }
}