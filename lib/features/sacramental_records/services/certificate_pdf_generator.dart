import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  /// Generates the official print-ready PDF binary data with dynamic typography and layout.
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

    // 1. Resolve Paper Size & Orientation
    PdfPageFormat pageFormat;
    if (template.paperSize == 'Letter') {
      pageFormat = PdfPageFormat.letter;
    } else if (template.paperSize == 'Legal') {
      pageFormat = PdfPageFormat.legal;
    } else {
      pageFormat = PdfPageFormat.a4;
    }

    if (template.orientation == 'Landscape') {
      pageFormat = pageFormat.landscape;
    }

    // 2. Resolve Curated PostScript Fonts (Zero latency, built into all PDF readers)
    pw.Font baseFont;
    pw.Font boldFont;
    pw.Font italicFont;

    switch (style.fontFamily.toLowerCase()) {
      case 'sans':
        baseFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
        italicFont = pw.Font.helveticaOblique();
        break;
      case 'courier':
        baseFont = pw.Font.courier();
        boldFont = pw.Font.courierBold();
        italicFont = pw.Font.courierOblique();
        break;
      case 'serif':
      default:
        baseFont = pw.Font.times();
        boldFont = pw.Font.timesBold();
        italicFont = pw.Font.timesItalic();
        break;
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    // 3. Fetch Assets Asynchronously with Graceful Fallbacks
    final bgImage = await _fetchNetworkImage(template.backgroundImageUrl);
    final dioceseLogo = template.showDioceseLogo
        ? await _fetchNetworkImage(template.dioceseLogoUrl)
        : null;
    final parishSeal = template.showParishSeal
        ? await _fetchNetworkImage(template.parishSealUrl)
        : null;
    final signatureImage = await _fetchNetworkImage(template.signatureImageUrl);

    // 4. Render Dynamic Wording via Placeholder Engine
    final placeholderValues = PlaceholderRegistry.extractPlaceholderValues(
      sacramentType: sacramentType,
      recordData: recordData,
      purpose: purpose,
      issueDate: issueDate,
    );
    final renderedBody = PlaceholderRegistry.renderTemplate(
      template.bodyWording,
      placeholderValues,
    );

    // 5. Construct Modular Sections for Dynamic Ordering
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

    // Map section names to widgets
    final sectionMap = <String, pw.Widget>{
      'header': headerWidget,
      'title': titleWidget,
      'body': bodyWidget,
      'footer': footerWidget,
    };

    // Arrange sections in user-configured sequence
    final List<pw.Widget> orderedWidgets = [];
    final activeOrder = style.sectionOrder.isNotEmpty
        ? style.sectionOrder
        : const ['header', 'title', 'body', 'footer'];

    for (final sectionKey in activeOrder) {
      final widget = sectionMap[sectionKey];
      if (widget != null) {
        if (sectionKey == 'body') {
          orderedWidgets.add(pw.Expanded(child: widget));
        } else {
          orderedWidgets.add(widget);
        }
        orderedWidgets.add(pw.SizedBox(height: 16));
      }
    }

    if (orderedWidgets.isNotEmpty && orderedWidgets.last is pw.SizedBox) {
      orderedWidgets.removeLast(); // Remove trailing spacer
    }

    // 6. Build Document Page
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

              // B. Printable Certificate Content Stack
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: orderedWidgets,
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
  // Section Builders
  // ===========================================================================

  /// Header Block:
  ///                             Diocese of San Pablo
  ///   [ Diocese Logo ]        Saint John Paul II Parish        [ Parish Seal ]
  ///                             Santa Cruz, Laguna
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
        // Left Logo (Diocese of San Pablo)
        pw.SizedBox(
          width: 58,
          height: 58,
          child: dioceseLogoBytes != null
              ? pw.Image(pw.MemoryImage(dioceseLogoBytes), fit: pw.BoxFit.contain)
              : _buildFallbackCrest(label: 'DSP', boldFont: boldFont),
        ),

        // Centered 3-line Text
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

        // Right Logo (Saint John Paul II Parish Seal)
        pw.SizedBox(
          width: 58,
          height: 58,
          child: parishSealBytes != null
              ? pw.Image(pw.MemoryImage(parishSealBytes), fit: pw.BoxFit.contain)
              : _buildFallbackCrest(label: 'SJP2', boldFont: boldFont),
        ),
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

    return pw.Column(
      children: [
        pw.Container(
          width: 320,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: goldAccent, width: 2),
            ),
          ),
          child: pw.Text(
            title.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: isBold ? boldFont : baseFont,
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
                font: isBold ? boldFont : baseFont,
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

  /// Dynamic Footer Layout supporting configurable anchor positions for QR and Signatory
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

    // Anchor: Signatory Centered
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

    // Anchor: Signatory Left, QR Right
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

    // Default Anchor: QR Left, Signatory Right
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

  /// Classical ecclesiastical double-line vector border with ornamental corners
  static pw.Widget _buildDefaultEcclesiasticalBorder() {
    return pw.Positioned.fill(
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(16),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: goldAccent, width: 2.5),
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(5),
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

  /// Fallback crest icon when no logo image file is available
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