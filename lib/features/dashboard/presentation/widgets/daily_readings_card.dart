import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/daily_reading_model.dart';
import '../../services/daily_readings_service.dart';

class DailyReadingsCard extends StatefulWidget {
  final DateTime? targetDate;

  const DailyReadingsCard({super.key, this.targetDate});

  @override
  State<DailyReadingsCard> createState() => _DailyReadingsCardState();
}

class _DailyReadingsCardState extends State<DailyReadingsCard> {
  DailyReadingModel? _reading;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReadings();
  }

  Future<void> _fetchReadings() async {
    setState(() => _isLoading = true);
    final data = await DailyReadingsService.getDailyReading(targetDate: widget.targetDate);
    if (!mounted) return;
    setState(() {
      _reading = data;
      _isLoading = false;
    });
  }

  Color _getSeasonColor(String season) {
    final s = season.toLowerCase();
    if (s.contains('lent') || s.contains('advent')) {
      return const Color(0xFF7C3AED); // Liturgical Violet
    }
    if (s.contains('easter') || s.contains('christmas')) {
      return ParishColors.goldAccent; // Liturgical White / Gold
    }
    return ParishColors.oliveGreen; // Ordinary Time Green
  }

  void _showReadingDetailsDialog(DailyReadingModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_stories, color: ParishColors.marianBlue, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Liturgy of the Word',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ParishColors.textDark),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.celebrationName != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ParishColors.marianBlue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.celebrationName!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                      if (r.saintQuote != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"${r.saintQuote}"',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ParishColors.textDark),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _buildModalPassageSection('First Reading', r.firstReading, Icons.menu_book),
              const SizedBox(height: 12),
              _buildModalPassageSection('Responsorial Psalm', r.psalm, Icons.music_note),
              if (r.secondReading != null && r.secondReading!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildModalPassageSection('Second Reading', r.secondReading!, Icons.book),
              ],
              const SizedBox(height: 12),
              _buildModalPassageSection('Holy Gospel', r.gospel, Icons.local_fire_department, isGospel: true),
              const SizedBox(height: 14),
              Text(
                'Readings follow the Roman Catholic Liturgical Lectionary for Mass.',
                style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildModalPassageSection(String title, String passage, IconData icon, {bool isGospel = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGospel ? ParishColors.goldLight : ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isGospel ? ParishColors.goldAccent : ParishColors.borderGrey,
          width: isGospel ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isGospel ? ParishColors.goldAccent : ParishColors.marianBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isGospel ? const Color(0xFF92400E) : ParishColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  passage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isGospel ? const Color(0xFF92400E) : ParishColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    if (_isLoading) {
      return Container(
        height: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderGrey, width: 1.2),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(height: 12),
              Text('Fetching today\'s Mass readings...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final r = _reading;
    if (r == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderGrey, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories, color: ParishColors.marianBlue, size: 22),
                const SizedBox(width: 10),
                Text('Daily Mass Readings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
              ],
            ),
            const Divider(height: 20),
            Text('Scripture readings available in parish missalettes.', style: TextStyle(fontSize: 13, color: textMuted)),
          ],
        ),
      );
    }

    final seasonColor = _getSeasonColor(r.season);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_stories, color: ParishColors.marianBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Mass Readings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      Text(
                        'Liturgy of the Word',
                        style: TextStyle(fontSize: 11.5, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: seasonColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: seasonColor.withOpacity(0.4)),
                ),
                child: Text(
                  r.season.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: seasonColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Saint / Feast Banner (if available)
          if (r.celebrationName != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderGrey.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.church_outlined, size: 16, color: seasonColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.celebrationName!,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Scripture Passages Summary
          _buildPassageRow('First Reading', r.firstReading),
          const SizedBox(height: 6),
          _buildPassageRow('Psalm', r.psalm),
          if (r.secondReading != null && r.secondReading!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildPassageRow('Second Reading', r.secondReading!),
          ],
          const SizedBox(height: 6),
          _buildPassageRow('Holy Gospel', r.gospel, isGospel: true),

          const SizedBox(height: 14),

          // Action Button to inspect details
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ParishColors.marianBlue, width: 1.2),
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showReadingDetailsDialog(r),
              icon: const Icon(Icons.menu_book, size: 16),
              label: const Text('Read Full Passages & Reflection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageRow(String label, String passage, {bool isGospel = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isGospel ? FontWeight.bold : FontWeight.w600,
              color: isGospel ? const Color(0xFF92400E) : ParishColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            passage,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isGospel ? FontWeight.bold : FontWeight.w500,
              color: isGospel ? const Color(0xFF92400E) : ParishColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}