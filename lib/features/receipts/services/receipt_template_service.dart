import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../../sacramental_records/services/certificate_service.dart';
import '../models/receipt_template_model.dart';

class ReceiptTemplateService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetches all receipt templates from public.receipt_templates.
  static Future<List<ReceiptTemplateModel>> getAllTemplates() async {
    try {
      final response = await _client
          .from('receipt_templates')
          .select()
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((row) => ReceiptTemplateModel.fromMap(row as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        // Fallback default seed with 'None' (plain, no border)
        final defaultTemplate = await createTemplate(
          const ReceiptTemplateModel(
            templateId: 'TPL-REC-ECCLESIASTICAL',
            templateName: 'Ecclesiastical Voucher Receipt (Standard 8.5 x 4.125 in)',
            receiptTitle: 'OFFICIAL RECEIPT',
            paperSize: 'Ecclesiastical',
            orientation: 'Landscape',
            backgroundMode: 'None',
            isDefault: true,
          ),
        );
        return [defaultTemplate];
      }

      return list;
    } catch (_) {
      // Offline fallback
      return [
        const ReceiptTemplateModel(
          templateId: 'TPL-REC-ECCLESIASTICAL',
          templateName: 'Ecclesiastical Voucher Receipt (Standard 8.5 x 4.125 in)',
          receiptTitle: 'OFFICIAL RECEIPT',
          paperSize: 'Ecclesiastical',
          orientation: 'Landscape',
          backgroundMode: 'None',
          isDefault: true,
        ),
      ];
    }
  }

  /// Retrieves the default active receipt template
  static Future<ReceiptTemplateModel> getDefaultTemplate() async {
    try {
      final response = await _client
          .from('receipt_templates')
          .select()
          .eq('is_default', true)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        return ReceiptTemplateModel.fromMap(response);
      }

      final fallback = await _client
          .from('receipt_templates')
          .select()
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (fallback != null) {
        return ReceiptTemplateModel.fromMap(fallback);
      }
    } catch (_) {}

    return const ReceiptTemplateModel(
      templateId: 'TPL-REC-ECCLESIASTICAL',
      templateName: 'Ecclesiastical Voucher Receipt (Standard 8.5 x 4.125 in)',
      receiptTitle: 'OFFICIAL RECEIPT',
      paperSize: 'Ecclesiastical',
      orientation: 'Landscape',
      backgroundMode: 'None',
      isDefault: true,
    );
  }

  /// Creates a new receipt template, inheriting centralized parish seals if not provided
  static Future<ReceiptTemplateModel> createTemplate(ReceiptTemplateModel template) async {
    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final globalEmblems = await CertificateService.getGlobalEmblemSettings();

    final map = template.toMap();
    map['created_by'] = currentUserId;
    map['created_at'] = DateTime.now().toIso8601String();
    map['updated_at'] = DateTime.now().toIso8601String();

    map['diocese_logo_url'] ??= globalEmblems['diocese_logo_url'];
    map['parish_seal_url'] ??= globalEmblems['parish_seal_url'];
    map['show_diocese_logo'] = globalEmblems['show_diocese_logo'] ?? true;
    map['show_parish_seal'] = globalEmblems['show_parish_seal'] ?? true;

    if (template.isDefault) {
      await _unsetDefaultTemplates();
    }

    final response = await _client
        .from('receipt_templates')
        .insert(map)
        .select()
        .single();

    return ReceiptTemplateModel.fromMap(response);
  }

  /// Updates an existing template and increments its version
  static Future<ReceiptTemplateModel> updateTemplate(ReceiptTemplateModel template) async {
    final map = template.toMap();
    map['version'] = template.version + 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    map.remove('created_at');

    if (template.isDefault) {
      await _unsetDefaultTemplates(excludeId: template.templateId);
    }

    final response = await _client
        .from('receipt_templates')
        .update(map)
        .eq('template_id', template.templateId)
        .select()
        .single();

    return ReceiptTemplateModel.fromMap(response);
  }

  /// Clones a receipt template
  static Future<ReceiptTemplateModel> duplicateTemplate(
      String sourceTemplateId,
      String newTemplateName,
      ) async {
    final source = await _client
        .from('receipt_templates')
        .select()
        .eq('template_id', sourceTemplateId)
        .single();

    final model = ReceiptTemplateModel.fromMap(source);
    final newId = 'TPL-REC-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final clone = model.copyWith(
      templateId: newId,
      templateName: newTemplateName,
      isDefault: false,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return createTemplate(clone);
  }

  /// Sets a specific template as default
  static Future<void> setDefaultTemplate(String templateId) async {
    await _unsetDefaultTemplates();
    await _client
        .from('receipt_templates')
        .update({'is_default': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('template_id', templateId);
  }

  /// Toggles template active state
  static Future<void> toggleTemplateStatus(String templateId, bool isActive) async {
    await _client
        .from('receipt_templates')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('template_id', templateId);
  }

  static Future<void> _unsetDefaultTemplates({String? excludeId}) async {
    var query = _client.from('receipt_templates').update({'is_default': false});
    if (excludeId != null) {
      query = query.neq('template_id', excludeId);
    }
    await query;
  }
}