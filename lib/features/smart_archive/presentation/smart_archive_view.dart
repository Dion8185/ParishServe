// =============================================================================
// FILE: lib/features/smart_archive/presentation/smart_archive_view.dart (PART 1 OF 2)
// =============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/configure_thresholds_dialog.dart';
import 'dialogs/sensor_detail_dialog.dart';
import 'widgets/storage_node_tile.dart';

class SmartArchiveNodeData {
  final String nodeId;
  final String roomTitle;
  final String storageType;
  final String locationDescription;
  final double temperature;
  final double humidity;
  final double idealTempMin;
  final double idealTempMax;
  final double idealHumidityMin;
  final double idealHumidityMax;
  final int signalDbm;
  final int batteryPercent;
  final bool isWarning;
  final String warningReason;
  final DateTime lastTelemetryAt;
  final List<double> recentTempHistory;
  final List<double> recentHumidityHistory;

  const SmartArchiveNodeData({
    required this.nodeId,
    required this.roomTitle,
    required this.storageType,
    required this.locationDescription,
    required this.temperature,
    required this.humidity,
    this.idealTempMin = 18.0,
    this.idealTempMax = 24.0,
    this.idealHumidityMin = 45.0,
    this.idealHumidityMax = 60.0,
    required this.signalDbm,
    required this.batteryPercent,
    required this.isWarning,
    required this.warningReason,
    required this.lastTelemetryAt,
    required this.recentTempHistory,
    required this.recentHumidityHistory,
  });

  SmartArchiveNodeData copyWith({
    double? temperature,
    double? humidity,
    bool? isWarning,
    String? warningReason,
    DateTime? lastTelemetryAt,
    List<double>? recentTempHistory,
    List<double>? recentHumidityHistory,
    int? signalDbm,
  }) {
    return SmartArchiveNodeData(
      nodeId: nodeId,
      roomTitle: roomTitle,
      storageType: storageType,
      locationDescription: locationDescription,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      idealTempMin: idealTempMin,
      idealTempMax: idealTempMax,
      idealHumidityMin: idealHumidityMin,
      idealHumidityMax: idealHumidityMax,
      signalDbm: signalDbm ?? this.signalDbm,
      batteryPercent: batteryPercent,
      isWarning: isWarning ?? this.isWarning,
      warningReason: warningReason ?? this.warningReason,
      lastTelemetryAt: lastTelemetryAt ?? this.lastTelemetryAt,
      recentTempHistory: recentTempHistory ?? this.recentTempHistory,
      recentHumidityHistory: recentHumidityHistory ?? this.recentHumidityHistory,
    );
  }
}

class SmartArchiveView extends StatefulWidget {
  const SmartArchiveView({super.key});

  @override
  State<SmartArchiveView> createState() => _SmartArchiveViewState();
}

class _SmartArchiveViewState extends State<SmartArchiveView>
    with SingleTickerProviderStateMixin {
  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  bool _isLoading = false;
  String _nodeFilter = 'All Nodes'; // 'All Nodes', 'Safe', 'Alerts'
  double _maxSafeHumidity = 60.0;
  double _maxSafeTemperature = 26.0;

  // Frontend State-Driven Monitored Storage Nodes
  late List<SmartArchiveNodeData> _nodes;

  @override
  void initState() {
    super.initState();

    _skeletonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _skeletonOpacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _skeletonAnimController, curve: Curves.easeInOut),
    );

    _initializeDefaultNodes();
  }

  void _initializeDefaultNodes() {
    final now = DateTime.now();

    _nodes = [
      SmartArchiveNodeData(
        nodeId: 'ESP32-NODE-01',
        roomTitle: 'Main Sacramental Archive Room',
        storageType: 'Canon 535 Sacramental Ledger Repository',
        locationDescription: 'Parish Administration Building, 2nd Floor Archive Vault',
        temperature: 24.2,
        humidity: 54.0,
        signalDbm: -58,
        batteryPercent: 98,
        isWarning: false,
        warningReason: 'Environmental conditions optimal for historical parchment.',
        lastTelemetryAt: now.subtract(const Duration(seconds: 42)),
        recentTempHistory: [23.8, 23.9, 24.0, 24.1, 24.3, 24.2],
        recentHumidityHistory: [52.0, 53.0, 53.5, 54.2, 54.0, 54.0],
      ),
      SmartArchiveNodeData(
        nodeId: 'ESP32-NODE-02',
        roomTitle: 'Liturgical Vessel & Robe Storage',
        storageType: 'Temporal Sacristy Vault',
        locationDescription: 'Main Altar Sacristy, Left Storage Wing',
        temperature: 29.1,
        humidity: 68.2,
        signalDbm: -64,
        batteryPercent: 92,
        isWarning: true,
        warningReason: 'Relative humidity (68.2% RH) exceeds safe threshold (60.0%). Mold & tarnish risk.',
        lastTelemetryAt: now.subtract(const Duration(seconds: 18)),
        recentTempHistory: [27.5, 28.0, 28.4, 28.9, 29.0, 29.1],
        recentHumidityHistory: [61.0, 63.5, 65.0, 66.8, 67.5, 68.2],
      ),
      SmartArchiveNodeData(
        nodeId: 'ESP32-NODE-03',
        roomTitle: 'Historical Parish Register Vault',
        storageType: 'Permanent Diocesan Rare Book Cabinet',
        locationDescription: 'De-humidified Fireproof Safe, Parish Archives',
        temperature: 23.5,
        humidity: 51.0,
        signalDbm: -52,
        batteryPercent: 100,
        isWarning: false,
        warningReason: 'Climate control active and sealed.',
        lastTelemetryAt: now.subtract(const Duration(seconds: 55)),
        recentTempHistory: [23.6, 23.5, 23.5, 23.4, 23.5, 23.5],
        recentHumidityHistory: [50.5, 51.0, 51.2, 50.8, 51.0, 51.0],
      ),
      SmartArchiveNodeData(
        nodeId: 'ESP32-NODE-04',
        roomTitle: 'Altar Linen & Vestment Closet',
        storageType: 'Textile & Liturgical Fabric Enclosure',
        locationDescription: 'Sanctuary Vesting Sacristy',
        temperature: 26.0,
        humidity: 58.0,
        signalDbm: -70,
        batteryPercent: 88,
        isWarning: false,
        warningReason: 'Safe preservation parameters.',
        lastTelemetryAt: now.subtract(const Duration(minutes: 1, seconds: 12)),
        recentTempHistory: [25.4, 25.6, 25.8, 25.9, 26.1, 26.0],
        recentHumidityHistory: [56.0, 57.0, 57.5, 58.2, 58.0, 58.0],
      ),
    ];
  }

  @override
  void dispose() {
    _skeletonAnimController.dispose();
    super.dispose();
  }

  Future<void> _refreshTelemetry() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    final rand = Random();
    setState(() {
      _nodes = _nodes.map((n) {
        final tempJitter = (rand.nextDouble() * 0.4) - 0.2;
        final humJitter = (rand.nextDouble() * 0.8) - 0.4;
        final newTemp = double.parse((n.temperature + tempJitter).toStringAsFixed(1));
        final newHum = double.parse((n.humidity + humJitter).toStringAsFixed(1));
        final isWarn = newHum > _maxSafeHumidity || newTemp > _maxSafeTemperature;

        final newTempHist = List<double>.from(n.recentTempHistory)..removeAt(0)..add(newTemp);
        final newHumHist = List<double>.from(n.recentHumidityHistory)..removeAt(0)..add(newHum);

        return n.copyWith(
          temperature: newTemp,
          humidity: newHum,
          isWarning: isWarn,
          warningReason: isWarn
              ? 'Telemetry breach: ${newHum > _maxSafeHumidity ? "Humidity ${newHum}% > ${_maxSafeHumidity}%" : "Temp ${newTemp}°C > ${_maxSafeTemperature}°C"}'
              : 'Environmental conditions within safe baseline.',
          lastTelemetryAt: DateTime.now(),
          recentTempHistory: newTempHist,
          recentHumidityHistory: newHumHist,
        );
      }).toList();
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ESP32 Mesh Telemetry updated. All sensor nodes responded.'),
        backgroundColor: ParishColors.oliveGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Frontend simulation of an emergency humidity breach alert
  void _simulateTelemetrySpike() {
    setState(() {
      final idx = _nodes.indexWhere((n) => n.nodeId == 'ESP32-NODE-01');
      if (idx != -1) {
        final node = _nodes[idx];
        final spikedHum = 72.4;
        _nodes[idx] = node.copyWith(
          humidity: spikedHum,
          isWarning: true,
          warningReason: 'SIMULATED BREACH: Relative humidity (72.4% RH) exceeded 60% threshold!',
          lastTelemetryAt: DateTime.now(),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated Alert: Humidity Spike triggered on ESP32-NODE-01 (72.4% RH).'),
        backgroundColor: ParishColors.mercyRed,
        duration: Duration(seconds: 3),
      ),
    );
  }

  List<SmartArchiveNodeData> get _filteredNodes {
    if (_nodeFilter == 'Alerts') {
      return _nodes.where((n) => n.isWarning).toList();
    } else if (_nodeFilter == 'Safe') {
      return _nodes.where((n) => !n.isWarning).toList();
    }
    return _nodes;
  }

  double get _avgTemperature {
    if (_nodes.isEmpty) return 0.0;
    return _nodes.fold(0.0, (sum, n) => sum + n.temperature) / _nodes.length;
  }

  double get _avgHumidity {
    if (_nodes.isEmpty) return 0.0;
    return _nodes.fold(0.0, (sum, n) => sum + n.humidity) / _nodes.length;
  }

  int get _warningCount => _nodes.where((n) => n.isWarning).length;
  int get _safeCount => _nodes.where((n) => !n.isWarning).length;

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final bool isMobile = constraints.maxWidth < 650;
        final double viewportHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;

        // Container explicitly claims full available height on desktop and anchors child to topCenter
        return Container(
          width: double.infinity,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          alignment: Alignment.topCenter,
          child: RefreshIndicator(
            onRefresh: _refreshTelemetry,
            color: ParishColors.marianBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: isMobile ? 12 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0.0, viewportHeight - (isMobile ? 24 : 40)),
                  minWidth: double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 1. Header & Live Telemetry Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart Archive & IoT Telemetry',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bolt, color: ParishColors.goldAccent, size: 20),
                              tooltip: 'Simulate Test Humidity Breach',
                              onPressed: _simulateTelemetrySpike,
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune, color: ParishColors.marianBlue, size: 20),
                              tooltip: 'Configure Safe Limits & Alert Rules',
                              onPressed: () => showConfigureThresholdsModal(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: ParishColors.marianBlue, size: 20),
                              tooltip: 'Poll Live ESP32 Nodes',
                              onPressed: _refreshTelemetry,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. Mesh Overview Banner (Active Network Status)
                    _buildMeshNetworkStatusBanner(isDesktop, isMobile),
                    const SizedBox(height: 14),

                    // 3. Compact Stats Row (Matching Assets, Appointments & Receipts)
                    _buildCompactStatsRow(),
                    const SizedBox(height: 14),

                    // 4. Quick Actions Toolbar
                    _buildActionButtons(isMobile),
                    const SizedBox(height: 14),

                    // 5. Zone Filter Chips Bar
                    Row(
                      children: [
                        Text(
                          'Monitored Storage Zones (${_filteredNodes.length})',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 6,
                          children: ['All Nodes', 'Safe', 'Alerts'].map((f) {
                            final isSelected = _nodeFilter == f;
                            Color activeColor = ParishColors.marianBlue;
                            if (f == 'Alerts') activeColor = ParishColors.mercyRed;
                            if (f == 'Safe') activeColor = ParishColors.oliveGreen;

                            return ChoiceChip(
                              label: Text(f),
                              selected: isSelected,
                              selectedColor: activeColor,
                              backgroundColor: cardWhite,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : textDark,
                              ),
                              onSelected: (_) => setState(() => _nodeFilter = f),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 6. Monitored Node Cards / Skeleton Loading
                    if (_isLoading)
                      _buildSkeletonLoading(constraints.maxWidth)
                    else if (_filteredNodes.isEmpty)
                      _buildEmptyState()
                    else
                      isDesktop
                          ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredNodes.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.85,
                        ),
                        itemBuilder: (context, index) {
                          final node = _filteredNodes[index];
                          return StorageNodeTile(
                            roomTitle: node.roomTitle,
                            nodeId: node.nodeId,
                            temperature: '${node.temperature.toStringAsFixed(1)} °C',
                            humidity: '${node.humidity.toStringAsFixed(1)} %',
                            isWarning: node.isWarning,
                            storageType: node.storageType,
                            signalDbm: node.signalDbm,
                            batteryPercent: node.batteryPercent,
                            lastTelemetry: node.lastTelemetryAt,
                          );
                        },
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredNodes.length,
                        itemBuilder: (context, index) {
                          final node = _filteredNodes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StorageNodeTile(
                              roomTitle: node.roomTitle,
                              nodeId: node.nodeId,
                              temperature: '${node.temperature.toStringAsFixed(1)} °C',
                              humidity: '${node.humidity.toStringAsFixed(1)} %',
                              isWarning: node.isWarning,
                              storageType: node.storageType,
                              signalDbm: node.signalDbm,
                              batteryPercent: node.batteryPercent,
                              lastTelemetry: node.lastTelemetryAt,
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),

                    // 7. Canonical Preservation Guidelines & Incident Log Footer
                    _buildPreservationProtocolSection(isDesktop),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// --- END OF PART 1 ---

// =============================================================================
// FILE: lib/features/smart_archive/presentation/smart_archive_view.dart (PART 2 OF 2)
// =============================================================================

  // ===========================================================================
  // Mesh Network Status Banner
  // ===========================================================================
  Widget _buildMeshNetworkStatusBanner(bool isDesktop, bool isMobile) {
    final bool hasActiveAlerts = _warningCount > 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: hasActiveAlerts ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveAlerts
              ? ParishColors.mercyRed.withOpacity(0.5)
              : ParishColors.marianBlue.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasActiveAlerts ? ParishColors.mercyRed : ParishColors.marianBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasActiveAlerts ? Icons.warning_amber_rounded : Icons.hub_outlined,
              color: Colors.white,
              size: isMobile ? 22 : 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasActiveAlerts
                          ? '$_warningCount Environmental Warning Active'
                          : 'ESP32 Telemetry Mesh Normal',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: hasActiveAlerts ? ParishColors.mercyRed : ParishColors.marianBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasActiveAlerts ? ParishColors.mercyRed : ParishColors.oliveGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasActiveAlerts ? 'ACTION REQ.' : 'ONLINE',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasActiveAlerts
                      ? 'Relative humidity exceeds 60% in Liturgical Storage. Inspect dehumidifier to prevent mold spores.'
                      : 'All 4 wireless sensor nodes streaming stable temperature and humidity baselines (Canon 1283 standards).',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: ParishColors.textDark,
                    height: 1.35,
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
  // Compact Stats Row
  // ===========================================================================
  Widget _buildCompactStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatItem(
              'Active Nodes',
              '${_nodes.length}',
              ParishColors.marianBlue,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Avg Temp',
              '${_avgTemperature.toStringAsFixed(1)}°C',
              ParishColors.goldAccent,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Avg Humidity',
              '${_avgHumidity.toStringAsFixed(1)}%',
              _avgHumidity > 60.0 ? ParishColors.mercyRed : ParishColors.oliveGreen,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Safe Zones',
              '$_safeCount',
              ParishColors.oliveGreen,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Alerts',
              '$_warningCount',
              _warningCount > 0 ? ParishColors.mercyRed : ParishColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ===========================================================================
  // Quick Action Buttons
  // ===========================================================================
  Widget _buildActionButtons(bool isMobile) {
    return isMobile
        ? Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showConfigureThresholdsModal(context),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text(
              'Configure Environmental Thresholds',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
              foregroundColor: ParishColors.goldAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _refreshTelemetry,
            icon: const Icon(Icons.sensors, size: 18),
            label: const Text(
              'Poll All Sensor Nodes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    )
        : Row(
      children: [
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showConfigureThresholdsModal(context),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text(
                'Configure Environmental Thresholds',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                foregroundColor: ParishColors.goldAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _refreshTelemetry,
              icon: const Icon(Icons.sensors, size: 18),
              label: const Text(
                'Poll All Sensor Nodes',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Anti-Layout-Shift Skeleton Loader
  // ===========================================================================
  Widget _buildSkeletonLoading(double availableWidth) {
    return AnimatedBuilder(
      animation: _skeletonOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _skeletonOpacityAnimation.value,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: availableWidth > 750 ? 2 : 1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.85,
            children: List.generate(4, (index) {
              return Container(
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParishColors.borderGrey.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(height: 16, width: 180, decoration: BoxDecoration(color: ParishColors.borderGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(4))),
                        Container(height: 16, width: 60, decoration: BoxDecoration(color: ParishColors.borderGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 12, width: 120, decoration: BoxDecoration(color: ParishColors.borderGrey.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Container(height: 36, width: 100, decoration: BoxDecoration(color: ParishColors.borderGrey.withOpacity(0.2), borderRadius: BorderRadius.circular(6))),
                        Container(height: 36, width: 100, decoration: BoxDecoration(color: ParishColors.borderGrey.withOpacity(0.2), borderRadius: BorderRadius.circular(6))),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Canonical Preservation Guidelines & Incident Log Footer
  // ===========================================================================
  Widget _buildPreservationProtocolSection(bool isDesktop) {
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: ParishColors.marianBlue),
              const SizedBox(width: 8),
              Text(
                'Preventive Conservation Protocol (Canon 1283 & ISO 11799)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(
            '• Relative Humidity: Maintain within 45% - 60% RH to prevent fungal mold growth and paper embrittlement.\n'
                '• Temperature Baseline: Target 18°C - 24°C ambient range to avoid thermal hydrolysis of legacy ink.\n'
                '• Automatic Push Alerts: Broadcast to Parish Secretariat & Clergy whenever a node logs >60% RH for 3 consecutive intervals.',
            style: TextStyle(fontSize: 12, color: textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(Icons.sensors_off_outlined, size: 40, color: ParishColors.textMuted),
          const SizedBox(height: 10),
          Text(
            'No storage nodes matching "$_nodeFilter".',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text('Tap "All Nodes" above to review all registered ESP32 monitoring devices.', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        ],
      ),
    );
  }
}