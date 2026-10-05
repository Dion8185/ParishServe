// =============================================================================
// FILE: lib/features/sacramental_records/models/certificate_template_model.dart
// =============================================================================

import 'dart:convert';
import 'certificate_style_config.dart';

class CertificateTemplateModel {
  final String templateId;
  final String sacramentType; // 'Baptism', 'Confirmation', 'First Communion', 'Matrimony', 'Death', 'Conversion'
  final String templateName;
  final String certificateTitle;
  final String headerText;

  // Header Logos & Emblems
  final String? dioceseLogoUrl;
  final String? parishSealUrl;
  final bool showDioceseLogo;
  final bool showParishSeal;

  // Content & Purpose
  final String bodyWording;
  final String defaultPurpose;

  // Layout & Formatting
  final String paperSize; // 'A4', 'Letter', 'Legal'
  final String orientation; // 'Portrait', 'Landscape'

  // Decorative Border / Background
  final String? backgroundImageUrl;
  final String backgroundMode; // 'Border', 'Full-Page', 'None'

  // Signatory Configuration
  final String signatoryName;
  final String signatoryTitle;
  final String? signatureImageUrl;

  // Advanced Visual Styling & Layout Configuration
  final CertificateStyleConfig styleConfig;

  // Verification & Status
  final bool enableQrVerification;
  final bool isActive;
  final bool isDefault;
  final int version;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CertificateTemplateModel({
    required this.templateId,
    required this.sacramentType,
    required this.templateName,
    this.certificateTitle = 'CERTIFICATE OF SACRAMENT',
    this.headerText = 'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
    this.dioceseLogoUrl,
    this.parishSealUrl,
    this.showDioceseLogo = true,
    this.showParishSeal = true,
    required this.bodyWording,
    this.defaultPurpose = 'For Record / Reference',
    this.paperSize = 'A4',
    this.orientation = 'Portrait',
    this.backgroundImageUrl,
    this.backgroundMode = 'Border',
    this.signatoryName = 'Rev. Fr. Roy G. Reyes',
    this.signatoryTitle = 'Parish Priest',
    this.signatureImageUrl,
    this.styleConfig = CertificateStyleConfig.defaultConfig,
    this.enableQrVerification = true,
    this.isActive = true,
    this.isDefault = false,
    this.version = 1,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Extracts the individual header lines safely for the centered layout
  List<String> get headerLines {
    final lines = headerText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const [
        'Diocese of San Pablo',
        'Saint John Paul II Parish',
        'Santa Cruz, Laguna',
      ];
    }
    return lines;
  }

  factory CertificateTemplateModel.fromMap(Map<String, dynamic> map) {
    // Robust boolean parsing for both Supabase bool and SQLite int (1/0)
    final rawDiocese = map['show_diocese_logo'];
    final bool showDioceseLogoParsed = rawDiocese == null ||
        rawDiocese == true ||
        rawDiocese == 1 ||
        rawDiocese == 'true' ||
        rawDiocese == '1';

    final rawSeal = map['show_parish_seal'];
    final bool showParishSealParsed = rawSeal == null ||
        rawSeal == true ||
        rawSeal == 1 ||
        rawSeal == 'true' ||
        rawSeal == '1';

    final rawQr = map['enable_qr_verification'];
    final bool enableQrParsed = rawQr == null ||
        rawQr == true ||
        rawQr == 1 ||
        rawQr == 'true' ||
        rawQr == '1';

    final rawActive = map['is_active'];
    final bool isActiveParsed = rawActive == null ||
        rawActive == true ||
        rawActive == 1 ||
        rawActive == 'true' ||
        rawActive == '1';

    final rawDefault = map['is_default'];
    final bool isDefaultParsed = rawDefault == true ||
        rawDefault == 1 ||
        rawDefault == 'true' ||
        rawDefault == '1';

    // Parse style_config whether passed as Map (Supabase) or JSON string (SQLite)
    Map<String, dynamic>? parsedStyleMap;
    final rawStyle = map['style_config'];
    if (rawStyle is Map<String, dynamic>) {
      parsedStyleMap = rawStyle;
    } else if (rawStyle is Map) {
      parsedStyleMap = Map<String, dynamic>.from(rawStyle);
    } else if (rawStyle is String && rawStyle.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStyle);
        if (decoded is Map<String, dynamic>) {
          parsedStyleMap = decoded;
        } else if (decoded is Map) {
          parsedStyleMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return CertificateTemplateModel(
      templateId: map['template_id']?.toString() ?? '',
      sacramentType: map['sacrament_type']?.toString() ?? 'Baptism',
      templateName: map['template_name']?.toString() ?? 'Official Certificate',
      certificateTitle: map['certificate_title']?.toString() ?? 'CERTIFICATE OF SACRAMENT',
      headerText: map['header_text']?.toString() ??
          'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
      dioceseLogoUrl: map['diocese_logo_url']?.toString(),
      parishSealUrl: map['parish_seal_url']?.toString(),
      showDioceseLogo: showDioceseLogoParsed,
      showParishSeal: showParishSealParsed,
      bodyWording: (map['body_wording'] ?? map['bodyWording'])?.toString() ?? '',
      defaultPurpose: map['default_purpose']?.toString() ?? 'For Record / Reference',
      paperSize: map['paper_size']?.toString() ?? 'A4',
      orientation: map['orientation']?.toString() ?? 'Portrait',
      backgroundImageUrl: map['background_image_url']?.toString(),
      backgroundMode: map['background_mode']?.toString() ?? 'Border',
      signatoryName: map['signatory_name']?.toString() ?? 'Rev. Fr. Roy G. Reyes',
      signatoryTitle: map['signatory_title']?.toString() ?? 'Parish Priest',
      signatureImageUrl: map['signature_image_url']?.toString(),
      styleConfig: CertificateStyleConfig.fromMap(parsedStyleMap),
      enableQrVerification: enableQrParsed,
      isActive: isActiveParsed,
      isDefault: isDefaultParsed,
      version: int.tryParse(map['version']?.toString() ?? '1') ?? 1,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'sacrament_type': sacramentType,
      'template_name': templateName,
      'certificate_title': certificateTitle,
      'header_text': headerText,
      'diocese_logo_url': dioceseLogoUrl,
      'parish_seal_url': parishSealUrl,
      'show_diocese_logo': showDioceseLogo,
      'show_parish_seal': showParishSeal,
      'body_wording': bodyWording, // Strictly snake_case matching Supabase column
      'default_purpose': defaultPurpose,
      'paper_size': paperSize,
      'orientation': orientation,
      'background_image_url': backgroundImageUrl,
      'background_mode': backgroundMode,
      'signatory_name': signatoryName,
      'signatory_title': signatoryTitle,
      'signature_image_url': signatureImageUrl,
      'style_config': styleConfig.toMap(),
      'enable_qr_verification': enableQrVerification,
      'is_active': isActive,
      'is_default': isDefault,
      'version': version,
      'created_by': createdBy,
    };
  }

  CertificateTemplateModel copyWith({
    String? templateId,
    String? sacramentType,
    String? templateName,
    String? certificateTitle,
    String? headerText,
    String? dioceseLogoUrl,
    String? parishSealUrl,
    bool? showDioceseLogo,
    bool? showParishSeal,
    String? bodyWording,
    String? defaultPurpose,
    String? paperSize,
    String? orientation,
    String? backgroundImageUrl,
    String? backgroundMode,
    String? signatoryName,
    String? signatoryTitle,
    String? signatureImageUrl,
    CertificateStyleConfig? styleConfig,
    bool? enableQrVerification,
    bool? isActive,
    bool? isDefault,
    int? version,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CertificateTemplateModel(
      templateId: templateId ?? this.templateId,
      sacramentType: sacramentType ?? this.sacramentType,
      templateName: templateName ?? this.templateName,
      certificateTitle: certificateTitle ?? this.certificateTitle,
      headerText: headerText ?? this.headerText,
      dioceseLogoUrl: dioceseLogoUrl ?? this.dioceseLogoUrl,
      parishSealUrl: parishSealUrl ?? this.parishSealUrl,
      showDioceseLogo: showDioceseLogo ?? this.showDioceseLogo,
      showParishSeal: showParishSeal ?? this.showParishSeal,
      bodyWording: bodyWording ?? this.bodyWording,
      defaultPurpose: defaultPurpose ?? this.defaultPurpose,
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryTitle: signatoryTitle ?? this.signatoryTitle,
      signatureImageUrl: signatureImageUrl ?? this.signatureImageUrl,
      styleConfig: styleConfig ?? this.styleConfig,
      enableQrVerification: enableQrVerification ?? this.enableQrVerification,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}