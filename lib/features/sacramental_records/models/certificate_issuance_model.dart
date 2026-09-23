class CertificateIssuanceModel {
  final String issuanceId;
  final String verificationId; // Unique, non-sequential cryptographic token
  final String recordId;
  final String sacramentType;
  final String recipientName;
  final String purpose;

  // Snapshot of template used at time of issuance
  final String? templateId;
  final int templateVersion;
  final String renderedWording;
  final String signatoryName;
  final String signatoryTitle;

  // Canonical coordinates snapshot
  final String? bookNumber;
  final String? pageNumber;
  final String? lineNumber;
  final String? registryReference;

  // Verification & Status
  final String qrVerificationUrl;
  final String? pdfStoragePath;
  final String certificateStatus; // 'Valid', 'Revoked', 'Cancelled'
  final String? revocationReason;
  final DateTime? revokedAt;
  final String? revokedBy;

  final String? issuedBy;
  final DateTime issuedAt;
  final DateTime? createdAt;

  CertificateIssuanceModel({
    required this.issuanceId,
    required this.verificationId,
    required this.recordId,
    required this.sacramentType,
    required this.recipientName,
    required this.purpose,
    this.templateId,
    this.templateVersion = 1,
    required this.renderedWording,
    required this.signatoryName,
    required this.signatoryTitle,
    this.bookNumber,
    this.pageNumber,
    this.lineNumber,
    this.registryReference,
    required this.qrVerificationUrl,
    this.pdfStoragePath,
    this.certificateStatus = 'Valid',
    this.revocationReason,
    this.revokedAt,
    this.revokedBy,
    this.issuedBy,
    required this.issuedAt,
    this.createdAt,
  });

  bool get isValid => certificateStatus == 'Valid';
  bool get isRevoked => certificateStatus == 'Revoked';
  bool get isCancelled => certificateStatus == 'Cancelled';

  String get bookReferenceDisplay {
    if (registryReference != null && registryReference!.trim().isNotEmpty) {
      return registryReference!;
    }
    if (bookNumber != null && pageNumber != null && lineNumber != null) {
      return 'Book $bookNumber, Page $pageNumber, Line $lineNumber';
    }
    return '—';
  }

  factory CertificateIssuanceModel.fromMap(Map<String, dynamic> map) {
    return CertificateIssuanceModel(
      issuanceId: map['issuance_id']?.toString() ?? '',
      verificationId: map['verification_id']?.toString() ?? '',
      recordId: map['record_id']?.toString() ?? '',
      sacramentType: map['sacrament_type']?.toString() ?? '',
      recipientName: map['recipient_name']?.toString() ?? '',
      purpose: map['purpose']?.toString() ?? '',
      templateId: map['template_id']?.toString(),
      templateVersion: int.tryParse(map['template_version']?.toString() ?? '1') ?? 1,
      renderedWording: map['rendered_wording']?.toString() ?? '',
      signatoryName: map['signatory_name']?.toString() ?? 'Rev. Fr. Joseph Santos',
      signatoryTitle: map['signatory_title']?.toString() ?? 'Parish Priest',
      bookNumber: map['book_number']?.toString(),
      pageNumber: map['page_number']?.toString(),
      lineNumber: map['line_number']?.toString(),
      registryReference: map['registry_reference']?.toString(),
      qrVerificationUrl: map['qr_verification_url']?.toString() ?? '',
      pdfStoragePath: map['pdf_storage_path']?.toString(),
      certificateStatus: map['certificate_status']?.toString() ?? 'Valid',
      revocationReason: map['revocation_reason']?.toString(),
      revokedAt: map['revoked_at'] != null ? DateTime.tryParse(map['revoked_at'].toString()) : null,
      revokedBy: map['revoked_by']?.toString(),
      issuedBy: map['issued_by']?.toString(),
      issuedAt: DateTime.tryParse(map['issued_at']?.toString() ?? '') ?? DateTime.now(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'issuance_id': issuanceId,
      'verification_id': verificationId,
      'record_id': recordId,
      'sacrament_type': sacramentType,
      'recipient_name': recipientName,
      'purpose': purpose,
      'template_id': templateId,
      'template_version': templateVersion,
      'rendered_wording': renderedWording,
      'signatory_name': signatoryName,
      'signatory_title': signatoryTitle,
      'book_number': bookNumber,
      'page_number': pageNumber,
      'line_number': lineNumber,
      'registry_reference': registryReference,
      'qr_verification_url': qrVerificationUrl,
      'pdf_storage_path': pdfStoragePath,
      'certificate_status': certificateStatus,
      'revocation_reason': revocationReason,
      'revoked_at': revokedAt?.toIso8601String(),
      'revoked_by': revokedBy,
      'issued_by': issuedBy,
      'issued_at': issuedAt.toIso8601String(),
    };
  }
}