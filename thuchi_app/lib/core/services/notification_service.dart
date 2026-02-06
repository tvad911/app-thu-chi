import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:thuchi_app/data/database/app_database.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleDebtReminder(Debt debt) async {
    if (debt.dueDate == null) return;

    final due = debt.dueDate!;
    final now = DateTime.now();
    
    // Don't schedule if already past
    if (due.isBefore(now)) return;

    // Schedule for 1 day before
    final reminderDate = due.subtract(const Duration(days: 1));
    if (reminderDate.isAfter(now)) {
      await _schedule(
        id: debt.id * 10 + 1, // Unique ID
        title: 'Nhắc nợ: ${debt.person}',
        body: 'Khoản nợ sẽ đến hạn vào ngày mai.',
        scheduledDate: reminderDate,
      );
    }

    // Schedule for due date (9:00 AM)
    final dueMorning = DateTime(due.year, due.month, due.day, 9, 0);
    if (dueMorning.isAfter(now)) {
       await _schedule(
        id: debt.id * 10 + 2,
        title: 'Đến hạn nợ: ${debt.person}',
        body: 'Khoản nợ đã đến hạn thanh toán hôm nay.',
        scheduledDate: dueMorning,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debt_reminders',
          'Nhắc nợ',
          channelDescription: 'Thông báo nhắc hạn nợ',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  
  Future<void> cancelDebtReminder(int debtId) async {
    await _notificationsPlugin.cancel(debtId * 10 + 1);
    await _notificationsPlugin.cancel(debtId * 10 + 2);
  }
}

final notificationServiceProvider = Provider((ref) => NotificationService());
