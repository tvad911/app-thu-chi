
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  Future<User?> login(String username, String password) async {
    // In a real app, verify hash. Here we compare plain/simple hash.
    return (_db.select(_db.users)
          ..where((u) => u.username.equals(username) & u.passwordHash.equals(password)))
        .getSingleOrNull();
  }

  Future<int> register(String username, String password, String displayName) {
    return _db.into(_db.users).insert(UsersCompanion(
          username: Value(username),
          passwordHash: Value(password),
          displayName: Value(displayName),
        ));
  }

  Future<User?> getUserById(int id) {
    return (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }
}
