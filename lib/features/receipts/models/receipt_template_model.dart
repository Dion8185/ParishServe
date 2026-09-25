import '../../sacramental_records/models/certificate_canvas_element.dart';

class ReceiptStyleConfig {
  final String fontFamily; // 'serif', 'sans', 'courier', 'cinzel', etc.
  final double titleFontSize;
  final String titleFontWeight; // 'bold', 'normal'
  final double bodyFontSize;
  final String bodyFontWeight;
  final double bodyLineSpacing;
  final String textAlignment; // 'left', 'center', 'right'

  // Snap Anchors for Simple / Structured Mode
  final String qrPosition; // 'bottom-left', 'bottom-center', 'bottom-right', 'none'
  final String signatoryPosition; // 'bottom-right', 'bottom-center', 'bottom-left'

  //  Advanced Mode Toggle & Elements
  final bool useVisualCanvas;
  final List<CertificateCanvasElement> canvasElements;

  const ReceiptStyleConfig({
    this.fontFamily = 'serif',
    this.titleFontSize = 16.0,
    this.titleFontWeight = 'bold',
    this.bodyFontSize = 10.5,
    this.bodyFontWeight = 'normal',
    this.bodyLineSpacing = 4.0,
    this.textAlignment = 'left',
    this.qrPosition = 'bottom-left',
    this.signatoryPosition = 'bottom-right',
    this.useVisualCanvas = false,
    this.canvasElements = const [],
  });

  static const ReceiptStyleConfig defaultConfig = ReceiptStyleConfig();

  factory ReceiptStyleConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaultConfig;

    List<CertificateCanvasElement> parseCanvasElements(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => CertificateCanvasElement.fromMap(e))
            .toList();
      }
      return const [];
    }

    return ReceiptStyleConfig(
      fontFamily: map['fontFamily']?.toString() ?? 'serif',
      titleFontSize: (map['titleFontSize'] as num?)?.toDouble() ?? 16.0,
      titleFontWeight: map['titleFontWeight']?.toString() ?? 'bold',
      bodyFontSize: (map['bodyFontSize'] as num?)?.toDouble() ?? 10.5,
      bodyFontWeight: map['bodyFontWeight']?.toString() ?? 'normal',
      bodyLineSpacing: (map['bodyLineSpacing'] as num?)?.toDouble() ?? 4.0,
      textAlignment: map['textAlignment']?.toString() ?? 'left',
      qrPosition: map['qrPosition']?.toString() ?? 'bottom-left',
      signatoryPosition: map['signatoryPosition']?.toString() ?? 'bottom-right',
      useVisualCanvas: map['useVisualCanvas'] == true,
      canvasElements: parseCanvasElements(map['canvasElements']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontFamily': fontFamily,
      'titleFontSize': titleFontSize,
      'titleFontWeight': titleFontWeight,
      'bodyFontSize': bodyFontSize,
      'bodyFontWeight': bodyFontWeight,
      'bodyLineSpacing': bodyLineSpacing,
      'textAlignment': textAlignment,
      'qrPosition': qrPosition,
      'signatoryPosition': signatoryPosition,
      'useVisualCanvas': useVisualCanvas,
      'canvasElements': canvasElements.map((e) => e.toMap()).toList(),
    };
  }

  ReceiptStyleConfig copyWith({
    String? fontFamily,
    double? titleFontSize,
    String? titleFontWeight,
    double? bodyFontSize,
    String? bodyFontWeight,
    double? bodyLineSpacing,
    String? textAlignment,
    String? qrPosition,
    String? signatoryPosition,
    bool? useVisualCanvas,
    List<CertificateCanvasElement>? canvasElements,
  }) {
    return ReceiptStyleConfig(
      fontFamily: fontFamily ?? this.fontFamily,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titleFontWeight: titleFontWeight ?? this.titleFontWeight,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      bodyFontWeight: bodyFontWeight ?? this.bodyFontWeight,
      bodyLineSpacing: bodyLineSpacing ?? this.bodyLineSpacing,
      textAlignment: textAlignment ?? this.textAlignment,
      qrPosition: qrPosition ?? this.qrPosition,
      signatoryPosition: signatoryPosition ?? this.signatoryPosition,
      useVisualCanvas: useVisualCanvas ?? this.useVisualCanvas,
      canvasElements: canvasElements ?? this.canvasElements,
    );
  }
}

class ReceiptTemplateModel {
  final String templateId;
  final String templateName;
  final String receiptTitle;
  final String headerText;

  // Supported Paper Sizes:
  // 'A4', 'Letter', 'Legal' (8.5 x 13 in Philippine long), 'Ecclesiastical' (8.5 x 4.125 in)
  final String paperSize;
  final String orientation; // 'Portrait', 'Landscape'

  // Decorative Border / Background: 'None' (Plain), 'Border', 'Full-Page'
  final String? backgroundImageUrl;
  final String backgroundMode;

  // Logos & Emblems
  final String? dioceseLogoUrl;
  final String? parishSealUrl;
  final bool showDioceseLogo;
  final bool showParishSeal;

  // Signatory & Cashier Configuration
  final String cashierTitle;
  final String parishPriestName;
  final String? signatureImageUrl;

  // Verification & Security
  final bool enableQrVerification;

  //  Style & Element JSON Configuration
  final ReceiptStyleConfig styleConfig;

  final bool isDefault;
  final bool isActive;
  final int version;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReceiptTemplateModel({
    required this.templateId,
    required this.templateName,
    this.receiptTitle = 'OFFICIAL RECEIPT',
    this.headerText = 'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
    this.paperSize = 'Ecclesiastical',
    this.orientation = 'Landscape',
    this.backgroundImageUrl,
    this.backgroundMode = 'None', // Default is completely plain (no border)
    this.dioceseLogoUrl,
    this.parishSealUrl,
    this.showDioceseLogo = true,
    this.showParishSeal = true,
    this.cashierTitle = 'Parish Cashier / Secretary',
    this.parishPriestName = 'Rev. Fr. Joseph Santos',
    this.signatureImageUrl,
    this.enableQrVerification = true,
    this.styleConfig = ReceiptStyleConfig.defaultConfig,
    this.isDefault = false,
    this.isActive = true,
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

  /// Calculates exact physical page dimensions in PostScript points (72 points = 1 inch)
  (double width, double height) get pageDimensionsInPoints {
    double width;
    double height;

    switch (paperSize.toLowerCase()) {
      case 'letter':
      // 8.5 x 11.0 in
        width = 8.5 * 72.0; // 612.0
        height = 11.0 * 72.0; // 792.0
        break;
      case 'legal':
      case 'legal (8.5 x 13 in)':
      case 'legal (8.5 x 13)':
      // Standard Philippine Folio / Legal (8.5 x 13.0 in)
        width = 8.5 * 72.0; // 612.0
        height = 13.0 * 72.0; // 936.0
        break;
      case 'a4':
      // Standard A4 (210 x 297 mm)
        width = 595.28;
        height = 841.89;
        break;
      case 'ecclesiastical':
      case 'ecclesiastical receipt':
      case 'ecclesiastical receipt (8.5 x 4.125 in)':
      default:
      // Canonical Voucher Slip (8.5 x 4.125 in / 215.9 x 104.775 mm)
        width = 8.5 * 72.0; // 612.0
        height = 4.125 * 72.0; // 297.0
        break;
    }

    if (orientation.toLowerCase() == 'landscape') {
      if (width < height) {
        return (height, width);
      }
      return (width, height);
    } else {
      if (width > height) {
        return (height, width);
      }
      return (width, height);
    }
  }

  factory ReceiptTemplateModel.fromMap(Map<String, dynamic> map) {
    return ReceiptTemplateModel(
      templateId: map['template_id']?.toString() ?? '',
      templateName: map['template_name']?.toString() ?? 'Official Receipt Template',
      receiptTitle: map['receipt_title']?.toString() ?? 'OFFICIAL RECEIPT',
      headerText: map['header_text']?.toString() ??
          'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
      paperSize: map['paper_size']?.toString() ?? 'Ecclesiastical',
      orientation: map['orientation']?.toString() ?? 'Landscape',
      backgroundImageUrl: map['background_image_url']?.toString(),
      backgroundMode: map['background_mode']?.toString() ?? 'None',
      dioceseLogoUrl: map['diocese_logo_url']?.toString(),
      parishSealUrl: map['parish_seal_url']?.toString(),
      showDioceseLogo: map['show_diocese_logo'] ?? true,
      showParishSeal: map['show_parish_seal'] ?? true,
      cashierTitle: map['cashier_title']?.toString() ?? 'Parish Cashier / Secretary',
      parishPriestName: map['parish_priest_name']?.toString() ?? 'Rev. Fr. Joseph Santos',
      signatureImageUrl: map['signature_image_url']?.toString(),
      enableQrVerification: map['enable_qr_verification'] ?? true,
      styleConfig: ReceiptStyleConfig.fromMap(
        map['style_config'] is Map<String, dynamic>
            ? map['style_config'] as Map<String, dynamic>
            : null,
      ),
      isDefault: map['is_default'] ?? false,
      isActive: map['is_active'] ?? true,
      version: int.tryParse(map['version']?.toString() ?? '1') ?? 1,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'template_name': templateName,
      'receipt_title': receiptTitle,
      'header_text': headerText,
      'paper_size': paperSize,
      'orientation': orientation,
      'background_image_url': backgroundImageUrl,
      'background_mode': backgroundMode,
      'diocese_logo_url': dioceseLogoUrl,
      'parish_seal_url': parishSealUrl,
      'show_diocese_logo': showDioceseLogo,
      'show_parish_seal': showParishSeal,
      'cashier_title': cashierTitle,
      'parish_priest_name': parishPriestName,
      'signature_image_url': signatureImageUrl,
      'enable_qr_verification': enableQrVerification,
      'style_config': styleConfig.toMap(),
      'is_default': isDefault,
      'is_active': isActive,
      'version': version,
      'created_by': createdBy,
    };
  }

  ReceiptTemplateModel copyWith({
    String? templateId,
    String? templateName,
    String? receiptTitle,
    String? headerText,
    String? paperSize,
    String? orientation,
    String? backgroundImageUrl,
    String? backgroundMode,
    String? dioceseLogoUrl,
    String? parishSealUrl,
    bool? showDioceseLogo,
    bool? showParishSeal,
    String? cashierTitle,
    String? parishPriestName,
    String? signatureImageUrl,
    bool? enableQrVerification,
    ReceiptStyleConfig? styleConfig,
    bool? isDefault,
    bool? isActive,
    int? version,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReceiptTemplateModel(
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      receiptTitle: receiptTitle ?? this.receiptTitle,
      headerText: headerText ?? this.headerText,
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      dioceseLogoUrl: dioceseLogoUrl ?? this.dioceseLogoUrl,
      parishSealUrl: parishSealUrl ?? this.parishSealUrl,
      showDioceseLogo: showDioceseLogo ?? this.showDioceseLogo,
      showParishSeal: showParishSeal ?? this.showParishSeal,
      cashierTitle: cashierTitle ?? this.cashierTitle,
      parishPriestName: parishPriestName ?? this.parishPriestName,
      signatureImageUrl: signatureImageUrl ?? this.signatureImageUrl,
      enableQrVerification: enableQrVerification ?? this.enableQrVerification,
      styleConfig: styleConfig ?? this.styleConfig,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}