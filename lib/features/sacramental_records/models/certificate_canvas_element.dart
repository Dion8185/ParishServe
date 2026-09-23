class CertificateCanvasElement {
  final String id;
  final String elementType; // 'text', 'placeholder', 'title', 'header', 'qr', 'signatory'
  final String text; // Static wording or placeholder tag like '{Full Name}'
  final double x; // Normalized horizontal coordinate (0.0 to 1.0)
  final double y; // Normalized vertical coordinate (0.0 to 1.0)
  final double? width; // Optional bounding width
  final double fontSize;
  final String fontWeight; // 'bold', 'normal'
  final String fontFamily; // 'serif', 'sans', 'courier'
  final String colorHex; // e.g. '#164E87', '#D49B18', '#1E293B'
  final String textAlign; // 'center', 'left', 'right'

  const CertificateCanvasElement({
    required this.id,
    required this.elementType,
    required this.text,
    required this.x,
    required this.y,
    this.width,
    this.fontSize = 12.0,
    this.fontWeight = 'normal',
    this.fontFamily = 'serif',
    this.colorHex = '#1E293B',
    this.textAlign = 'center',
  });

  bool get isBold => fontWeight == 'bold';

  CertificateCanvasElement copyWith({
    String? id,
    String? elementType,
    String? text,
    double? x,
    double? y,
    double? width,
    double? fontSize,
    String? fontWeight,
    String? fontFamily,
    String? colorHex,
    String? textAlign,
  }) {
    return CertificateCanvasElement(
      id: id ?? this.id,
      elementType: elementType ?? this.elementType,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      colorHex: colorHex ?? this.colorHex,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  factory CertificateCanvasElement.fromMap(Map<String, dynamic> map) {
    return CertificateCanvasElement(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      elementType: map['elementType']?.toString() ?? 'text',
      text: map['text']?.toString() ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      width: (map['width'] as num?)?.toDouble(),
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 12.0,
      fontWeight: map['fontWeight']?.toString() ?? 'normal',
      fontFamily: map['fontFamily']?.toString() ?? 'serif',
      colorHex: map['colorHex']?.toString() ?? '#1E293B',
      textAlign: map['textAlign']?.toString() ?? 'center',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'elementType': elementType,
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'fontSize': fontSize,
      'fontWeight': fontWeight,
      'fontFamily': fontFamily,
      'colorHex': colorHex,
      'textAlign': textAlign,
    };
  }
}