import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/services/auth_service.dart';
import '../../sacramental_records/models/certificate_canvas_element.dart';
import '../models/receipt_template_model.dart';
import 'receipt_template_service.dart';

class ReceiptPdfGenerator {
  ReceiptPdfGenerator._();

  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFD49B18);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  // ===========================================================================
  // Unicode / Tofu Character Sanitizer
  // ===========================================================================
  /// Replaces non-ASCII symbols with clean ASCII characters
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

  // ===========================================================================
  // Amount in Words Conversion Engine
  // ===========================================================================
  static String convertAmountToWords(double amount) {
    if (amount <= 0) return 'Zero Pesos Only';

    final int pesos = amount.floor();
    final int centavos = ((amount - pesos) * 100).round();

    final String pesoWords = _numberToWords(pesos);

    if (centavos > 0) {
      return '$pesoWords Pesos and $centavos/100';
    } else {
      return '$pesoWords Pesos Only';
    }
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'Zero';

    const units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];

    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    if (number < 20) {
      return units[number];
    }

    if (number < 100) {
      final rem = number % 10;
      return '${tens[number ~/ 10]}${rem > 0 ? " ${units[rem]}" : ""}';
    }

    if (number < 1000) {
      final rem = number % 100;
      return '${units[number ~/ 100]} Hundred${rem > 0 ? " ${_numberToWords(rem)}" : ""}';
    }

    if (number < 1000000) {
      final rem = number % 1000;
      return '${_numberToWords(number ~/ 1000)} Thousand${rem > 0 ? " ${_numberToWords(rem)}" : ""}';
    }

    if (number < 1000000000) {
      final rem = number % 1000000;
      return '${_numberToWords(number ~/ 1000000)} Million${rem > 0 ? " ${_numberToWords(rem)}" : ""}';
    }

    final rem = number % 1000000000;
    return '${_numberToWords(number ~/ 1000000000)} Billion${rem > 0 ? " ${_numberToWords(rem)}" : ""}';
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

  /// Compiles the official print-ready PDF binary for an ecclesiastical receipt
  static Future<Uint8List> generateReceiptPdf({
    required String receiptNumber,
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String transactionDetails,
    required double amount,
    String paymentMode = 'Cash',
    String? dateString,
    ReceiptTemplateModel? template,
    bool isThermalRoll = false,
  }) async {
    final activeTemplate = template ?? await ReceiptTemplateService.getDefaultTemplate();
    final style = activeTemplate.styleConfig;

    PdfPageFormat pageFormat;
    if (isThermalRoll) {
      pageFormat = const PdfPageFormat(
        80 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 4 * PdfPageFormat.mm,
      );
    } else {
      final dims = activeTemplate.pageDimensionsInPoints;
      pageFormat = PdfPageFormat(
        dims.$1,
        dims.$2,
        marginAll: 0,
      );
    }

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

    final bgImage = await _fetchNetworkImage(activeTemplate.backgroundImageUrl);
    final dioceseLogo = await _fetchNetworkImage(activeTemplate.dioceseLogoUrl);
    final parishSeal = await _fetchNetworkImage(activeTemplate.parishSealUrl);
    final signatureImage = await _fetchNetworkImage(activeTemplate.signatureImageUrl);

    final now = DateTime.now();
    final issuedDate = dateString ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final cashierName = AuthService.currentUser?.fullName ?? 'Parish Secretariat';

    final amountInWordsText = convertAmountToWords(amount);

    // Sanitize particulars text and strip out Cash Tendered / Change computation so it NEVER prints on the receipt
    final rawCleanDetails = sanitizePdfText(
      transactionDetails.isNotEmpty ? transactionDetails : relatedService,
    );

    final cleanDetails = rawCleanDetails
        .split('\n')
        .where((line) {
      final l = line.toLowerCase();
      return !l.contains('cash tendered') && !l.contains('(change:');
    })
        .join('\n')
        .trim();

    final placeholderMap = <String, String>{
      '{Receipt Number}': receiptNumber,
      '{Receipt No}': receiptNumber,
      '{Payor}': payorName,
      '{Payor Name}': payorName,
      '{Contact}': payorContact ?? '—',
      '{Date}': issuedDate,
      '{Amount}': 'P ${amount.toStringAsFixed(2)}',
      '{Total}': 'P ${amount.toStringAsFixed(2)}',
      '{Amount in Words}': amountInWordsText,
      '{Amount In Words}': amountInWordsText,
      '{Total in Words}': amountInWordsText,
      '{Total In Words}': amountInWordsText,
      '{Payment Mode}': paymentMode.toUpperCase(),
      '{Service}': relatedService,
      '{Particulars}': cleanDetails,
      '{Details}': cleanDetails,
      '{Cashier}': cashierName,
      '{Cashier Title}': activeTemplate.cashierTitle,
      '{Parish Priest}': activeTemplate.parishPriestName,
    };

    final qrUrl = 'https://parishserve.web.app/verify-receipt?rec=$receiptNumber';
    final bool isCanvaMode = style.useVisualCanvas && style.canvasElements.isNotEmpty && !isThermalRoll;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          if (isThermalRoll) {
            return _buildThermalRollContent(
              receiptNumber: receiptNumber,
              payorName: payorName,
              payorContact: payorContact,
              relatedService: relatedService,
              cleanDetails: cleanDetails,
              amount: amount,
              amountInWordsText: amountInWordsText,
              paymentMode: paymentMode,
              issuedDate: issuedDate,
              cashierName: cashierName,
            );
          }

          return pw.Stack(
            children: [
              if (bgImage != null)
                pw.Positioned.fill(
                  child: pw.Image(
                    pw.MemoryImage(bgImage),
                    fit: activeTemplate.backgroundMode == 'Full-Page'
                        ? pw.BoxFit.cover
                        : pw.BoxFit.fill,
                  ),
                )
              else if (activeTemplate.backgroundMode == 'Border')
                _buildDefaultReceiptVectorBorder(activeTemplate.paperSize),

              if (isCanvaMode)
                ...style.canvasElements.map((element) {
                  return _buildCanvaReceiptPdfElement(
                    element: element,
                    template: activeTemplate,
                    placeholderValues: placeholderMap,
                    pageWidth: pageFormat.width,
                    pageHeight: pageFormat.height,
                    dioceseLogo: dioceseLogo,
                    parishSeal: parishSeal,
                    signatureImage: signatureImage,
                    qrUrl: qrUrl,
                  );
                })
              else
                pw.Padding(
                  padding: _resolveStructuredPadding(activeTemplate.paperSize, activeTemplate.orientation),
                  child: _buildStructuredReceiptLayout(
                    template: activeTemplate,
                    style: style,
                    receiptNumber: receiptNumber,
                    payorName: payorName,
                    payorContact: payorContact,
                    relatedService: relatedService,
                    cleanDetails: cleanDetails,
                    amount: amount,
                    amountInWordsText: amountInWordsText,
                    paymentMode: paymentMode,
                    issuedDate: issuedDate,
                    cashierName: cashierName,
                    dioceseLogo: dioceseLogo,
                    parishSeal: parishSeal,
                    signatureImage: signatureImage,
                    qrUrl: qrUrl,
                    baseFont: baseFont,
                    boldFont: boldFont,
                    italicFont: italicFont,
                  ),
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printReceipt({
    required String receiptNumber,
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String transactionDetails,
    required double amount,
    String paymentMode = 'Cash',
    String? dateString,
    ReceiptTemplateModel? template,
    bool isThermalRoll = false,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      receiptNumber: receiptNumber,
      payorName: payorName,
      payorContact: payorContact,
      relatedService: relatedService,
      transactionDetails: transactionDetails,
      amount: amount,
      paymentMode: paymentMode,
      dateString: dateString,
      template: template,
      isThermalRoll: isThermalRoll,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Receipt_$receiptNumber',
    );
  }

  // ===========================================================================
  // 1. Structured Canonical Receipt Layout
  // ===========================================================================

  static pw.EdgeInsets _resolveStructuredPadding(String paperSize, String orientation) {
    if (paperSize.toLowerCase().contains('ecclesiastical')) {
      return const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28);
  }

  static pw.Widget _buildStructuredReceiptLayout({
    required ReceiptTemplateModel template,
    required ReceiptStyleConfig style,
    required String receiptNumber,
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String cleanDetails,
    required double amount,
    required String amountInWordsText,
    required String paymentMode,
    required String issuedDate,
    required String cashierName,
    required Uint8List? dioceseLogo,
    required Uint8List? parishSeal,
    required Uint8List? signatureImage,
    required String qrUrl,
    required pw.Font baseFont,
    required pw.Font boldFont,
    required pw.Font italicFont,
  }) {
    final bool isEcclesiastical = template.paperSize.toLowerCase().contains('ecclesiastical');
    final bool isPlain = template.backgroundMode == 'None';
    final lines = template.headerLines;

    // Parse itemized lines from clean details (cash tendered is already excluded)
    final detailLines = cleanDetails
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.toLowerCase().contains('cash tendered') && !l.toLowerCase().contains('change:'))
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // A. Header Row (Diocese Logo, Parish Details, Parish Seal)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (template.showDioceseLogo)
              pw.SizedBox(
                width: isEcclesiastical ? 40 : 50,
                height: isEcclesiastical ? 40 : 50,
                child: dioceseLogo != null
                    ? pw.Image(pw.MemoryImage(dioceseLogo), fit: pw.BoxFit.contain)
                    : _buildFallbackEmblem('DSP', boldFont),
              )
            else
              pw.SizedBox(width: isEcclesiastical ? 40 : 50),

            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    lines.isNotEmpty ? lines[0] : 'Diocese of San Pablo',
                    style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 8.5 : 9.5, color: textDark),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    lines.length > 1 ? lines[1] : 'Saint John Paul II Parish',
                    style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 12 : 14, color: isPlain ? textDark : marianBlue),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    lines.length > 2 ? lines.sublist(2).join(', ') : 'Santa Cruz, Laguna',
                    style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 7.5 : 8.5, color: textMuted),
                  ),
                ],
              ),
            ),

            if (template.showParishSeal)
              pw.SizedBox(
                width: isEcclesiastical ? 40 : 50,
                height: isEcclesiastical ? 40 : 50,
                child: parishSeal != null
                    ? pw.Image(pw.MemoryImage(parishSeal), fit: pw.BoxFit.contain)
                    : _buildFallbackEmblem('SJP2', boldFont),
              )
            else
              pw.SizedBox(width: isEcclesiastical ? 40 : 50),
          ],
        ),
        pw.SizedBox(height: isEcclesiastical ? 4 : 8),

        // B. Title & Receipt Number Bar
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              decoration: isPlain
                  ? null
                  : const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: goldAccent, width: 1.5)),
              ),
              child: pw.Text(
                template.receiptTitle.toUpperCase(),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: isEcclesiastical ? 10.5 : 12,
                  letterSpacing: 1.0,
                  color: isPlain ? textDark : marianBlue,
                ),
              ),
            ),
            pw.Row(
              children: [
                pw.Text('RECEIPT NO: ', style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 8.0 : 9.0, color: textMuted)),
                pw.Text(
                  receiptNumber,
                  style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 9.5 : 10.5, color: isPlain ? textDark : marianBlue),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: isEcclesiastical ? 6 : 10),

        // C. Payor & Date Row
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: isPlain
              ? const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderGrey, width: 0.6),
              bottom: pw.BorderSide(color: borderGrey, width: 0.6),
            ),
          )
              : pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 8.5 : 9.5, color: textDark),
                    children: [
                      pw.TextSpan(text: 'Received From: ', style: pw.TextStyle(font: boldFont, color: textMuted)),
                      pw.TextSpan(text: payorName, style: pw.TextStyle(font: boldFont, color: textDark)),
                      if (payorContact != null && payorContact.isNotEmpty)
                        pw.TextSpan(text: '  ($payorContact)', style: pw.TextStyle(fontSize: 8.0, color: textMuted)),
                    ],
                  ),
                ),
              ),
              pw.Text('Date: $issuedDate', style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 8.0 : 9.0, color: textMuted)),
            ],
          ),
        ),
        pw.SizedBox(height: isEcclesiastical ? 6 : 10),

        // D. Itemized Particulars Box (Excludes cash tendered / change)
        pw.Expanded(
          child: pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: isPlain
                ? const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: borderGrey, width: 0.6),
              ),
            )
                : pw.BoxDecoration(
              border: pw.Border.all(color: borderGrey, width: 0.8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PARTICULARS / OFFERING DETAILS', style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 7.5 : 8.5, color: textMuted)),
                    pw.Text('AMOUNT', style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 7.5 : 8.5, color: textMuted)),
                  ],
                ),
                pw.Divider(thickness: 0.5, color: borderGrey),
                pw.SizedBox(height: 2),

                // Render item rows cleanly
                ...detailLines.map((line) {
                  if (line.contains('@') && line.contains('=')) {
                    final parts = line.split('=');
                    final left = parts[0].replaceAll('-', '').trim();
                    final right = parts.length > 1 ? parts[1].trim() : '';
                    final amtDisplay = right.startsWith('P') ? right : 'P $right';

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(left, style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 8.5 : 9.5, color: textDark)),
                          ),
                          pw.Text(amtDisplay, style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 9.0 : 10.0, color: isPlain ? textDark : marianBlue)),
                        ],
                      ),
                    );
                  }
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Text(line, style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 8.5 : 9.5, color: textDark)),
                  );
                }),

                pw.Spacer(),
                // AMOUNT IN WORDS ROW
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 0.5)),
                  ),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 8.0 : 9.0, color: textDark),
                      children: [
                        pw.TextSpan(text: 'Amount in Words: ', style: pw.TextStyle(font: boldFont, color: textMuted)),
                        pw.TextSpan(text: amountInWordsText, style: pw.TextStyle(font: boldFont, fontStyle: pw.FontStyle.italic, color: textDark)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: isEcclesiastical ? 6 : 10),

        // E. Total & Footer Signatories Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (template.enableQrVerification)
              pw.Row(
                children: [
                  pw.Container(
                    width: isEcclesiastical ? 42 : 48,
                    height: isEcclesiastical ? 42 : 48,
                    padding: const pw.EdgeInsets.all(2),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGrey, width: 0.6)),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrUrl,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Tender Mode: ${paymentMode.toUpperCase()}', style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 7.0 : 8.0)),
                      pw.Text('Canonical verification token', style: pw.TextStyle(font: baseFont, fontSize: 6.0, color: textMuted)),
                      pw.Text('TOTUS TUUS', style: pw.TextStyle(font: boldFont, fontSize: 6.5, color: isPlain ? textMuted : goldAccent, letterSpacing: 0.8)),
                    ],
                  ),
                ],
              )
            else
              pw.Text('Tender Mode: ${paymentMode.toUpperCase()}', style: pw.TextStyle(font: boldFont, fontSize: 8.0)),

            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (signatureImage != null)
                  pw.Container(
                    height: isEcclesiastical ? 20 : 26,
                    child: pw.Image(pw.MemoryImage(signatureImage), fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: isEcclesiastical ? 16 : 20),
                pw.Container(
                  width: isEcclesiastical ? 130 : 160,
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: textDark, width: 0.8))),
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Column(
                    children: [
                      pw.Text(cashierName, style: pw.TextStyle(font: boldFont, fontSize: isEcclesiastical ? 8.0 : 9.0, color: textDark)),
                      pw.Text(template.cashierTitle, style: pw.TextStyle(font: baseFont, fontSize: isEcclesiastical ? 6.5 : 7.5, color: textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. Canva-Style Visual Mode Element Renderer (With Character Sanitization)
  // ===========================================================================

  static pw.Widget _buildCanvaReceiptPdfElement({
    required CertificateCanvasElement element,
    required ReceiptTemplateModel template,
    required Map<String, String> placeholderValues,
    required double pageWidth,
    required double pageHeight,
    required Uint8List? dioceseLogo,
    required Uint8List? parishSeal,
    required Uint8List? signatureImage,
    required String qrUrl,
  }) {
    final bool isItalic = element.fontFamily.toLowerCase() == 'script';
    final elemBaseFont = _resolvePdfFont(element.fontFamily, isItalic: isItalic);
    final elemBoldFont = _resolvePdfFont(element.fontFamily, isBold: true, isItalic: isItalic);

    final double elementWidth = (element.width ?? 0.84) * pageWidth;
    final double? elementHeight = element.height != null ? element.height! * pageHeight : null;
    final double pixelCenterX = element.x * pageWidth;
    final double pixelCenterY = element.y * pageHeight;
    final double left = pixelCenterX - (elementWidth / 2);
    final double top = elementHeight != null
        ? pixelCenterY - (elementHeight / 2)
        : pixelCenterY - 14;

    if (element.elementType == 'diocese_seal') {
      final double diameter = element.fontSize * 4.0;
      return pw.Positioned(
        left: pixelCenterX - (diameter / 2),
        top: pixelCenterY - (diameter / 2),
        child: pw.Container(
          width: diameter,
          height: diameter,
          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: marianBlue, width: 1.5)),
          child: dioceseLogo != null
              ? pw.ClipOval(child: pw.Image(pw.MemoryImage(dioceseLogo), fit: pw.BoxFit.contain))
              : pw.Center(child: pw.Text('DSP', style: pw.TextStyle(font: elemBoldFont, fontSize: diameter * 0.22, color: marianBlue))),
        ),
      );
    }

    if (element.elementType == 'parish_seal') {
      final double diameter = element.fontSize * 4.0;
      return pw.Positioned(
        left: pixelCenterX - (diameter / 2),
        top: pixelCenterY - (diameter / 2),
        child: pw.Container(
          width: diameter,
          height: diameter,
          decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: goldAccent, width: 1.5)),
          child: parishSeal != null
              ? pw.ClipOval(child: pw.Image(pw.MemoryImage(parishSeal), fit: pw.BoxFit.contain))
              : pw.Center(child: pw.Text('SJP2', style: pw.TextStyle(font: elemBoldFont, fontSize: diameter * 0.22, color: marianBlue))),
        ),
      );
    }

    if (element.elementType == 'qr') {
      return pw.Positioned(
        left: pixelCenterX - 24,
        top: pixelCenterY - 24,
        child: pw.Container(
          width: 48,
          height: 48,
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGrey, width: 0.6)),
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrUrl),
        ),
      );
    }

    if (element.elementType == 'signatory') {
      final resolvedText = sanitizePdfText(_replacePlaceholders(element.text, placeholderValues));
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: elementWidth,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (signatureImage != null)
                pw.Container(
                  height: 24,
                  child: pw.Image(pw.MemoryImage(signatureImage), fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(height: 18),
              pw.Container(
                width: elementWidth * 0.85,
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: textDark, width: 0.8))),
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  resolvedText,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: element.isBold ? elemBoldFont : elemBaseFont,
                    fontSize: element.fontSize,
                    color: _hexToPdfColor(element.colorHex),
                    lineSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final resolvedText = sanitizePdfText(_replacePlaceholders(element.text, placeholderValues));
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.SizedBox(
        width: elementWidth,
        height: elementHeight,
        child: pw.Text(
          resolvedText,
          textAlign: _resolveTextAlign(element.textAlign),
          style: pw.TextStyle(
            font: element.isBold ? elemBoldFont : elemBaseFont,
            fontSize: element.fontSize,
            color: _hexToPdfColor(element.colorHex),
            lineSpacing: 1.6,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. 80mm Thermal Slip Renderer (Excludes cash tendered)
  // ===========================================================================

  static pw.Widget _buildThermalRollContent({
    required String receiptNumber,
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String cleanDetails,
    required double amount,
    required String amountInWordsText,
    required String paymentMode,
    required String issuedDate,
    required String cashierName,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('DIOCESE OF SAN PABLO', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
        pw.Text('ST. JOHN PAUL II PARISH', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
        pw.Text('Brgy. Labuin, Santa Cruz, Laguna', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
        pw.SizedBox(height: 6),
        pw.Text('OFFICIAL RECEIPT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.Divider(thickness: 0.5, color: borderGrey),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Receipt No:', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(receiptNumber, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Date:', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(issuedDate, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Payor:', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(payorName, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Divider(thickness: 0.5, color: borderGrey),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            cleanDetails,
            style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.5),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Words: $amountInWordsText',
            style: const pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
          ),
        ),
        pw.Divider(thickness: 0.5, color: borderGrey),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Mode: ${paymentMode.toUpperCase()}', style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text('TOTAL: P ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
          ],
        ),
        pw.Divider(thickness: 0.5, color: borderGrey),
        pw.Text('Cashier: $cashierName', style: const pw.TextStyle(fontSize: 7.5, color: textMuted)),
        pw.Text('Thank you for your offering. Totus Tuus.', style: const pw.TextStyle(fontSize: 7, color: textMuted)),
      ],
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  static pw.Widget _buildDefaultReceiptVectorBorder(String paperSize) {
    final bool isEcclesiastical = paperSize.toLowerCase().contains('ecclesiastical');
    return pw.Positioned.fill(
      child: pw.Padding(
        padding: pw.EdgeInsets.all(isEcclesiastical ? 10.0 : 16.0),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: goldAccent, width: 1.8),
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(3.0),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: marianBlue, width: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildFallbackEmblem(String label, pw.Font boldFont) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: borderGrey, width: 0.8),
        color: PdfColors.grey100,
      ),
      child: pw.Center(
        child: pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: textDark)),
      ),
    );
  }

  static String _replacePlaceholders(String text, Map<String, String> values) {
    String output = text;
    values.forEach((tag, val) {
      output = output.replaceAll(tag, val);
    });
    return output;
  }

  static pw.TextAlign _resolveTextAlign(String align) {
    switch (align.toLowerCase()) {
      case 'left':
        return pw.TextAlign.left;
      case 'right':
        return pw.TextAlign.right;
      case 'center':
      default:
        return pw.TextAlign.center;
    }
  }

  static Future<Uint8List?> _fetchNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}