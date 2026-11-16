// =============================================================================
// FILE: lib/features/smart_archive/presentation/smart_archive_view.dart
// =============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/sensor_detail_dialog.dart';
import 'telemetry_history_logs_view.dart';
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
  final bool isWarning;
  final String warningReason;
  final DateTime lastTelemetryAt;

  const SmartArchiveNodeData({
    required this.nodeId,
    required this.roomTitle,
    required this.storageType,
    required this.locationDescription,
    required this.temperature,
    required this.humidity,
    this.idealTempMin = 22.0,
    this.idealTempMax = 32.0, // Santa Cruz, Laguna tropical baseline
    this.idealHumidityMin = 50.0,
    this.idealHumidityMax = 75.0, // Calibrated for Laguna ambient humidity (83.9% avg)
    required this.isWarning,
    required this.warningReason,
    required this.lastTelemetryAt,
  });

  /// Flags as OFFLINE if no telemetry received in 5 minutes
  bool get isOffline {
    final diffMinutes = DateTime.now().difference(lastTelemetryAt).inMinutes.abs();
    return diffMinutes >= 5;
  }

  factory SmartArchiveNodeData.fromFirebase(Map<String, dynamic> map, String fallbackId) {
    final rawTemp = map['temperature'] ?? map['temp'];
    final rawHum = map['humidity'] ?? map['hum'];
    final double temp = double.tryParse(rawTemp?.toString() ?? '28.0') ?? 28.0;
    final double hum = double.tryParse(rawHum?.toString() ?? '68.0') ?? 68.0;

    // Santa Cruz, Laguna Tropical Preservation Baseline
    const double maxHum = 75.0; // Real breach limit for Laguna
    const double maxTemp = 32.0; // Real breach limit for Laguna

    final bool isWarn = hum > maxHum || temp > maxTemp;

    final rawTimestamp = map['timestamp'] ??
        map['last_telemetry_at'] ??
        map['last_updated'] ??
        map['time'];

    DateTime telemetryTime = DateTime.now();

    if (rawTimestamp != null) {
      if (rawTimestamp is int) {
        if (rawTimestamp < 10000000000) {
          telemetryTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000, isUtc: true).toLocal();
        } else {
          telemetryTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp, isUtc: true).toLocal();
        }
      } else if (rawTimestamp is num) {
        final val = rawTimestamp.toInt();
        if (val < 10000000000) {
          telemetryTime = DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true).toLocal();
        } else {
          telemetryTime = DateTime.fromMillisecondsSinceEpoch(val, isUtc: true).toLocal();
        }
      } else if (rawTimestamp is String) {
        final parsed = DateTime.tryParse(rawTimestamp);
        if (parsed != null) {
          telemetryTime = parsed.isUtc ? parsed.toLocal() : parsed;
        }
      }

      if (telemetryTime.year < 2024) {
        telemetryTime = DateTime.now();
      }
    }

    return SmartArchiveNodeData(
      nodeId: map['node_id']?.toString() ?? map['nodeId']?.toString() ?? fallbackId,
      roomTitle: map['room_title']?.toString() ?? map['roomTitle']?.toString() ?? 'Sacramental Archive Room',
      storageType: map['storage_type']?.toString() ?? map['storageType']?.toString() ?? 'Sacramental Archive Repository',
      locationDescription: map['location_description']?.toString() ?? map['location']?.toString() ?? 'Parish Archive Vault',
      temperature: temp,
      humidity: hum,
      idealHumidityMax: maxHum,
      idealTempMax: maxTemp,
      isWarning: isWarn,
      warningReason: isWarn
          ? 'Tropical moisture breach: Humidity ($hum%) or temperature ($temp°C) exceeds safe limits (Max: $maxHum% RH, $maxTemp°C).'
          : 'Preservation parameters optimal for Laguna tropical climate.',
      lastTelemetryAt: telemetryTime,
    );
  }
}

class _TelemetryReadingPoint {
  final double temperature;
  final double humidity;
  final DateTime recordedAt;

  const _TelemetryReadingPoint({
    required this.temperature,
    required this.humidity,
    required this.recordedAt,
  });
}

class _WarningLogEntry {
  final String telemetryId;
  final String nodeId;
  final double temperature;
  final double humidity;
  final String alertType;
  final DateTime recordedAt;

  const _WarningLogEntry({
    required this.telemetryId,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.alertType,
    required this.recordedAt,
  });

  factory _WarningLogEntry.fromMap(Map<String, dynamic> map) {
    final rawAlert = map['alert_type']?.toString().trim();
    final parsedTemp = double.tryParse(map['temperature']?.toString() ?? '') ?? 0.0;
    final parsedHum = double.tryParse(map['humidity']?.toString() ?? '') ?? 0.0;
    final parsedTime = DateTime.tryParse(map['recorded_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();

    String formattedAlert = 'Microclimate Threshold Breach';
    if (rawAlert != null && rawAlert.isNotEmpty) {
      formattedAlert = rawAlert
          .replaceAll('_', ' ')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }

    return _WarningLogEntry(
      telemetryId: map['telemetry_id']?.toString() ?? '',
      nodeId: map['node_id']?.toString() ?? 'ESP32-NODE-01',
      temperature: parsedTemp,
      humidity: parsedHum,
      alertType: formattedAlert,
      recordedAt: parsedTime,
    );
  }
}

class SmartArchiveView extends StatefulWidget {
  const SmartArchiveView({super.key});

  @override
  State<SmartArchiveView> createState() => _SmartArchiveViewState();
}

class _SmartArchiveViewState extends State<SmartArchiveView> {
  // Explicit Singapore regional RTDB endpoint matching your ESP32 configuration
  static const String _kFirebaseRtdbUrl =
      "https://parishserve-default-rtdb.asia-southeast1.firebasedatabase.app";

  late DatabaseReference _rtdbRef;
  StreamSubscription<DatabaseEvent>? _rtdbSubscription;

  SmartArchiveNodeData? _liveNode;
  Object? _streamError;
  bool _isWaitingFirstStream = true;

  List<_TelemetryReadingPoint> _historicalLogs = [];
  final List<_TelemetryReadingPoint> _liveBuffer = [];

  List<_WarningLogEntry> _recentWarningLogs = [];
  bool _isLoadingWarnings = true;
  String? _warningsError;

  @override
  void initState() {
    super.initState();
    _initializeRealtimeDatabase();
    _fetchHistoricalLogs();
    _fetchWarningLogs();
    _runDiagnosticCheck();
  }

  @override
  void dispose() {
    _rtdbSubscription?.cancel();
    super.dispose();
  }

  void _initializeRealtimeDatabase() {
    _rtdbSubscription?.cancel();
    _streamError = null;

    try {
      debugPrint('[SmartArchiveView] Connecting explicitly to regional RTDB: $_kFirebaseRtdbUrl');

      final rtdb = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _kFirebaseRtdbUrl,
      );

      _rtdbRef = rtdb.ref('storage_nodes');
    } catch (e) {
      debugPrint('[SmartArchiveView] Error obtaining DatabaseReference: $e');
      _rtdbRef = FirebaseDatabase.instance.ref('storage_nodes');
    }

    _rtdbSubscription = _rtdbRef.onValue.listen(
          (event) {
        SmartArchiveNodeData? parsedNode;
        final raw = event.snapshot.value;

        if (raw is Map) {
          raw.forEach((key, val) {
            if (val is Map && parsedNode == null) {
              parsedNode = SmartArchiveNodeData.fromFirebase(
                Map<String, dynamic>.from(val),
                key.toString(),
              );
            }
          });
        }

        if (!mounted) return;
        setState(() {
          _isWaitingFirstStream = false;
          _streamError = null;
          _liveNode = parsedNode;

          if (parsedNode != null) {
            final point = _TelemetryReadingPoint(
              temperature: parsedNode!.temperature,
              humidity: parsedNode!.humidity,
              recordedAt: parsedNode!.lastTelemetryAt,
            );

            final shouldAppend = _liveBuffer.isEmpty ||
                _liveBuffer.last.temperature != point.temperature ||
                _liveBuffer.last.humidity != point.humidity ||
                point.recordedAt.difference(_liveBuffer.last.recordedAt).inSeconds.abs() >= 5;

            if (shouldAppend) {
              _liveBuffer.add(point);
              if (_liveBuffer.length > 15) {
                _liveBuffer.removeAt(0);
              }
            }
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isWaitingFirstStream = false;
          _streamError = error;
        });
      },
    );
  }

  Future<void> _runDiagnosticCheck() async {
    try {
      final snapshot = await _rtdbRef.get().timeout(const Duration(seconds: 6));
      debugPrint('[RTDB Diagnostic] SUCCESS! Data received on mobile: ${snapshot.value}');
    } catch (e) {
      debugPrint('[RTDB Diagnostic] CONNECTION NOTICE OR TIMEOUT: $e');
    }
  }

  Future<void> _fetchHistoricalLogs() async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      var data = await Supabase.instance.client
          .from('sensor_telemetry_logs')
          .select('temperature, humidity, recorded_at')
          .gte('recorded_at', twentyFourHoursAgo)
          .order('recorded_at', ascending: false)
          .limit(30);

      // Fallback to latest 20 records overall if fewer than 2 points exist in the last 24h
      if ((data as List).length < 2) {
        data = await Supabase.instance.client
            .from('sensor_telemetry_logs')
            .select('temperature, humidity, recorded_at')
            .order('recorded_at', ascending: false)
            .limit(20);
      }

      debugPrint('[SmartArchiveView] Historical chart logs fetched: ${(data as List).length}');

      final parsed = (data as List).reversed.map((row) {
        final map = row as Map<String, dynamic>;
        return _TelemetryReadingPoint(
          temperature: double.tryParse(map['temperature']?.toString() ?? '') ?? 28.0,
          humidity: double.tryParse(map['humidity']?.toString() ?? '') ?? 65.0,
          recordedAt: DateTime.tryParse(map['recorded_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _historicalLogs = parsed;
        });
      }
    } catch (e) {
      debugPrint('[SmartArchiveView] Error loading chart logs: $e');
    }
  }

  Future<void> _fetchWarningLogs() async {
    if (mounted) {
      setState(() {
        _isLoadingWarnings = true;
        _warningsError = null;
      });
    }

    try {
      final data = await Supabase.instance.client
          .from('sensor_telemetry_logs')
          .select('telemetry_id, node_id, temperature, humidity, is_warning, alert_type, recorded_at')
          .eq('is_warning', true)
          .order('recorded_at', ascending: false)
          .limit(5);

      debugPrint('[SmartArchiveView] Recent warning logs fetched: ${(data as List).length}');

      final parsed = (data as List)
          .map((row) => _WarningLogEntry.fromMap(row as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _recentWarningLogs = parsed;
          _isLoadingWarnings = false;
        });
      }
    } catch (e) {
      debugPrint('[SmartArchiveView] Error loading warning logs: $e');
      if (mounted) {
        setState(() {
          _warningsError = e.toString();
          _isLoadingWarnings = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _initializeRealtimeDatabase());
    await Future.wait([
      _fetchHistoricalLogs(),
      _fetchWarningLogs(),
    ]);
  }

  void _openAllHistoryLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TelemetryHistoryLogsView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: ParishColors.mercyRed),
              const SizedBox(height: 12),
              Text(
                'IoT Telemetry Connection Notice',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ParishColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                '$_streamError',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    final SmartArchiveNodeData activeNode = _liveNode ??
        SmartArchiveNodeData(
          nodeId: 'ESP32-NODE-01',
          roomTitle: 'Sacramental Archive Room',
          storageType: 'Canon 535 Sacramental Ledger Repository',
          locationDescription: 'Parish Administration Building, 2nd Floor Archive Vault',
          temperature: 28.2,
          humidity: 64.0,
          isWarning: false,
          warningReason: 'Awaiting first live transmission from hardware...',
          lastTelemetryAt: DateTime.now(),
        );

    final bool isOffline = activeNode.isOffline;
    final bool isWarning = activeNode.isWarning;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isDesktop = screenWidth >= 1080;
        final bool isMobile = screenWidth < 650;

        return RefreshIndicator(
          onRefresh: _refreshAll,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 28,
              isMobile ? 14 : 24,
              isMobile ? 16 : 28,
              isMobile ? 110 : 36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Header with SJP Background & Real-Time Sync Ribbon
                    _buildHeroHeader(isMobile, isWarning, isOffline),
                    const SizedBox(height: 22),

                    // 2. Cohesive Main Workspace
                    if (_isWaitingFirstStream)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(60),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Primary): Live Node Status + Microclimate Trends Plot
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Monitored Archive Vault Telemetry'),
                                const SizedBox(height: 12),
                                StorageNodeTile(
                                  roomTitle: activeNode.roomTitle,
                                  nodeId: activeNode.nodeId,
                                  temperature: '${activeNode.temperature.toStringAsFixed(1)} °C',
                                  humidity: '${activeNode.humidity.toStringAsFixed(1)} %',
                                  isWarning: isWarning,
                                  isOffline: isOffline,
                                  storageType: activeNode.storageType,
                                  lastTelemetry: activeNode.lastTelemetryAt,
                                ),
                                const SizedBox(height: 16),
                                _buildTelemetryLineGraphCard(activeNode),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Right Column (Secondary): Recent Telemetry Warning Logs
                          Expanded(
                            flex: 5,
                            child: _buildWarningLogsSection(isMobile),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Monitored Archive Vault Telemetry'),
                          const SizedBox(height: 12),
                          StorageNodeTile(
                            roomTitle: activeNode.roomTitle,
                            nodeId: activeNode.nodeId,
                            temperature: '${activeNode.temperature.toStringAsFixed(1)} °C',
                            humidity: '${activeNode.humidity.toStringAsFixed(1)} %',
                            isWarning: isWarning,
                            isOffline: isOffline,
                            storageType: activeNode.storageType,
                            lastTelemetry: activeNode.lastTelemetryAt,
                          ),
                          const SizedBox(height: 14),
                          _buildTelemetryLineGraphCard(activeNode),
                          const SizedBox(height: 24),
                          _buildWarningLogsSection(isMobile),
                        ],
                      ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Hero Header with SJP Background & Embedded Live Telemetry Ribbon
  // ===========================================================================

  Widget _buildHeroHeader(bool isMobile, bool isWarning, bool isOffline) {
    final fade = ParishColors.cardWhite;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/jp2-bg.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, -0.55),
              errorBuilder: (_, __, ___) => Container(color: ParishColors.marianBlueSurface),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    fade.withOpacity(0.96),
                    fade.withOpacity(isMobile ? 0.88 : 0.80),
                    fade.withOpacity(isMobile ? 0.25 : 0.0),
                  ],
                  stops: [0.0, isMobile ? 0.62 : 0.45, isMobile ? 1.0 : 0.85],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, fade.withOpacity(0.55)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 22, isMobile ? 12 : 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 3,
                            decoration: BoxDecoration(
                              color: ParishColors.goldAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Smart Archive & IoT',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: const ['Times New Roman', 'serif'],
                              fontSize: isMobile ? 26 : 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: ParishColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Preserving sacramental ledgers under Santa Cruz, Laguna microclimate standards',
                            style: TextStyle(
                              fontSize: isMobile ? 12.5 : 14,
                              fontStyle: FontStyle.italic,
                              color: ParishColors.textDark.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: ParishColors.cardWhite.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: ParishColors.borderGrey),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: ParishColors.marianBlue, size: 21),
                        tooltip: 'Reload Telemetry Feed',
                        onPressed: () async {
                          await _refreshAll();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Telemetry feed and warning logs reloaded.'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 38 : 50),
                _buildTelemetrySyncRibbon(isMobile, isWarning, isOffline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetrySyncRibbon(bool isMobile, bool isWarning, bool isOffline) {
    Color pillColor;
    Color textColor;
    IconData statusIcon;
    String statusLabel;

    if (isOffline) {
      pillColor = Colors.amber.shade50;
      textColor = Colors.amber.shade900;
      statusIcon = Icons.wifi_off_rounded;
      statusLabel = 'Hardware Offline • ESP32 disconnected or power interrupted';
    } else if (isWarning) {
      pillColor = ParishColors.mercyRedSurface;
      textColor = ParishColors.mercyRed;
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = 'Tropical Moisture Alert • Relative humidity exceeds 75% threshold';
    } else {
      pillColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_outline;
      statusLabel = 'Online • Live DHT11 stream (Santa Cruz, Laguna Tropical Baseline)';
    }

    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                'ESP32 Node Active',
                style: TextStyle(fontSize: 11.5, color: textColor.withOpacity(0.85)),
              ),
            ),
          const SizedBox(width: 10),
          Icon(Icons.sensors, size: 17, color: textColor),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: ParishColors.goldAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['Times New Roman', 'serif'],
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: ParishColors.textDark,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ===========================================================================
  // Live Microclimate Line Graph (Interactive Hover + Tight Auto-Scaled Range)
  // ===========================================================================

  Widget _buildTelemetryLineGraphCard(SmartArchiveNodeData node) {
    final List<_TelemetryReadingPoint> combined = [..._historicalLogs];

    for (final livePoint in _liveBuffer) {
      if (combined.isEmpty ||
          livePoint.recordedAt.isAfter(combined.last.recordedAt) ||
          livePoint.humidity != combined.last.humidity ||
          livePoint.temperature != combined.last.temperature) {
        combined.add(livePoint);
      }
    }

    if (combined.isEmpty) {
      combined.add(
        _TelemetryReadingPoint(
          temperature: node.temperature,
          humidity: node.humidity,
          recordedAt: node.lastTelemetryAt,
        ),
      );
    }

    // Keep latest 35 points so fluctuations remain spacious and crisp
    final List<_TelemetryReadingPoint> window =
    combined.length > 35 ? combined.sublist(combined.length - 35) : combined;

    final List<double> humPoints = window.map((e) => e.humidity).toList();
    final List<double> tempPoints = window.map((e) => e.temperature).toList();

    final _AxisRange humRange = _computeTightRange(humPoints, minSpan: 6.0);
    final _AxisRange tempRange = _computeTightRange(tempPoints, minSpan: 2.5);

    final double minHumObs = humPoints.reduce(math.min);
    final double maxHumObs = humPoints.reduce(math.max);
    final double minTempObs = tempPoints.reduce(math.min);
    final double maxTempObs = tempPoints.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Microclimate Trends Plot',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hover or tap points to inspect readings (${window.length} points)',
                      style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildLegendItem('Humidity', ParishColors.marianBlue),
                  _buildLegendItem('Temp', ParishColors.goldAccent),
                  _buildLimitLegendItem('75% Limit'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Observed Min-Max Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildRangeBadge(
                label: 'RH Range: ${minHumObs.toStringAsFixed(1)}% – ${maxHumObs.toStringAsFixed(1)}%',
                color: ParishColors.marianBlue,
                bgColor: ParishColors.marianBlueSurface,
              ),
              _buildRangeBadge(
                label: 'Temp Range: ${minTempObs.toStringAsFixed(1)}°C – ${maxTempObs.toStringAsFixed(1)}°C',
                color: ParishColors.goldAccent,
                bgColor: ParishColors.goldAccent.withOpacity(0.12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Chart Area with Left (Humidity) & Right (Temperature) Dynamic Axis Labels
          SizedBox(
            height: 185,
            child: Row(
              children: [
                // Left Y-Axis: Humidity %
                SizedBox(
                  width: 38,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${humRange.max.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ParishColors.marianBlue),
                      ),
                      Text(
                        '${((humRange.max + humRange.min) / 2).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 9, color: ParishColors.marianBlue.withOpacity(0.7)),
                      ),
                      Text(
                        '${humRange.min.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ParishColors.marianBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Interactive Plot Canvas
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _InteractiveTelemetryChart(
                      points: window,
                      humRange: humRange,
                      tempRange: tempRange,
                      maxHumThreshold: node.idealHumidityMax,
                      formatTimestamp: _formatFullTimestamp,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Right Y-Axis: Temperature °C
                SizedBox(
                  width: 38,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tempRange.max.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ParishColors.goldAccent),
                      ),
                      Text(
                        '${((tempRange.max + tempRange.min) / 2).toStringAsFixed(1)}°',
                        style: TextStyle(fontSize: 9, color: ParishColors.goldAccent.withOpacity(0.75)),
                      ),
                      Text(
                        '${tempRange.min.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ParishColors.goldAccent),
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

  Widget _buildRangeBadge({required String label, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.textDark),
        ),
      ],
    );
  }

  Widget _buildLimitLegendItem(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 2,
          color: ParishColors.mercyRed.withOpacity(0.75),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
        ),
      ],
    );
  }

  // ===========================================================================
  // History Logs Section (5 Most Recent Warning Logs + Corner View All Button)
  // ===========================================================================

  Widget _buildWarningLogsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Recent Warning Logs',
          trailing: TextButton.icon(
            onPressed: _openAllHistoryLogs,
            style: TextButton.styleFrom(
              foregroundColor: ParishColors.marianBlue,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.history, size: 17),
            label: const Text(
              'View All Logs',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ParishColors.borderGrey),
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
              Text(
                '5 most recent warning alerts from archive sensors',
                style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
              ),
              const SizedBox(height: 12),
              if (_isLoadingWarnings)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_warningsError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: ParishColors.mercyRedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.mercyRed.withOpacity(0.35)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Unable to load warning logs',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _warningsError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                )
              else if (_recentWarningLogs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: ParishColors.oliveGreenSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.verified_outlined, color: ParishColors.oliveGreen, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'No recent warning logs recorded',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'All archive vault thresholds are currently clear. You can still inspect all routine telemetry logs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentWarningLogs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _buildWarningLogTile(_recentWarningLogs[index]);
                    },
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningLogTile(_WarningLogEntry log) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showSensorDetailModal(
        context,
        roomTitle: 'Sacramental Archive Room',
        nodeId: log.nodeId,
        temperature: '${log.temperature.toStringAsFixed(1)} °C',
        humidity: '${log.humidity.toStringAsFixed(1)} %',
        isWarning: true,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ParishColors.mercyRedSurface.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParishColors.mercyRed.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRed.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.alertType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: ParishColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${log.nodeId} • ${_formatFullTimestamp(log.recordedAt)}',
                    style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ParishColors.mercyRed,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${log.humidity.toStringAsFixed(1)}% RH',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.temperature.toStringAsFixed(1)} °C',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

  // ===========================================================================
  // Range & Date Formatting Helpers
  // ===========================================================================

  _AxisRange _computeTightRange(List<double> values, {required double minSpan}) {
    if (values.isEmpty) {
      return _AxisRange(0, minSpan);
    }

    final double rawMin = values.reduce(math.min);
    final double rawMax = values.reduce(math.max);
    final double rawSpan = rawMax - rawMin;

    if (rawSpan < minSpan) {
      final double center = (rawMin + rawMax) / 2;
      return _AxisRange(center - (minSpan / 2), center + (minSpan / 2));
    }

    final double padding = rawSpan * 0.18;
    return _AxisRange(rawMin - padding, rawMax + padding);
  }

  String _formatShortTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  String _formatFullTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];
    return '$month ${dt.day}, ${dt.year} • ${_formatShortTime(dt)}';
  }
}

class _AxisRange {
  final double min;
  final double max;

  const _AxisRange(this.min, this.max);
}

// =============================================================================
// Interactive Hover/Tap Wrapper for Telemetry Line Chart
// =============================================================================

class _InteractiveTelemetryChart extends StatefulWidget {
  final List<_TelemetryReadingPoint> points;
  final _AxisRange humRange;
  final _AxisRange tempRange;
  final double maxHumThreshold;
  final String Function(DateTime) formatTimestamp;

  const _InteractiveTelemetryChart({
    required this.points,
    required this.humRange,
    required this.tempRange,
    required this.maxHumThreshold,
    required this.formatTimestamp,
  });

  @override
  State<_InteractiveTelemetryChart> createState() => _InteractiveTelemetryChartState();
}

class _InteractiveTelemetryChartState extends State<_InteractiveTelemetryChart> {
  int? _hoveredIndex;

  void _updateIndexFromDx(double dx, double width) {
    if (widget.points.isEmpty || width <= 0) return;
    final int idx;
    if (widget.points.length == 1) {
      idx = 0;
    } else {
      final ratio = (dx / width).clamp(0.0, 1.0);
      idx = (ratio * (widget.points.length - 1)).round().clamp(0, widget.points.length - 1);
    }
    if (_hoveredIndex != idx) {
      setState(() => _hoveredIndex = idx);
    }
  }

  void _clearHover() {
    if (_hoveredIndex != null) {
      setState(() => _hoveredIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<double> humPoints = widget.points.map((e) => e.humidity).toList();
    final List<double> tempPoints = widget.points.map((e) => e.temperature).toList();

    final int? safeIndex = (_hoveredIndex != null && _hoveredIndex! < widget.points.length)
        ? _hoveredIndex
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double tooltipWidth = 172;

        double tooltipLeft = 0;
        if (safeIndex != null) {
          final double pointX = widget.points.length == 1
              ? width / 2
              : (safeIndex / (widget.points.length - 1)) * width;
          tooltipLeft = (pointX - (tooltipWidth / 2)).clamp(4.0, math.max(4.0, width - tooltipWidth - 4.0));
        }

        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (event) => _updateIndexFromDx(event.localPosition.dx, width),
          onExit: (_) => _clearHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _updateIndexFromDx(details.localPosition.dx, width),
            onPanUpdate: (details) => _updateIndexFromDx(details.localPosition.dx, width),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MicroclimateLineChartPainter(
                      humidityPoints: humPoints,
                      temperaturePoints: tempPoints,
                      humRange: widget.humRange,
                      tempRange: widget.tempRange,
                      maxHumThreshold: widget.maxHumThreshold,
                      hoveredIndex: safeIndex,
                    ),
                  ),
                ),
                if (safeIndex != null)
                  Positioned(
                    top: 4,
                    left: tooltipLeft,
                    width: tooltipWidth,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: ParishColors.textDark.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.formatTimestamp(widget.points[safeIndex].recordedAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF64B5F6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.points[safeIndex].humidity.toStringAsFixed(1)}% RH',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: ParishColors.goldAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.points[safeIndex].temperature.toStringAsFixed(1)} °C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Custom Painter for Microclimate Curves (Auto-Scaled Tight Range + Hover)
// =============================================================================

class _MicroclimateLineChartPainter extends CustomPainter {
  final List<double> humidityPoints;
  final List<double> temperaturePoints;
  final _AxisRange humRange;
  final _AxisRange tempRange;
  final double maxHumThreshold;
  final int? hoveredIndex;

  _MicroclimateLineChartPainter({
    required this.humidityPoints,
    required this.temperaturePoints,
    required this.humRange,
    required this.tempRange,
    required this.maxHumThreshold,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = ParishColors.borderGrey.withOpacity(0.55)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw 75% RH limit dashed line if it falls within the zoomed humidity window
    if (maxHumThreshold >= humRange.min && maxHumThreshold <= humRange.max) {
      final thresholdY = _getY(maxHumThreshold, humRange.min, humRange.max, size.height);
      final thresholdPaint = Paint()
        ..color = ParishColors.mercyRed.withOpacity(0.75)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;

      const double dashWidth = 6;
      const double dashSpace = 4;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, thresholdY),
          Offset(math.min(startX + dashWidth, size.width), thresholdY),
          thresholdPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // Vertical hover crosshair
    if (hoveredIndex != null && humidityPoints.isNotEmpty) {
      final double hoverX = humidityPoints.length == 1
          ? size.width / 2
          : (hoveredIndex! / (humidityPoints.length - 1)) * size.width;
      final crosshairPaint = Paint()
        ..color = ParishColors.textMuted.withOpacity(0.45)
        ..strokeWidth = 1.1;
      canvas.drawLine(Offset(hoverX, 0), Offset(hoverX, size.height), crosshairPaint);
    }

    // Humidity Curve (Marian Blue)
    _drawMetricCurve(
      canvas,
      size,
      humidityPoints,
      minVal: humRange.min,
      maxVal: humRange.max,
      lineColor: ParishColors.marianBlue,
      gradientStart: ParishColors.marianBlue.withOpacity(0.18),
    );

    // Temperature Curve (Gold Accent)
    _drawMetricCurve(
      canvas,
      size,
      temperaturePoints,
      minVal: tempRange.min,
      maxVal: tempRange.max,
      lineColor: ParishColors.goldAccent,
      gradientStart: ParishColors.goldAccent.withOpacity(0.10),
    );
  }

  void _drawMetricCurve(
      Canvas canvas,
      Size size,
      List<double> values, {
        required double minVal,
        required double maxVal,
        required Color lineColor,
        required Color gradientStart,
      }) {
    if (values.isEmpty) return;

    final List<Offset> points = [];
    if (values.length == 1) {
      points.add(Offset(size.width / 2, _getY(values[0], minVal, maxVal, size.height)));
    } else {
      final double stepX = size.width / (values.length - 1);
      for (int i = 0; i < values.length; i++) {
        points.add(Offset(i * stepX, _getY(values[i], minVal, maxVal, size.height)));
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final dotInner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      final fillPath = Path()
        ..moveTo(points.first.dx, size.height)
        ..lineTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final dx = (p1.dx - p0.dx) / 2.5;
        final cp1 = Offset(p0.dx + dx, p0.dy);
        final cp2 = Offset(p1.dx - dx, p1.dy);

        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
        fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientStart, Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    for (int i = 0; i < points.length; i++) {
      final isHovered = hoveredIndex == i;
      final isLatest = i == points.length - 1;

      if (isHovered) {
        final haloPaint = Paint()
          ..color = lineColor.withOpacity(0.24)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], 8.0, haloPaint);
        canvas.drawCircle(points[i], 4.8, dotPaint);
        canvas.drawCircle(points[i], 2.2, dotInner);
      } else if (isLatest) {
        canvas.drawCircle(points[i], 4.4, dotPaint);
        canvas.drawCircle(points[i], 2.0, dotInner);
      } else {
        canvas.drawCircle(points[i], 2.3, dotPaint);
      }
    }
  }

  double _getY(double value, double min, double max, double height) {
    final span = max - min;
    if (span <= 0) return height / 2;
    final clamped = value.clamp(min, max);
    final ratio = (clamped - min) / span;
    return height - (ratio * height);
  }

  @override
  bool shouldRepaint(covariant _MicroclimateLineChartPainter oldDelegate) {
    if (oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.humidityPoints.length != humidityPoints.length ||
        oldDelegate.temperaturePoints.length != temperaturePoints.length ||
        oldDelegate.humRange.min != humRange.min ||
        oldDelegate.humRange.max != humRange.max ||
        oldDelegate.tempRange.min != tempRange.min ||
        oldDelegate.tempRange.max != tempRange.max) {
      return true;
    }

    for (int i = 0; i < humidityPoints.length; i++) {
      if (oldDelegate.humidityPoints[i] != humidityPoints[i]) return true;
    }
    for (int i = 0; i < temperaturePoints.length; i++) {
      if (oldDelegate.temperaturePoints[i] != temperaturePoints[i]) return true;
    }
    return false;
  }
}