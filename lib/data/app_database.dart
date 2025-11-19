import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Item {
  final int? id;
  final String name;
  final String location;

  Item({
    this.id,
    required this.name,
    required this.location,
  });

  Item copyWith({
    int? id,
    String? name,
    String? location,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
    };
  }

  factory Item.fromMap(Map<String, Object?> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] as String,
      location: map['location'] as String,
    );
  }
}

class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static const _dbName = 'findmystuff.db';
  static const _dbVersion = 1;
  static const _tableItems = 'items';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT NOT NULL
      )
    ''');

    // Seed some starter data so the app feels alive
    final seedItems = <Item>[
      Item(name: 'Toy Box', location: 'Second Shelf → Basement'),
      Item(name: 'Watch', location: 'Bedside Drawer → Bedroom'),
      Item(name: 'Passport', location: 'File Shelf → Study Room'),
      Item(name: 'Car Keys', location: 'Hook Rail → Entrance Hall'),
      Item(name: 'Umbrella', location: 'Corner Stand → Garage'),
    ];

    for (final item in seedItems) {
      await db.insert(_tableItems, item.toMap());
    }
  }

  // ---------- CRUD ----------

  Future<int> insertItem(Item item) async {
    final db = await database;
    return db.insert(
      _tableItems,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Item>> searchItems(String query) async {
    final db = await database;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final like = '%${trimmed.toLowerCase()}%';

    final rows = await db.query(
      _tableItems,
      where: 'LOWER(name) LIKE ?',
      whereArgs: [like],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map((m) => Item.fromMap(m)).toList();
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete(
      _tableItems,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllItems() async {
    final db = await database;
    return db.delete(_tableItems);
  }

  Future<int> getTotalRecords() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM $_tableItems');
    final value = res.first['cnt'] as int?;
    return value ?? 0;
  }

  Future<List<String>> getSomeItemNames({int limit = 5}) async {
    final db = await database;
    final rows = await db.query(
      _tableItems,
      columns: ['name'],
      limit: limit,
    );
    return rows.map((e) => e['name'] as String).toList();
  }
}
