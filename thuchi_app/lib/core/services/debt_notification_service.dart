import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/debt_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../core/utils/currency_utils.dart';

class DebtNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(defaultActionName: 'Open App');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      linux: initializationSettingsLinux,
    );
    
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
  }

  static Future<void> checkAndNotify(AppDatabase db) async {
    final accountRepo = AccountRepository(db);
    final debtRepo = DebtRepository(db, accountRepo);
    
    // 1. Check Debts
    final debts = await (db.select(db.debts)..where((d) => d.isFinished.equals(false))).get();
    final now = DateTime.now();

    for (final debt in debts) {
      if (debt.dueDate == null) continue;

      final difference = debt.dueDate!.difference(now).inDays;
      
      if (difference <= debt.notifyDays && difference >= -1) {
        String message = '';
        if (difference < 0) {
          message = 'Khoản nợ từ ${debt.person} đã quá hạn!';
        } else if (difference == 0) {
          message = 'Hôm nay là hạn trả nợ cho ${debt.person}';
        } else {
          message = 'Đến hạn trả ${CurrencyUtils.formatVND(debt.remainingAmount)} cho ${debt.person} trong $difference ngày nữa';
        }

        await _showNotification(
          id: debt.id, // ID range 0-999999
          title: 'Nhắc nhở nợ',
          body: message,
          channelId: 'debt_reminders',
          channelName: 'Nhắc nhở nợ',
        );
      }
    }

    // 2. Check Bills
    final bills = await (db.select(db.bills)..where((b) => b.isPaid.equals(false))).get();
    
    for (final bill in bills) {
      final difference = bill.dueDate.difference(now).inDays;
      
      if (difference <= bill.notifyBefore && difference >= -1) {
        String message = '';
        if (difference < 0) {
          message = 'Hóa đơn ${bill.title} đã quá hạn!';
        } else if (difference == 0) {
          message = 'Hôm nay đến hạn thanh toán: ${bill.title}';
        } else {
          message = 'Chuẩn bị thanh toán ${bill.title} (${CurrencyUtils.formatVND(bill.amount)}) trong $difference ngày nữa';
        }

        await _showNotification(
          id: 1000000 + bill.id, // Offset ID for bills to avoid collision
          title: 'Nhắc hóa đơn',
          body: message,
          channelId: 'bill_reminders',
          channelName: 'Nhắc hóa đơn',
        );
      }
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Thông báo nhắc nhở từ ứng dụng',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    await _notificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }
}
