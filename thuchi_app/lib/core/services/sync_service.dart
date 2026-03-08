import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/attachment_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File(p.join(docsDir.path, item.localPath));
        if (!file.existsSync()) {
          // If we have a driveFileId already or it's just local, we can't upload.
          // Note: Maybe it's not downloaded yet? We shouldn't mark ERROR if we are syncing down later.
          // But for now, pending attachments mean they need upload.
          await repo.updateSyncStatus(
            id: item.id,
            status: 'ERROR',
            errorMessage: 'Local file not found at ${file.path}',
          );
          continue;
        }

        // Determine folder based on fileType / extension
        final ext = p.extension(item.fileName.toLowerCase());
        
        final isImage = item.fileType.startsWith('image/') || 
            ['.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif'].contains(ext);
            
        final isMedia = item.fileType.startsWith('video/') || item.fileType.startsWith('audio/') ||
            ['.mp4', '.avi', '.mov', '.mp3', '.wav', '.m4a'].contains(ext);
            
        String subFolder = 'document';
        if (isImage) {
          subFolder = 'image';
        } else if (isMedia) {
          subFolder = 'media';
        }
        
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
         final fileName = p.basename(file.path);
         final remotePath = 'backups/$fileName';
         final remoteId = await provider.uploadFile(file, remotePath);
         print('SyncService: Uploaded backup $fileName -> $remoteId');
       } catch (e) {
         print('SyncService: Error uploading backup ${file.path}: $e');
       }
    }
  }

  static Future<void> downloadMissingAttachments(AppDatabase db) async {
    print('SyncService: Checking missing attachments...');
    final provider = await _getProvider();
    if (provider == null) return;

    final attachments = await db.select(db.attachments).get();
    final docsDir = await getApplicationDocumentsDirectory();

    for (var att in attachments) {
      if (att.localPath.isNotEmpty && att.driveFileId != null && att.driveFileId!.isNotEmpty) {
        final file = File(p.join(docsDir.path, att.localPath));
        if (!file.existsSync()) {
          try {
            print('SyncService: Downloading missing file ${att.fileName}...');
            await provider.downloadFile(att.driveFileId!, file.path);
          } catch (e) {
            print('SyncService: Error downloading ${att.fileName}: $e');
          }
        }
      }
    }
  }

  static Future<void> processDeletions() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList('deleted_cloud_files') ?? [];
    if (deletedIds.isEmpty) return;

    final provider = await _getProvider();
    if (provider == null) return;

    print('SyncService: Processing ${deletedIds.length} cloud deletions...');
    final remaining = <String>[];
    for (var id in deletedIds) {
      try {
        await provider.deleteFile(id);
        print('SyncService: Deleted cloud file $id');
      } catch (e) {
        print('SyncService: Failed to delete $id: $e');
        remaining.add(id);
      }
    }
    await prefs.setStringList('deleted_cloud_files', remaining);
  }

  static Future<List<Map<String, dynamic>>> getCloudBackups() async {
    final provider = await _getProvider();
    if (provider == null) return [];
    return provider.listBackups();
  }

  static Future<File?> downloadBackup(String remoteId, String fileName) async {
    final provider = await _getProvider();
    if (provider == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final localPath = p.join(dir.path, fileName);
    return provider.downloadFile(remoteId, localPath);
  }
}
