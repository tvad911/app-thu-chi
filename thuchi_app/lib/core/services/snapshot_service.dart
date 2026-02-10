import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'data_service.dart';

class SnapshotService {
  final DataService _dataService;
  
  SnapshotService(this._dataService);

  Future<Directory> get _snapshotDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final snapshotDir = Directory(p.join(appDir.path, 'snapshots'));
    if (!await snapshotDir.exists()) {
      await snapshotDir.create(recursive: true);
    }
    return snapshotDir;
  }

  Future<List<File>> listSnapshots() async {
    final dir = await _snapshotDir;
    final entities = dir.listSync();
    return entities.whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  }

  Future<void> createSnapshot(String name) async {
    final data = await _dataService.exportData();
    final jsonString = jsonEncode(data);
    
    // Sanitize name
    final safeName = name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_$safeName.json';
    
    final dir = await _snapshotDir;
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(jsonString);
  }

  Future<void> restoreSnapshot(File file) async {
    await _dataService.importFromFile(file);
  }

  Future<void> deleteSnapshot(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  final dataService = ref.watch(dataServiceProvider);
  return SnapshotService(dataService);
});

final snapshotListProvider = FutureProvider.autoDispose<List<File>>((ref) async {
  final service = ref.watch(snapshotServiceProvider);
  return service.listSnapshots();
});
