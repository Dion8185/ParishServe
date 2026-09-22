import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/matrimony_record_model.dart';
import '../validators/sacramental_validators.dart';

class MatrimonyService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all matrimony records ordered by marriage date descending
  static Future<List<MatrimonyRecordModel>> getMatrimonyRecords() async {
    final response = await _client
        .from('matrimony_records')
        .select()
        .order('date_of_marriage', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => MatrimonyRecordModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Validates and inserts a manual Matrimony record into public.matrimony_records
  static Future<MatrimonyRecordModel> insertManualMatrimonyRecord(Map<String, dynamic> data) async {
    // 1. Validate required fields
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'groom_first_name': 'Groom First Name',
      'groom_last_name': 'Groom Last Name',
      'groom_address': 'Groom Address',
      'bride_first_name': 'Bride First Name',
      'bride_last_name': 'Bride Last Name',
      'bride_address': 'Bride Address',
      'sponsor_1_first_name': 'Primary Sponsor 1 First Name',
      'sponsor_1_last_name': 'Primary Sponsor 1 Last Name',
      'sponsor_2_first_name': 'Primary Sponsor 2 First Name',
      'sponsor_2_last_name': 'Primary Sponsor 2 Last Name',
      'date_of_marriage': 'Date of Marriage',
      'solemnizer_first_name': 'Solemnizing Minister First Name',
      'solemnizer_last_name': 'Solemnizing Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // 2. Physical reference limits (Canon 535) using SacramentalValidators
    final bookError = SacramentalValidators.validateBookNumber(data['book_number']?.toString());
    if (bookError != null) throw bookError;

    final pageError = SacramentalValidators.validatePageNumber(data['page_number']?.toString());
    if (pageError != null) throw pageError;

    final lineError = SacramentalValidators.validateLineNumber(data['line_number']?.toString());
    if (lineError != null) throw lineError;

    final cleanBook = int.parse(data['book_number'].toString().trim()).toString();
    final cleanPage = int.parse(data['page_number'].toString().trim()).toString();
    final cleanLine = int.parse(data['line_number'].toString().trim()).toString();

    data['book_number'] = cleanBook;
    data['page_number'] = cleanPage;
    data['line_number'] = cleanLine;

    // 3. Demographic age checks
    final groomAgeError = SacramentalValidators.validateWholeNumberAge(data['groom_age']?.toString());
    if (groomAgeError != null) throw 'Groom: $groomAgeError';

    final brideAgeError = SacramentalValidators.validateWholeNumberAge(data['bride_age']?.toString());
    if (brideAgeError != null) throw 'Bride: $brideAgeError';

    // 4. Duplicate physical reference check
    final duplicate = await _client
        .from('matrimony_records')
        .select('record_id')
        .eq('book_number', cleanBook)
        .eq('page_number', cleanPage)
        .eq('line_number', cleanLine)
        .maybeSingle();

    if (duplicate != null) {
      throw 'This Book, Page, and Line reference is already registered in the Matrimony Register.';
    }

    // 5. Generate unique record ID: MAT-YY-XXXX
    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = await _generateRecordId();
    }

    // 6. Automatic encoded_by mapping
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
        .from('matrimony_records')
        .insert(data)
        .select()
        .single();

    return MatrimonyRecordModel.fromMap(response);
  }

  /// Updates an existing manual Matrimony record in public.matrimony_records
  static Future<MatrimonyRecordModel> updateMatrimonyRecord(String recordId, Map<String, dynamic> data) async {
    final requiredFields = {
      'groom_first_name': 'Groom First Name',
      'groom_last_name': 'Groom Last Name',
      'groom_address': 'Groom Address',
      'bride_first_name': 'Bride First Name',
      'bride_last_name': 'Bride Last Name',
      'bride_address': 'Bride Address',
      'sponsor_1_first_name': 'Primary Sponsor 1 First Name',
      'sponsor_1_last_name': 'Primary Sponsor 1 Last Name',
      'sponsor_2_first_name': 'Primary Sponsor 2 First Name',
      'sponsor_2_last_name': 'Primary Sponsor 2 Last Name',
      'date_of_marriage': 'Date of Marriage',
      'solemnizer_first_name': 'Solemnizing Minister First Name',
      'solemnizer_last_name': 'Solemnizing Minister Last Name',
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
        .from('matrimony_records')
        .update(data)
        .eq('record_id', recordId)
        .select()
        .single();

    return MatrimonyRecordModel.fromMap(response);
  }

  /// Generates sequential record ID: MAT-YY-XXXX
  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    try {
      final records = await _client
          .from('matrimony_records')
          .select('record_id')
          .like('record_id', 'MAT-$yearSuffix-%');

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
      return 'MAT-$yearSuffix-$nextSeq';
    } catch (_) {
      final timestampSeq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'MAT-$yearSuffix-$timestampSeq';
    }
  }
}