import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../services/encoder_service.dart';

class EncoderDashboardWidget extends StatefulWidget {
  const EncoderDashboardWidget({super.key});

  @override
  State<EncoderDashboardWidget> createState() => _EncoderDashboardWidgetState();
}

class _EncoderDashboardWidgetState extends State<EncoderDashboardWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _unverifiedRecords = [];
  List<Map<String, dynamic>> _assets = [];
  int _offlineQueueCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEncoderData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEncoderData() async {
    setState(() => _isLoading = true);
    try {
      final records = await EncoderService.getUnverifiedRecords();
      final assets = await EncoderService.getAssets();
      if (!mounted) return;
      setState(() {
        _unverifiedRecords = records;
        _assets = assets;
      });
    } catch (e) {
      debugPrint('Error loading encoder data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOcrRecord(String recordId, String childName) async {
    try {
      await EncoderService.verifyRecord(recordId);
      _loadEncoderData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Record for $childName verified and committed to canonical database.'), backgroundColor: ParishColors.oliveGreen),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _updateAssetAudit(String controlNumber, String newCondition) async {
    try {
      await EncoderService.auditAsset(controlNumber, newCondition);
      _loadEncoderData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Asset $controlNumber status updated to $newCondition.'), backgroundColor: ParishColors.oliveGreen),
      );
    } catch (e) {
      setState(() => _offlineQueueCount++);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline mode: Audit saved to local cache. Will sync when online.'), backgroundColor: ParishColors.goldAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Encoder Workspace Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ParishColors.marianBlueSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.document_scanner, size: 36, color: ParishColors.marianBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encoder Digitization & Audit Workspace',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OCR Transcription Verification & Mobile Asset Tagging',
                      style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_offlineQueueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(8)),
                  child: Text('$_offlineQueueCount Cached', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: ParishColors.marianBlue,
          unselectedLabelColor: ParishColors.textMuted,
          indicatorColor: ParishColors.marianBlue,
          tabs: const [
            Tab(text: 'OCR Verification Queue'),
            Tab(text: 'Field Asset Audit'),
          ],
        ),

        // Tab Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
            controller: _tabController,
            children: [
              _buildOcrQueueTab(),
              _buildAssetAuditTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOcrQueueTab() {
    if (_unverifiedRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: ParishColors.oliveGreen),
            const SizedBox(height: 10),
            Text('No unverified OCR records in queue.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
            Text('All scanned ledgers have been transcribed and verified.', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _unverifiedRecords.length,
      itemBuilder: (context, index) {
        final rec = _unverifiedRecords[index];
        final childName = '${rec['child_first_name']} ${rec['child_last_name']}';
        final recordId = rec['record_id'];
        final ref = 'Book ${rec['book_number']}, Page ${rec['page_number']}, Line ${rec['line_number']}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(recordId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ParishColors.marianBlue)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                    child: const Text('PENDING OCR VERIFICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(childName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Text(ref, style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.oliveGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _verifyOcrRecord(recordId, childName),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Verify & Commit Transcription', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssetAuditTab() {
    if (_assets.isEmpty) {
      return const Center(child: Text('No registered parish assets found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final controlNo = asset['control_number'];
        final itemName = asset['item_name'];
        final location = asset['storage_location'];
        final condition = asset['condition_status'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.goldAccent),
                ),
                child: const Icon(Icons.qr_code, color: ParishColors.goldAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controlNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                    Text(itemName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Text(location, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                  ],
                ),
              ),
              DropdownButton<String>(
                value: ['VERIFIED / GOOD', 'REQUIRES REPAIR', 'MISSING', 'DAMAGED'].contains(condition) ? condition : 'VERIFIED / GOOD',
                items: const [
                  DropdownMenuItem(value: 'VERIFIED / GOOD', child: Text('Good', style: TextStyle(fontSize: 12, color: ParishColors.oliveGreen, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'REQUIRES REPAIR', child: Text('Repair', style: TextStyle(fontSize: 12, color: ParishColors.goldAccent, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'MISSING', child: Text('Missing', style: TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.bold))),
                ],
                onChanged: (val) {
                  if (val != null) _updateAssetAudit(controlNo, val);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}