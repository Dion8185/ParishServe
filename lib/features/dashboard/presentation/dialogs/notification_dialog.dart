import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../appointments/presentation/dialogs/appointment_detail_dialog.dart';
import '../../../notifications/models/notification_model.dart';
import '../../../notifications/services/in_app_notification_service.dart';
import '../../../smart_archive/presentation/dialogs/sensor_detail_dialog.dart';

void showNotificationModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _NotificationCenterDialog(),
  );
}

class _NotificationCenterDialog extends StatefulWidget {
  const _NotificationCenterDialog();

  @override
  State<_NotificationCenterDialog> createState() => _NotificationCenterDialogState();
}

class _NotificationCenterDialogState extends State<_NotificationCenterDialog> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await InAppNotificationService.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = data;
      _isLoading = false;
    });
  }

  Future<void> _handleItemTap(NotificationModel item) async {
    // 1. Mark as read in Supabase and deduct from the bell counter
    if (!item.isRead) {
      await InAppNotificationService.markAsRead(item.notificationId);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.notificationId == item.notificationId);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            notificationId: item.notificationId,
            userId: item.userId,
            targetRole: item.targetRole,
            title: item.title,
            message: item.message,
            notificationType: item.notificationType,
            referenceId: item.referenceId,
            isRead: true,
            isCleared: item.isCleared,
            createdAt: item.createdAt,
          );
        }
      });
    }

    if (!mounted) return;
    Navigator.pop(context); // Close notification modal before deep-linking

    // 2. Route to respective screen or modal
    final type = item.notificationType.toLowerCase();

    if (type.contains('appointment') || type.contains('tuesday') || type.contains('reminder')) {
      // Deep-link to the specific appointment approval / details modal
      showAppointmentDetailModal(
        context,
        refNo: item.referenceId ?? 'APT-RECORD',
      );
    } else if (type.contains('iot') || type.contains('humidity') || type.contains('temperature')) {
      // Deep-link to Smart Archive telemetry warning modal
      showSensorDetailModal(
        context,
        roomTitle: 'Monitored Archive Storage Room',
        nodeId: item.referenceId ?? 'ESP32-NODE-01',
        temperature: '28.5 °C',
        humidity: '68.2 %',
        isWarning: true,
      );
    }
  }

  Future<void> _handleClearAll() async {
    await InAppNotificationService.clearAllNotifications();
    if (!mounted) return;
    setState(() {
      _notifications.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification tray cleared.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleMarkAllRead() async {
    await InAppNotificationService.markAllAsRead();
    if (!mounted) return;
    setState(() {
      _notifications = _notifications.map((n) {
        return NotificationModel(
          notificationId: n.notificationId,
          userId: n.userId,
          targetRole: n.targetRole,
          title: n.title,
          message: n.message,
          notificationType: n.notificationType,
          referenceId: n.referenceId,
          isRead: true,
          isCleared: n.isCleared,
          createdAt: n.createdAt,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueAdaptive,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Parish Alerts & History',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textDark),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ParishColors.mercyRed,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount NEW',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Recent push dispatches and operational notices',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Secondary Action Bar (Mark all read & Clear tray)
            if (_notifications.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  border: Border(bottom: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: unreadCount > 0 ? _handleMarkAllRead : null,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark All as Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: ParishColors.mercyRed,
                      ),
                      onPressed: _handleClearAll,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                      label: const Text('Clear Tray', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Notification List Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 48, color: borderGrey),
                    const SizedBox(height: 12),
                    Text(
                      'All caught up!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No recent notifications or alerts in your tray.',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  return _buildNotificationCard(item, textDark, textMuted, borderGrey);
                },
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item, Color textDark, Color textMuted, Color borderGrey) {
    return InkWell(
      onTap: () => _handleItemTap(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead ? ParishColors.cardWhite : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isRead ? borderGrey : item.accentColor.withOpacity(0.5),
            width: item.isRead ? 1.0 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.iconData, color: item.accentColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 13.5,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.timeAgo,
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: TextStyle(fontSize: 12, color: textMuted, height: 1.35),
                  ),
                  if (item.referenceId != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ref: ${item.referenceId}',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to view details',
                          style: TextStyle(fontSize: 10, color: ParishColors.marianBlueAdaptive, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Unread Indicator Dot
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}