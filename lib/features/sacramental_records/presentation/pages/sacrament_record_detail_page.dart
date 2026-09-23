import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/generate_certificate_dialog.dart';
import 'baptism_manual_entry_page.dart';
import 'certificate_template_management_page.dart';
import 'confirmation_manual_entry_page.dart';
import 'conversion_manual_entry_page.dart';
import 'death_manual_entry_page.dart';
import 'first_communion_manual_entry_page.dart';
import 'matrimony_manual_entry_page.dart';

class SacramentRecordDetailPage extends StatelessWidget {
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

  /// Opens the matching manual entry form in Edit Record Mode
  void _openEditRecord(BuildContext context) {
    Widget? editPage;

    if (sacramentName == 'Baptism') {
      editPage = BaptismManualEntryPage(
        initialData: rawRecordData,
        onRecordSaved: () {
          onRecordUpdated?.call();
          Navigator.pop(context); // Close detail page so user returns to refreshed registry
        },
      );
    } else if (sacramentName == 'Confirmation') {
      editPage = ConfirmationManualEntryPage(
        initialData: rawRecordData,
        onRecordSaved: () {
          onRecordUpdated?.call();
          Navigator.pop(context);
        },
      );
    } else if (sacramentName == 'First Communion') {
      editPage = FirstCommunionManualEntryPage(
        initialData: rawRecordData,
        onRecordSaved: () {
          onRecordUpdated?.call();
          Navigator.pop(context);
        },
      );
    } else if (sacramentName == 'Matrimony') {
      editPage = MatrimonyManualEntryPage(
        initialData: rawRecordData,
        onRecordSaved: () {
          onRecordUpdated?.call();
          Navigator.pop(context);
        },
      );
    } else if (sacramentName == 'Death') {
      editPage = DeathManualEntryPage(
        initialData: rawRecordData,
        onRecordSaved: () {
          onRecordUpdated?.call();
          Navigator.pop(context);
        },
      );
    } else if (sacramentName == 'Conversion') {
      editPage = ConversionManualEntryPage(
        initialData: rawRecordData,
        onRecordSaved: () {
          onRecordUpdated?.call();
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

  /// Safely extracts and formats data from the raw database map
  String _val(String key) {
    final v = rawRecordData[key];
    if (v == null) return '—';
    final str = v.toString().trim();
    if (str.isEmpty) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    return str;
  }

  /// Constructs a full name from separate database fields without trailing or misplaced dashes
  String _fullName(String prefix) {
    final f = _val('${prefix}_first_name');
    final m = _val('${prefix}_middle_name');

    // Check all possible schema column variants for surnames
    String l = _val('${prefix}_last_name');
    if (l == '—') {
      l = _val('${prefix}_maiden_last_name');
    }
    if (l == '—') {
      l = _val('${prefix}_maiden_last');
    }

    final s = _val('${prefix}_suffix');

    // Check for Canon 877 §2 placeholder
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

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$sacramentName Record Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              'Canonical ID: $recordId',
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.design_services_outlined, color: themeColor),
            tooltip: 'Manage Certificate Templates',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: themeColor),
            tooltip: 'Edit Record',
            onPressed: () => _openEditRecord(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: themeColor,
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
                              name,
                              softWrap: true,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bookRef,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Sacrament-Specific Detailed Canonical View
                Text(
                  'Canonical Register Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
                const SizedBox(height: 12),
                _buildSacramentSpecificDetails(),

                const SizedBox(height: 16),

                // 3. Primary Action: Launch Official Certificate Workflow Modal
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => showGenerateCertificateModal(
                      context,
                      sacramentType: sacramentName,
                      recordId: recordId,
                      recipientName: name,
                      rawRecordData: rawRecordData,
                      bookRef: bookRef,
                      onCertificateIssued: () {
                        onRecordUpdated?.call();
                      },
                    ),
                    icon: const Icon(Icons.print, size: 22),
                    label: Text(
                      'Generate Official $sacramentName Certificate',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Specific Sacrament Layout Builders
  // ===========================================================================

  Widget _buildSacramentSpecificDetails() {
    switch (sacramentName) {
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
          _buildDataRow('Officiating Priest', 'Rev. Fr. ${_fullName('minister')}'),
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
          _buildDataRow('Is Gratis?', _val('is_gratis'), 'Stipend (₱)', _val('stipend')),
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
      margin: const EdgeInsets.only(bottom: 20),
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
              Icon(icon, color: themeColor, size: 22),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)),
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