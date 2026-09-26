import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/certificate_canvas_element.dart';
import '../models/certificate_style_config.dart';
import '../models/certificate_template_model.dart';
import '../utils/placeholder_registry.dart';

class CertificatePdfGenerator {
  CertificatePdfGenerator._();

  // Color Palette for Canonical PDF Output
  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFD49B18);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  // In-memory cache for loaded Unicode TrueType fonts
  static final Map<String, pw.Font> _fontCache = {};

  // ===========================================================================
  // Unicode TrueType Font Resolver (Resolves "no Unicode support" warnings)
  // ===========================================================================
  static Future<pw.Font> _resolveUnicodePdfFont(
      String fontFamily, {
        bool isBold = false,
        bool isItalic = false,
      }) async {
    final cacheKey =
        '${fontFamily.toLowerCase()}_${isBold ? "b" : "r"}_${isItalic ? "i" : "n"}';

    if (_fontCache.containsKey(cacheKey)) {
      return _fontCache[cacheKey]!;
    }

    pw.Font? loadedFont;

    try {
      switch (fontFamily.toLowerCase()) {
        case 'sans':
        case 'trebuchet':
          if (isBold && isItalic) {
            loadedFont = await PdfGoogleFonts.arimoBoldItalic();
          } else if (isBold) {
            loadedFont = await PdfGoogleFonts.arimoBold();
          } else if (isItalic) {
            loadedFont = await PdfGoogleFonts.arimoItalic();
          } else {
            loadedFont = await PdfGoogleFonts.arimoRegular();
          }
          break;
        case 'courier':
          if (isBold && isItalic) {
            loadedFont = await PdfGoogleFonts.cousineBoldItalic();
          } else if (isBold) {
            loadedFont = await PdfGoogleFonts.cousineBold();
          } else if (isItalic) {
            loadedFont = await PdfGoogleFonts.cousineItalic();
          } else {
            loadedFont = await PdfGoogleFonts.cousineRegular();
          }
          break;
        case 'cinzel':
          if (isBold) {
            loadedFont = await PdfGoogleFonts.cinzelBold();
          } else {
            loadedFont = await PdfGoogleFonts.cinzelRegular();
          }
          break;
        case 'garamond':
          if (isBold && isItalic) {
            loadedFont = await PdfGoogleFonts.eBGaramondBoldItalic();
          } else if (isBold) {
            loadedFont = await PdfGoogleFonts.eBGaramondBold();
          } else if (isItalic) {
            loadedFont = await PdfGoogleFonts.eBGaramondItalic();
          } else {
            loadedFont = await PdfGoogleFonts.eBGaramondRegular();
          }
          break;
        case 'script':
          if (isBold) {
            loadedFont = await PdfGoogleFonts.caveatBold();
          } else {
            loadedFont = await PdfGoogleFonts.caveatRegular();
          }
          break;
        case 'georgia':
        case 'serif':
        default:
          if (isBold && isItalic) {
            loadedFont = await PdfGoogleFonts.tinosBoldItalic();
          } else if (isBold) {
            loadedFont = await PdfGoogleFonts.tinosBold();
          } else if (isItalic) {
            loadedFont = await PdfGoogleFonts.tinosItalic();
          } else {
            loadedFont = await PdfGoogleFonts.tinosRegular();
          }
          break;
      }
    } catch (_) {
      // Offline fallback to standard Type 1 fonts
      loadedFont = _fallbackType1Font(fontFamily, isBold: isBold, isItalic: isItalic);
    }

    // Ensure non-null return value for sound null-safety
    loadedFont ??= _fallbackType1Font(fontFamily, isBold: isBold, isItalic: isItalic);
    _fontCache[cacheKey] = loadedFont;
    return loadedFont;
  }

  static pw.Font _fallbackType1Font(String fontFamily, {bool isBold = false, bool isItalic = false}) {
    switch (fontFamily.toLowerCase()) {
      case 'sans':
      case 'trebuchet':
        if (isBold && isItalic) return pw.Font.helveticaBoldOblique();
        if (isBold) return pw.Font.helveticaBold();
        if (isItalic) return pw.Font.helveticaOblique();
        return pw.Font.helvetica();
      case 'courier':
        if (isBold && isItalic) return pw.Font.courierBoldOblique();
        if (isBold) return pw.Font.courierBold();
        if (isItalic) return pw.Font.courierOblique();
        return pw.Font.courier();
      case 'script':
        if (isBold) return pw.Font.timesBoldItalic();
        return pw.Font.timesItalic();
      case 'cinzel':
      case 'georgia':
      case 'garamond':
      case 'serif':
      default:
        if (isBold && isItalic) return pw.Font.timesBoldItalic();
        if (isBold) return pw.Font.timesBold();
        if (isItalic) return pw.Font.timesItalic();
        return pw.Font.times();
    }
  }

  // ===========================================================================
  // Unicode / Glyph Sanitizer
  // ===========================================================================
  static String sanitizePdfText(String text) {
    return text
        .replaceAll('•', '-')
        .replaceAll('\u2022', '-')
        .replaceAll('₱', 'P ')
        .replaceAll('\u20B1', 'P ')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
  }

  static PdfColor _hexToPdfColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      int intVal = int.parse(clean, radix: 16);
      if (clean.length == 6) {
        intVal |= 0xFF000000;
      }
      return PdfColor.fromInt(intVal);
    } catch (_) {
      return textDark;
    }
  }

  /// Generates the official print-ready PDF binary data with 1:1 visual canvas parity
  static Future<Uint8List> generatePdf({
    required CertificateTemplateModel template,
    required String sacramentType,
    required Map<String, dynamic> recordData,
    required String purpose,
    required String verificationId,
    required String qrVerificationUrl,
    DateTime? issueDate,
  }) async {
    final style = template.styleConfig;

    // 1. Resolve Standard Paper Size in PostScript Points
    PdfPageFormat pageFormat;
    if (template.paperSize == 'Letter') {
      pageFormat = PdfPageFormat.letter;
    } else if (template.paperSize == 'Legal') {
      pageFormat = const PdfPageFormat(612.0, 936.0); // 8.5 x 13 in Philippine Folio Legal
    } else {
      pageFormat = PdfPageFormat.a4; // 595.28 x 841.89 pt
    }

    if (template.orientation == 'Landscape') {
      pageFormat = pageFormat.landscape;
    }

    // 2. Resolve TrueType Unicode Base Fonts
    final baseFont = await _resolveUnicodePdfFont(style.fontFamily);
    final boldFont = await _resolveUnicodePdfFont(style.fontFamily, isBold: true);
    final italicFont = await _resolveUnicodePdfFont(style.fontFamily, isItalic: true);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    // 3. Fetch Network Assets Asynchronously
    final bgImage = await _fetchNetworkImage(template.backgroundImageUrl);
    final dioceseLogo = await _fetchNetworkImage(template.dioceseLogoUrl);
    final parishSeal = await _fetchNetworkImage(template.parishSealUrl);
    final signatureImage = await _fetchNetworkImage(template.signatureImageUrl);

    // 4. Render Dynamic Wording via Placeholder Engine
    final placeholderValues = PlaceholderRegistry.extractPlaceholderValues(
      sacramentType: sacramentType,
      recordData: recordData,
      purpose: purpose,
      issueDate: issueDate,
    );

    final bool isCanvaMode = style.useVisualCanvas && style.canvasElements.isNotEmpty;

    // Pre-resolve TrueType fonts for canvas elements
    final Map<String, pw.Font> elementFonts = {};
    if (isCanvaMode) {
      for (final el in style.canvasElements) {
        final key = '${el.fontFamily}_${el.isBold}';
        if (!elementFonts.containsKey(key)) {
          elementFonts[key] = await _resolveUnicodePdfFont(el.fontFamily, isBold: el.isBold);
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Stack(
            children: [
              // A. Background / Border Layer
              if (bgImage != null)
                pw.Positioned.fill(
                  child: pw.Image(
                    pw.MemoryImage(bgImage),
                    fit: template.backgroundMode == 'Full-Page'
                        ? pw.BoxFit.cover
                        : pw.BoxFit.fill,
                  ),
                )
              else if (template.backgroundMode != 'None')
                _buildDefaultEcclesiasticalBorder(),

              // B. Content Layer
              if (isCanvaMode)
              // CANVA VISUAL MODE (Ungrouped elements, pure unbordered seals, resizable text boxes)
                ...style.canvasElements.map((element) {
                  final key = '${element.fontFamily}_${element.isBold}';
                  final elemFont = elementFonts[key] ?? (element.isBold ? boldFont : baseFont);

                  return _buildCanvaElementPdfWidget(
                    element: element,
                    template: template,
                    placeholderValues: placeholderValues,
                    pageWidth: pageFormat.width,
                    pageHeight: pageFormat.height,
                    dioceseLogo: dioceseLogo,
                    parishSeal: parishSeal,
                    signatureImage: signatureImage,
                    qrVerificationUrl: qrVerificationUrl,
                    verificationId: verificationId,
                    elemFont: elemFont,
                    boldFont: boldFont,
                  );
                })
              else
              // SIMPLE STRUCTURED MODE
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: _buildSimpleModeWidgets(
                      template: template,
                      style: style,
                      placeholderValues: placeholderValues,
                      baseFont: baseFont,
                      boldFont: boldFont,
                      dioceseLogo: dioceseLogo,
                      parishSeal: parishSeal,
                      signatureImage: signatureImage,
                      qrVerificationUrl: qrVerificationUrl,
                      verificationId: verificationId,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Sends the compiled certificate directly to the printer or OS print dialog
  static Future<void> printCertificate({
    required Uint8List pdfBytes,
    required String documentTitle,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: documentTitle,
    );
  }

  // ===========================================================================
  // 1:1 Canva-Style Unified Coordinate Element Renderer
  // ===========================================================================

  static pw.Widget _buildCanvaElementPdfWidget({
    required CertificateCanvasElement element,
    required CertificateTemplateModel template,
    required Map<String, String> placeholderValues,
    required double pageWidth,
    required double pageHeight,
    required Uint8List? dioceseLogo,
    required Uint8List? parishSeal,
    required Uint8List? signatureImage,
    required String qrVerificationUrl,
    required String verificationId,
    required pw.Font elemFont,
    required pw.Font boldFont,
  }) {
    final double elementWidth = (element.width ?? 0.84) * pageWidth;
    final double? elementHeight = element.height != null ? element.height! * pageHeight : null;
    final double pixelCenterX = element.x * pageWidth;
    final double pixelCenterY = element.y * pageHeight;
    final double left = pixelCenterX - (elementWidth / 2);
    final double top = elementHeight != null
        ? pixelCenterY - (elementHeight / 2)
        : pixelCenterY - 18;

    // 1. Ecclesiastical Header Block (Legacy composite fallback)
    if (element.elementType == 'header') {
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: elementWidth,
          child: _buildCanonicalHeader(
            template: template,
            dioceseLogoBytes: dioceseLogo,
            parishSealBytes: parishSeal,
            baseFont: elemFont,
            boldFont: boldFont,
          ),
        ),
      );
    }

    // 2. Certificate Title Banner
    if (element.elementType == 'title') {
      final titleText = sanitizePdfText(
        PlaceholderRegistry.renderTemplate(element.text, placeholderValues),
      );
      final titleColor = _hexToPdfColor(element.colorHex);
      final isBold = element.isBold;
      final titleFont = isBold ? boldFont : elemFont;

      return pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: elementWidth,
          child: pw.Center(
            child: pw.Container(
              width: 340,
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: goldAccent, width: 2.0),
                ),
              ),
              child: pw.Text(
                titleText.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: titleFont,
                  fontSize: element.fontSize,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  letterSpacing: 2.0,
                  color: titleColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 3. Independent Parish Seal Element (Pure unbordered graphic)
    if (element.elementType == 'parish_seal' || element.elementType == 'seal') {
      final double sealDiameter = element.fontSize * 4.0;

      return pw.Positioned(
        left: pixelCenterX - (sealDiameter / 2),
        top: pixelCenterY - (sealDiameter / 2),
        child: pw.SizedBox(
          width: sealDiameter,
          height: sealDiameter,
          child: _buildIndividualSealPdfWidget(
            isParish: true,
            diameter: sealDiameter,
            sealBytes: parishSeal,
            sealColor: _hexToPdfColor(element.colorHex),
            boldFont: boldFont,
          ),
        ),
      );
    }

    // 4. Independent Diocese Seal Element (Pure unbordered graphic)
    if (element.elementType == 'diocese_seal') {
      final double sealDiameter = element.fontSize * 4.0;

      return pw.Positioned(
        left: pixelCenterX - (sealDiameter / 2),
        top: pixelCenterY - (sealDiameter / 2),
        child: pw.SizedBox(
          width: sealDiameter,
          height: sealDiameter,
          child: _buildIndividualSealPdfWidget(
            isParish: false,
            diameter: sealDiameter,
            sealBytes: dioceseLogo,
            sealColor: _hexToPdfColor(element.colorHex),
            boldFont: boldFont,
          ),
        ),
      );
    }

    // 5. UNGROUPED SIGNATURE LINE
    if (element.elementType == 'signature_line' || element.elementType == 'signature') {
      return pw.Positioned(
        left: left,
        top: pixelCenterY - 10,
        child: pw.SizedBox(
          width: elementWidth,
          child: pw.Column(
            children: [
              if (signatureImage != null)
                pw.Container(
                  height: 32,
                  child: pw.Image(pw.MemoryImage(signatureImage), fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(height: 24),
              pw.Container(
                width: elementWidth,
                height: 1.0,
                color: _hexToPdfColor(element.colorHex),
              ),
            ],
          ),
        ),
      );
    }

    // 6. QR Verification Block
    if (element.elementType == 'qr') {
      return pw.Positioned(
        left: pixelCenterX - (elementWidth / 2),
        top: pixelCenterY - 18,
        child: pw.SizedBox(
          width: elementWidth,
          child: pw.Center(
            child: _buildQrBlock(
              qrUrl: qrVerificationUrl,
              verificationId: verificationId,
              baseFont: elemFont,
              boldFont: boldFont,
            ),
          ),
        ),
      );
    }

    // 7. Signatory Block (Legacy composite fallback)
    if (element.elementType == 'signatory') {
      return pw.Positioned(
        left: pixelCenterX - (elementWidth / 2),
        top: pixelCenterY - 18,
        child: pw.SizedBox(
          width: elementWidth,
          child: _buildSignatoryBlock(
            template: template,
            signatureBytes: signatureImage,
            baseFont: elemFont,
            boldFont: boldFont,
          ),
        ),
      );
    }

    // 8. Text Boxes, Ungrouped Header Lines, Signatory Name/Title with Auto-Wrap
    final resolvedText = sanitizePdfText(
      PlaceholderRegistry.renderTemplate(element.text, placeholderValues),
    );
    final isBold = element.isBold;
    final elemColor = _hexToPdfColor(element.colorHex);

    pw.TextAlign align;
    switch (element.textAlign.toLowerCase()) {
      case 'left':
        align = pw.TextAlign.left;
        break;
      case 'right':
        align = pw.TextAlign.right;
        break;
      case 'center':
      default:
        align = pw.TextAlign.center;
        break;
    }

    double letterSpacing = 0.0;
    if (element.fontFamily.toLowerCase() == 'cinzel') letterSpacing = 2.0;

    return pw.Positioned(
      left: left,
      top: top,
      child: pw.SizedBox(
        width: elementWidth,
        height: elementHeight,
        child: pw.Text(
          resolvedText,
          textAlign: align,
          style: pw.TextStyle(
            font: elemFont,
            fontSize: element.fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: elemColor,
            letterSpacing: letterSpacing,
            lineSpacing: 3.5,
          ),
        ),
      ),
    );
  }

  /// Renders clean unbordered seal image matching the visual canvas
  static pw.Widget _buildIndividualSealPdfWidget({
    required bool isParish,
    required double diameter,
    required Uint8List? sealBytes,
    required PdfColor sealColor,
    required pw.Font boldFont,
  }) {
    final String fallbackLabel = isParish ? 'SJP2' : 'DSP';

    if (sealBytes != null) {
      return pw.Center(
        child: pw.Image(
          pw.MemoryImage(sealBytes),
          width: diameter,
          height: diameter,
          fit: pw.BoxFit.contain,
        ),
      );
    }

    return pw.Container(
      width: diameter,
      height: diameter,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Text(
          fallbackLabel,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: diameter * 0.22,
            fontWeight: pw.FontWeight.bold,
            color: sealColor,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Simple Mode Sequential Structured Flow
  // ===========================================================================

  static List<pw.Widget> _buildSimpleModeWidgets({
    required CertificateTemplateModel template,
    required CertificateStyleConfig style,
    required Map<String, String> placeholderValues,
    required pw.Font baseFont,
    required pw.Font boldFont,
    required Uint8List? dioceseLogo,
    required Uint8List? parishSeal,
    required Uint8List? signatureImage,
    required String qrVerificationUrl,
    required String verificationId,
  }) {
    final renderedBody = sanitizePdfText(
      PlaceholderRegistry.renderTemplate(
        template.bodyWording,
        placeholderValues,
      ),
    );

    pw.Widget headerWidget = _buildCanonicalHeader(
      template: template,
      dioceseLogoBytes: dioceseLogo,
      parishSealBytes: parishSeal,
      baseFont: baseFont,
      boldFont: boldFont,
    );

    pw.Widget titleWidget = _buildCertificateTitle(
      title: template.certificateTitle,
      style: style,
      baseFont: baseFont,
      boldFont: boldFont,
    );

    pw.Widget bodyWidget = _buildBodyWording(
      renderedText: renderedBody,
      style: style,
      baseFont: baseFont,
      boldFont: boldFont,
    );

    pw.Widget footerWidget = _buildFooterLayout(
      template: template,
      style: style,
      signatureBytes: signatureImage,
      qrUrl: qrVerificationUrl,
      verificationId: verificationId,
      baseFont: baseFont,
      boldFont: boldFont,
    );

    final sectionMap = <String, pw.Widget>{
      'header': headerWidget,
      'title': titleWidget,
      'body': bodyWidget,
      'footer': footerWidget,
    };

    final List<pw.Widget> ordered = [];
    final activeOrder = style.sectionOrder.isNotEmpty
        ? style.sectionOrder
        : const ['header', 'title', 'body', 'footer'];

    for (final key in activeOrder) {
      final w = sectionMap[key];
      if (w != null) {
        if (key == 'body') {
          ordered.add(pw.Expanded(child: w));
        } else {
          ordered.add(w);
        }
        ordered.add(pw.SizedBox(height: 16));
      }
    }

    if (ordered.isNotEmpty && ordered.last is pw.SizedBox) {
      ordered.removeLast();
    }
    return ordered;
  }

  // ===========================================================================
  // Shared Canonical Header & Layout Elements
  // ===========================================================================

  static pw.Widget _buildCanonicalHeader({
    required CertificateTemplateModel template,
    required Uint8List? dioceseLogoBytes,
    required Uint8List? parishSealBytes,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final lines = template.headerLines;
    final line1 = lines.isNotEmpty ? lines[0] : 'Diocese of San Pablo';
    final line2 = lines.length > 1 ? lines[1] : 'Saint John Paul II Parish';
    final line3 = lines.length > 2 ? lines.sublist(2).join(', ') : 'Santa Cruz, Laguna';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (template.showDioceseLogo)
          pw.SizedBox(
            width: 58,
            height: 58,
            child: dioceseLogoBytes != null
                ? pw.Image(pw.MemoryImage(dioceseLogoBytes), fit: pw.BoxFit.contain)
                : _buildFallbackCrest(label: 'DSP', boldFont: boldFont),
          )
        else
          pw.SizedBox(width: 58),

        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                line1,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                line2,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                  color: marianBlue,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                line3,
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 9.5,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),

        if (template.showParishSeal)
          pw.SizedBox(
            width: 58,
            height: 58,
            child: parishSealBytes != null
                ? pw.Image(pw.MemoryImage(parishSealBytes), fit: pw.BoxFit.contain)
                : _buildFallbackCrest(label: 'SJP2', boldFont: boldFont),
          )
        else
          pw.SizedBox(width: 58),
      ],
    );
  }

  static pw.Widget _buildCertificateTitle({
    required String title,
    required CertificateStyleConfig style,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final isBold = style.titleFontWeight == 'bold';
    final titleFont = isBold ? boldFont : baseFont;
    final cleanTitle = sanitizePdfText(title);

    return pw.Column(
      children: [
        pw.Container(
          width: 340,
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: goldAccent, width: 2.0),
            ),
          ),
          child: pw.Text(
            cleanTitle.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: titleFont,
              fontSize: style.titleFontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              letterSpacing: 2.0,
              color: marianBlue,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBodyWording({
    required String renderedText,
    required CertificateStyleConfig style,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final paragraphs = renderedText.split('\n\n');
    final isBold = style.bodyFontWeight == 'bold';
    final bodyFont = isBold ? boldFont : baseFont;

    pw.TextAlign textAlign;
    switch (style.textAlignment.toLowerCase()) {
      case 'left':
        textAlign = pw.TextAlign.left;
        break;
      case 'justify':
        textAlign = pw.TextAlign.justify;
        break;
      case 'center':
      default:
        textAlign = pw.TextAlign.center;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: paragraphs.map((p) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              p.trim(),
              textAlign: textAlign,
              style: pw.TextStyle(
                font: bodyFont,
                fontSize: style.bodyFontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                lineSpacing: style.bodyLineSpacing,
                color: textDark,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildFooterLayout({
    required CertificateTemplateModel template,
    required CertificateStyleConfig style,
    required Uint8List? signatureBytes,
    required String qrUrl,
    required String verificationId,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    final showQr = template.enableQrVerification && style.qrPosition != 'none';

    final qrWidget = showQr
        ? _buildQrBlock(
      qrUrl: qrUrl,
      verificationId: verificationId,
      baseFont: baseFont,
      boldFont: boldFont,
    )
        : pw.SizedBox(width: 80);

    final signatoryWidget = _buildSignatoryBlock(
      template: template,
      signatureBytes: signatureBytes,
      baseFont: baseFont,
      boldFont: boldFont,
    );

    if (style.signatoryPosition == 'bottom-center') {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          signatoryWidget,
          if (showQr) ...[
            pw.SizedBox(height: 12),
            qrWidget,
          ],
        ],
      );
    }

    if (style.signatoryPosition == 'bottom-left' && style.qrPosition == 'bottom-right') {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          signatoryWidget,
          qrWidget,
        ],
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        qrWidget,
        signatoryWidget,
      ],
    );
  }

  static pw.Widget _buildQrBlock({
    required String qrUrl,
    required String verificationId,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: borderGrey, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrUrl,
            width: 62,
            height: 62,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Verification Token:',
          style: pw.TextStyle(font: baseFont, fontSize: 6.5, color: textMuted),
        ),
        pw.Text(
          verificationId.length > 18
              ? '${verificationId.substring(0, 18)}...'
              : verificationId,
          style: pw.TextStyle(font: boldFont, fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark),
        ),
        pw.Text(
          'Scan QR to verify canonical authenticity',
          style: pw.TextStyle(font: baseFont, fontSize: 6.0, color: textMuted),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatoryBlock({
    required CertificateTemplateModel template,
    required Uint8List? signatureBytes,
    required pw.Font baseFont,
    required pw.Font boldFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (signatureBytes != null)
          pw.Container(
            height: 38,
            child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
          )
        else
          pw.SizedBox(height: 34),

        pw.Container(
          width: 180,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: textDark, width: 1)),
          ),
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Column(
            children: [
              pw.Text(
                template.signatoryName,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                template.signatoryTitle,
                style: pw.TextStyle(font: baseFont, fontSize: 8.5, color: textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDefaultEcclesiasticalBorder() {
    return pw.Positioned.fill(
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(16.0),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: goldAccent, width: 2.5),
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(5.0),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: marianBlue, width: 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildFallbackCrest({
    required String label,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Text(
          label,
          style: pw.TextStyle(font: boldFont, fontSize: 9, fontWeight: pw.FontWeight.bold, color: marianBlue),
        ),
      ),
    );
  }

  static Future<Uint8List?> _fetchNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}