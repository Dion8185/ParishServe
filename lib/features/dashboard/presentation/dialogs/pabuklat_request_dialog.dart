import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/services/auth_service.dart';
import '../../../auth/services/user_service.dart';

void showPabuklatRequestModal(BuildContext context, {VoidCallback? onRequestSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PabuklatRequestDialog(onRequestSaved: onRequestSaved),
  );
}

class _PabuklatRequestDialog extends StatefulWidget {
  final VoidCallback? onRequestSaved;

  const _PabuklatRequestDialog({this.onRequestSaved});

  @override
  State<_PabuklatRequestDialog> createState() => _PabuklatRequestDialogState();
}

class _PabuklatRequestDialogState extends State<_PabuklatRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameOnRecordController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _purposeController = TextEditingController();

  String _selectedCertificate = 'Baptismal Certificate';
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _certificateTypes = [
    'Baptismal Certificate',
    'Confirmation Certificate',
    'Marriage Certificate',
  ];

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null) {
      _nameOnRecordController.text = user.fullName;
    }
  }

  @override
  void dispose() {
    _nameOnRecordController.dispose();
    _contactNumberController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final details = 'Record Name: ${_nameOnRecordController.text.trim()}\nPurpose: ${_purposeController.text.trim()}';

      await UserService.createServiceRequest(
        requesterName: AuthService.currentUser?.fullName ?? 'Parishioner',
        contactNumber: _contactNumberController.text.trim(),
        serviceType: 'Pabuklat / $_selectedCertificate',
        details: details,
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pabuklat request submitted successfully! Please wait for Parish Office confirmation.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 4),
        ),
      );

      widget.onRequestSaved?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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
                    decoration: const BoxDecoration(
                      color: ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_shared, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Request Sacramental Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                        Text('Pabuklat / Certificate Issuance', style: TextStyle(fontSize: 12, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      _buildLabel('Certificate Type *'),
                      DropdownButtonFormField<String>(
                        value: _selectedCertificate,
                        items: _certificateTypes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) => setState(() => _selectedCertificate = val!),
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 14),

                      _buildLabel('Name on Record *'),
                      TextFormField(
                        controller: _nameOnRecordController,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        decoration: _inputDecoration(hint: 'Full name of the person on the certificate'),
                      ),
                      const SizedBox(height: 14),

                      _buildLabel('Contact Number *'),
                      TextFormField(
                        controller: _contactNumberController,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
                      ),
                      const SizedBox(height: 14),

                      _buildLabel('Purpose of Request *'),
                      TextFormField(
                        controller: _purposeController,
                        maxLines: 2,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        decoration: _inputDecoration(hint: 'e.g. For Marriage, Employment, School Reference'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 14, color: textMuted)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitRequest,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, size: 18),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}