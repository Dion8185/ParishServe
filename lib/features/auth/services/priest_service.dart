import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class PriestService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch pending baptism records awaiting Pastoral approval and sign-off
  static Future<List<Map<String, dynamic>>> getPendingCertificates() async {
    final response = await _client
        .from('baptism_records')
        .select()
        .eq('approved_by_priest', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Digitally approve and sign a sacramental certificate
  static Future<void> approveCertificate(String recordId) async {
    final priestId = AuthService.currentUser?.userId ?? 'S26-0005'; // Default to Parish Priest dummy ID

    // 1. Update record approval state
    await _client.from('baptism_records').update({
      'approved_by_priest': true,
      'priest_signed_at': DateTime.now().toIso8601String(),
    }).eq('record_id', recordId);

    // 2. Log into pastoral audit table
    await _client.from('pastoral_audit_logs').insert({
      'log_id': 'LOG-${DateTime.now().millisecondsSinceEpoch}',
      'priest_id': priestId,
      'action_type': 'CERTIFICATE_APPROVAL',
      'target_reference_id': recordId,
      'justification': 'Canonical review and digital signature affixed by Parish Priest.',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Commit a canonical marginal notation (Canon 535 §2)
  static Future<void> addMarginalNotation(String recordId, String notation) async {
    final priestId = AuthService.currentUser?.userId ?? 'S26-0005';

    // Fetch existing remarks
    final record = await _client
        .from('baptism_records')
        .select('remarks')
        .eq('record_id', recordId)
        .single();

    final existingRemarks = record['remarks'] ?? '';
    final updatedRemarks = existingRemarks.isEmpty
        ? '[Canonical Note]: $notation'
        .trim()
        : '$existingRemarks\n[Canonical Note]: $notation';

    await _client.from('baptism_records').update({
      'remarks': updatedRemarks,
    }).eq('record_id', recordId);

    // Log action
    await _client.from('pastoral_audit_logs').insert({
      'log_id': 'LOG-${DateTime.now().millisecondsSinceEpoch}',
      'priest_id': priestId,
      'action_type': 'MARGINAL_NOTATION',
      'target_reference_id': recordId,
      'justification': notation,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}