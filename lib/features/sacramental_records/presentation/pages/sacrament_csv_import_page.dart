// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/sacrament_csv_import_page.dart
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/sacrament_csv_service.dart';
import '../dialogs/csv_preview_confirmation_dialog.dart';

class SacramentCsvImportPage extends StatefulWidget {
  final String sacramentName;
  final Color themeColor;
  final Color surfaceColor;

  const SacramentCsvImportPage({
    super.key,
    required this.sacramentName,
    required this.themeColor,
    required this.surfaceColor,
  });

  @override
  State<SacramentCsvImportPage> createState() => _SacramentCsvImportPageState();
}

class _SacramentCsvImportPageState extends State<SacramentCsvImportPage> {
  bool _isReadingFile = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importProgressStatus = '';

  String? _selectedFileName;
  int? _selectedFileSizeBytes;
  String? _rawCsvContent;
  CsvValidationResult? _validationResult;

  String get _expectedFileName =>
      SacramentCsvService.getExpectedFileName(widget.sacramentName);

  Future<void> _pickCsvFile() async {
    setState(() {
      _isReadingFile = true;
    });

    try {
      final dynamic result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) {
        setState(() => _isReadingFile = false);
        return;
      }

      dynamic file;
      if (result is List && result.isNotEmpty) {
        file = result.first;
      } else {
        try {
          final files = (result as dynamic).files;
          if (files != null && files.isNotEmpty) {
            file = files.first;
          }
        } catch (_) {
          file = result;
        }
      }

      if (file == null) {
        setState(() => _isReadingFile = false);
        return;
      }

      String fileName = _expectedFileName;
      try {
        fileName = (file as dynamic).name ?? (file as dynamic).path?.split('/')?.last ?? (file as dynamic).path?.split(r'\')?.last ?? _expectedFileName;
      } catch (_) {}

      Uint8List? bytes;
      try {
        bytes = await (file as dynamic).readAsBytes();
      } catch (_) {
        try {
          bytes = (file as dynamic).bytes;
        } catch (_) {}
      }

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _isReadingFile = false;
          _selectedFileName = fileName;
          _validationResult = const CsvValidationResult(
            isValid: false,
            errorMessage: 'Unable to read file content or file is empty.',
          );
        });
        return;
      }

      int fileSizeBytes = bytes.length;
      try {
        final dynamic size = (file as dynamic).size;
        if (size is int && size > 0) {
          fileSizeBytes = size;
        }
      } catch (_) {}

      // Decode with fallback handling for utf8 and latin1
      String decodedContent;
      try {
        decodedContent = utf8.decode(bytes);
      } catch (_) {
        decodedContent = latin1.decode(bytes);
      }

      final validation = SacramentCsvService.validateAndParseCsv(
        fileName: fileName,
        rawContent: decodedContent,
        sacramentName: widget.sacramentName,
      );

      setState(() {
        _isReadingFile = false;
        _selectedFileName = fileName;
        _selectedFileSizeBytes = fileSizeBytes;
        _rawCsvContent = decodedContent;
        _validationResult = validation;
      });
    } catch (e) {
      setState(() {
        _isReadingFile = false;
        _validationResult = CsvValidationResult(
          isValid: false,
          errorMessage: 'Error opening file: $e',
        );
      });
    }
  }

  Future<void> _startPreviewAndImport() async {
    if (_validationResult == null ||
        !_validationResult!.isValid ||
        _validationResult!.parsedRows.isEmpty) {
      return;
    }

    final confirmed = await showCsvPreviewConfirmationDialog(
      context: context,
      sacramentName: widget.sacramentName,
      fileName: _selectedFileName ?? _expectedFileName,
      headers: _validationResult!.headers,
      records: _validationResult!.parsedRows,
      themeColor: widget.themeColor,
    );

    if (confirmed != true) return;

    // Execute database import
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importProgressStatus = 'Initializing batch import...';
    });

    try {
      final importedCount = await SacramentCsvService.executeImport(
        sacramentName: widget.sacramentName,
        records: _validationResult!.parsedRows,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _importProgress = progress;
              _importProgressStatus = status;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isImporting = false;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: ParishColors.cardWhite,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: ParishColors.oliveGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Import Successful',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Successfully imported $importedCount ${widget.sacramentName.toLowerCase()} record(s) into the canonical database.',
            style: TextStyle(
              fontSize: 14,
              color: ParishColors.textDark.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Return true to refresh registry
              },
              child: const Text(
                'Back to Registry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import error: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: widget.themeColor, size: 26),
          onPressed: _isImporting ? null : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import ${widget.sacramentName} Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            Text(
              'Batch CSV record ingestion for ${widget.sacramentName} Registry',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Strict File Restriction Policy Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.themeColor.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.themeColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sacrament Registry Restriction Policy',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.themeColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To preserve ledger integrity, only "$_expectedFileName" can be imported inside the ${widget.sacramentName} registry. Files belonging to other sacraments will be rejected automatically.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textDark.withOpacity(0.85),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Click or Select File Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _validationResult != null &&
                            !_validationResult!.isValid
                            ? ParishColors.mercyRed
                            : borderGrey,
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: widget.surfaceColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.upload_file_outlined,
                            size: 32,
                            color: widget.themeColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Upload "$_expectedFileName"',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select your comma-separated CSV file containing canonical records.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: textMuted),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            onPressed:
                            (_isReadingFile || _isImporting) ? null : _pickCsvFile,
                            icon: const Icon(Icons.folder_open, size: 20),
                            label: Text(
                              _selectedFileName == null
                                  ? 'Browse Files'
                                  : 'Select Different File',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: widget.themeColor,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              SacramentCsvService.downloadSampleTemplate(
                                widget.sacramentName,
                              ),
                          icon: const Icon(Icons.download, size: 16),
                          label: Text(
                            'Download blank template for ${widget.sacramentName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. File Selected & Validation Feedback
                  if (_isReadingFile)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: widget.themeColor),
                            const SizedBox(height: 12),
                            Text(
                              'Analyzing and validating CSV structure...',
                              style: TextStyle(fontSize: 13, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_selectedFileName != null && _validationResult != null) ...[
                    if (!_validationResult!.isValid)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ParishColors.mercyRed),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: ParishColors.mercyRed,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Validation Failed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.mercyRed,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _validationResult!.errorMessage ??
                                        'File failed verification.',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: ParishColors.mercyRed,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Valid File Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: ParishColors.oliveGreen.withOpacity(0.5),
                            width: 1.3,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: ParishColors.oliveGreen,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedFileName!,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedFileSizeBytes != null)
                                  Text(
                                    _formatFileSize(_selectedFileSizeBytes!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_validationResult!.totalCount} records identified',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.oliveGreen,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.surfaceColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_validationResult!.headers.length} columns verified',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: widget.themeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Preview and Confirmation Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ParishColors.oliveGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _isImporting
                                    ? null
                                    : _startPreviewAndImport,
                                icon: const Icon(
                                  Icons.preview_outlined,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Preview & Confirm Import',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // 4. Progress Feedback While Ingesting
                  if (_isImporting) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Importing records...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: textDark,
                                ),
                              ),
                              Text(
                                '${(_importProgress * 100).toInt()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: widget.themeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _importProgress > 0 ? _importProgress : null,
                              minHeight: 8,
                              backgroundColor: widget.surfaceColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.themeColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _importProgressStatus,
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}