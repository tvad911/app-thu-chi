import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class FileStorageService {
  static const _uuid = Uuid();
  
  /// Get the app documents directory
  Future<Directory> get _documentsDir async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get the attachments root directory
  Future<Directory> get _attachmentsDir async {
    final docs = await _documentsDir;
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Compress and save an image/file to local storage
  /// Returns the relative path
  Future<Map<String, dynamic>> saveFile(File sourceFile) async {
    final ext = p.extension(sourceFile.path).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.heic'].contains(ext);
    
    final fileName = '${_uuid.v4()}$ext'; // Random unique filename
    final attachmentsDir = await _attachmentsDir;
    final targetPath = p.join(attachmentsDir.path, fileName);
    
    int fileSize = 0;

    if (isImage) {
      // Compress Logic
      try {
        // flutter_image_compress only supports limited formats for output (jpg, png, webp)
        // We typically convert to jpg for efficiency
        final result = await FlutterImageCompress.compressAndGetFile(
          sourceFile.absolute.path,
          targetPath,
          quality: 70,
          minWidth: 1024,
          minHeight: 1024,
        );
        
        if (result != null) {
          fileSize = await result.length();
        } else {
          // Fallback if compression fails (e.g. valid file but compress error)
          await sourceFile.copy(targetPath);
          fileSize = await sourceFile.length();
        }
      } catch (e) {
        // Fallback
        await sourceFile.copy(targetPath);
        fileSize = await sourceFile.length();
      }
    } else {
      // Just copy docs/pdfs
      await sourceFile.copy(targetPath);
      fileSize = await sourceFile.length();
    }
    
    // Return metadata
    return {
      'fileName': fileName,
      'localPath': 'attachments/$fileName', // Relative path
      'format': isImage ? 'image/jpeg' : 'application/octet-stream', // simplified
      'size': fileSize,
    };
  }

  /// Retrieve a file object from relative path
  Future<File?> getFile(String relativePath) async {
    final docs = await _documentsDir;
    final fullPath = p.join(docs.path, relativePath);
    final file = File(fullPath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Delete a local file
  Future<void> deleteFile(String relativePath) async {
    final docs = await _documentsDir;
    final fullPath = p.join(docs.path, relativePath);
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
