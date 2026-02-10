import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart'; // Not needed if using direct mock
import 'package:thuchi_app/core/services/data_service.dart';
import 'package:thuchi_app/core/services/snapshot_service.dart';
import 'package:thuchi_app/data/database/app_database.dart';
import 'package:thuchi_app/providers/auth_provider.dart';
import 'package:thuchi_app/providers/app_providers.dart'; // For other providers

// Mock PathProvider
class MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync().path;
  }
}

// Mock Ref
class MockRef extends Mock implements Ref {}

void main() {
  late AppDatabase db;
  late DataService dataService;
  late SnapshotService snapshotService;
  late MockRef mockRef;

  setUpAll(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    registerFallbackValue(const AsyncValue<void>.data(null));
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockRef = MockRef();
    
    // Mock user
    final mockUser = User(
      id: 1, 
      username: 'testuser', 
      passwordHash: 'hash', 
      displayName: 'Test User',
      createdAt: DateTime.now(),
    );
    
    // Mock ref.read(currentUserProvider)
    when(() => mockRef.read(currentUserProvider)).thenReturn(mockUser);

    // Mock ref.invalidate calls
    when(() => mockRef.invalidate(any())).thenReturn(null);
    
    dataService = DataService(db, mockRef);
    snapshotService = SnapshotService(dataService);
  });

  tearDown(() async {
    await db.close();
  });

  group('DataService Reset', () {
    test('resetToDefault clears data and seeds defaults', () async {
      // 1. Setup initial data
      await db.into(db.accounts).insert(AccountsCompanion.insert(
        name: 'Old Account',
        balance: const Value(100),
        type: 'bank',
        userId: 1,
      ));
      
      // 2. Call reset
      await dataService.resetToDefault(seedData: true);

      // 3. Verify
      final accounts = await db.select(db.accounts).get();
      // Expect 1 account (Default 'Tiền mặt' seeded)
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Tiền mặt');
      expect(accounts.first.balance, 0);

      final transactions = await db.select(db.transactions).get();
      expect(transactions, isEmpty);
      
      final auditLogs = await db.select(db.auditLogs).get();
      expect(auditLogs, isEmpty);
      
      // Verify invalidations
      verify(() => mockRef.invalidate(accountsProvider)).called(1);
    });
  });

  group('SnapshotService', () {
    test('create and restore snapshot', () async {
      // 1. Setup initial data
      await db.into(db.accounts).insert(AccountsCompanion.insert(
        id: const Value(1),
        name: 'Account A',
        balance: const Value(1000),
        type: 'cash',
        userId: 1,
      ));

      // 2. Create Snapshot
      final snapshotName = 'test_snapshot';
      await snapshotService.createSnapshot(snapshotName);
      
      final snapshots = await snapshotService.listSnapshots();
      expect(snapshots, isNotEmpty);
      expect(snapshots.first.path, contains(snapshotName));

      // 3. Modify Data (Delete account)
      await db.delete(db.accounts).go();
      expect(await db.select(db.accounts).get(), isEmpty);

      // 4. Restore Snapshot
      await snapshotService.restoreSnapshot(snapshots.first);

      // 5. Verify Data Restored
      final accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Account A');
      expect(accounts.first.balance, 1000);
      
      // Cleanup
      await snapshotService.deleteSnapshot(snapshots.first);
    });
  });
}
