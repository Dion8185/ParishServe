// =============================================================================
// FILE: lib/features/smart_archive/presentation/smart_archive_view.dart
// =============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
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
    this.idealTempMax = 32.0,     // Santa Cruz, Laguna tropical baseline
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
    const double maxHum = 75.0;  // Real breach limit for Laguna
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

class SmartArchiveView extends StatefulWidget {
  const SmartArchiveView({super.key});

  @override
  State<SmartArchiveView> createState() => _SmartArchiveViewState();
}

class _SmartArchiveViewState extends State<SmartArchiveView> {
  // Explicit Singapore regional RTDB endpoint matching your ESP32 configuration
  static const String _kFirebaseRtdbUrl =
      "https://parishserve-default-rtdb.asia-southeast1.firebasedatabase.app";

  late final DatabaseReference _rtdbRef;
  List<Map<String, dynamic>> _chartTelemetryLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeRealtimeDatabase();
    _fetchHistoricalLogs();
    _runDiagnosticCheck();
  }

  void _initializeRealtimeDatabase() {
    try {
      debugPrint('[SmartArchiveView] Connecting explicitly to regional RTDB: $_kFirebaseRtdbUrl');

      // Explicitly connects Android native client to asia-southeast1 (Singapore)
      final rtdb = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _kFirebaseRtdbUrl,
      );

      _rtdbRef = rtdb.ref('storage_nodes');
    } catch (e) {
      debugPrint('[SmartArchiveView] Error obtaining DatabaseReference: $e');
      _rtdbRef = FirebaseDatabase.instance.ref('storage_nodes');
    }
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
      final data = await Supabase.instance.client
          .from('sensor_telemetry_logs')
          .select('temperature, humidity, recorded_at')
          .gte('recorded_at', twentyFourHoursAgo)
          .order('recorded_at', ascending: true)
          .limit(25);

      if (mounted) {
        setState(() {
          _chartTelemetryLogs = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('[SmartArchiveView] Notice loading chart logs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _rtdbRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _initializeRealtimeDatabase()),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),
          );
        }

        final bool isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

        SmartArchiveNodeData? activeNode;

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final raw = snapshot.data!.snapshot.value;
          if (raw is Map) {
            raw.forEach((key, val) {
              if (val is Map && activeNode == null) {
                activeNode = SmartArchiveNodeData.fromFirebase(
                  Map<String, dynamic>.from(val),
                  key.toString(),
                );
              }
            });
          }
        }

        // Fallback default node calibrated for Laguna
        activeNode ??= SmartArchiveNodeData(
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

        final bool isOffline = activeNode!.isOffline;
        final bool isWarning = activeNode!.isWarning;

        return LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final bool isDesktop = screenWidth >= 1080;
            final bool isMobile = screenWidth < 650;

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _initializeRealtimeDatabase());
                await _fetchHistoricalLogs();
              },
              color: ParishColors.marianBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 28,
                  vertical: isMobile ? 14 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Hero Header with SJP Background & Real-Time Sync Ribbon
                        _buildHeroHeader(isMobile, isWarning, isOffline),
                        const SizedBox(height: 20),

                        // 2. Section Title
                        _buildSectionTitle(),
                        const SizedBox(height: 12),

                        // 3. Single Node Card + Live Microclimate Line Graph
                        if (isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(60),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          isDesktop
                              ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Single Node Card
                              SizedBox(
                                width: 420,
                                child: StorageNodeTile(
                                  roomTitle: activeNode!.roomTitle,
                                  nodeId: activeNode!.nodeId,
                                  temperature: '${activeNode!.temperature.toStringAsFixed(1)} °C',
                                  humidity: '${activeNode!.humidity.toStringAsFixed(1)} %',
                                  isWarning: isWarning,
                                  isOffline: isOffline,
                                  storageType: activeNode!.storageType,
                                  lastTelemetry: activeNode!.lastTelemetryAt,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right: Real Microclimate Line Graph
                              Expanded(
                                child: _buildTelemetryLineGraphCard(activeNode!),
                              ),
                            ],
                          )
                              : Column(
                            children: [
                              StorageNodeTile(
                                roomTitle: activeNode!.roomTitle,
                                nodeId: activeNode!.nodeId,
                                temperature: '${activeNode!.temperature.toStringAsFixed(1)} °C',
                                humidity: '${activeNode!.humidity.toStringAsFixed(1)} %',
                                isWarning: isWarning,
                                isOffline: isOffline,
                                storageType: activeNode!.storageType,
                                lastTelemetry: activeNode!.lastTelemetryAt,
                              ),
                              const SizedBox(height: 14),
                              _buildTelemetryLineGraphCard(activeNode!),
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
                    // Functional Feed Refresh Button
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
                          setState(() => _initializeRealtimeDatabase());
                          await _fetchHistoricalLogs();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Telemetry feed reloaded.'),
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

  Widget _buildSectionTitle() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 26,
          decoration: BoxDecoration(
            color: ParishColors.goldAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Monitored Archive Vault Telemetry',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['Times New Roman', 'serif'],
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            color: ParishColors.textDark,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Live Microclimate Line Graph (Zero packages, pure Flutter)
  // ===========================================================================

  Widget _buildTelemetryLineGraphCard(SmartArchiveNodeData node) {
    List<double> humPoints = [];
    List<double> tempPoints = [];

    if (_chartTelemetryLogs.isNotEmpty) {
      for (final log in _chartTelemetryLogs) {
        final hum = double.tryParse(log['humidity']?.toString() ?? '65.0') ?? 65.0;
        final temp = double.tryParse(log['temperature']?.toString() ?? '28.0') ?? 28.0;
        humPoints.add(hum);
        tempPoints.add(temp);
      }
    }

    humPoints.add(node.humidity);
    tempPoints.add(node.temperature);

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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time line visualization of conditions',
                      style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem('Humidity', ParishColors.marianBlue),
                  const SizedBox(width: 8),
                  _buildLegendItem('Temp', ParishColors.goldAccent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _MicroclimateLineChartPainter(
                humidityPoints: humPoints,
                temperaturePoints: tempPoints,
                maxHumThreshold: node.idealHumidityMax,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Past Readings', style: TextStyle(fontSize: 10, color: ParishColors.textMuted)),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 2,
                    color: ParishColors.mercyRed.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Laguna Limit: 75% RH',
                    style: TextStyle(fontSize: 10, color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text('Live Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
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
}

// =============================================================================
// Custom Painter for Microclimate Curves (35% to 90% RH range for Laguna)
// =============================================================================

class _MicroclimateLineChartPainter extends CustomPainter {
  final List<double> humidityPoints;
  final List<double> temperaturePoints;
  final double maxHumThreshold;

  _MicroclimateLineChartPainter({
    required this.humidityPoints,
    required this.temperaturePoints,
    required this.maxHumThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = ParishColors.borderGrey.withOpacity(0.5)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Threshold Line at 75% RH
    final thresholdY = _getY(maxHumThreshold, 35.0, 90.0, size.height);
    final thresholdPaint = Paint()
      ..color = ParishColors.mercyRed.withOpacity(0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, thresholdY), Offset(size.width, thresholdY), thresholdPaint);

    // Humidity Curve (Marian Blue)
    _drawMetricCurve(
      canvas,
      size,
      humidityPoints,
      minVal: 35.0,
      maxVal: 90.0,
      lineColor: ParishColors.marianBlue,
      gradientStart: ParishColors.marianBlue.withOpacity(0.18),
    );

    // Temperature Curve (Gold Accent)
    _drawMetricCurve(
      canvas,
      size,
      temperaturePoints,
      minVal: 15.0,
      maxVal: 40.0,
      lineColor: ParishColors.goldAccent,
      gradientStart: ParishColors.goldAccent.withOpacity(0.12),
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

    final path = Path();
    final fillPath = Path();

    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = _getY(values[i], minVal, maxVal, size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i >= values.length - 3) {
        canvas.drawCircle(Offset(x, y), 4.0, dotPaint);
        canvas.drawCircle(Offset(x, y), 2.0, dotInner);
      }
    }

    fillPath.lineTo(size.width, size.height);
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

  double _getY(double value, double min, double max, double height) {
    final clamped = value.clamp(min, max);
    final ratio = (clamped - min) / (max - min);
    return height - (ratio * height);
  }

  @override
  bool shouldRepaint(covariant _MicroclimateLineChartPainter oldDelegate) {
    return oldDelegate.humidityPoints != humidityPoints ||
        oldDelegate.temperaturePoints != temperaturePoints;
  }
}