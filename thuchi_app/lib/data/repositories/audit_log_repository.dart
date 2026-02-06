import 'package:drift/drift.dart';
import '../database/app_database.dart';

class AuditLogRepository {
  final AppDatabase _db;

  AuditLogRepository(this._db);

  /// Watch recent audit logs
  Stream<List<AuditLog>> watchRecentLogs(int limit) {
    return (_db.select(_db.auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  /// Get all logs for a specific entity
  Future<List<AuditLog>> getLogsForEntity(String entityType, int entityId) {
    return (_db.select(_db.auditLogs)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }
}
