import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/attachment_repository.dart';
import 'cloud_models.dart';
import 'drive_storage_provider.dart';
import 's3_storage_provider.dart';

class SyncService {
  static Future<void> syncPendingAttachments(AppDatabase db) async {
    print('SyncService: Starting sync...');
    
    // 1. Get Config
    final prefs = await SharedPreferences.getInstance();
    final providerType = prefs.getString('sync_provider') ?? 'none';
    
    if (providerType == 'none') {
      print('SyncService: Sync disabled.');
      return;
    }

    CloudStorageProvider? provider;
    
    // 2. Init Provider
    if (providerType == 'drive') {
      provider = GoogleDriveProvider();
    } else if (providerType == 's3') {
      const secureStorage = FlutterSecureStorage();
      final endpoint = await secureStorage.read(key: 's3_endpoint') ?? '';
      final accessKey = await secureStorage.read(key: 's3_access_key') ?? '';
      final secretKey = await secureStorage.read(key: 's3_secret_key') ?? '';
      final bucket = await secureStorage.read(key: 's3_bucket') ?? '';
      final region = await secureStorage.read(key: 's3_region') ?? 'us-east-1';
      
      if (endpoint.isEmpty || bucket.isEmpty) {
        print('SyncService: S3 config missing.');
        return;
      }
      
      provider = S3StorageProvider(S3Config(
        endpoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        bucketName: bucket,
        region: region,
      ));
    }

    if (provider == null) return;

    // 3. Authenticate
    final isAuthenticated = await provider.authenticate();
    if (!isAuthenticated) {
      print('SyncService: Auth failed for $providerType');
      return;
    }

    // 4. Process Pending Attachments
    final repo = AttachmentRepository(db);
    final pendingItems = await repo.getPendingAttachments();
    
    if (pendingItems.isEmpty) {
      print('SyncService: No pending attachments.');
      return;
    }

    print('SyncService: Found ${pendingItems.length} pending items.');

    for (final item in pendingItems) {
      try {
        final file = File(item.localPath);
        if (!file.existsSync()) {
          await repo.updateSyncStatus(
            id: item.id,
            status: 'ERROR',
            errorMessage: 'Local file not found',
          );
          continue;
        }

        final remoteId = await provider.uploadFile(file, item.fileName);
        
        await repo.updateSyncStatus(
          id: item.id,
          status: 'SYNCED',
          driveFileId: remoteId,
        );
        print('SyncService: Uploaded ${item.fileName} -> $remoteId');
        
      } catch (e) {
        print('SyncService: Error uploading ${item.fileName}: $e');
        await repo.updateSyncStatus(
          id: item.id,
          status: 'ERROR',
          errorMessage: e.toString(),
        );
      }
    }
  }
}
