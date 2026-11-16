import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'parish_payment_settings_service.dart';

class GcashOcrResult {
  final String? referenceNumber;
  final double? amount;
  final String? recipientName;
  final String? recipientNumber;
  final String rawText;
  final bool isSuccess;
  final String? errorMessage;

  const GcashOcrResult({
    this.referenceNumber,
    this.amount,
    this.recipientName,
    this.recipientNumber,
    this.rawText = '',
    this.isSuccess = false,
    this.errorMessage,
  });

  GcashOcrResult copyWith({
    String? referenceNumber,
    double? amount,
    String? recipientName,
    String? recipientNumber,
    String? rawText,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return GcashOcrResult(
      referenceNumber: referenceNumber ?? this.referenceNumber,
      amount: amount ?? this.amount,
      recipientName: recipientName ?? this.recipientName,
      recipientNumber: recipientNumber ?? this.recipientNumber,
      rawText: rawText ?? this.rawText,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GcashOcrService {
  GcashOcrService._();

  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Process GCash receipt screenshot using Google Gemini Vision API.
  /// Uses the configured Gemini API key and model (default: gemini-3.1-flash-lite).
  static Future<GcashOcrResult> processReceiptImage({
    String? filePath,
    Uint8List? imageBytes,
    required String fileName,
  }) async {
    try {
      final settings =
      await ParishPaymentSettingsService.getSettings(forceRefresh: true);
      final apiKey = settings.geminiApiKey.trim();
      final model = settings.geminiModel.trim().isNotEmpty
          ? settings.geminiModel.trim()
          : ParishPaymentSettings.defaultGeminiModel;

      if (apiKey.isEmpty) {
        return GcashOcrResult(
          rawText: 'GCash receipt attached: $fileName',
          isSuccess: false,
          errorMessage:
          'Gemini API key is not configured. Please enter it in GCash QR & Bank Ledger settings, or enter the Reference Number and Amount manually.',
        );
      }

      Uint8List? bytes = imageBytes;
      if ((bytes == null || bytes.isEmpty) &&
          !kIsWeb &&
          filePath != null &&
          filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return const GcashOcrResult(
          isSuccess: false,
          errorMessage: 'Unable to read receipt image bytes.',
        );
      }

      final mimeType = _resolveMimeType(fileName);
      final base64Image = base64Encode(bytes);

      final uri = Uri.parse(
        '$_geminiBaseUrl/${Uri.encodeComponent(model)}:generateContent',
      );

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                'You are an OCR parser for Philippine GCash payment receipt screenshots. '
                    'Extract the payment details from this image and return ONLY a valid JSON object with these exact keys: '
                    '"reference_number" (string or null, e.g. "1002 9847 1120" or digits only as shown on the receipt), '
                    '"amount" (number or null, the total amount sent/paid in PHP without currency symbols, e.g. 100.00), '
                    '"recipient_name" (string or null), '
                    '"recipient_number" (string or null), '
                    '"raw_text" (string containing the key text lines visible on the receipt). '
                    'If the image is not a GCash or payment receipt, set reference_number and amount to null.',
              },
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Image,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        },
      });

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: requestBody,
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        String apiError = 'Gemini OCR request failed (${response.statusCode}).';
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          final msg = errJson['error']?['message']?.toString();
          if (msg != null && msg.isNotEmpty) {
            apiError = msg;
          }
        } catch (_) {}

        debugPrint('[GcashOcrService] Gemini HTTP ${response.statusCode}: $apiError');
        return GcashOcrResult(
          rawText: 'GCash receipt attached: $fileName',
          isSuccess: false,
          errorMessage: apiError,
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return GcashOcrResult(
          rawText: 'GCash receipt attached: $fileName',
          isSuccess: false,
          errorMessage: 'Gemini did not return any OCR result.',
        );
      }

      final parts = candidates.first['content']?['parts'] as List?;
      final responseText = parts != null && parts.isNotEmpty
          ? (parts.first['text']?.toString() ?? '')
          : '';

      if (responseText.trim().isEmpty) {
        return GcashOcrResult(
          rawText: 'GCash receipt attached: $fileName',
          isSuccess: false,
          errorMessage: 'Empty OCR response from Gemini.',
        );
      }

      final cleanedJson = _stripMarkdownCodeFence(responseText);
      try {
        final parsedJson = jsonDecode(cleanedJson) as Map<String, dynamic>;

        String? refNo = parsedJson['reference_number']?.toString().trim();
        if (refNo != null &&
            (refNo.isEmpty || refNo.toLowerCase() == 'null')) {
          refNo = null;
        }

        double? amount;
        final rawAmount = parsedJson['amount'];
        if (rawAmount is num) {
          amount = rawAmount.toDouble();
        } else if (rawAmount != null) {
          amount = _cleanAmount(rawAmount.toString());
        }
        if (amount != null && amount <= 0) {
          amount = null;
        }

        String? recipientName = parsedJson['recipient_name']?.toString().trim();
        if (recipientName != null &&
            (recipientName.isEmpty || recipientName.toLowerCase() == 'null')) {
          recipientName = null;
        }

        String? recipientNumber =
        parsedJson['recipient_number']?.toString().trim();
        if (recipientNumber != null &&
            (recipientNumber.isEmpty ||
                recipientNumber.toLowerCase() == 'null')) {
          recipientNumber = null;
        }

        final rawText = parsedJson['raw_text']?.toString().trim() ?? responseText;

        // Fallback to regex parser on rawText if Gemini missed a field
        if (refNo == null || amount == null) {
          final fallback = parseGcashText(rawText);
          refNo ??= fallback.referenceNumber;
          amount ??= fallback.amount;
        }

        return GcashOcrResult(
          referenceNumber: refNo,
          amount: amount,
          recipientName: recipientName,
          recipientNumber: recipientNumber,
          rawText: rawText,
          isSuccess: refNo != null || amount != null,
          errorMessage: (refNo == null && amount == null)
              ? 'Could not detect Reference Number or Amount from the screenshot. Please enter them manually.'
              : null,
        );
      } catch (_) {
        final fallback = parseGcashText(responseText);
        return fallback.copyWith(
          errorMessage: fallback.isSuccess
              ? null
              : 'Could not parse Gemini OCR output. Please confirm the Reference Number and Amount manually.',
        );
      }
    } catch (e) {
      debugPrint('[GcashOcrService] Gemini OCR error: $e');
      return GcashOcrResult(
        rawText: 'GCash receipt attached: $fileName',
        isSuccess: false,
        errorMessage:
        'OCR error: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  static String _resolveMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _stripMarkdownCodeFence(String text) {
    var trimmed = text.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      trimmed = trimmed.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return trimmed.trim();
  }

  /// Fallback multi-line GCash receipt text parser.
  static GcashOcrResult parseGcashText(String rawText) {
    if (rawText.trim().isEmpty) {
      return const GcashOcrResult(rawText: '', isSuccess: false);
    }

    final normalizedText = rawText.replaceAll('\r', '\n');
    final lines = normalizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? foundReference;
    double? foundAmount;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (RegExp(r'(?:Ref|Reference)\.?\s*(?:No|Number|#)?',
          caseSensitive: false)
          .hasMatch(line)) {
        final sameLineMatch = RegExp(
          r'(?:Ref|Reference)\.?\s*(?:No|Number|#)?\.?:?\s*([0-9\s]{9,20})',
          caseSensitive: false,
        ).firstMatch(line);

        if (sameLineMatch != null) {
          final digits =
          sameLineMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (digits != null && digits.replaceAll(' ', '').length >= 10) {
            foundReference = digits;
            break;
          }
        }

        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final nextLineMatch =
          RegExp(r'^([0-9\s]{10,20})$').firstMatch(nextLine);
          if (nextLineMatch != null) {
            final digits =
            nextLineMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (digits != null && digits.replaceAll(' ', '').length >= 10) {
              foundReference = digits;
              break;
            }
          }
        }
      }
    }

    if (foundReference == null) {
      final groupedPattern = RegExp(r'\b(\d{4}\s\d{4}\s\d{4,5})\b');
      final match = groupedPattern.firstMatch(normalizedText);
      if (match != null) {
        foundReference = match.group(1)?.trim();
      }
    }

    if (foundReference == null) {
      final longNumberPattern = RegExp(r'\b([019]\d{11,13})\b');
      final match = longNumberPattern.firstMatch(normalizedText);
      if (match != null) {
        foundReference = match.group(1)?.trim();
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (RegExp(r'(?:Total\s*Amount|Amount\s*Sent|Amount|Sent)',
          caseSensitive: false)
          .hasMatch(line)) {
        final sameLineMatch =
        RegExp(r'(?:PHP|Php|php|₱|P)?\s*([0-9,]+\.[0-9]{2})')
            .firstMatch(line);
        if (sameLineMatch != null) {
          final amt = _cleanAmount(sameLineMatch.group(1));
          if (amt != null && amt > 0) {
            foundAmount = amt;
            break;
          }
        }

        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final nextLineMatch =
          RegExp(r'(?:PHP|Php|php|₱|P)?\s*([0-9,]+\.[0-9]{2})')
              .firstMatch(nextLine);
          if (nextLineMatch != null) {
            final amt = _cleanAmount(nextLineMatch.group(1));
            if (amt != null && amt > 0) {
              foundAmount = amt;
              break;
            }
          }
        }
      }
    }

    if (foundAmount == null) {
      final currencyPattern = RegExp(
        r'(?:PHP|Php|php|₱)\s*([0-9,]+\.[0-9]{2})',
        caseSensitive: false,
      );
      final match = currencyPattern.firstMatch(normalizedText);
      if (match != null) {
        foundAmount = _cleanAmount(match.group(1));
      }
    }

    if (foundAmount == null) {
      final decimalPattern = RegExp(r'\b([0-9,]+\.[0-9]{2})\b');
      final matches = decimalPattern.allMatches(normalizedText);
      for (final m in matches) {
        final amt = _cleanAmount(m.group(1));
        if (amt != null && amt >= 50.0 && amt <= 50000.0) {
          foundAmount = amt;
          break;
        }
      }
    }

    return GcashOcrResult(
      referenceNumber: foundReference,
      amount: foundAmount,
      rawText: rawText,
      isSuccess: foundReference != null || foundAmount != null,
    );
  }

  static double? _cleanAmount(String? raw) {
    if (raw == null) return null;
    final clean =
    raw.replaceAll('₱', '').replaceAll('P', '').replaceAll(',', '').trim();
    return double.tryParse(clean);
  }
}