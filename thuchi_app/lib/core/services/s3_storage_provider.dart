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
      // Check if bucket exists
      bool exists = await _client.bucketExists(config.bucketName);
      if (!exists) {
        // Try creating the bucket
        await _client.makeBucket(config.bucketName, config.region);
        print('S3: Created bucket ${config.bucketName}');
      }
      _isAuthenticated = true;
      return true;
    } catch (e) {
      _isAuthenticated = false;
      print('S3 Auth Error: $e');
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
