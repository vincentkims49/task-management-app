import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/task.dart';
import '../utils/date_utils.dart' as app_date_utils;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static const String kenyaTimeZone = 'Africa/Nairobi';

  static final Map<String, DateTime> _scheduledNotifications = {};

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      try {
        tz.setLocalLocation(tz.getLocation(kenyaTimeZone));
      } catch (e) {
        try {
          final localName = tz.local.name;
          print('Falling back to system timezone: $localName');
          tz.setLocalLocation(tz.local);
        } catch (e) {
          print('Error using system timezone: $e');
          tz.setLocalLocation(tz.getLocation('UTC'));
          print('Fell back to UTC timezone');
        }
      }

      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'task_reminders',
          'Task Reminders',
          description: 'Notifications for task reminders',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        );

        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        print('Android notification channel created successfully');
      }

      try {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
          await androidImplementation.requestExactAlarmsPermission();
          print('Android permissions requested successfully');
        }
      } catch (e) {
        print('Failed to request permissions: $e');
      }

      _isInitialized = true;
      print('Notification initialization completed');
    } catch (e) {
      print('Error initializing notifications: $e');
      _isInitialized = true;
    }
  }

  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    try {
      final payload = notificationResponse.payload;
      if (payload != null &&
          payload.isNotEmpty &&
          navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pushNamed(
          '/task/detail',
          arguments: payload,
        );
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    try {
      if (!_isInitialized) await initialize();
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }

  static Future<void> scheduleTaskReminder(Task task) async {
    if (task.id.isEmpty) {
      print('Cannot schedule notification: Task ID is invalid');
      return;
    }

    if (task.dueDate == null) {
      print('Cannot schedule notification: Task has no due date');
      return;
    }

    try {
      if (!_isInitialized) await initialize();

      final int notificationId = task.id.hashCode.abs();

      // Check if we've already scheduled recently for this task
      if (_scheduledNotifications.containsKey(task.id)) {
        final lastScheduled = _scheduledNotifications[task.id]!;
        if (DateTime.now().difference(lastScheduled).inMinutes < 5) {
          print(
              'Skipping notification for task ${task.id} - recently scheduled');
          return;
        }
      }

      // Cancel any existing notification for this task
      try {
        await _notifications.cancel(notificationId);
      } catch (e) {
        print('Error canceling previous notification: $e');
      }

      final androidDetails = AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(_getPriorityColor(task.priority)),
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final DateTime idealScheduleTimeLocal =
          task.dueDate.subtract(const Duration(minutes: 30));

      // Get current time in Kenya timezone
      final now = tz.TZDateTime.now(tz.getLocation(kenyaTimeZone));

      tz.TZDateTime scheduledDate;

      try {
        // Convert the ideal schedule time to Kenya timezone
        final idealTime = tz.TZDateTime(
          tz.getLocation(kenyaTimeZone),
          idealScheduleTimeLocal.year,
          idealScheduleTimeLocal.month,
          idealScheduleTimeLocal.day,
          idealScheduleTimeLocal.hour,
          idealScheduleTimeLocal.minute,
        );

        if (idealTime.isBefore(now)) {
          // If the ideal time is in the past, schedule for 15 seconds from now
          scheduledDate = now.add(const Duration(seconds: 15));
        } else {
          scheduledDate = idealTime;
        }
      } catch (e) {
        print('Error converting date to Kenya timezone: $e');
        scheduledDate = now.add(const Duration(seconds: 15));
      }

      String title = 'Task Reminder';
      String body;

      try {
        body =
            '${task.title} - Due ${app_date_utils.DateUtils.formatRelativeDateTime(task.dueDate)}';
      } catch (e) {
        print('Error formatting date: $e');
        body = task.title;
      }

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );

      // Record this scheduling to prevent duplicates
      _scheduledNotifications[task.id] = DateTime.now();

      print(
          'Notification scheduled for task ${task.id} at ${scheduledDate.toString()} (Kenya time)');
    } catch (e) {
      print('Error scheduling notification for task ${task.id}: $e');
    }
  }

  static Future<void> cancelTaskReminder(String taskId) async {
    if (taskId.isEmpty) {
      print('Cannot cancel notification: Invalid task ID');
      return;
    }

    try {
      if (!_isInitialized) await initialize();

      final int notificationId = taskId.hashCode.abs();
      await _notifications.cancel(notificationId);

      // Remove from scheduled cache
      _scheduledNotifications.remove(taskId);

      print('Notification canceled for task $taskId');
    } catch (e) {
      print('Error canceling notification for task $taskId: $e');
    }
  }

  static Future<void> cancelAllReminders() async {
    try {
      if (!_isInitialized) await initialize();
      await _notifications.cancelAll();

      // Clear scheduled cache
      _scheduledNotifications.clear();

      print('All notifications canceled');
    } catch (e) {
      print('Error canceling all notifications: $e');
    }
  }

  static int _getPriorityColor(TaskPriority? priority) {
    if (priority == null) {
      return 0xFF8BC34A;
    }

    switch (priority) {
      case TaskPriority.low:
        return 0xFF8BC34A;
      case TaskPriority.medium:
        return 0xFFFFC107;
      case TaskPriority.high:
        return 0xFFF44336;
    }
  }
}
