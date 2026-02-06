import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/debt_notification_service.dart';
import 'core/services/sync_service.dart';
import 'data/database/app_database.dart';

const debtCheckTask = "com.thuchi.debtCheckTask";
const syncTask = "com.thuchi.syncTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == debtCheckTask) {
      final db = AppDatabase();
      await DebtNotificationService.init();
      await DebtNotificationService.checkAndNotify(db);
      await db.close();
    } else if (task == syncTask) {
      final db = AppDatabase();
      await SyncService.syncPendingAttachments(db);
      await db.close();
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  // Register daily task
  await Workmanager().registerPeriodicTask(
    "1",
    debtCheckTask,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: true,
    ),
  );

  // Register sync task (1 hour)
  await Workmanager().registerPeriodicTask(
    "2",
    syncTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );

  final container = ProviderContainer();
  await container.read(notificationServiceProvider).init();
  await DebtNotificationService.init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ThuChiApp(),
    ),
  );
}
