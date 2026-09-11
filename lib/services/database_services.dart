import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/study_session.dart';
import '../models/transaction_item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('studyfin.db');
    return _database!;
  }

  // 1. Inisialisasi Database & Path
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }
  //first time create db
  Future<void> _createDB(Database db, int version) async {
    // Tabel Study
    await db.execute('''
      CREATE TABLE study_sessions (
        studyId INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        topic TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        isDone INTEGER NOT NULL
      )
    ''');

    // Tabel Finance
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        isIncome INTEGER NOT NULL
      )
    ''');
  }

  //study
  Future<int> insertStudySession(StudySession session) async {
    final db = await instance.database;
    return await db.insert('study_sessions', session.toMap());
  }

  Future<List<StudySession>> getAllStudySessions() async {
    final db = await instance.database;
    final result = await db.query('study_sessions', orderBy: 'date DESC');
    return result.map((json) => StudySession.fromMap(json)).toList();
  }

  Future<int> updateStudySession(StudySession session) async {
    final db = await instance.database;
    return await db.update(
      'study_sessions',
      session.toMap(),
      where: 'studyId = ?',
      whereArgs: [session.studyId],
    );
  }

  Future<int> deleteStudySession(int id) async {
    final db = await instance.database;
    return await db.delete(
      'study_sessions',
      where: 'studyId = ?',
      whereArgs: [id],
    );
  }

  //transcation

  Future<int> insertTransaction(TransactionItem item) async {
    final db = await instance.database;
    return await db.insert('transactions', item.toMap());
  }

  Future<List<TransactionItem>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => TransactionItem.fromMap(json)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}