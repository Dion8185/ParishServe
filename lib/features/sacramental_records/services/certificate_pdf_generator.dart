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

  /// Converts a hex color string (e.g. #164E87) to PdfColor
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

  /// Maps the 8 expanded font families to vector PostScript fonts
  static pw.Font _resolvePdfFont(String fontFamily, {bool isBold = false, bool isItalic = false}) {
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
      // Cursive calligraphic style
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

  /// Generates the official print-ready PDF binary data with 1:1 visual canvas parity.
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
      pageFormat = PdfPageFormat.legal;
    } else {
      pageFormat = PdfPageFormat.a4; // 595.28 x 841.89 pt
    }

    if (template.orientation == 'Landscape') {
      pageFormat = pageFormat.landscape;
    }

    // 2. Resolve Base Fonts
    final baseFont = _resolvePdfFont(style.fontFamily);
    final boldFont = _resolvePdfFont(style.fontFamily, isBold: true);
    final italicFont = _resolvePdfFont(style.fontFamily, isItalic: true);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    // 3. Fetch Network Assets Asynchronously with Graceful Fallbacks
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

    // 5. Verification of Mode: Canva Visual Mode overwrites Simple Mode completely
    final bool isCanvaMode = style.useVisualCanvas && style.canvasElements.isNotEmpty;

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
              else
                _buildDefaultEcclesiasticalBorder(),

              // B. Content Layer
              if (isCanvaMode)
              // CANVA-STYLE VISUAL MODE: 1:1 Center-Anchor Proportional Points
                ...style.canvasElements.map((element) {
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
                  );
                })
              else
              // SIMPLE MODE: Sequential Structured Fallback
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

  /// Sends the compiled certificate directly to the printer or OS print dialog.
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
  }) {
    final bool isItalic = element.fontFamily.toLowerCase() == 'script';
    final elemBaseFont = _resolvePdfFont(element.fontFamily, isItalic: isItalic);
    final elemBoldFont = _resolvePdfFont(element.fontFamily, isBold: true, isItalic: isItalic);

    final double elementWidth = (element.width ?? 0.84) * pageWidth;
    final double pixelCenterX = element.x * pageWidth;
    final double pixelCenterY = element.y * pageHeight;
    final double left = pixelCenterX - (elementWidth / 2);
    final double top = pixelCenterY - 18;

    // 1. Ecclesiastical Header Block
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
            baseFont: elemBaseFont,
            boldFont: elemBoldFont,
          ),
        ),
      );
    }

    // 2. Certificate Title Banner
    if (element.elementType == 'title') {
      final titleText = PlaceholderRegistry.renderTemplate(element.text, placeholderValues);
      final titleColor = _hexToPdfColor(element.colorHex);
      final isBold = element.isBold;
      final titleFont = isBold ? elemBoldFont : elemBaseFont;

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

    // 3. Independent Parish Seal Element
    if (element.elementType == 'parish_seal' || element.elementType == 'seal') {
      final double sealDiameter = element.fontSize * 4.5;
      final sealColor = _hexToPdfColor(element.colorHex);

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
            sealColor: sealColor,
            boldFont: elemBoldFont,
          ),
        ),
      );
    }

    // 4. Independent Diocese Seal Element
    if (element.elementType == 'diocese_seal') {
      final double sealDiameter = element.fontSize * 4.5;
      final sealColor = _hexToPdfColor(element.colorHex);

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
            sealColor: sealColor,
            boldFont: elemBoldFont,
          ),
        ),
      );
    }

    // 5. QR Verification Block
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
              baseFont: elemBaseFont,
              boldFont: elemBoldFont,
            ),
          ),
        ),
      );
    }

    // 6. Signatory Block
    if (element.elementType == 'signatory') {
      return pw.Positioned(
        left: pixelCenterX - (elementWidth / 2),
        top: pixelCenterY - 18,
        child: pw.SizedBox(
          width: elementWidth,
          child: _buildSignatoryBlock(
            template: template,
            signatureBytes: signatureImage,
            baseFont: elemBaseFont,
            boldFont: elemBoldFont,
          ),
        ),
      );
    }

    // 7. Freeform Text & Dynamic Placeholders
    final resolvedText = PlaceholderRegistry.renderTemplate(element.text, placeholderValues);
    final isBold = element.isBold;
    final elemFont = isBold ? elemBoldFont : elemBaseFont;
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

  /// Renders an independent circular Parish or Diocese Seal matching the visual canvas
  static pw.Widget _buildIndividualSealPdfWidget({
    required bool isParish,
    required double diameter,
    required Uint8List? sealBytes,
    required PdfColor sealColor,
    required pw.Font boldFont,
  }) {
    final String fallbackLabel = isParish ? 'SJP2' : 'DSP';
    final String sealTitle = isParish ? 'PARISH SEAL' : 'DIOCESE EMBLEM';

    return pw.Container(
      width: diameter,
      height: diameter,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: PdfColors.white,
        border: pw.Border.all(color: sealColor, width: 2.2),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(3.0),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: sealColor, width: 1.0),
          ),
          child: sealBytes != null
              ? pw.ClipOval(
            child: pw.Image(
              pw.MemoryImage(sealBytes),
              fit: pw.BoxFit.contain,
            ),
          )
              : pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  fallbackLabel,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: diameter * 0.16,
                    fontWeight: pw.FontWeight.bold,
                    color: sealColor,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  sealTitle,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: diameter * 0.08,
                    fontWeight: pw.FontWeight.bold,
                    color: sealColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Simple Mode Sequential Structured Flow (When Canva Mode is Untoggled)
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
    final renderedBody = PlaceholderRegistry.renderTemplate(
      template.bodyWording,
      placeholderValues,
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
            title.toUpperCase(),
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
        padding: const pw.EdgeInsets.all(16.0), // Matches exact 16pt canvas margin
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: goldAccent, width: 2.5),
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(5.0), // Matches exact 5pt inner canvas offset
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
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: goldAccent, width: 1.5),
        color: PdfColors.grey100,
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