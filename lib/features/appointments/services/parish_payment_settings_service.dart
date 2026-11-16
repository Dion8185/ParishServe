import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParishPaymentSettings {
  final String gcashAccountName;
  final String gcashAccountNumber;
  final String? gcashQrCodeUrl;
  final String paymentInstructions;
  final String geminiApiKey;
  final String geminiModel;

  static const String defaultGeminiModel = 'gemini-3.1-flash-lite';

  const ParishPaymentSettings({
    this.gcashAccountName = 'ST. JOHN PAUL II PARISH',
    this.gcashAccountNumber = '0917-882-9912',
    this.gcashQrCodeUrl,
    this.paymentInstructions =
    'Please scan the official parish GCash QR code or send to the account number above. Ensure you capture a screenshot of your successful transaction receipt and upload it below for verification.',
    this.geminiApiKey = '',
    this.geminiModel = defaultGeminiModel,
  });

  factory ParishPaymentSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ParishPaymentSettings();
    final rawModel = map['gemini_model']?.toString().trim();
    return ParishPaymentSettings(
      gcashAccountName:
      map['gcash_account_name']?.toString() ?? 'ST. JOHN PAUL II PARISH',
      gcashAccountNumber:
      map['gcash_account_number']?.toString() ?? '0917-882-9912',
      gcashQrCodeUrl: map['gcash_qr_code_url']?.toString(),
      paymentInstructions: map['payment_instructions']?.toString() ??
          'Please scan the official parish GCash QR code or send to the account number above. Ensure you capture a screenshot of your successful transaction receipt and upload it below for verification.',
      geminiApiKey: map['gemini_api_key']?.toString() ?? '',
      geminiModel: (rawModel != null && rawModel.isNotEmpty)
          ? rawModel
          : defaultGeminiModel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gcash_account_name': gcashAccountName,
      'gcash_account_number': gcashAccountNumber,
      'gcash_qr_code_url': gcashQrCodeUrl,
      'payment_instructions': paymentInstructions,
      'gemini_api_key': geminiApiKey.trim(),
      'gemini_model': geminiModel.trim().isNotEmpty
          ? geminiModel.trim()
          : defaultGeminiModel,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ParishPaymentSettings copyWith({
    String? gcashAccountName,
    String? gcashAccountNumber,
    String? gcashQrCodeUrl,
    String? paymentInstructions,
    String? geminiApiKey,
    String? geminiModel,
  }) {
    return ParishPaymentSettings(
      gcashAccountName: gcashAccountName ?? this.gcashAccountName,
      gcashAccountNumber: gcashAccountNumber ?? this.gcashAccountNumber,
      gcashQrCodeUrl: gcashQrCodeUrl ?? this.gcashQrCodeUrl,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
    );
  }
}

class ParishPaymentSettingsService {
  ParishPaymentSettingsService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static ParishPaymentSettings? _cachedSettings;

  static const String _prefGeminiKey = 'parishserve_gemini_api_key';
  static const String _prefGeminiModel = 'parishserve_gemini_model';

  /// Fetches global parish payment settings (GCash details, QR code URL, payment instructions, Gemini OCR config)
  static Future<ParishPaymentSettings> getSettings({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedSettings != null) {
      return _cachedSettings!;
    }

    String localKey = '';
    String localModel = ParishPaymentSettings.defaultGeminiModel;
    try {
      final prefs = await SharedPreferences.getInstance();
      localKey = prefs.getString(_prefGeminiKey) ?? '';
      localModel = prefs.getString(_prefGeminiModel) ??
          ParishPaymentSettings.defaultGeminiModel;
    } catch (_) {}

    try {
      final res = await _client
          .from('parish_certificate_settings')
          .select(
        'gcash_account_name, gcash_account_number, gcash_qr_code_url, payment_instructions, gemini_api_key, gemini_model',
      )
          .eq('id', 'global')
          .maybeSingle();

      if (res != null) {
        final loaded = ParishPaymentSettings.fromMap(res);
        _cachedSettings = loaded.copyWith(
          geminiApiKey:
          loaded.geminiApiKey.isNotEmpty ? loaded.geminiApiKey : localKey,
          geminiModel:
          loaded.geminiModel.isNotEmpty ? loaded.geminiModel : localModel,
        );
        await _saveLocalGeminiFallback(_cachedSettings!);
        return _cachedSettings!;
      }
    } catch (e) {
      debugPrint(
          '[ParishPaymentSettingsService] Error loading payment settings: $e');
    }

    _cachedSettings = ParishPaymentSettings(
      geminiApiKey: localKey,
      geminiModel: localModel,
    );
    return _cachedSettings!;
  }

  /// Updates global parish payment settings (Secretary / Administrator permission)
  static Future<void> updateSettings(ParishPaymentSettings settings) async {
    await _saveLocalGeminiFallback(settings);

    try {
      await _client
          .from('parish_certificate_settings')
          .update(settings.toMap())
          .eq('id', 'global');

      _cachedSettings = settings;
    } catch (e) {
      debugPrint(
          '[ParishPaymentSettingsService] Error updating payment settings: $e');
      rethrow;
    }
  }

  static Future<void> _saveLocalGeminiFallback(
      ParishPaymentSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefGeminiKey, settings.geminiApiKey.trim());
      await prefs.setString(
        _prefGeminiModel,
        settings.geminiModel.trim().isNotEmpty
            ? settings.geminiModel.trim()
            : ParishPaymentSettings.defaultGeminiModel,
      );
    } catch (_) {}
  }

  /// Uploads a replacement official GCash QR image to Supabase Storage
  static Future<String> uploadGcashQrImage({
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    try {
      final ext = fileExtension.replaceAll('.', '').toLowerCase();
      final fileName = 'gcash_qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'receipt_logos/$fileName';

      await _client.storage.from('certificate-assets').uploadBinary(
        path,
        imageBytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      final publicUrl =
      _client.storage.from('certificate-assets').getPublicUrl(path);

      // Automatically persist to settings row
      final current = await getSettings(forceRefresh: true);
      final updated = current.copyWith(gcashQrCodeUrl: publicUrl);
      await updateSettings(updated);

      return publicUrl;
    } catch (e) {
      debugPrint(
          '[ParishPaymentSettingsService] Error uploading GCash QR image: $e');
      rethrow;
    }
  }
}