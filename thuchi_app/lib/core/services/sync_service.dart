import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/attachment_repository.dart';
import 'cloud_models.dart';
import 'drive_storage_provider.dart';
import 's3_storage_provider.dart';

class SyncService {
  static Future<CloudStorageProvider?> _getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerType = prefs.getString('sync_provider') ?? 'none';
    
    if (providerType == 'none') return null;

    CloudStorageProvider? provider;
    if (providerType == 'drive') {
      provider = GoogleDriveProvider();
    } else if (providerType == 's3') {
      const secureStorage = FlutterSecureStorage();
      final endpoint = await secureStorage.read(key: 's3_endpoint') ?? '';
      final accessKey = await secureStorage.read(key: 's3_access_key') ?? '';
      final secretKey = await secureStorage.read(key: 's3_secret_key') ?? '';
      final bucket = await secureStorage.read(key: 's3_bucket') ?? '';
      final region = await secureStorage.read(key: 's3_region') ?? 'us-east-1';
      
      if (endpoint.isEmpty || bucket.isEmpty) return null;
      
      provider = S3StorageProvider(S3Config(
        endpoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        bucketName: bucket,
        region: region,
      ));
    }

    if (provider == null) return null;

    final isAuthenticated = await provider.authenticate();
    if (!isAuthenticated) return null;

    return provider;
  }

  static Future<void> syncPendingAttachments(AppDatabase db) async {
    print('SyncService: Starting attachment sync...');
    
    final provider = await _getProvider();
    if (provider == null) {
      print('SyncService: Sync disabled or auth failed.');
      return;
    }

    final repo = AttachmentRepository(db);
    final pendingItems = await repo.getPendingAttachments();
    
    if (pendingItems.isEmpty) {
      print('SyncService: No pending attachments.');
      return;
    }

    print('SyncService: Found ${pendingItems.length} pending attachments.');

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

        // Determine folder based on fileType / extension
        final isImage = item.fileType.startsWith('image/') || 
            ['.jpg', '.jpeg', '.png', '.heic'].any((e) => item.fileName.toLowerCase().endsWith(e));
        final subFolder = isImage ? 'images' : 'documents';
        final remotePath = 'attachments/$subFolder/${item.fileName}';

        final remoteId = await provider.uploadFile(file, remotePath);
        
        await repo.updateSyncStatus(
          id: item.id,
          status: 'SYNCED',
          driveFileId: remoteId,
        );
        print('SyncService: Uploaded ${item.fileName} -> $remoteId (as $remotePath)');
        
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

  static Future<void> syncBackups(List<File> snapshotFiles) async {
    print('SyncService: Starting backup sync...');
    
    final provider = await _getProvider();
    if (provider == null) {
      print('SyncService: Sync disabled or auth failed.');
      return;
    }

    for (final file in snapshotFiles) {
       try {
         final fileName = file.uri.pathSegments.last;
         final remotePath = 'backups/$fileName';
         final remoteId = await provider.uploadFile(file, remotePath);
         print('SyncService: Uploaded backup $fileName -> $remoteId');
       } catch (e) {
         print('SyncService: Error uploading backup ${file.path}: $e');
       }
    }
  }
}
