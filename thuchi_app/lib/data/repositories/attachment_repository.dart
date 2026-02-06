import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Repository for Attachment operations
class AttachmentRepository {
  final AppDatabase _db;

  AttachmentRepository(this._db);

  /// Create a new attachment
  Future<int> createAttachment(AttachmentsCompanion attachment) {
    return _db.into(_db.attachments).insert(attachment);
  }

  /// Get attachment by ID
  Future<Attachment?> getAttachmentById(int id) {
    return (_db.select(_db.attachments)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Get all attachments for a transaction
  Future<List<Attachment>> getAttachmentsByTransaction(int transactionId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.transactionId.equals(transactionId))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Get all attachments for a debt
  Future<List<Attachment>> getAttachmentsByDebt(int debtId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.debtId.equals(debtId))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Get all attachments for a bill
  Future<List<Attachment>> getAttachmentsByBill(int billId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.billId.equals(billId))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Delete an attachment
  Future<void> deleteAttachment(int id) {
    return (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
  }

  /// Update sync status
  Future<void> updateSyncStatus({
    required int id,
    required String status,
    String? driveFileId,
    String? errorMessage,
  }) {
    return (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        syncStatus: Value(status),
        driveFileId: Value(driveFileId),
        syncError: Value(errorMessage),
        lastSyncAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get all pending attachments (for sync)
  Future<List<Attachment>> getPendingAttachments() {
    return (_db.select(_db.attachments)
          ..where((a) => a.syncStatus.equals('PENDING'))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt)]))
        .get();
  }

  /// Get all attachments with error status
  Future<List<Attachment>> getErrorAttachments() {
    return (_db.select(_db.attachments)
          ..where((a) => a.syncStatus.equals('ERROR'))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Retry sync for failed attachments
  Future<void> retryFailedSync(int id) {
    return (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
      const AttachmentsCompanion(
        syncStatus: Value('PENDING'),
        syncError: Value(null),
      ),
    );
  }

  /// Get total size of attachments
  Future<int> getTotalAttachmentSize() async {
    final result = await (_db.selectOnly(_db.attachments)
          ..addColumns([_db.attachments.fileSize.sum()]))
        .getSingle();
    return result.read(_db.attachments.fileSize.sum()) ?? 0;
  }
}
