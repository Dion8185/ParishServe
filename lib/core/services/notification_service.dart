import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../features/auth/models/user_model.dart';

class NotificationService {
  NotificationService._();

  // Replace with your OneSignal App ID from your OneSignal Dashboard
  static const String _oneSignalAppId = "YOUR_ONESIGNAL_APP_ID_HERE";

  static bool _isInitialized = false;

  /// Global navigator key reference for in-app push deep-linking
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('[OneSignal Foreground]: ${event.notification.title} - ${event.notification.body}');
        event.notification.display();
      });

      OneSignal.Notifications.addClickListener((event) {
        final notification = event.notification;
        debugPrint('[OneSignal Clicked]: ${notification.title}');
        _handleNotificationClick(notification.additionalData);
      });

      _isInitialized = true;
      debugPrint('[NotificationService] OneSignal successfully initialized for Staff Mobile.');
    } catch (e) {
      debugPrint('[NotificationService] Error initializing OneSignal: $e');
    }
  }

  /// Associates the logged-in staff member with OneSignal and sets 1 clean tag
  static Future<void> syncStaffUser(UserModel user) async {
    if (kIsWeb) return;

    if (!_isInitialized) {
      await initialize();
    }

    final role = user.userRole.toLowerCase();

    // Parishioners on web do not receive staff push alerts
    if (role == 'user') {
      debugPrint('[NotificationService] User is a Parishioner. Push registration skipped.');
      return;
    }

    try {
      // 1. Opt-in the device push channel
      OneSignal.User.pushSubscription.optIn();

      // 2. Link OneSignal External ID to Supabase user_id (Uses 0 tag quota!)
      await OneSignal.login(user.userId);

      // 3. Set exactly 1 clean tag (Complies with OneSignal Free Tier quota)
      await OneSignal.User.addTagWithKey("role", role);

      debugPrint('[NotificationService] OneSignal tag successfully set: role=$role');
      debugPrint('[NotificationService] Device Subscription ID: ${OneSignal.User.pushSubscription.id}');
    } catch (e) {
      debugPrint('[NotificationService] Error syncing staff user tags: $e');
    }
  }

  /// Unlinks staff user from OneSignal on logout to prevent receiving other users' notifications
  static Future<void> clearStaffUser() async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await OneSignal.User.removeTag("role");
      await OneSignal.logout();
      debugPrint('[NotificationService] OneSignal staff session detached.');
    } catch (e) {
      debugPrint('[NotificationService] Error logging out of OneSignal: $e');
    }
  }

  /// Routes the staff user to the appropriate screen depending on the alert payload
  static void _handleNotificationClick(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;

    final type = additionalData['type']?.toString().toLowerCase();

    switch (type) {
      case 'iot_alert':
      case 'humidity_breach':
      case 'temperature_spike':
        debugPrint('[NotificationService] Deep-linking to Smart Archive Telemetry screen.');
        break;

      case 'appointment_pending':
      case 'tuesday_approval':
        debugPrint('[NotificationService] Deep-linking to Appointments Desk.');
        break;

      case 'certificate_ready':
      case 'pabuklat_request':
        debugPrint('[NotificationService] Deep-linking to Sacramental Records.');
        break;

      default:
        debugPrint('[NotificationService] Notification opened with generic payload: $additionalData');
        break;
    }
  }
}