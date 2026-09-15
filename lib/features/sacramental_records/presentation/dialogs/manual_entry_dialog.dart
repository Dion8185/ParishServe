import 'package:flutter/material.dart';
import '../pages/baptism_manual_entry_page.dart';

void showManualEntryModal(BuildContext context, {VoidCallback? onRecordSaved}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BaptismManualEntryPage(onRecordSaved: onRecordSaved),
    ),
  );
}