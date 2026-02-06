import 'dart:io';
import 'package:minio/minio.dart';
// ignore: depend_on_referenced_packages
import 'package:minio/models.dart'; 
import 'cloud_models.dart';

class S3StorageProvider implements CloudStorageProvider {
  final S3Config config;
  late final Minio _client;
  bool _isAuthenticated = false;

  S3StorageProvider(this.config) {
    _client = Minio(
      endPoint: config.endpoint,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
      useSSL: config.useSSL,
      region: config.region,
    );
  }

  @override
  String get providerId => 's3';

  @override
  Future<bool> authenticate() async {
    try {
      // Check if bucket exists to verify credentials
      final exists = await _client.bucketExists(config.bucketName);
      if (!exists) {
        // Option: Create bucket if not exists? Or strictly require it?
        // For safety, let's assume user must provide existing bucket or we try to create
        // Usually safer to check access.
        // If false, it might mean it doesn't exist OR no permission.
        // Let's try to list buckets as a lighter check if specific bucket check fails permission
      }
      _isAuthenticated = true;
      return true;
    } catch (e) {
      _isAuthenticated = false;
      // If error is "NoSuchBucket", it means Auth worked but bucket missing
      if (e.toString().contains('NoSuchBucket')) {
         // Create logic could be here, but simpler to just return false or throw
         return false; 
      }
      return false;
    }
  }

  @override
  Future<String> uploadFile(File file, String remotePath) async {
    // remotePath example: attachments/img_123.jpg
    await _client.fPutObject(config.bucketName, remotePath, file.path);
    return remotePath; // For S3, the ID is the path/key
  }

  @override
  Future<File> downloadFile(String remoteId, String localPath) async {
    // remoteId is the object key
    await _client.fGetObject(config.bucketName, remoteId, localPath);
    return File(localPath);
  }

  @override
  Future<void> deleteFile(String remoteId) async {
    await _client.removeObject(config.bucketName, remoteId);
  }

  @override
  Future<bool> isConnected() async {
    return _isAuthenticated;
  }
  
  @override
  Future<Map<String, String>> getUserInfo() async {
    return {
      'name': config.endpoint,
      'email': 'Bucket: ${config.bucketName}',
    };
  }
  
  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
  }
}
