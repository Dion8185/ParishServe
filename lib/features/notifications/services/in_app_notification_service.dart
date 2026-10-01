import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/notification_model.dart';

class InAppNotificationService {
  InAppNotificationService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Global value notifier holding the live unread count for fast UI updates
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static RealtimeChannel? _subscriptionChannel;

  /// Fetches the notification history for the current staff member
  static Future<List<NotificationModel>> getNotifications() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final role = user.userRole.toLowerCase();
    final userId = user.userId;

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('is_cleared', false)
          .or('user_id.eq.$userId,target_role.eq.$role,target_role.eq.all_staff')
          .order('created_at', ascending: false)
          .limit(50);

      final list = (response as List)
          .map((row) => NotificationModel.fromMap(row as Map<String, dynamic>))
          .toList();

      // Recalculate and update the unread count badge
      final unreadCount = list.where((n) => !n.isRead).length;
      unreadCountNotifier.value = unreadCount;

      return list;
    } catch (e) {
      debugPrint('[InAppNotificationService] Error fetching notifications: $e');
      return [];
    }
  }

  /// Starts listening to real-time changes in public.notifications
  static void startRealtimeListener() {
    final user = AuthService.currentUser;
    if (user == null || _subscriptionChannel != null) return;

    // Initial fetch to prime the unread counter
    getNotifications();

    _subscriptionChannel = _client
        .channel('public:notifications')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        debugPrint('[InAppNotificationService] Realtime notification update received.');
        // Re-fetch notifications and refresh the unread counter badge
        getNotifications();
      },
    )
        .subscribe();
  }

  /// Stops the realtime listener upon logout
  static void stopRealtimeListener() {
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    unreadCountNotifier.value = 0;
  }

  /// Marks a specific notification as read in Supabase
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);

      // Immediately deduct from the local unread count
      if (unreadCountNotifier.value > 0) {
        unreadCountNotifier.value--;
      }
    } catch (e) {
      debugPrint('[InAppNotificationService] Error marking notification as read: $e');
    }
  }

  /// Marks all active notifications as read
  static Future<void> markAllAsRead() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final role = user.userRole.toLowerCase();
    final userId = user.userId;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('is_cleared', false)
          .or('user_id.eq.$userId,target_role.eq.$role,target_role.eq.all_staff');

      unreadCountNotifier.value = 0;
    } catch (e) {
      debugPrint('[InAppNotificationService] Error marking all as read: $e');
    }
  }

  /// Clears the notification tray for the user (sets is_cleared = true)
  static Future<void> clearAllNotifications() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final role = user.userRole.toLowerCase();
    final userId = user.userId;

    try {
      await _client
          .from('notifications')
          .update({'is_cleared': true, 'is_read': true})
          .or('user_id.eq.$userId,target_role.eq.$role,target_role.eq.all_staff');

      unreadCountNotifier.value = 0;
    } catch (e) {
      debugPrint('[InAppNotificationService] Error clearing notification tray: $e');
    }
  }
}