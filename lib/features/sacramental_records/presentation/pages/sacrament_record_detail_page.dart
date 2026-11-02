// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/sacrament_record_detail_page.dart
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../models/certificate_issuance_model.dart';
import '../../services/certificate_service.dart';
import '../dialogs/generate_certificate_dialog.dart';
import 'baptism_manual_entry_page.dart';
import 'certificate_template_management_page.dart';
import 'confirmation_manual_entry_page.dart';
import 'conversion_manual_entry_page.dart';
import 'death_manual_entry_page.dart';
import 'first_communion_manual_entry_page.dart';
import 'matrimony_manual_entry_page.dart';

class SacramentRecordDetailPage extends StatefulWidget {
  final String sacramentName;
  final String recordId;
  final String name;
  final String bookRef;
  final String dateString;
  final String parentage;
  final String sponsors;
  final String? marginalNotation;
  final Color themeColor;
  final Color surfaceColor;
  final Map<String, dynamic> rawRecordData;
  final VoidCallback? onRecordUpdated;

  const SacramentRecordDetailPage({
    super.key,
    required this.sacramentName,
    required this.recordId,
    required this.name,
    required this.bookRef,
    required this.dateString,
    required this.parentage,
    required this.sponsors,
    this.marginalNotation,
    required this.themeColor,
    required this.surfaceColor,
    required this.rawRecordData,
    this.onRecordUpdated,
  });

  @override
  State<SacramentRecordDetailPage> createState() => _SacramentRecordDetailPageState();
}

class _SacramentRecordDetailPageState extends State<SacramentRecordDetailPage> {
  // Pagination States
  int _auditLogCurrentPage = 1;
  final int _auditLogRowsPerPage = 5;

  int _issuanceCurrentPage = 1;
  final int _issuanceRowsPerPage = 5;

  List<CertificateIssuanceModel> _pastIssuances = [];
  bool _isLoadingIssuances = true;

  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoadingAuditLogs = true;

  @override
  void initState() {
    super.initState();
    _loadIssuances();
    _loadAuditLogs();
  }

  Future<void> _loadIssuances() async {
    setState(() => _isLoadingIssuances = true);
    try {
      final list = await CertificateService.getIssuancesForRecord(widget.recordId);
      if (!mounted) return;
      setState(() {
        _pastIssuances = list;
        _isLoadingIssuances = false;
        _issuanceCurrentPage = 1;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingIssuances = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAuditLogs = true);
    try {
      final response = await Supabase.instance.client
          .from('sacramental_record_audit_logs')
          .select()
          .eq('record_id', widget.recordId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _auditLogs = List<Map<String, dynamic>>.from(response as List);
        _isLoadingAuditLogs = false;
        _auditLogCurrentPage = 1;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingAuditLogs = false);
    }
  }

  /// Opens the matching manual entry form in Edit Record Mode
  void _openEditRecord(BuildContext context) {
    Widget? editPage;

    if (widget.sacramentName == 'Baptism') {
      editPage = BaptismManualEntryPage(
        initialData: widget.rawRecordData,
        onRecordSaved: () {
          widget.onRecordUpdated?.call();
          _loadIssuances();
          _loadAuditLogs();
          Navigator.pop(context);
        },
      );
    } else if (widget.sacramentName == 'Confirmation') {
      editPage = ConfirmationManualEntryPage(
        initialData: widget.rawRecordData,
        onRecordSaved: () {
          widget.onRecordUpdated?.call();
          _loadIssuances();
          _loadAuditLogs();
          Navigator.pop(context);
        },
      );
    } else if (widget.sacramentName == 'First Communion') {
      editPage = FirstCommunionManualEntryPage(
        initialData: widget.rawRecordData,
        onRecordSaved: () {
          widget.onRecordUpdated?.call();
          _loadIssuances();
          _loadAuditLogs();
          Navigator.pop(context);
        },
      );
    } else if (widget.sacramentName == 'Matrimony') {
      editPage = MatrimonyManualEntryPage(
        initialData: widget.rawRecordData,
        onRecordSaved: () {
          widget.onRecordUpdated?.call();
          _loadIssuances();
          _loadAuditLogs();
          Navigator.pop(context);
        },
      );
    } else if (widget.sacramentName == 'Death') {
      editPage = DeathManualEntryPage(
        initialData: widget.rawRecordData,
        onRecordSaved: () {
          widget.onRecordUpdated?.call();
          _loadIssuances();
          _loadAuditLogs();
          Navigator.pop(context);
        },
      );
    } else if (widget.sacramentName == 'Conversion') {
      editPage = ConversionManualEntryPage(
        initialData: widget.rawRecordData,
        onRecordSaved: () {
          widget.onRecordUpdated?.call();
          _loadIssuances();
          _loadAuditLogs();
          Navigator.pop(context);
        },
      );
    }

    if (editPage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => editPage!),
      );
    }
  }

  void _copyReference() {
    Clipboard.setData(ClipboardData(text: '${widget.recordId} • ${widget.bookRef}'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Canonical reference "${widget.bookRef}" copied to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _toCamelCase(String text) {
    final parts = text.split('_');
    if (parts.length <= 1) return text;
    final buffer = StringBuffer(parts.first);
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        buffer.write(parts[i][0].toUpperCase() + parts[i].substring(1));
      }
    }
    return buffer.toString();
  }

  String _toSnakeCase(String text) {
    final exp = RegExp(r'(?<=[a-z])[A-Z]');
    return text.replaceAllMapped(exp, (m) => '_${m.group(0)}').toLowerCase();
  }

  /// Safely extracts and formats data from both snake_case and camelCase database structures
  String _val(String key) {
    dynamic v = widget.rawRecordData[key];

    if (v == null) {
      final camelKey = _toCamelCase(key);
      v = widget.rawRecordData[camelKey];
    }

    if (v == null) {
      final snakeKey = _toSnakeCase(key);
      v = widget.rawRecordData[snakeKey];
    }

    if (v == null) {
      if (key == 'entry_status' || key == 'entryStatus') {
        v = widget.rawRecordData['status'] ??
            widget.rawRecordData['entry_type'] ??
            widget.rawRecordData['entryType'] ??
            'ORIGINAL';
      } else if (key == 'stipend') {
        v = widget.rawRecordData['stipend_amount'] ??
            widget.rawRecordData['stipendAmount'] ??
            widget.rawRecordData['amount'];
      } else if (key == 'place_of_baptism' || key == 'placeOfBaptism') {
        v = widget.rawRecordData['parish_name'] ??
            widget.rawRecordData['parishName'] ??
            widget.rawRecordData['baptism_parish'] ??
            widget.rawRecordData['baptismParish'];
      } else if (key == 'church_baptized' || key == 'churchBaptized') {
        v = widget.rawRecordData['baptism_parish'] ??
            widget.rawRecordData['baptismParish'] ??
            widget.rawRecordData['place_of_baptism'] ??
            widget.rawRecordData['placeOfBaptism'];
      } else if (key == 'other_godparents' || key == 'otherGodparents') {
        v = widget.rawRecordData['other_sponsors'] ?? widget.rawRecordData['otherSponsors'];
      }
    }

    if (v == null) return '—';
    final str = v.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    return str;
  }

  String _fullName(String prefix) {
    final f = _val('${prefix}_first_name');
    final m = _val('${prefix}_middle_name');

    String l = _val('${prefix}_last_name');
    if (l == '—') {
      l = _val('${prefix}_maiden_last_name');
    }
    if (l == '—') {
      l = _val('${prefix}_maiden_last');
    }

    final s = _val('${prefix}_suffix');

    if (f.toLowerCase() == 'not indicated') return '—';
    if (f == '—' && l == '—') return '—';

    final parts = <String>[];
    if (f != '—') parts.add(f);
    if (m != '—') parts.add(m);
    if (l != '—') parts.add(l);
    if (s != '—') parts.add(s);

    return parts.isEmpty ? '—' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: widget.themeColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.sacramentName} Record Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              'Canonical ID: ${widget.recordId}',
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.design_services_outlined, color: widget.themeColor),
            tooltip: 'Manage Certificate Templates',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: widget.themeColor),
            tooltip: 'Edit Record',
            onPressed: () => _openEditRecord(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Profile Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.themeColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.themeColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              softWrap: true,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.themeColor),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  widget.bookRef,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDarkColor),
                                ),
                                InkWell(
                                  onTap: _copyReference,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: widget.themeColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy, size: 12, color: widget.themeColor),
                                        const SizedBox(width: 4),
                                        Text('Copy', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: widget.themeColor)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // =============================================================
                // SECTION 1: PRIMARY CANONICAL REGISTER INFORMATION
                // =============================================================
                _buildHIGSectionHeader(
                  title: 'CANONICAL REGISTER INFORMATION',
                  icon: Icons.article_outlined,
                  action: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: widget.themeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _openEditRecord(context),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSacramentSpecificDetails(),
                const SizedBox(height: 20),

                // =============================================================
                // SECTION 2: CANONICAL LEDGER STATUS & AUDIT TRAIL
                // =============================================================
                _buildHIGSectionHeader(
                  title: 'CANONICAL LEDGER STATUS & AUDIT TRAIL',
                  icon: Icons.history_edu_outlined,
                ),
                const SizedBox(height: 10),
                _buildAuditTrailTimelineCard(cardWhiteColor, borderGreyColor, textDarkColor, textMutedColor),
                const SizedBox(height: 24),

                // =============================================================
                // SECTION 3: OFFICIAL CERTIFICATE ISSUANCE HISTORY
                // =============================================================
                _buildHIGSectionHeader(
                  title: 'OFFICIAL CERTIFICATE ISSUANCE HISTORY',
                  icon: Icons.verified_outlined,
                ),
                const SizedBox(height: 10),
                _buildIssuanceHistoryCard(cardWhiteColor, borderGreyColor, textDarkColor, textMutedColor),
                const SizedBox(height: 26),

                // =============================================================
                // PRIMARY BOTTOM ACTION BAR
                // =============================================================
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      foregroundColor: Colors.white,
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => showGenerateCertificateModal(
                      context,
                      sacramentType: widget.sacramentName,
                      recordId: widget.recordId,
                      recipientName: widget.name,
                      rawRecordData: widget.rawRecordData,
                      bookRef: widget.bookRef,
                      onCertificateIssued: () {
                        widget.onRecordUpdated?.call();
                        _loadIssuances();
                        _loadAuditLogs();
                      },
                    ),
                    icon: const Icon(Icons.print, size: 22),
                    label: Text(
                      'Generate Official ${widget.sacramentName} Certificate',
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HIG Section Header Component
  // ===========================================================================

  Widget _buildHIGSectionHeader({
    required String title,
    required IconData icon,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: widget.themeColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: ParishColors.textDark.withOpacity(0.85),
                ),
              ),
            ],
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  // ===========================================================================
  // Concise Timeline Trail History & Audit Details Dialog
  // ===========================================================================

  Widget _buildAuditTrailTimelineCard(Color cardWhite, Color borderGrey, Color textDark, Color textMuted) {
    final entryStatus = _val('entry_status');
    final isCorrected = entryStatus.toUpperCase() == 'CORRECTED';
    final encodedBy = _val('encoded_by');
    final dateEncoded = _val('date_encoded');

    final statusColor = isCorrected ? ParishColors.goldAccent : ParishColors.oliveGreen;

    // Pagination for Audit Trail
    final totalAuditLogs = _auditLogs.length;
    final totalAuditPages = (totalAuditLogs / _auditLogRowsPerPage).ceil() > 0 ? (totalAuditLogs / _auditLogRowsPerPage).ceil() : 1;
    if (_auditLogCurrentPage > totalAuditPages) _auditLogCurrentPage = totalAuditPages;

    final startIdx = (_auditLogCurrentPage - 1) * _auditLogRowsPerPage;
    final endIdx = (startIdx + _auditLogRowsPerPage) > totalAuditLogs ? totalAuditLogs : (startIdx + _auditLogRowsPerPage);
    final pagedAuditLogs = totalAuditLogs > 0 ? _auditLogs.sublist(startIdx, endIdx) : <Map<String, dynamic>>[];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: borderGrey)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: widget.themeColor),
                    const SizedBox(width: 10),
                    Text(
                      'Canonical Ledger Status',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textDark),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    entryStatus.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AUDIT TRAIL HISTORY ($totalAuditLogs)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.8),
                    ),
                    Text(
                      'Tap any trail item for details',
                      style: TextStyle(fontSize: 11, color: widget.themeColor, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isLoadingAuditLogs)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_auditLogs.isEmpty) ...[
                  _buildTimelineNode(
                    isFirst: true,
                    isLast: true,
                    actionTitle: 'Initial Canonical Registration',
                    timestamp: dateEncoded != '—' ? dateEncoded : 'On File',
                    userName: encodedBy != '—' ? encodedBy : 'Parish Secretariat',
                    userRole: 'Encoder / Staff',
                    details: 'Registered original entry in ${widget.sacramentName} register.',
                    themeColor: ParishColors.oliveGreen,
                    onTap: null,
                  ),
                ] else ...[
                  ...pagedAuditLogs.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final Map<String, dynamic> log = entry.value;

                    final createdAt = (log['created_at'] ?? '').toString();
                    final dateStr = createdAt.isNotEmpty ? createdAt.substring(0, 16).replaceAll('T', ' ') : '—';
                    final userName = log['performed_by_name']?.toString() ?? 'Authorized Personnel';
                    final userRole = log['performed_by_role']?.toString() ?? 'Staff';
                    final actionType = log['action_type']?.toString() ?? 'UPDATED';
                    final justification = log['justification']?.toString() ?? 'Canonical record update';

                    final bool isFirstNode = startIdx == 0 && idx == 0;
                    final bool isLastNode = startIdx + idx == totalAuditLogs - 1;

                    return _buildTimelineNode(
                      isFirst: isFirstNode,
                      isLast: isLastNode,
                      actionTitle: actionType == 'CREATED' ? 'Initial Registration' : 'Record Modification ($actionType)',
                      timestamp: dateStr,
                      userName: userName,
                      userRole: userRole,
                      details: justification,
                      themeColor: actionType == 'CREATED' ? ParishColors.oliveGreen : widget.themeColor,
                      onTap: () => _showAuditDetailsModal(context, log),
                    );
                  }),

                  // Pagination Toolbar for Audit Logs
                  if (totalAuditLogs > _auditLogRowsPerPage) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page $_auditLogCurrentPage of $totalAuditPages',
                          style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: _auditLogCurrentPage > 1 ? () => setState(() => _auditLogCurrentPage--) : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: _auditLogCurrentPage < totalAuditPages ? () => setState(() => _auditLogCurrentPage++) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required bool isFirst,
    required bool isLast,
    required String actionTitle,
    required String timestamp,
    required String userName,
    required String userRole,
    required String details,
    required Color themeColor,
    VoidCallback? onTap,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Timeline Line & Dot Indicator
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 1)),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: ParishColors.borderGrey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Right Concise Timeline Tile (Clickable for full inspection)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ParishColors.borderGrey),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    actionTitle,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                  ),
                                  Text(
                                    timestamp,
                                    style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$userName ($userRole) • "$details"',
                                style: TextStyle(fontSize: 12, color: ParishColors.textDark.withOpacity(0.85)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, size: 18, color: ParishColors.textMuted),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens an Audit Trail Details Dialog showing complete log info & altered fields diff
  void _showAuditDetailsModal(BuildContext context, Map<String, dynamic> log) {
    final createdAt = (log['created_at'] ?? '').toString();
    final dateStr = createdAt.isNotEmpty ? createdAt.substring(0, 19).replaceAll('T', ' ') : '—';
    final userName = log['performed_by_name']?.toString() ?? 'Authorized Personnel';
    final userRole = log['performed_by_role']?.toString() ?? 'Staff';
    final actionType = log['action_type']?.toString() ?? 'UPDATED';
    final justification = log['justification']?.toString() ?? 'No justification provided';
    final changesSummary = log['changes_summary']?.toString();

    Map<String, dynamic> parsedChanges = {};
    if (changesSummary != null && changesSummary.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(changesSummary);
        if (decoded is Map<String, dynamic>) {
          parsedChanges = decoded;
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: ParishColors.cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history_edu, color: widget.themeColor, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Audit Log Inspection Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ParishColors.borderGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAuditDetailRow('Log ID:', log['log_id']?.toString() ?? '—'),
                      _buildAuditDetailRow('Action Type:', actionType),
                      _buildAuditDetailRow('Timestamp:', dateStr),
                      _buildAuditDetailRow('Performed By:', '$userName ($userRole)'),
                      _buildAuditDetailRow('Record ID:', log['record_id']?.toString() ?? widget.recordId),
                      _buildAuditDetailRow('Coordinates:', 'Book ${log['book_number'] ?? "—"}, Page ${log['page_number'] ?? "—"}, Line ${log['line_number'] ?? "—"}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Justification / Canonical Reason:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.textDark),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5)),
                  ),
                  child: Text(
                    justification,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Altered Informatiom:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.textDark),
                ),
                const SizedBox(height: 8),

                if (parsedChanges.isEmpty)
                  Text(
                    changesSummary != null && changesSummary.trim().isNotEmpty
                        ? changesSummary
                        : 'No detailed field diff recorded for this action.',
                    style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted, fontStyle: FontStyle.italic),
                  )
                else
                  ...parsedChanges.entries.map((diffEntry) {
                    final fieldName = diffEntry.key;
                    final valMap = diffEntry.value;
                    final oldVal = valMap is Map ? valMap['old']?.toString() ?? '—' : '—';
                    final newVal = valMap is Map ? valMap['new']?.toString() ?? '—' : valMap.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ParishColors.borderGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fieldName.toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.themeColor),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Previous Value:', style: TextStyle(fontSize: 10, color: ParishColors.mercyRed)),
                                    Text(oldVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.mercyRed)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward, size: 14, color: ParishColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Updated Value:', style: TextStyle(fontSize: 10, color: ParishColors.oliveGreen)),
                                    Text(newVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.oliveGreen)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Inspection'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Issuance History Card (With Pagination)
  // ===========================================================================

  Widget _buildIssuanceHistoryCard(Color cardWhite, Color borderGrey, Color textDark, Color textMuted) {
    final totalIssuances = _pastIssuances.length;
    final totalIssuancePages = (totalIssuances / _issuanceRowsPerPage).ceil() > 0 ? (totalIssuances / _issuanceRowsPerPage).ceil() : 1;
    if (_issuanceCurrentPage > totalIssuancePages) _issuanceCurrentPage = totalIssuancePages;

    final startIdx = (_issuanceCurrentPage - 1) * _issuanceRowsPerPage;
    final endIdx = (startIdx + _issuanceRowsPerPage) > totalIssuances ? totalIssuances : (startIdx + _issuanceRowsPerPage);
    final pagedIssuances = totalIssuances > 0 ? _pastIssuances.sublist(startIdx, endIdx) : <CertificateIssuanceModel>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: widget.themeColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Issued Certificates ($totalIssuances)',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: widget.themeColor),
                  ),
                ],
              ),
              if (_pastIssuances.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pastIssuances.length} Logged',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.themeColor),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),

          if (_isLoadingIssuances)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_pastIssuances.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No official certificates have been issued yet for this canonical record.',
                style: TextStyle(fontSize: 13, color: textMuted, fontStyle: FontStyle.italic),
              ),
            )
          else ...[
              ...pagedIssuances.map((issuance) {
                final isValid = issuance.isValid;
                final statusColor = isValid ? ParishColors.oliveGreen : ParishColors.mercyRed;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isValid ? Icons.verified : Icons.cancel,
                        size: 20,
                        color: statusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    issuance.issuanceId,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    issuance.certificateStatus.toUpperCase(),
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Purpose: ${issuance.purpose}', style: TextStyle(fontSize: 12.5, color: textDark.withOpacity(0.85))),
                            Text(
                              'Issued: ${issuance.issuedAt.toIso8601String().substring(0, 10)} • Signatory: ${issuance.signatoryName}',
                              style: TextStyle(fontSize: 11.5, color: textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Token: ${issuance.verificationId}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Pagination for Issuance History
              if (totalIssuances > _issuanceRowsPerPage) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page $_issuanceCurrentPage of $totalIssuancePages',
                      style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: _issuanceCurrentPage > 1 ? () => setState(() => _issuanceCurrentPage--) : null,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: _issuanceCurrentPage < totalIssuancePages ? () => setState(() => _issuanceCurrentPage++) : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Specific Sacrament Layout Builders
  // ===========================================================================

  Widget _buildSacramentSpecificDetails() {
    switch (widget.sacramentName) {
      case 'Baptism':
        return _buildBaptismDetails();
      case 'Confirmation':
        return _buildConfirmationDetails();
      case 'First Communion':
        return _buildFirstCommunionDetails();
      case 'Matrimony':
        return _buildMatrimonyDetails();
      case 'Death':
        return _buildDeathDetails();
      case 'Conversion':
        return _buildConversionDetails();
      default:
        return const Center(child: Text('Unknown Sacrament Type.'));
    }
  }

  Widget _buildBaptismDetails() {
    return Column(
      children: [
        _buildDetailCard("Child's Identity", Icons.child_care, [
          _buildDataRow('Full Name', _fullName('child')),
          _buildDataRow('Date of Birth', _val('date_of_birth'), 'Place of Birth', _val('place_of_birth')),
          _buildDataRow('Gender', _val('gender'), 'Legitimacy', _val('legitimacy')),
        ]),
        _buildDetailCard("Parents' Lineage", Icons.people, [
          _buildDataRow("Father's Name", _fullName('father'), "Origin", _val('father_place_of_birth')),
          _buildDataRow("Mother's Maiden Name", _fullName('mother'), "Origin", _val('mother_place_of_birth')),
          _buildDataRow('Contact No.', _val('parents_contact_number'), 'Residence', _val('parents_residence')),
        ]),
        _buildDetailCard('Sponsors / Godparents', Icons.people_outline, [
          _buildDataRow('Primary Sponsor 1', _fullName('sponsor_1'), 'Residence', _val('sponsor_1_residence')),
          _buildDataRow('Primary Sponsor 2', _fullName('sponsor_2'), 'Residence', _val('sponsor_2_residence')),
          _buildDataRow('Other Godparents', _val('other_godparents')),
        ]),
        _buildDetailCard('Administration Details', Icons.church, [
          _buildDataRow('Date of Baptism', _val('date_of_baptism'), 'Parish / Church', _val('place_of_baptism')),
          _buildDataRow('Officiating Minister', 'Rev. Fr. ${_fullName('minister')}'),
          _buildDataRow('Stipend (₱)', _val('stipend'), 'Entry Status', _val('entry_status')),
          if (_val('remarks') != '—') _buildDataRow('Marginal Annotations', _val('remarks')),
        ]),
      ],
    );
  }

  Widget _buildConfirmationDetails() {
    return Column(
      children: [
        _buildDetailCard("Confirmand's Identity", Icons.local_fire_department, [
          _buildDataRow('Full Name', _fullName('confirmand')),
          _buildDataRow('Date of Birth', _val('date_of_birth'), 'Age', _val('age')),
          _buildDataRow('Date of Baptism', _val('date_of_baptism'), 'Church of Baptism', _val('church_baptized')),
          _buildDataRow('Residence Address', _val('address')),
        ]),
        _buildDetailCard("Parents' Lineage", Icons.people, [
          _buildDataRow("Father's Name", _fullName('father'), "Origin", _val('father_origin')),
          _buildDataRow("Mother's Maiden Name", _fullName('mother'), "Origin", _val('mother_origin')),
        ]),
        _buildDetailCard('Sponsors', Icons.people_outline, [
          _buildDataRow('Primary Sponsor 1', _fullName('sponsor_1'), 'Origin', _val('sponsor_1_origin_address')),
          _buildDataRow('Primary Sponsor 2', _fullName('sponsor_2'), 'Origin', _val('sponsor_2_origin_address')),
        ]),
        _buildDetailCard('Administration Details', Icons.church, [
          _buildDataRow('Date of Confirmation', _val('date_of_confirmation'), 'Parish', _val('parish_name')),
          _buildDataRow('Officiating Bishop/Minister', 'Rev. Fr. ${_fullName('minister')}', 'Stipend (₱)', _val('stipend')),
          _buildDataRow('Entry Status', _val('entry_status')),
          if (_val('remarks') != '—') _buildDataRow('Marginal Annotations', _val('remarks')),
        ]),
      ],
    );
  }

  Widget _buildFirstCommunionDetails() {
    return Column(
      children: [
        _buildDetailCard("Communicant's Identity", Icons.restaurant, [
          _buildDataRow('Full Name', _fullName('communicant')),
          _buildDataRow('Church of Baptism', _val('baptism_parish'), 'Date of Baptism', _val('baptism_date')),
        ]),
        _buildDetailCard("Parents' Lineage", Icons.people, [
          _buildDataRow("Father's Name", _fullName('father'), "Mother's Maiden Name", _fullName('mother')),
        ]),
        _buildDetailCard('Administration Details', Icons.church, [
          _buildDataRow('Date of Communion', _val('date_of_communion'), 'Reception Year', _val('year')),
          _buildDataRow('Officiating Minister', 'Rev. Fr. ${_fullName('minister')}'),
          _buildDataRow('Control Number', _val('control_number'), 'Entry Status', _val('entry_status')),
          if (_val('remarks') != '—') _buildDataRow('Batch / Mass Annotations', _val('remarks')),
        ]),
      ],
    );
  }

  Widget _buildMatrimonyDetails() {
    return Column(
      children: [
        _buildDetailCard("Groom's Identity", Icons.male, [
          _buildDataRow('Full Name', _fullName('groom')),
          _buildDataRow('Age', _val('groom_age'), 'Civil Status', _val('groom_civil_status')),
          _buildDataRow('Date of Birth', _val('groom_date_of_birth'), 'Place of Birth', _val('groom_place_of_birth')),
          _buildDataRow('Residence', _val('groom_address')),
          _buildDataRow("Father's Name", _fullName('groom_father'), "Mother's Name", _fullName('groom_mother')),
        ]),
        _buildDetailCard("Bride's Identity", Icons.female, [
          _buildDataRow('Full Name', _fullName('bride')),
          _buildDataRow('Age', _val('bride_age'), 'Civil Status', _val('bride_civil_status')),
          _buildDataRow('Date of Birth', _val('bride_date_of_birth'), 'Place of Birth', _val('bride_place_of_birth')),
          _buildDataRow('Residence', _val('bride_address')),
          _buildDataRow("Father's Name", _fullName('bride_father'), "Mother's Name", _fullName('bride_mother')),
        ]),
        _buildDetailCard('Sponsors & Witnesses', Icons.people_outline, [
          _buildDataRow('Primary Sponsor 1', _fullName('sponsor_1'), 'Origin', _val('sponsor_1_origin_address')),
          _buildDataRow('Primary Sponsor 2', _fullName('sponsor_2'), 'Origin', _val('sponsor_2_origin_address')),
          if (_val('other_sponsors') != '—') _buildDataRow('Other Witnesses', _val('other_sponsors')),
        ]),
        _buildDetailCard('Ceremony & Civil Compliance', Icons.church, [
          _buildDataRow('Date of Marriage', _val('date_of_marriage'), 'Marriage Type', _val('marriage_type')),
          _buildDataRow('Marriage License No.', _val('marriage_license_no'), 'Date Registered', _val('license_date_registered')),
          _buildDataRow('Filipino / Foreigner?', _val('is_filipino_foreigner'), 'License Issued At', _val('license_place_issued')),
        ]),
        _buildDetailCard('Solemnizing Minister', Icons.verified, [
          _buildDataRow('Minister Name', 'Rev. Fr. ${_fullName('solemnizer')}'),
          _buildDataRow('CRASM Number', _val('crasm_number'), 'CRASM Validity', _val('crasm_validity_date')),
          _buildDataRow('Stipend (₱)', _val('stipend'), 'Entry Status', _val('entry_status')),
          if (_val('remarks') != '—') _buildDataRow('Marginal Annotations', _val('remarks')),
        ]),
      ],
    );
  }

  Widget _buildDeathDetails() {
    return Column(
      children: [
        _buildDetailCard("Deceased Identity (Defuncti)", Icons.person, [
          _buildDataRow('Full Name', _fullName('deceased')),
          _buildDataRow('Age at Death', _val('age'), 'Gender', _val('gender')),
          _buildDataRow('Civil Status', _val('civil_status'), 'Residence', _val('residence')),
        ]),
        _buildDetailCard("Next of Kin", Icons.family_restroom, [
          _buildDataRow('Surviving Spouse', _fullName('spouse')),
          _buildDataRow("Father's Name", _fullName('father'), "Mother's Maiden Name", _fullName('mother')),
        ]),
        _buildDetailCard('Burial & Circumstances', Icons.local_hospital, [
          _buildDataRow('Date of Death', _val('date_of_death'), 'Cause of Death', _val('cause_of_death')),
          _buildDataRow('Date of Burial', _val('date_of_burial'), 'Cemetery', _val('place_of_burial')),
          _buildDataRow('Sacraments Received Before Death', _val('sacraments_received')),
          if (_val('sacraments_notes') != '—') _buildDataRow('Sacrament Details', _val('sacraments_notes')),
        ]),
        _buildDetailCard('Liturgical Service & Minister', Icons.church, [
          _buildDataRow('Liturgical Rite', _val('liturgical_service'), 'Stipend (₱)', _val('stipend')),
          _buildDataRow('Officiating Priest', 'Rev. Fr. ${_fullName('minister')}', 'Entry Status', _val('entry_status')),
          if (_val('remarks') != '—') _buildDataRow('Observanda (Remarks)', _val('remarks')),
        ]),
      ],
    );
  }

  Widget _buildConversionDetails() {
    return Column(
      children: [
        _buildDetailCard("Identity & Reception", Icons.person, [
          _buildDataRow('Full Name', _fullName('convert')),
          _buildDataRow('Date of Reception', _val('date_of_reception')),
          _buildDataRow('Date of Birth', _val('date_of_birth'), 'Place of Birth', _val('place_of_birth')),
        ]),
        _buildDetailCard("Prior Non-Catholic Baptism", Icons.water_drop_outlined, [
          _buildDataRow('Prior Baptism Date', _val('prior_baptism_date'), 'Prior Church', _val('prior_baptism_church')),
          _buildDataRow('Place of Baptism', _val('prior_baptism_place')),
        ]),
        _buildDetailCard("Parents' Religion", Icons.people, [
          _buildDataRow("Father's Name", _fullName('father'), "Religion", _val('father_religion')),
          _buildDataRow("Mother's Maiden Name", _fullName('mother'), "Religion", _val('mother_religion')),
        ]),
        _buildDetailCard('Witnesses & Minister', Icons.church, [
          _buildDataRow('Witness 1', _fullName('witness_1'), 'Witness 2', _fullName('witness_2')),
          _buildDataRow('Officiating Minister', 'Rev. Fr. ${_fullName('minister')}'),
          _buildDataRow('Is Gratis?', _val('is_gratis'), 'Entry Status', _val('entry_status')),
          if (_val('remarks') != '—') _buildDataRow('Marginal Annotations', _val('remarks')),
        ]),
      ],
    );
  }

  // ===========================================================================
  // Reusable UI Builders
  // ===========================================================================

  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: widget.themeColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.themeColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label1, String value1, [String? label2, String? value2]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDataField(label1, value1)),
          if (label2 != null && value2 != null) ...[
            const SizedBox(width: 16),
            Expanded(child: _buildDataField(label2, value2)),
          ] else if (label2 != null) ...[
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ]
        ],
      ),
    );
  }

  Widget _buildDataField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: ParishColors.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          softWrap: true,
          style: TextStyle(fontSize: 14, color: ParishColors.textDark, fontWeight: FontWeight.w600, height: 1.4),
        ),
      ],
    );
  }
}