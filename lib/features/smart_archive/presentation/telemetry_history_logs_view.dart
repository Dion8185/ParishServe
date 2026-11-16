// =============================================================================
// FILE: lib/features/smart_archive/presentation/telemetry_history_logs_view.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/sensor_detail_dialog.dart';

enum _TelemetryLogFilter { all, warningsOnly, optimalOnly }

class TelemetryHistoryLogItem {
  final String telemetryId;
  final String nodeId;
  final double temperature;
  final double humidity;
  final bool isWarning;
  final String? alertType;
  final DateTime recordedAt;

  const TelemetryHistoryLogItem({
    required this.telemetryId,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.isWarning,
    this.alertType,
    required this.recordedAt,
  });

  String get displayTitle {
    if (!isWarning) return 'Routine Microclimate Reading';
    final raw = alertType?.trim();
    if (raw == null || raw.isEmpty) return 'Microclimate Warning Alert';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  factory TelemetryHistoryLogItem.fromMap(Map<String, dynamic> map) {
    return TelemetryHistoryLogItem(
      telemetryId: map['telemetry_id']?.toString() ?? '',
      nodeId: map['node_id']?.toString() ?? 'ESP32-NODE-01',
      temperature: double.tryParse(map['temperature']?.toString() ?? '') ?? 0.0,
      humidity: double.tryParse(map['humidity']?.toString() ?? '') ?? 0.0,
      isWarning: (map['is_warning'] as bool?) ?? false,
      alertType: map['alert_type']?.toString(),
      recordedAt: DateTime.tryParse(map['recorded_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class TelemetryHistoryLogsView extends StatefulWidget {
  const TelemetryHistoryLogsView({super.key});

  @override
  State<TelemetryHistoryLogsView> createState() => _TelemetryHistoryLogsViewState();
}

class _TelemetryHistoryLogsViewState extends State<TelemetryHistoryLogsView> {
  static const int _pageSize = 30;

  final List<TelemetryHistoryLogItem> _logs = [];
  _TelemetryLogFilter _selectedFilter = _TelemetryLogFilter.all;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _fetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs(reset: true);
  }

  Future<void> _loadLogs({bool reset = false}) async {
    if (reset) {
      _fetchGeneration++;
      setState(() {
        _isInitialLoading = true;
        _isLoadingMore = false;
        _hasMore = true;
        _errorMessage = null;
        _logs.clear();
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    final int generation = _fetchGeneration;
    final int offset = reset ? 0 : _logs.length;

    try {
      var query = Supabase.instance.client
          .from('sensor_telemetry_logs')
          .select('telemetry_id, node_id, temperature, humidity, is_warning, alert_type, recorded_at');

      if (_selectedFilter == _TelemetryLogFilter.warningsOnly) {
        query = query.eq('is_warning', true);
      } else if (_selectedFilter == _TelemetryLogFilter.optimalOnly) {
        query = query.eq('is_warning', false);
      }

      final response = await query
          .order('recorded_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      if (!mounted || generation != _fetchGeneration) return;

      final fetched = (response as List)
          .map((row) => TelemetryHistoryLogItem.fromMap(row as Map<String, dynamic>))
          .toList();

      setState(() {
        _logs.addAll(fetched);
        _hasMore = fetched.length == _pageSize;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _errorMessage = e.toString();
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onFilterChanged(_TelemetryLogFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _loadLogs(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final warningCount = _logs.where((l) => l.isWarning).length;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: ParishColors.cardWhite,
        foregroundColor: ParishColors.textDark,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Telemetry History Logs',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: const ['Times New Roman', 'serif'],
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ParishColors.textDark,
              ),
            ),
            Text(
              'Santa Cruz, Laguna Archive Vault Readings',
              style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
            tooltip: 'Refresh Logs',
            onPressed: () => _loadLogs(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Summary Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All Logs',
                          filter: _TelemetryLogFilter.all,
                          icon: Icons.list_alt_rounded,
                        ),
                        _buildFilterChip(
                          label: 'Warnings Only',
                          filter: _TelemetryLogFilter.warningsOnly,
                          icon: Icons.warning_amber_rounded,
                          selectedColor: ParishColors.mercyRed,
                        ),
                        _buildFilterChip(
                          label: 'Optimal Only',
                          filter: _TelemetryLogFilter.optimalOnly,
                          icon: Icons.check_circle_outline,
                          selectedColor: ParishColors.oliveGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Loaded ${_logs.length} log${_logs.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
                        ),
                        if (_selectedFilter == _TelemetryLogFilter.all && _logs.isNotEmpty)
                          Text(
                            '$warningCount warning${warningCount == 1 ? '' : 's'} in loaded batch',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.mercyRed,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Logs List Body
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorState()
                : _logs.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: () => _loadLogs(reset: true),
              color: ParishColors.marianBlue,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _logs.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == _logs.length) {
                        return _buildLoadMoreButton();
                      }
                      return _buildLogCard(_logs[index]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required _TelemetryLogFilter filter,
    required IconData icon,
    Color selectedColor = ParishColors.marianBlue,
  }) {
    final bool isSelected = _selectedFilter == filter;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : selectedColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : ParishColors.textDark,
        ),
      ),
      selected: isSelected,
      selectedColor: selectedColor,
      backgroundColor: ParishColors.backgroundLight,
      side: BorderSide(color: isSelected ? selectedColor : ParishColors.borderGrey),
      onSelected: (_) => _onFilterChanged(filter),
    );
  }

  Widget _buildLogCard(TelemetryHistoryLogItem item) {
    final Color statusColor = item.isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen;
    final Color statusBg = item.isWarning ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showSensorDetailModal(
        context,
        roomTitle: 'Sacramental Archive Room',
        nodeId: item.nodeId,
        temperature: '${item.temperature.toStringAsFixed(1)} °C',
        humidity: '${item.humidity.toStringAsFixed(1)} %',
        isWarning: item.isWarning,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isWarning ? ParishColors.mercyRed.withOpacity(0.45) : ParishColors.borderGrey,
            width: item.isWarning ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: statusBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isWarning ? Icons.warning_amber_rounded : Icons.sensors,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.displayTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: ParishColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.isWarning ? 'WARNING' : 'OPTIMAL',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.nodeId} • ${_formatTimestamp(item.recordedAt)}',
                    style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.humidity.toStringAsFixed(1)} % RH',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: item.isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.temperature.toStringAsFixed(1)} °C',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: ParishColors.marianBlue,
            side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _loadLogs(reset: false),
          icon: const Icon(Icons.expand_more, size: 18),
          label: const Text(
            'Load More Logs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 52, color: ParishColors.borderGrey),
            const SizedBox(height: 12),
            Text(
              'No Telemetry Logs Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              'No recorded sensor logs match the selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 46, color: ParishColors.mercyRed),
            const SizedBox(height: 12),
            Text(
              'Unable to Load Telemetry Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _loadLogs(reset: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dt.day}, ${dt.year} • $hour12:$minute $period';
  }
}