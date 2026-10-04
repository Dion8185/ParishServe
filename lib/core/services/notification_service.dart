// =============================================================================
// FILE: lib/core/services/notification_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/appointments/presentation/dialogs/appointment_detail_dialog.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/sacramental_records/presentation/dialogs/pabuklat_requests_modal.dart';
import '../../features/smart_archive/presentation/dialogs/sensor_detail_dialog.dart';

class NotificationService {
  NotificationService._();

  // OneSignal Public App ID
  static const String _oneSignalAppId = "54bdc4cd-8445-4c44-883c-068487b04ca7";

  static bool _isInitialized = false;

  /// Global navigator key reference for in-app push deep-linking
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Caches push payloads received during cold start / killed state before the user session is mounted
  static Map<String, dynamic>? pendingNotificationData;

  /// Initializes the OneSignal SDK on mobile platforms
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[NotificationService] Running on Web - skipping native OneSignal mobile SDK initialization.');
      return;
    }

    if (_isInitialized) return;

    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(_oneSignalAppId);

      final permissionGranted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('[NotificationService] Push Permission Granted: $permissionGranted');

      OneSignal.User.pushSubscription.addObserver((state) {
        debugPrint('[OneSignal Observer] Subscription ID: ${state.current.id}');
        debugPrint('[OneSignal Observer] Push Token: ${state.current.token}');
        debugPrint('[OneSignal Observer] Opted In: ${state.current.optedIn}');
      });

      // Foreground notification banner display
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('[OneSignal Foreground]: ${event.notification.title} - ${event.notification.body}');
        event.notification.display();
      });

      // Notification click listener with cold-start resilience
      OneSignal.Notifications.addClickListener((event) {
        final notification = event.notification;
        debugPrint('[OneSignal Clicked]: ${notification.title}');
        _handleNotificationClick(notification.additionalData);
      });

      _isInitialized = true;
      debugPrint('[NotificationService] OneSignal successfully initialized.');
    } catch (e) {
      debugPrint('[NotificationService] Error initializing OneSignal: $e');
    }
  }

  /// Associates the logged-in user (Staff or Parishioner) with OneSignal
  /// and links their user_id as External ID to enable targeted push notifications.
  static Future<void> syncStaffUser(UserModel user) async {
    if (kIsWeb) return;

    if (!_isInitialized) {
      await initialize();
    }

    final role = user.userRole.toLowerCase();

    try {
      // 1. Opt-in the device push channel
      OneSignal.User.pushSubscription.optIn();

      // 2. Link OneSignal External ID to Supabase user_id for targeted alerts
      await OneSignal.login(user.userId);

      // 3. Set clean role tag (staff roles or 'user')
      await OneSignal.User.addTagWithKey("role", role);

      debugPrint('[NotificationService] OneSignal user synced: userId=${user.userId}, role=$role');
      debugPrint('[NotificationService] Device Subscription ID: ${OneSignal.User.pushSubscription.id}');
    } catch (e) {
      debugPrint('[NotificationService] Error syncing user with OneSignal: $e');
    }
  }

  /// Unlinks user from OneSignal on logout to prevent receiving other users' notifications
  static Future<void> clearStaffUser() async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await OneSignal.User.removeTag("role");
      await OneSignal.logout();
      debugPrint('[NotificationService] OneSignal session detached.');
    } catch (e) {
      debugPrint('[NotificationService] Error logging out of OneSignal: $e');
    }
  }

  /// Dispatches a push notification to all devices tagged with [targetRole] (e.g. 'secretary', 'parishpriest')
  /// by invoking the Supabase Edge Function 'dispatch-alert'.
  static Future<void> sendRolePushNotification({
    required String targetRole,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String alertType = 'pabuklat_request',
  }) async {
    try {
      final client = Supabase.instance.client;

      await client.functions.invoke(
        'dispatch-alert',
        body: {
          'alertType': alertType,
          'title': title,
          'message': message,
          'targetRoles': [targetRole.toLowerCase()],
          'additionalData': data,
        },
      );

      debugPrint('[NotificationService] Push dispatched to role: $targetRole');
    } catch (e) {
      debugPrint('[NotificationService] Role push invocation notice: $e');
    }
  }

  /// Dispatches a direct push notification to a specific requester account [targetUserId]
  /// via the Supabase Edge Function 'dispatch-alert'.
  static Future<void> sendUserPushNotification({
    required String targetUserId,
    required String title,
    required String message,
    required Map<String, dynamic> data,
    String alertType = 'pabuklat_ready',
  }) async {
    try {
      final client = Supabase.instance.client;

      await client.functions.invoke(
        'dispatch-alert',
        body: {
          'alertType': alertType,
          'title': title,
          'message': message,
          'targetUserIds': [targetUserId],
          'additionalData': data,
        },
      );

      debugPrint('[NotificationService] User push dispatched to external_id: $targetUserId');
    } catch (e) {
      debugPrint('[NotificationService] User push invocation notice: $e');
    }
  }

  /// Consumes and executes any pending notification payload once the app is authenticated and mounted
  static void consumePendingNotification(BuildContext context) {
    if (pendingNotificationData != null) {
      final data = pendingNotificationData;
      pendingNotificationData = null;
      debugPrint('[NotificationService] Consuming pending cold-start notification payload.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationClick(data);
      });
    }
  }

  /// Routes the user to the appropriate screen or modal depending on the alert payload
  static void _handleNotificationClick(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;

    final context = navigatorKey.currentContext;

    if (context == null || AuthService.currentUser == null) {
      debugPrint('[NotificationService] Context or session not yet ready. Caching notification payload.');
      pendingNotificationData = additionalData;
      return;
    }

    final type = (additionalData['type'] ?? additionalData['alertType'] ?? additionalData['notification_type'])?.toString().toLowerCase() ?? '';
    final refId = (additionalData['appointment_id'] ?? additionalData['reference_id'] ?? additionalData['node_id'] ?? additionalData['service_request_id'])?.toString();

    try {
      // 1. Appointments, Tuesday Approvals, and 24h/12h Reminders
      if (type.contains('appointment') || type.contains('tuesday') || type.contains('reminder')) {
        debugPrint('[NotificationService] Deep-linking to Appointment Detail: $refId');
        showAppointmentDetailModal(
          context,
          refNo: refId ?? 'APT-RECORD',
        );
      }
      // 2. Smart Archive IoT Environmental Breaches
      else if (type.contains('iot') || type.contains('humidity') || type.contains('temperature')) {
        debugPrint('[NotificationService] Deep-linking to Smart Archive Sensor Dialog: $refId');
        final tempStr = additionalData['temperature'] != null ? '${additionalData["temperature"]} °C' : '28.5 °C';
        final humStr = additionalData['humidity'] != null ? '${additionalData["humidity"]} %' : '68.2 %';

        showSensorDetailModal(
          context,
          roomTitle: 'Monitored Archive Storage Room',
          nodeId: refId ?? 'ESP32-NODE-01',
          temperature: tempStr,
          humidity: humStr,
          isWarning: true,
        );
      }
      // 3. Pabuklat Requests (Secretary view)
      else if (type.contains('pabuklat_request')) {
        debugPrint('[NotificationService] Deep-linking to Secretary Pabuklat Review Modal: $refId');
        showPabuklatRequestsModal(context);
      }
    } catch (e) {
      debugPrint('[NotificationService] Error executing deep-link action: $e');
    }
  }
}