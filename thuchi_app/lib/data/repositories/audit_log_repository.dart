import 'package:drift/drift.dart';
import '../database/app_database.dart';

class AuditLogRepository {
  final AppDatabase _db;

  AuditLogRepository(this._db);

  /// Watch recent audit logs
  Stream<List<AuditLog>> watchRecentLogs({int limit = 100}) {
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
  /// Get recent audit logs
  Future<List<AuditLog>> getRecentLogs({int limit = 100}) {
    return (_db.select(_db.auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }

  /// Get logs by entity type (e.g., 'Transaction')
  Future<List<AuditLog>> getLogsByEntityType(String type, {int limit = 100}) {
    return (_db.select(_db.auditLogs)
          ..where((t) => t.entityType.equals(type))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }
  
  /// Watch logs by entity type
  Stream<List<AuditLog>> watchLogsByEntityType(String type, {int limit = 100}) {
    return (_db.select(_db.auditLogs)
          ..where((t) => t.entityType.equals(type))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  /// Clear all logs
  Future<int> clearLogs() {
    return _db.delete(_db.auditLogs).go();
  }
}
