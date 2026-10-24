// =============================================================================
// FILE: lib/features/smart_archive/presentation/smart_archive_view.dart
// =============================================================================

import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/configure_thresholds_dialog.dart';
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

  factory SmartArchiveNodeData.fromFirebase(Map<String, dynamic> map, String fallbackId) {
    final double temp = double.tryParse(map['temperature']?.toString() ?? '24.0') ?? 24.0;
    final double hum = double.tryParse(map['humidity']?.toString() ?? '50.0') ?? 50.0;
    final bool isWarn = map['is_warning'] == true || hum > 60.0 || temp > 26.0;

    return SmartArchiveNodeData(
      nodeId: map['node_id']?.toString() ?? fallbackId,
      roomTitle: map['room_title']?.toString() ?? 'Monitored Archive Storage',
      storageType: map['storage_type']?.toString() ?? 'Sacramental Archive Repository',
      locationDescription: map['location_description']?.toString() ?? 'Parish Archive Vault',
      temperature: temp,
      humidity: hum,
      signalDbm: int.tryParse(map['rssi']?.toString() ?? '-60') ?? -60,
      batteryPercent: int.tryParse(map['battery']?.toString() ?? '95') ?? 95,
      isWarning: isWarn,
      warningReason: isWarn
          ? 'Environmental breach detected: Temperature or humidity exceeds safe thresholds.'
          : 'Preservation parameters optimal.',
      lastTelemetryAt: DateTime.now(),
      recentTempHistory: [temp],
      recentHumidityHistory: [hum],
    );
  }
}

class SmartArchiveView extends StatefulWidget {
  const SmartArchiveView({super.key});

  @override
  State<SmartArchiveView> createState() => _SmartArchiveViewState();
}

class _SmartArchiveViewState extends State<SmartArchiveView> {
  String _nodeFilter = 'All Nodes'; // 'All Nodes', 'Safe', 'Alerts'
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref('storage_nodes');

  List<SmartArchiveNodeData> _filterNodes(List<SmartArchiveNodeData> nodes) {
    if (_nodeFilter == 'Alerts') {
      return nodes.where((n) => n.isWarning).toList();
    } else if (_nodeFilter == 'Safe') {
      return nodes.where((n) => !n.isWarning).toList();
    }
    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;

    return StreamBuilder<DatabaseEvent>(
      stream: _rtdbRef.onValue,
      builder: (context, snapshot) {
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

        // Parse nodes from Firebase Realtime Database
        List<SmartArchiveNodeData> allNodes = [];
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final raw = snapshot.data!.snapshot.value;
          if (raw is Map) {
            raw.forEach((key, val) {
              if (val is Map) {
                allNodes.add(
                  SmartArchiveNodeData.fromFirebase(
                    Map<String, dynamic>.from(val),
                    key.toString(),
                  ),
                );
              }
            });
          }
        }

        // Fallback placeholder node if no hardware has posted yet
        if (allNodes.isEmpty && !isLoading) {
          allNodes = [
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
              warningReason: 'Awaiting first live transmission from hardware...',
              lastTelemetryAt: DateTime.now(),
              recentTempHistory: [24.2],
              recentHumidityHistory: [54.0],
            ),
          ];
        }

        final filteredNodes = _filterNodes(allNodes);
        final warningCount = allNodes.where((n) => n.isWarning).length;
        final safeCount = allNodes.where((n) => !n.isWarning).length;
        final avgTemp = allNodes.isEmpty
            ? 0.0
            : allNodes.fold(0.0, (s, n) => s + n.temperature) / allNodes.length;
        final avgHum = allNodes.isEmpty
            ? 0.0
            : allNodes.fold(0.0, (s, n) => s + n.humidity) / allNodes.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 900;
            final bool isMobile = constraints.maxWidth < 650;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: isMobile ? 12 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header & Live Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Smart Archive & IoT Telemetry',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ParishColors.oliveGreenSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.circle, color: ParishColors.oliveGreen, size: 8),
                                SizedBox(width: 5),
                                Text(
                                  'LIVE STREAMING',
                                  style: TextStyle(
                                    color: ParishColors.oliveGreen,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.tune, color: ParishColors.marianBlue, size: 20),
                            tooltip: 'Configure Safe Limits',
                            onPressed: () => showConfigureThresholdsModal(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Status Banner
                  _buildStatusBanner(warningCount, isMobile),
                  const SizedBox(height: 14),

                  // 3. Compact Stats Row
                  _buildCompactStatsRow(allNodes.length, avgTemp, avgHum, safeCount, warningCount),
                  const SizedBox(height: 14),

                  // 4. Filter Chips Bar
                  Row(
                    children: [
                      Text(
                        'Storage Nodes (${filteredNodes.length})',
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

                  // 5. Monitored Node Tiles Grid
                  if (isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (filteredNodes.isEmpty)
                    _buildEmptyState()
                  else
                    isDesktop
                        ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredNodes.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.85,
                      ),
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
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
                      itemCount: filteredNodes.length,
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
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

                  // 6. Conservation Guidelines Card
                  _buildConservationProtocol(isDesktop),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBanner(int warningCount, bool isMobile) {
    final bool hasAlerts = warningCount > 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: hasAlerts ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAlerts ? ParishColors.mercyRed.withOpacity(0.5) : ParishColors.marianBlue.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasAlerts ? ParishColors.mercyRed : ParishColors.marianBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasAlerts ? Icons.warning_amber_rounded : Icons.sensors,
              color: Colors.white,
              size: isMobile ? 22 : 26,
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
                      hasAlerts ? '$warningCount Environmental Warning Active' : 'ESP32 IoT Network Normal',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: hasAlerts ? ParishColors.mercyRed : ParishColors.marianBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasAlerts ? ParishColors.mercyRed : ParishColors.oliveGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasAlerts ? 'BREACH' : 'ONLINE',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasAlerts
                      ? 'Relative humidity exceeds 60% in monitored area. Inspect dehumidifiers.'
                      : 'Live DHT11 telemetry streamed from ESP32 via Firebase RTDB (Canon 1283 standards).',
                  style: TextStyle(fontSize: isMobile ? 11 : 12, color: ParishColors.textDark, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatsRow(int count, double avgTemp, double avgHum, int safe, int alerts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          Expanded(child: _statItem('Nodes', '$count', ParishColors.marianBlue)),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(child: _statItem('Avg Temp', '${avgTemp.toStringAsFixed(1)}°C', ParishColors.goldAccent)),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(child: _statItem('Avg Hum', '${avgHum.toStringAsFixed(1)}%', avgHum > 60.0 ? ParishColors.mercyRed : ParishColors.oliveGreen)),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(child: _statItem('Safe', '$safe', ParishColors.oliveGreen)),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(child: _statItem('Alerts', '$alerts', alerts > 0 ? ParishColors.mercyRed : ParishColors.textMuted)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color), maxLines: 1),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ParishColors.textMuted), maxLines: 1),
      ],
    );
  }

  Widget _buildConservationProtocol(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: ParishColors.marianBlue),
              SizedBox(width: 8),
              Text(
                'Preventive Conservation Standards (Canon 1283 & ISO 11799)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(
            '• Relative Humidity: Target 45%–60% RH to prevent fungal mold germination and leather embrittlement.\n'
                '• Temperature Baseline: Target 18°C–24°C ambient range to avoid thermal hydrolysis of legacy ink.\n'
                '• Push Alerts: Dispatched via Supabase Edge Function to Clergy & Secretariat on 60%+ RH breach.',
            style: TextStyle(fontSize: 12, color: ParishColors.textMuted, height: 1.45),
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
          Text('No sensor nodes match "$_nodeFilter".', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}