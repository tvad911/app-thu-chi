import 'dart:io';

/// Abstract interface for Cloud Storage providers
abstract class CloudStorageProvider {
  /// Unique identifier for the provider (drive, s3)
  String get providerId;
  
  /// Authenticate with the provider
  /// Returns true if successful
  Future<bool> authenticate();
  
  /// Upload a file to the remote storage
  /// Returns the remote identifier (file ID or path)
  Future<String> uploadFile(File file, String remotePath);
  
  /// Download a file from remote storage
  Future<File> downloadFile(String remoteId, String localPath);
  
  /// Delete a file from remote storage
  Future<void> deleteFile(String remoteId);
  
  /// Check if currently connected/authenticated
  Future<bool> isConnected();
  
  /// Get current user/account info
  Future<Map<String, String>> getUserInfo();
  
  /// Sign out / specific cleanup
  Future<void> signOut();
}

/// Configuration for S3 Provider
class S3Config {
  final String endpoint;
  final String accessKey;
  final String secretKey;
  final String bucketName;
  final String region;
  final bool useSSL;

  S3Config({
    required this.endpoint,
    required this.accessKey,
    required this.secretKey,
    required this.bucketName,
    this.region = 'us-east-1',
    this.useSSL = true,
  });
  
  Map<String, String> toMap() {
    return {
      'endpoint': endpoint,
      'accessKey': accessKey,
      'secretKey': secretKey,
      'bucketName': bucketName,
      'region': region,
      'useSSL': useSSL.toString(),
    };
  }
}
