import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParishPaymentSettings {
  final String gcashAccountName;
  final String gcashAccountNumber;
  final String? gcashQrCodeUrl;
  final String paymentInstructions;

  const ParishPaymentSettings({
    this.gcashAccountName = 'ST. JOHN PAUL II PARISH',
    this.gcashAccountNumber = '0917-882-9912',
    this.gcashQrCodeUrl,
    this.paymentInstructions =
    'Please scan the official parish GCash QR code or send to the account number above. Ensure you capture a screenshot of your successful transaction receipt and upload it below for verification.',
  });

  factory ParishPaymentSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ParishPaymentSettings();
    return ParishPaymentSettings(
      gcashAccountName: map['gcash_account_name']?.toString() ?? 'ST. JOHN PAUL II PARISH',
      gcashAccountNumber: map['gcash_account_number']?.toString() ?? '0917-882-9912',
      gcashQrCodeUrl: map['gcash_qr_code_url']?.toString(),
      paymentInstructions: map['payment_instructions']?.toString() ??
          'Please scan the official parish GCash QR code or send to the account number above. Ensure you capture a screenshot of your successful transaction receipt and upload it below for verification.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gcash_account_name': gcashAccountName,
      'gcash_account_number': gcashAccountNumber,
      'gcash_qr_code_url': gcashQrCodeUrl,
      'payment_instructions': paymentInstructions,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ParishPaymentSettings copyWith({
    String? gcashAccountName,
    String? gcashAccountNumber,
    String? gcashQrCodeUrl,
    String? paymentInstructions,
  }) {
    return ParishPaymentSettings(
      gcashAccountName: gcashAccountName ?? this.gcashAccountName,
      gcashAccountNumber: gcashAccountNumber ?? this.gcashAccountNumber,
      gcashQrCodeUrl: gcashQrCodeUrl ?? this.gcashQrCodeUrl,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
    );
  }
}

class ParishPaymentSettingsService {
  ParishPaymentSettingsService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static ParishPaymentSettings? _cachedSettings;

  /// Fetches global parish payment settings (GCash details, QR code URL, payment instructions)
  static Future<ParishPaymentSettings> getSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    try {
      final res = await _client
          .from('parish_certificate_settings')
          .select('gcash_account_name, gcash_account_number, gcash_qr_code_url, payment_instructions')
          .eq('id', 'global')
          .maybeSingle();

      if (res != null) {
        _cachedSettings = ParishPaymentSettings.fromMap(res);
        return _cachedSettings!;
      }
    } catch (e) {
      debugPrint('[ParishPaymentSettingsService] Error loading payment settings: $e');
    }

    _cachedSettings = const ParishPaymentSettings();
    return _cachedSettings!;
  }

  /// Updates global parish payment settings (Secretary / Administrator permission)
  static Future<void> updateSettings(ParishPaymentSettings settings) async {
    try {
      await _client
          .from('parish_certificate_settings')
          .update(settings.toMap())
          .eq('id', 'global');

      _cachedSettings = settings;
    } catch (e) {
      debugPrint('[ParishPaymentSettingsService] Error updating payment settings: $e');
      rethrow;
    }
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

      final publicUrl = _client.storage.from('certificate-assets').getPublicUrl(path);

      // Automatically persist to settings row
      final current = await getSettings();
      final updated = current.copyWith(gcashQrCodeUrl: publicUrl);
      await updateSettings(updated);

      return publicUrl;
    } catch (e) {
      debugPrint('[ParishPaymentSettingsService] Error uploading GCash QR image: $e');
      rethrow;
    }
  }
}