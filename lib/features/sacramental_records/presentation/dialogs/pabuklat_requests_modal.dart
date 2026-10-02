import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../receipts/services/secretary_service.dart';

void showPabuklatRequestsModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _PabuklatRequestsModal(),
  );
}

class _PabuklatRequestsModal extends StatefulWidget {
  const _PabuklatRequestsModal();

  @override
  State<_PabuklatRequestsModal> createState() => _PabuklatRequestsModalState();
}

class _PabuklatRequestsModalState extends State<_PabuklatRequestsModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final data = await SecretaryService.getServiceRequests();
      if (!mounted) return;
      setState(() {
        _requests = data.where((r) => r['service_type'].toString().toLowerCase().contains('pabuklat')).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    DateTime? assignedPickupDate = DateTime.now().add(const Duration(days: 3));

    final picked = await showDatePicker(
      context: context,
      initialDate: assignedPickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (picked != null) assignedPickupDate = picked;

    try {
      await SecretaryService.updateServiceRequestStatus(
        serviceRequestId: request['service_request_id'],
        requestStatus: 'approved',
        pickupDate: assignedPickupDate,
      );

      _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request approved! Pickup date assigned to parishioner.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving request: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Pabuklat Request', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason for Rejection *', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await SecretaryService.updateServiceRequestStatus(
          serviceRequestId: request['service_request_id'],
          requestStatus: 'rejected',
          rejectionReason: reasonController.text.trim(),
        );

        _loadRequests();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request marked as rejected.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: ParishColors.marianBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.folder_shared, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Secretary Review: Pabuklat Requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                        Text('Review matched records and assign physical certificate release schedules', style: TextStyle(fontSize: 11.5, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                  ? Center(child: Text('No Pabuklat requests pending.', style: TextStyle(color: textMuted)))
                  : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  final status = req['request_status']?.toString().toUpperCase() ?? 'SUBMITTED';
                  final summary = req['matched_record_summary']?.toString() ?? 'Matched Record';
                  final details = req['service_request_details']?.toString() ?? '';
                  final pickup = req['pickup_date']?.toString();

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(req['service_request_id'] ?? 'REQ-X', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ParishColors.marianBlue)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                              child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Requester: ${req['requester_name']} (${req['contact_number']})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark)),
                        const SizedBox(height: 4),
                        Text(summary, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                        Text(details, style: TextStyle(fontSize: 11.5, color: textDark)),
                        if (pickup != null) ...[
                          const SizedBox(height: 4),
                          Text('Pickup Date Assigned: $pickup', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: ParishColors.mercyRed),
                              onPressed: () => _rejectRequest(req),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                              onPressed: () => _approveRequest(req),
                              child: const Text('Approve & Set Pickup'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}