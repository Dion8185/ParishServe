import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class EncoderService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch unverified baptism records awaiting OCR transcription verification
  static Future<List<Map<String, dynamic>>> getUnverifiedRecords() async {
    final response = await _client
        .from('baptism_records')
        .select()
        .eq('is_verified', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mark OCR transcribed record as verified
  static Future<void> verifyRecord(String recordId) async {
    await _client.from('baptism_records').update({
      'is_verified': true,
    }).eq('record_id', recordId);
  }

  /// Fetch all parish assets for field auditing
  static Future<List<Map<String, dynamic>>> getAssets() async {
    final response = await _client
        .from('parish_assets')
        .select()
        .order('item_name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Update asset audit condition (Supports offline sync batching)
  static Future<void> auditAsset(String controlNumber, String conditionStatus) async {
    final userId = AuthService.currentUser?.userId ?? 'S26-0004'; // Default to Encoder ID

    await _client.from('parish_assets').update({
      'condition_status': conditionStatus,
      'last_audited_at': DateTime.now().toIso8601String(),
      'audited_by': userId,
    }).eq('control_number', controlNumber);
  }
}