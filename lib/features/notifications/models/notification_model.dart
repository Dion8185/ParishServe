import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class NotificationModel {
  final String notificationId;
  final String? userId;
  final String? targetRole; // 'parishpriest', 'secretary', 'all_staff'
  final String title;
  final String message;
  final String notificationType;
  // 'new_appointment', 'tuesday_approval', 'iot_breach', 'reminder_24h', 'reminder_12h', 'pabuklat_ready', 'general'
  final String? referenceId; // appointment_id, node_id, record_id
  final bool isRead;
  final bool isCleared;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    this.userId,
    this.targetRole,
    required this.title,
    required this.message,
    this.notificationType = 'general',
    this.referenceId,
    this.isRead = false,
    this.isCleared = false,
    required this.createdAt,
  });

  /// Relative human-readable time (e.g., "Just now", "15m ago", "2h ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    }
  }

  /// Appropriate icon based on alert category
  IconData get iconData {
    switch (notificationType.toLowerCase()) {
      case 'iot_breach':
      case 'humidity_breach':
      case 'temperature_spike':
        return Icons.warning_amber_rounded;
      case 'tuesday_approval':
        return Icons.approval_outlined;
      case 'new_appointment':
        return Icons.calendar_today_outlined;
      case 'reminder_24h':
      case 'reminder_12h':
        return Icons.alarm;
      case 'pabuklat_ready':
      case 'certificate_ready':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  /// Appropriate theme accent color based on urgency
  Color get accentColor {
    switch (notificationType.toLowerCase()) {
      case 'iot_breach':
      case 'humidity_breach':
      case 'temperature_spike':
        return ParishColors.mercyRed;
      case 'tuesday_approval':
      case 'reminder_24h':
      case 'reminder_12h':
        return ParishColors.goldAccent;
      case 'pabuklat_ready':
      case 'certificate_ready':
        return ParishColors.oliveGreen;
      case 'new_appointment':
      default:
        return ParishColors.marianBlue;
    }
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      notificationId: map['notification_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      targetRole: map['target_role']?.toString(),
      title: map['title']?.toString() ?? 'Notification',
      message: map['message']?.toString() ?? '',
      notificationType: map['notification_type']?.toString() ?? 'general',
      referenceId: map['reference_id']?.toString(),
      isRead: map['is_read'] ?? false,
      isCleared: map['is_cleared'] ?? false,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'target_role': targetRole,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'reference_id': referenceId,
      'is_read': isRead,
      'is_cleared': isCleared,
      'created_at': createdAt.toIso8601String(),
    };
  }
}