import 'dart:io';
import 'dart:typed_data';
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
    final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));
    await _client.putObject(config.bucketName, remotePath, stream, size: await file.length());
    return remotePath; 
  }

  @override
  Future<File> downloadFile(String remoteId, String localPath) async {
    final response = await _client.getObject(config.bucketName, remoteId);
    final file = File(localPath);
    await response.pipe(file.openWrite());
    return file;
  }

  @override
  Future<void> deleteFile(String remoteId) async {
    await _client.removeObject(config.bucketName, remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> listBackups() async {
    final list = <Map<String, dynamic>>[];
    try {
      final stream = _client.listObjects(config.bucketName, prefix: 'backups/', recursive: true);
      await for (final chunk in stream) {
        for (final item in chunk.objects) {
          if (item.key != null && item.key!.endsWith('.json')) {
            list.add({
              'id': item.key!,
              'name': item.key!.split('/').last,
              'size': item.size ?? 0,
              'modified': item.lastModified,
            });
          }
        }
      }
    } catch (e) {
      print('S3 List Backups Error: $e');
    }
    return list;
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
