import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;
import 'cloud_models.dart';

class GoogleDriveProvider implements CloudStorageProvider {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );
  
  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _currentUser;
  
  static const String _appFolderName = 'MyFinanceApp_Data';
  String? _appFolderId;

  @override
  String get providerId => 'drive';

  @override
  Future<bool> authenticate() async {
    try {
      // 1. Sign In
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;

      // 2. Get Authenticated Client
      // Note: This requires the extension package
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;

      // 3. Init Drive API
      _driveApi = drive.DriveApi(httpClient);
      
      // 4. Initialize App Folder
      await _getOrCreateAppFolder();
      
      return true;
    } catch (e) {
      print('Drive Auth Error: $e');
      return false;
    }
  }

  Future<String> _getOrCreateAppFolder() async {
    if (_appFolderId != null) return _appFolderId!;
    if (_driveApi == null) throw Exception('Drive API not initialized');
    
    // Check if folder exists
    final q = "mimeType = 'application/vnd.google-apps.folder' and name = '$_appFolderName' and trashed = false";
    final fileList = await _driveApi!.files.list(q: q);
    
    if (fileList.files?.isNotEmpty == true) {
      _appFolderId = fileList.files!.first.id;
    } else {
      // Create it
      final folder = drive.File()
        ..name = _appFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      final created = await _driveApi!.files.create(folder);
      _appFolderId = created.id;
    }
    return _appFolderId!;
  }

  @override
  Future<String> uploadFile(File file, String remotePath) async {
    if (_driveApi == null) {
      final success = await authenticate();
      if (!success) throw Exception('Drive authentication failed');
    }
    
    final folderId = await _getOrCreateAppFolder();
    // Use basename of remotePath as the filename on Drive
    final fileName = p.basename(remotePath); 
    
    // Check if file exists in the specific folder
    final q = "'$folderId' in parents and name = '$fileName' and trashed = false";
    final list = await _driveApi!.files.list(q: q);
    
    final media = drive.Media(file.openRead(), await file.length());

    if (list.files?.isNotEmpty == true) {
      // Update existing file
      final existingId = list.files!.first.id!;
      await _driveApi!.files.update(
          drive.File(), 
          existingId, 
          uploadMedia: media
      );
      print('Drive: Updated file $fileName ($existingId)');
      return existingId;
    } else {
      // Create new file
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];
      
      final result = await _driveApi!.files.create(driveFile, uploadMedia: media);
      print('Drive: Created file $fileName (${result.id})');
      return result.id!;
    }
  }

  @override
  Future<File> downloadFile(String remoteId, String localPath) async {
    if (_driveApi == null) {
        final success = await authenticate();
        if (!success) throw Exception('Drive authentication failed');
    }
    
    final file = File(localPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    try {
      final media = await _driveApi!.files.get(remoteId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final sink = file.openWrite();
      await media.stream.pipe(sink);
      await sink.close();
      return file;
    } catch (e) {
      print('Drive Download Error: $e');
      throw Exception('Failed to download file: $e');
    }
  }

  @override
  Future<void> deleteFile(String remoteId) async {
    if (_driveApi == null) {
        final success = await authenticate();
        if (!success) throw Exception('Drive authentication failed');
    }
    try {
      await _driveApi!.files.delete(remoteId);
    } catch (e) {
       print('Drive Delete Error: $e');
       // Ignore if not found
    }
  }

  @override
  Future<bool> isConnected() async {
    // Check if sign in is silent possible
    if (_googleSignIn.currentUser == null) {
       try {
         await _googleSignIn.signInSilently();
       } catch (e) {
         // Ignore silent sign-in errors
       }
    }
    return _googleSignIn.currentUser != null;
  }
  
  @override
  Future<Map<String, String>> getUserInfo() async {
    final user = _googleSignIn.currentUser;
    return {
      'name': user?.displayName ?? 'Người dùng',
      'email': user?.email ?? '',
      'photoUrl': user?.photoUrl ?? '',
    };
  }
  
  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('SignOut error: $e');
    }
    _driveApi = null;
    _currentUser = null;
    _appFolderId = null;
  }
}
