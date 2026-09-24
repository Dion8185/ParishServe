import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/certificate_issuance_model.dart';
import '../../services/certificate_service.dart';

class CertificateVerificationPage extends StatefulWidget {
  final String? initialVerificationId;

  const CertificateVerificationPage({super.key, this.initialVerificationId});

  @override
  State<CertificateVerificationPage> createState() => _CertificateVerificationPageState();
}

class _CertificateVerificationPageState extends State<CertificateVerificationPage> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _hasSearched = false;
  CertificateIssuanceModel? _issuanceRecord;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _resolveAndVerifyToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Automatically extracts the token from constructor arguments or browser URL
  void _resolveAndVerifyToken() {
    String? token = widget.initialVerificationId;

    // If no token was passed via constructor, extract directly from web address bar
    if ((token == null || token.trim().isEmpty) && kIsWeb) {
      final uri = Uri.base;

      // 1. Check standard query parameter: https://app.web.app/verify?v=TOKEN
      if (uri.queryParameters.containsKey('v')) {
        token = uri.queryParameters['v'];
      }
      // 2. Check hash routing format: https://app.web.app/#/verify?v=TOKEN
      else if (uri.hasFragment) {
        try {
          final fragmentUri = Uri.parse(uri.fragment);
          if (fragmentUri.queryParameters.containsKey('v')) {
            token = fragmentUri.queryParameters['v'];
          }
        } catch (_) {}
      }
    }

    if (token != null && token.trim().isNotEmpty) {
      _tokenController.text = token.trim();
      _performVerification(token.trim());
    }
  }

  Future<void> _performVerification(String tokenId) async {
    final cleanToken = tokenId.trim().toUpperCase();
    if (cleanToken.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchError = null;
      _issuanceRecord = null;
    });

    try {
      final record = await CertificateService.verifyCertificate(cleanToken);
      if (!mounted) return;
      setState(() {
        _issuanceRecord = record;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
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
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
          onPressed: () => Navigator.pop(context),
        )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Verification Portal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
            Text(
              'Official Document Authentication System • Diocese of San Pablo',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Parish Header Branding
                Container(
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
                    children: [
                      Icon(Icons.verified_user_outlined, size: 44, color: ParishColors.marianBlue),
                      const SizedBox(height: 10),
                      Text(
                        'Diocese of San Pablo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Saint John Paul II Parish',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Santa Cruz, Laguna, Philippines',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const Divider(height: 26),
                      Text(
                        'Scan the QR code printed on the physical certificate or enter the Verification Token below to confirm official parish registry authenticity.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Token Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.marianBlue, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: ParishColors.marianBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tokenController,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: 'Enter Verification Token (e.g. 550E8400-E29B-...)',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (v) => _performVerification(v),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _isLoading ? null : () => _performVerification(_tokenController.text),
                        child: _isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Results View
                if (_isLoading) ...[
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ] else if (_hasSearched) ...[
                  if (_issuanceRecord == null)
                    _buildInvalidResultCard()
                  else if (_issuanceRecord!.isRevoked)
                    _buildRevokedResultCard(_issuanceRecord!)
                  else
                    _buildValidResultCard(_issuanceRecord!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Valid Authentic Certificate State
  // ===========================================================================

  Widget _buildValidResultCard(CertificateIssuanceModel record) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.oliveGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: ParishColors.oliveGreen.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: const BoxDecoration(
              color: ParishColors.oliveGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFICIAL CERTIFICATE VERIFIED',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.5),
                      ),
                      Text(
                        'Valid canonical record issued by Saint John Paul II Parish',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVerificationRow('Recipient Full Name', record.recipientName, isBold: true),
                _buildVerificationRow('Sacrament Type', '${record.sacramentType} Certificate'),
                _buildVerificationRow('Date Issued', record.issuedAt.toIso8601String().substring(0, 10)),
                _buildVerificationRow('Official Purpose', record.purpose),
                const Divider(height: 24),
                _buildVerificationRow('Physical Ledger Coordinates', record.bookReferenceDisplay),
                _buildVerificationRow('Canonical Record ID', record.recordId),
                _buildVerificationRow('Issuing Signatory', '${record.signatoryName} (${record.signatoryTitle})'),
                _buildVerificationRow('Verification Token', record.verificationId),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ParishColors.borderGrey),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: ParishColors.oliveGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The information presented above matches the verified parish ledger archives of Saint John Paul II Parish.',
                          style: TextStyle(fontSize: 11.5, color: ParishColors.textDark, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. Revoked / Nullified State
  // ===========================================================================

  Widget _buildRevokedResultCard(CertificateIssuanceModel record) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.mercyRed, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: const BoxDecoration(
              color: ParishColors.mercyRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CERTIFICATE HAS BEEN REVOKED',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Text(
                        'This document is no longer recognized as valid or authentic',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVerificationRow('Recipient', record.recipientName),
                _buildVerificationRow('Certificate ID', record.issuanceId),
                _buildVerificationRow('Date Revoked', record.revokedAt?.toIso8601String().substring(0, 10) ?? '—'),
                _buildVerificationRow('Reason for Revocation', record.revocationReason ?? 'Cancelled by parish administration', isRed: true),
                const Divider(height: 24),
                Text(
                  'NOTICE: This certificate has been officially cancelled in the parish archives. It must not be honored for ecclesiastical, civil, or legal purposes.',
                  style: TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.bold, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. Invalid Token / Not Found State
  // ===========================================================================

  Widget _buildInvalidResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.mercyRed),
      ),
      child: Column(
        children: [
          Icon(Icons.gpp_bad, size: 54, color: ParishColors.mercyRed),
          const SizedBox(height: 12),
          Text(
            'INVALID VERIFICATION TOKEN',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
          ),
          const SizedBox(height: 6),
          Text(
            'No matching issuance record was found in the official archives of Saint John Paul II Parish.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ParishColors.textDark, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'WARNING: This certificate may be altered, expired, or counterfeit. Please contact the Parish Office of Saint John Paul II Parish in Santa Cruz, Laguna for manual verification.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ParishColors.mercyRed, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRow(String label, String value, {bool isBold = false, bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isRed ? ParishColors.mercyRed : ParishColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}