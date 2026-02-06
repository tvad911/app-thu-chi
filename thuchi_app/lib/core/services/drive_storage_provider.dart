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
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;

      _driveApi = drive.DriveApi(httpClient);
      
      // Initialize app folder check
      await _getOrCreateAppFolder();
      
      return true;
    } catch (e) {
      print('Drive Auth Error: $e');
      return false;
    }
  }

  Future<String> _getOrCreateAppFolder() async {
    if (_appFolderId != null) return _appFolderId!;
    
    // Check if exists
    final q = "mimeType = 'application/vnd.google-apps.folder' and name = '$_appFolderName' and trashed = false";
    final fileList = await _driveApi!.files.list(q: q);
    
    if (fileList.files != null && fileList.files!.isNotEmpty) {
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
    if (_driveApi == null) await authenticate();
    if (_driveApi == null) throw Exception('Drive not authenticated');
    
    final folderId = await _getOrCreateAppFolder();
    final fileName = p.basename(remotePath); // remotePath here is just treated as filename relative to app folder or just name

    // Upload
    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];
    
    final media = drive.Media(file.openRead(), await file.length());
    final result = await _driveApi!.files.create(driveFile, uploadMedia: media);
    
    return result.id!; // Returns Drive File ID
  }

  @override
  Future<File> downloadFile(String remoteId, String localPath) async {
    if (_driveApi == null) await authenticate();
    
    final file = File(localPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final media = await _driveApi!.files.get(remoteId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    
    final sink = file.openWrite();
    await media.stream.pipe(sink);
    
    return file;
  }

  @override
  Future<void> deleteFile(String remoteId) async {
    if (_driveApi == null) await authenticate();
    await _driveApi!.files.delete(remoteId);
  }

  @override
  Future<bool> isConnected() async {
    return _googleSignIn.currentUser != null;
  }
  
  @override
  Future<Map<String, String>> getUserInfo() async {
    final user = _googleSignIn.currentUser;
    return {
      'name': user?.displayName ?? 'Unknown',
      'email': user?.email ?? 'Unknown',
      'photoUrl': user?.photoUrl ?? '',
    };
  }
  
  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
    _currentUser = null;
    _appFolderId = null;
  }
}
