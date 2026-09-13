import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:motocaja/models/movement.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  static const String _databaseName = 'motocaja.db';

  static const int _databaseVersion = 2;

  static const String movementsTable = 'movements';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,

      onCreate: (db, version) async {
        await _createTables(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createMovementsTable(db);
        }
      },

      onOpen: (db) async {
        await _createMovementsTable(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await _createMovementsTable(db);
  }

  Future<void> _createMovementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $movementsTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<List<Movement>> getAllMovements() async {
    final db = await database;

    final result = await db.query(movementsTable, orderBy: 'date DESC');

    return result.map((row) => Movement.fromDatabaseMap(row)).toList();
  }

  Future<void> insertMovement(Movement movement) async {
    final db = await database;

    await db.insert(
      movementsTable,
      movement.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMovements(List<Movement> movements) async {
    final db = await database;

    final batch = db.batch();

    for (final movement in movements) {
      batch.insert(
        movementsTable,
        movement.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> updateMovement(Movement movement) async {
    final db = await database;

    await db.update(
      movementsTable,
      movement.toDatabaseMap(),
      where: 'id = ?',
      whereArgs: [movement.id],
    );
  }

  Future<void> deleteMovement(String id) async {
    final db = await database;

    await db.delete(movementsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllMovements() async {
    final db = await database;

    await db.delete(movementsTable);
  }
}
