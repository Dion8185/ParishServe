// =============================================================================
// FILE: lib/features/sacramental_records/presentation/dialogs/csv_preview_confirmation_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

/// Shows an interactive preview and confirmation dialog before executing CSV import.
/// Displays import status, total record count tally, and a full horizontally-scrollable table of parsed records.
/// Returns `true` if the user confirms the import, or `false` if cancelled.
Future<bool> showCsvPreviewConfirmationDialog({
  required BuildContext context,
  required String sacramentName,
  required String fileName,
  required List<String> headers,
  required List<Map<String, dynamic>> records,
  required Color themeColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CsvPreviewConfirmationDialog(
      sacramentName: sacramentName,
      fileName: fileName,
      headers: headers,
      records: records,
      themeColor: themeColor,
    ),
  );
  return result ?? false;
}

class CsvPreviewConfirmationDialog extends StatefulWidget {
  final String sacramentName;
  final String fileName;
  final List<String> headers;
  final List<Map<String, dynamic>> records;
  final Color themeColor;

  const CsvPreviewConfirmationDialog({
    super.key,
    required this.sacramentName,
    required this.fileName,
    required this.headers,
    required this.records,
    required this.themeColor,
  });

  @override
  State<CsvPreviewConfirmationDialog> createState() =>
      _CsvPreviewConfirmationDialogState();
}

class _CsvPreviewConfirmationDialogState
    extends State<CsvPreviewConfirmationDialog> {
  int _currentPage = 0;
  static const int _rowsPerPage = 8;

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final totalCount = widget.records.length;
    final int totalPages = (totalCount / _rowsPerPage).ceil() > 0
        ? (totalCount / _rowsPerPage).ceil()
        : 1;

    final startIdx = _currentPage * _rowsPerPage;
    final endIdx = (startIdx + _rowsPerPage) > totalCount
        ? totalCount
        : (startIdx + _rowsPerPage);
    final displayedRecords = totalCount > 0
        ? widget.records.sublist(startIdx, endIdx)
        : <Map<String, dynamic>>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final bool isSmallScreen = screenWidth < 700;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: cardWhite,
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: widget.themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.table_view_rounded,
                        color: widget.themeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm & Preview Import',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.sacramentName} Registry • ${widget.fileName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                tooltip: 'Cancel Import',
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 960,
              maxHeight: screenHeight * 0.72,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status & Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ParishColors.oliveGreen.withOpacity(0.4),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: ParishColors.oliveGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ready for Import',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.oliveGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.themeColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$totalCount Records Queued',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Info Description
                  Text(
                    'Review the records below extracted from ${widget.fileName}. Existing entries with matching IDs will be safely updated, and new entries will be inserted.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Scrollable Data Preview Table
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 700),
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 38,
                            dataRowMaxHeight: 46,
                            columnSpacing: 18,
                            horizontalMargin: 16,
                            headingRowColor: WidgetStateProperty.all(
                              widget.themeColor.withOpacity(0.08),
                            ),
                            headingTextStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.themeColor,
                            ),
                            dataTextStyle: TextStyle(
                              fontSize: 12,
                              color: textDark,
                            ),
                            columns: widget.headers.map((h) {
                              return DataColumn(
                                label: Text(
                                  h.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            }).toList(),
                            rows: displayedRecords.map((row) {
                              return DataRow(
                                cells: widget.headers.map((h) {
                                  final val = row[h];
                                  final display = (val == null ||
                                      val.toString().trim().isEmpty)
                                      ? '—'
                                      : val.toString();
                                  return DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: Text(
                                        display,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4. Pagination Controller
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${startIdx + 1}–$endIdx of $totalCount rows',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Page ${_currentPage + 1} of $totalPages',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: widget.themeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _currentPage < totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 44),
                    side: BorderSide(color: borderGrey, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(180, 44),
                    backgroundColor: widget.themeColor,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(
                    'Confirm Import ($totalCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}