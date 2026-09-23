import 'certificate_canvas_element.dart';

class CertificateStyleConfig {
  // Simple Mode Controls (Word-Processor Style)
  final String fontFamily; // 'serif' (Times), 'sans' (Helvetica), 'courier' (Typewriter)
  final double titleFontSize; // e.g. 14.0 - 24.0
  final String titleFontWeight; // 'bold', 'normal'
  final double bodyFontSize; // e.g. 9.0 - 16.0
  final String bodyFontWeight; // 'normal', 'bold'
  final double bodyLineSpacing; // e.g. 3.0 - 8.0
  final String textAlignment; // 'center', 'justify', 'left'

  // Snap Anchors for Simple Mode
  final String qrPosition; // 'bottom-left', 'bottom-center', 'bottom-right', 'none'
  final String signatoryPosition; // 'bottom-right', 'bottom-center', 'bottom-left'
  final List<String> sectionOrder; // e.g. ['header', 'title', 'body', 'footer']

  // Canva-Style Advanced Mode Toggle & Elements
  final bool useVisualCanvas; // Toggle between Simple Mode and Canva Drag & Drop
  final List<CertificateCanvasElement> canvasElements;

  const CertificateStyleConfig({
    this.fontFamily = 'serif',
    this.titleFontSize = 16.0,
    this.titleFontWeight = 'bold',
    this.bodyFontSize = 11.5,
    this.bodyFontWeight = 'normal',
    this.bodyLineSpacing = 5.0,
    this.textAlignment = 'center',
    this.qrPosition = 'bottom-left',
    this.signatoryPosition = 'bottom-right',
    this.sectionOrder = const ['header', 'title', 'body', 'footer'],
    this.useVisualCanvas = false,
    this.canvasElements = const [],
  });

  static const CertificateStyleConfig defaultConfig = CertificateStyleConfig();

  factory CertificateStyleConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaultConfig;

    List<String> parseOrder(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const ['header', 'title', 'body', 'footer'];
    }

    List<CertificateCanvasElement> parseCanvasElements(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((e) => CertificateCanvasElement.fromMap(e))
            .toList();
      }
      return const [];
    }

    return CertificateStyleConfig(
      fontFamily: map['fontFamily']?.toString() ?? 'serif',
      titleFontSize: (map['titleFontSize'] as num?)?.toDouble() ?? 16.0,
      titleFontWeight: map['titleFontWeight']?.toString() ?? 'bold',
      bodyFontSize: (map['bodyFontSize'] as num?)?.toDouble() ?? 11.5,
      bodyFontWeight: map['bodyFontWeight']?.toString() ?? 'normal',
      bodyLineSpacing: (map['bodyLineSpacing'] as num?)?.toDouble() ?? 5.0,
      textAlignment: map['textAlignment']?.toString() ?? 'center',
      qrPosition: map['qrPosition']?.toString() ?? 'bottom-left',
      signatoryPosition: map['signatoryPosition']?.toString() ?? 'bottom-right',
      sectionOrder: parseOrder(map['sectionOrder']),
      useVisualCanvas: map['useVisualCanvas'] ?? false,
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
      'sectionOrder': sectionOrder,
      'useVisualCanvas': useVisualCanvas,
      'canvasElements': canvasElements.map((e) => e.toMap()).toList(),
    };
  }

  CertificateStyleConfig copyWith({
    String? fontFamily,
    double? titleFontSize,
    String? titleFontWeight,
    double? bodyFontSize,
    String? bodyFontWeight,
    double? bodyLineSpacing,
    String? textAlignment,
    String? qrPosition,
    String? signatoryPosition,
    List<String>? sectionOrder,
    bool? useVisualCanvas,
    List<CertificateCanvasElement>? canvasElements,
  }) {
    return CertificateStyleConfig(
      fontFamily: fontFamily ?? this.fontFamily,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titleFontWeight: titleFontWeight ?? this.titleFontWeight,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      bodyFontWeight: bodyFontWeight ?? this.bodyFontWeight,
      bodyLineSpacing: bodyLineSpacing ?? this.bodyLineSpacing,
      textAlignment: textAlignment ?? this.textAlignment,
      qrPosition: qrPosition ?? this.qrPosition,
      signatoryPosition: signatoryPosition ?? this.signatoryPosition,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      useVisualCanvas: useVisualCanvas ?? this.useVisualCanvas,
      canvasElements: canvasElements ?? this.canvasElements,
    );
  }
}