import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class GcashOcrResult {
  final String? referenceNumber;
  final double? amount;
  final String rawText;
  final bool isSuccess;
  final String? errorMessage;

  const GcashOcrResult({
    this.referenceNumber,
    this.amount,
    this.rawText = '',
    this.isSuccess = false,
    this.errorMessage,
  });

  GcashOcrResult copyWith({
    String? referenceNumber,
    double? amount,
    String? rawText,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return GcashOcrResult(
      referenceNumber: referenceNumber ?? this.referenceNumber,
      amount: amount ?? this.amount,
      rawText: rawText ?? this.rawText,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GcashOcrService {
  GcashOcrService._();

  /// Process GCash receipt screenshot using Google ML Kit on-device Text Recognition.
  /// Runs completely offline and locally on mobile devices without relying on unconfigured cloud endpoints.
  static Future<GcashOcrResult> processReceiptImage({
    String? filePath,
    Uint8List? imageBytes,
    required String fileName,
  }) async {
    String extractedRawText = '';
    File? tempFile;

    final bool isMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    try {
      if (isMobilePlatform) {
        String? targetPath = filePath;

        // If filePath is null but bytes are available, write to a temp file for Google ML Kit
        if ((targetPath == null || targetPath.isEmpty) && imageBytes != null && imageBytes.isNotEmpty) {
          final tempDir = Directory.systemTemp;
          final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
          tempFile = File('${tempDir.path}/gcash_ocr_${DateTime.now().millisecondsSinceEpoch}.$ext');
          await tempFile.writeAsBytes(imageBytes);
          targetPath = tempFile.path;
        }

        if (targetPath != null && targetPath.isNotEmpty) {
          final inputImage = InputImage.fromFilePath(targetPath);
          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          extractedRawText = recognizedText.text;
          await textRecognizer.close();

          if (extractedRawText.trim().isNotEmpty) {
            final parsed = parseGcashText(extractedRawText);
            return GcashOcrResult(
              referenceNumber: parsed.referenceNumber,
              amount: parsed.amount,
              rawText: extractedRawText,
              isSuccess: parsed.referenceNumber != null || parsed.amount != null,
            );
          }
        }
      }
    } catch (mlKitError) {
      debugPrint('[GcashOcrService] Google ML Kit OCR error: $mlKitError');
    } finally {
      // Clean up temporary local file if created
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    // Fallback: If text was extracted or needs manual entry review
    if (extractedRawText.trim().isNotEmpty) {
      return parseGcashText(extractedRawText);
    }

    return GcashOcrResult(
      rawText: 'GCash receipt attached: $fileName',
      isSuccess: false,
      errorMessage: 'Could not automatically detect text on this platform. Please confirm the Reference Number and Amount below.',
    );
  }

  /// Advanced multi-line GCash receipt text parser.
  /// Handles both single-line and broken-line formats common in GCash screenshots.
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

    // =========================================================================
    // 1. REFERENCE NUMBER EXTRACTION
    // =========================================================================

    // Case A: Look for lines explicitly mentioning Ref / Reference No
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (RegExp(r'(?:Ref|Reference)\.?\s*(?:No|Number|#)?', caseSensitive: false).hasMatch(line)) {
        // Try extracting digits on the SAME line first
        final sameLineMatch = RegExp(
          r'(?:Ref|Reference)\.?\s*(?:No|Number|#)?\.?:?\s*([0-9\s]{9,20})',
          caseSensitive: false,
        ).firstMatch(line);

        if (sameLineMatch != null) {
          final digits = sameLineMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (digits != null && digits.replaceAll(' ', '').length >= 10) {
            foundReference = digits;
            break;
          }
        }

        // Try extracting digits on the IMMEDIATE NEXT LINE (very common in GCash layout)
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final nextLineMatch = RegExp(r'^([0-9\s]{10,20})$').firstMatch(nextLine);
          if (nextLineMatch != null) {
            final digits = nextLineMatch.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (digits != null && digits.replaceAll(' ', '').length >= 10) {
              foundReference = digits;
              break;
            }
          }
        }
      }
    }

    // Case B: General pattern match for 4-4-4 or 4-4-5 digit groups (e.g. "1002 9847 1120" or "0012 3456 7890")
    if (foundReference == null) {
      final groupedPattern = RegExp(r'\b(\d{4}\s\d{4}\s\d{4,5})\b');
      final match = groupedPattern.firstMatch(normalizedText);
      if (match != null) {
        foundReference = match.group(1)?.trim();
      }
    }

    // Case C: Continuous 12 to 14 digit number starting with 0, 1, or 9
    if (foundReference == null) {
      final longNumberPattern = RegExp(r'\b([019]\d{11,13})\b');
      final match = longNumberPattern.firstMatch(normalizedText);
      if (match != null) {
        foundReference = match.group(1)?.trim();
      }
    }

    // =========================================================================
    // 2. AMOUNT EXTRACTION
    // =========================================================================

    // Case A: Look for lines explicitly mentioning Amount / Total / Sent
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (RegExp(r'(?:Total\s*Amount|Amount\s*Sent|Amount|Sent)', caseSensitive: false).hasMatch(line)) {
        // Try on the SAME line
        final sameLineMatch = RegExp(r'(?:PHP|Php|php|₱|P)?\s*([0-9,]+\.[0-9]{2})').firstMatch(line);
        if (sameLineMatch != null) {
          final amt = _cleanAmount(sameLineMatch.group(1));
          if (amt != null && amt > 0) {
            foundAmount = amt;
            break;
          }
        }

        // Try on the IMMEDIATE NEXT LINE
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final nextLineMatch = RegExp(r'(?:PHP|Php|php|₱|P)?\s*([0-9,]+\.[0-9]{2})').firstMatch(nextLine);
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

    // Case B: Search for currency symbol followed by decimal amount (e.g. "₱ 500.00" or "PHP 1,000.00")
    if (foundAmount == null) {
      final currencyPattern = RegExp(r'(?:PHP|Php|php|₱)\s*([0-9,]+\.[0-9]{2})', caseSensitive: false);
      final match = currencyPattern.firstMatch(normalizedText);
      if (match != null) {
        foundAmount = _cleanAmount(match.group(1));
      }
    }

    // Case C: Standalone decimal currency number
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
    final clean = raw.replaceAll('₱', '').replaceAll('P', '').replaceAll(',', '').trim();
    return double.tryParse(clean);
  }
}