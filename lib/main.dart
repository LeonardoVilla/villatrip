import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TravelPlannerApp());
}

class TravelPlannerApp extends StatelessWidget {
  const TravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roteiro de Viagens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const AppShell();
        }
        return const LoginPage();
      },
    );
  }
}

String formatDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

String formatTimeLabel(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay? parseTimeLabel(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

double parseCurrencyInput(String raw) {
  final normalized = raw
      .replaceAll('R\$', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
  return double.tryParse(normalized) ?? 0;
}

String formatCurrency(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $fixed';
}

class TravelPlace {
  const TravelPlace({
    this.id,
    this.remoteId,
    required this.name,
    required this.location,
    required this.openingTime,
    required this.closingTime,
    required this.commuteDuration,
    required this.transportSchedule,
    required this.updatedAt,
    this.needsSync = true,
    this.visited = false,
  });

  final int? id;
  final String? remoteId;
  final String name;
  final String location;
  final String openingTime;
  final String closingTime;
  final String commuteDuration;
  final String transportSchedule;
  final String updatedAt;
  final bool needsSync;
  final bool visited;

  TravelPlace copyWith({
    int? id,
    String? remoteId,
    String? name,
    String? location,
    String? openingTime,
    String? closingTime,
    String? commuteDuration,
    String? transportSchedule,
    String? updatedAt,
    bool? needsSync,
    bool? visited,
  }) {
    return TravelPlace(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      location: location ?? this.location,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      commuteDuration: commuteDuration ?? this.commuteDuration,
      transportSchedule: transportSchedule ?? this.transportSchedule,
      updatedAt: updatedAt ?? this.updatedAt,
      needsSync: needsSync ?? this.needsSync,
      visited: visited ?? this.visited,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'name': name,
      'location': location,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'commute_duration': commuteDuration,
      'transport_schedule': transportSchedule,
      'updated_at': updatedAt,
      'needs_sync': needsSync ? 1 : 0,
      'visited': visited ? 1 : 0,
    };
  }

  static TravelPlace fromMap(Map<String, Object?> map) {
    return TravelPlace(
      id: map['id'] as int,
      remoteId: map['remote_id'] as String?,
      name: map['name'] as String,
      location: map['location'] as String,
      openingTime: map['opening_time'] as String,
      closingTime: map['closing_time'] as String,
      commuteDuration: map['commute_duration'] as String,
      transportSchedule: map['transport_schedule'] as String,
      updatedAt:
          (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      needsSync: ((map['needs_sync'] as int?) ?? 1) == 1,
      visited: ((map['visited'] as int?) ?? 0) == 1,
    );
  }
}

class DayPlan {
  const DayPlan({
    this.id,
    this.remoteId,
    required this.date,
    required this.title,
    required this.notes,
    required this.createdAt,
    this.needsSync = true,
  });

  final int? id;
  final String? remoteId;
  final String date;
  final String title;
  final String notes;
  final String createdAt;
  final bool needsSync;

  DateTime get parsedDate => DateTime.parse(date);

  DayPlan copyWith({
    int? id,
    String? remoteId,
    String? date,
    String? title,
    String? notes,
    String? createdAt,
    bool? needsSync,
  }) {
    return DayPlan(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      date: date ?? this.date,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'date': date,
      'title': title,
      'notes': notes,
      'created_at': createdAt,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  static DayPlan fromMap(Map<String, Object?> map) {
    return DayPlan(
      id: map['id'] as int,
      remoteId: map['remote_id'] as String?,
      date: map['date'] as String,
      title: (map['title'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at'] as String,
      needsSync: ((map['needs_sync'] as int?) ?? 1) == 1,
    );
  }
}

class DayPlanItem {
  const DayPlanItem({
    this.id,
    this.remoteId,
    required this.dayPlanId,
    required this.placeId,
    this.placeRemoteId,
    required this.arrivalTime,
    required this.leaveTime,
    required this.amountSpent,
    required this.notes,
    required this.sortOrder,
    this.needsSync = true,
  });

  final int? id;
  final String? remoteId;
  final int dayPlanId;
  final int placeId;
  final String? placeRemoteId;
  final String arrivalTime;
  final String leaveTime;
  final double amountSpent;
  final String notes;
  final int sortOrder;
  final bool needsSync;

  DayPlanItem copyWith({
    int? id,
    String? remoteId,
    int? dayPlanId,
    int? placeId,
    String? placeRemoteId,
    String? arrivalTime,
    String? leaveTime,
    double? amountSpent,
    String? notes,
    int? sortOrder,
    bool? needsSync,
  }) {
    return DayPlanItem(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      dayPlanId: dayPlanId ?? this.dayPlanId,
      placeId: placeId ?? this.placeId,
      placeRemoteId: placeRemoteId ?? this.placeRemoteId,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      leaveTime: leaveTime ?? this.leaveTime,
      amountSpent: amountSpent ?? this.amountSpent,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'day_plan_id': dayPlanId,
      'place_id': placeId,
      'place_remote_id': placeRemoteId,
      'arrival_time': arrivalTime,
      'leave_time': leaveTime,
      'amount_spent': amountSpent,
      'notes': notes,
      'sort_order': sortOrder,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  static DayPlanItem fromMap(Map<String, Object?> map) {
    return DayPlanItem(
      id: map['id'] as int,
      remoteId: map['remote_id'] as String?,
      dayPlanId: map['day_plan_id'] as int,
      placeId: map['place_id'] as int,
      placeRemoteId: map['place_remote_id'] as String?,
      arrivalTime: map['arrival_time'] as String,
      leaveTime: map['leave_time'] as String,
      amountSpent: (map['amount_spent'] as num).toDouble(),
      notes: (map['notes'] as String?) ?? '',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      needsSync: ((map['needs_sync'] as int?) ?? 1) == 1,
    );
  }
}

class DayPlanSummary {
  const DayPlanSummary({
    required this.plan,
    required this.totalSpent,
    required this.stopCount,
  });

  final DayPlan plan;
  final double totalSpent;
  final int stopCount;
}

class DayPlanItemDetail {
  const DayPlanItemDetail({required this.item, required this.place});

  final DayPlanItem item;
  final TravelPlace place;
}

class ExpenseReportEntry {
  const ExpenseReportEntry({
    required this.date,
    required this.totalSpent,
    required this.totalTrips,
    required this.totalStops,
  });

  final DateTime date;
  final double totalSpent;
  final int totalTrips;
  final int totalStops;
}

class TravelPlaceRepository {
  static final TravelPlaceRepository instance = TravelPlaceRepository._();
  TravelPlaceRepository._();

  sqflite.Database? _database;
  final List<TravelPlace> _webPlaces = <TravelPlace>[];
  final List<DayPlan> _webDayPlans = <DayPlan>[];
  final List<DayPlanItem> _webDayPlanItems = <DayPlanItem>[];
  int _webPlaceAutoIncrement = 1;
  int _webDayPlanAutoIncrement = 1;
  int _webDayPlanItemAutoIncrement = 1;

  Future<sqflite.Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _open();
    return _database!;
  }

  Future<sqflite.Database> _open() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = p.join(dbPath, 'travel_planner.db');

    return sqflite.openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE places ADD COLUMN remote_id TEXT');
          await db.execute(
            "ALTER TABLE places ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            'ALTER TABLE places ADD COLUMN needs_sync INTEGER NOT NULL DEFAULT 1',
          );
          await db.update('places', {
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE day_plans (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              title TEXT NOT NULL DEFAULT '',
              notes TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE day_plan_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              day_plan_id INTEGER NOT NULL,
              place_id INTEGER NOT NULL,
              arrival_time TEXT NOT NULL,
              leave_time TEXT NOT NULL,
              amount_spent REAL NOT NULL DEFAULT 0,
              notes TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE day_plans ADD COLUMN remote_id TEXT');
          await db.execute(
            'ALTER TABLE day_plans ADD COLUMN needs_sync INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE day_plan_items ADD COLUMN remote_id TEXT',
          );
          await db.execute(
            'ALTER TABLE day_plan_items ADD COLUMN place_remote_id TEXT',
          );
          await db.execute(
            'ALTER TABLE day_plan_items ADD COLUMN needs_sync INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  Future<void> _createTables(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        opening_time TEXT NOT NULL,
        closing_time TEXT NOT NULL,
        commute_duration TEXT NOT NULL,
        transport_schedule TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1,
        visited INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE day_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        date TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE day_plan_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        day_plan_id INTEGER NOT NULL,
        place_id INTEGER NOT NULL,
        place_remote_id TEXT,
        arrival_time TEXT NOT NULL,
        leave_time TEXT NOT NULL,
        amount_spent REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<List<TravelPlace>> getAll() async {
    if (kIsWeb) {
      final places = List<TravelPlace>.from(_webPlaces);
      places.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return places;
    }

    final db = await database;
    final rows = await db.query('places', orderBy: 'name COLLATE NOCASE');
    return rows.map(TravelPlace.fromMap).toList();
  }

  Future<void> insert(TravelPlace place) async {
    if (kIsWeb) {
      _webPlaces.add(
        place.copyWith(
          id: _webPlaceAutoIncrement++,
          updatedAt: DateTime.now().toIso8601String(),
          needsSync: true,
        ),
      );
      return;
    }

    final db = await database;
    await db.insert(
      'places',
      place
          .copyWith(
            updatedAt: DateTime.now().toIso8601String(),
            needsSync: true,
          )
          .toMap()
        ..remove('id'),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> update(TravelPlace place) async {
    if (kIsWeb) {
      final index = _webPlaces.indexWhere((item) => item.id == place.id);
      if (index >= 0) {
        _webPlaces[index] = place.copyWith(
          updatedAt: DateTime.now().toIso8601String(),
          needsSync: true,
        );
      }
      return;
    }

    final db = await database;
    await db.update(
      'places',
      place
          .copyWith(
            updatedAt: DateTime.now().toIso8601String(),
            needsSync: true,
          )
          .toMap()
        ..remove('id'),
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  Future<void> delete(int id) async {
    if (kIsWeb) {
      _webPlaces.removeWhere((item) => item.id == id);
      return;
    }

    final db = await database;
    await db.delete('places', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> placeHasDayPlans(int placeId) async {
    if (kIsWeb) {
      return _webDayPlanItems.any((item) => item.placeId == placeId);
    }

    final db = await database;
    final rows = await db.query(
      'day_plan_items',
      columns: ['id'],
      where: 'place_id = ?',
      whereArgs: [placeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<TravelPlace>> getPendingSync() async {
    if (kIsWeb) {
      return _webPlaces.where((item) => item.needsSync).toList();
    }
    final db = await database;
    final rows = await db.query('places', where: 'needs_sync = 1');
    return rows.map(TravelPlace.fromMap).toList();
  }

  Future<void> markSynced({
    required int localId,
    required String? remoteId,
    required String updatedAt,
  }) async {
    if (kIsWeb) {
      final index = _webPlaces.indexWhere((item) => item.id == localId);
      if (index < 0) {
        return;
      }
      _webPlaces[index] = _webPlaces[index].copyWith(
        remoteId: remoteId,
        updatedAt: updatedAt,
        needsSync: false,
      );
      return;
    }
    final db = await database;
    await db.update(
      'places',
      {'remote_id': remoteId, 'updated_at': updatedAt, 'needs_sync': 0},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertFromRemote(TravelPlace place) async {
    if (place.remoteId == null) {
      return;
    }

    if (kIsWeb) {
      final byRemote = _webPlaces.indexWhere(
        (item) => item.remoteId == place.remoteId,
      );
      if (byRemote >= 0) {
        _webPlaces[byRemote] = place.copyWith(
          id: _webPlaces[byRemote].id,
          needsSync: false,
        );
        return;
      }
      _webPlaces.add(
        place.copyWith(id: _webPlaceAutoIncrement++, needsSync: false),
      );
      return;
    }

    final db = await database;
    final existing = await db.query(
      'places',
      where: 'remote_id = ?',
      whereArgs: [place.remoteId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        'places',
        place.copyWith(needsSync: false).toMap()..remove('id'),
      );
    } else {
      final localId = existing.first['id'] as int;
      await db.update(
        'places',
        place.copyWith(needsSync: false).toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [localId],
      );
    }
  }

  Future<List<DayPlan>> getDayPlans() async {
    if (kIsWeb) {
      final plans = List<DayPlan>.from(_webDayPlans);
      plans.sort((a, b) => b.date.compareTo(a.date));
      return plans;
    }

    final db = await database;
    final rows = await db.query(
      'day_plans',
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(DayPlan.fromMap).toList();
  }

  Future<int> insertDayPlan(DayPlan plan) async {
    if (kIsWeb) {
      final id = _webDayPlanAutoIncrement++;
      _webDayPlans.add(plan.copyWith(id: id));
      return id;
    }

    final db = await database;
    return db.insert('day_plans', plan.toMap()..remove('id'));
  }

  Future<void> updateDayPlan(DayPlan plan) async {
    if (kIsWeb) {
      final index = _webDayPlans.indexWhere((item) => item.id == plan.id);
      if (index >= 0) {
        _webDayPlans[index] = plan;
      }
      return;
    }

    final db = await database;
    await db.update(
      'day_plans',
      plan.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> deleteDayPlan(int id) async {
    if (kIsWeb) {
      _webDayPlanItems.removeWhere((item) => item.dayPlanId == id);
      _webDayPlans.removeWhere((plan) => plan.id == id);
      return;
    }

    final db = await database;
    await db.delete(
      'day_plan_items',
      where: 'day_plan_id = ?',
      whereArgs: [id],
    );
    await db.delete('day_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DayPlanItem>> getDayPlanItems(int dayPlanId) async {
    if (kIsWeb) {
      final items = _webDayPlanItems
          .where((item) => item.dayPlanId == dayPlanId)
          .toList();
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return items;
    }

    final db = await database;
    final rows = await db.query(
      'day_plan_items',
      where: 'day_plan_id = ?',
      whereArgs: [dayPlanId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(DayPlanItem.fromMap).toList();
  }

  Future<int> insertDayPlanItem(DayPlanItem item) async {
    if (kIsWeb) {
      final id = _webDayPlanItemAutoIncrement++;
      _webDayPlanItems.add(item.copyWith(id: id));
      return id;
    }

    final db = await database;
    return db.insert('day_plan_items', item.toMap()..remove('id'));
  }

  Future<void> updateDayPlanItem(DayPlanItem item) async {
    if (kIsWeb) {
      final index = _webDayPlanItems.indexWhere(
        (current) => current.id == item.id,
      );
      if (index >= 0) {
        _webDayPlanItems[index] = item;
      }
      return;
    }

    final db = await database;
    await db.update(
      'day_plan_items',
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteDayPlanItem(int id) async {
    if (kIsWeb) {
      _webDayPlanItems.removeWhere((item) => item.id == id);
      return;
    }

    final db = await database;
    await db.delete('day_plan_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DayPlanSummary>> getDayPlanSummaries() async {
    final plans = await getDayPlans();
    final allPlaces = await getAll();
    final validPlaceIds = {
      for (final place in allPlaces)
        if (place.id != null) place.id!,
    };
    final List<DayPlanSummary> summaries = <DayPlanSummary>[];

    for (final plan in plans) {
      final allItems = await getDayPlanItems(plan.id!);
      // Only count items whose place still exists (same filter as detail page)
      final items = allItems
          .where((item) => validPlaceIds.contains(item.placeId))
          .toList();
      final totalSpent = items.fold<double>(
        0,
        (total, item) => total + item.amountSpent,
      );
      summaries.add(
        DayPlanSummary(
          plan: plan,
          totalSpent: totalSpent,
          stopCount: items.length,
        ),
      );
    }

    return summaries;
  }

  Future<List<DayPlanItemDetail>> getDayPlanItemDetails(int dayPlanId) async {
    final items = await getDayPlanItems(dayPlanId);
    final places = await getAll();
    final byId = {
      for (final place in places)
        if (place.id != null) place.id!: place,
    };

    return items
        .where((item) => byId.containsKey(item.placeId))
        .map(
          (item) => DayPlanItemDetail(item: item, place: byId[item.placeId]!),
        )
        .toList();
  }

  Future<List<ExpenseReportEntry>> getExpenseReportEntries({
    DateTime? from,
    DateTime? to,
  }) async {
    final allSummaries = await getDayPlanSummaries();
    final summaries = allSummaries.where((s) {
      final d = s.plan.parsedDate;
      if (from != null && d.isBefore(from)) return false;
      if (to != null &&
          d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59))) {
        return false;
      }
      return true;
    }).toList();
    final totalsByDate = <String, double>{};
    final tripsByDate = <String, int>{};
    final stopsByDate = <String, int>{};

    for (final summary in summaries) {
      final key = summary.plan.date;
      totalsByDate[key] = (totalsByDate[key] ?? 0) + summary.totalSpent;
      tripsByDate[key] = (tripsByDate[key] ?? 0) + 1;
      stopsByDate[key] = (stopsByDate[key] ?? 0) + summary.stopCount;
    }

    final entries = totalsByDate.entries.map((entry) {
      final key = entry.key;
      return ExpenseReportEntry(
        date: DateTime.parse(key),
        totalSpent: entry.value,
        totalTrips: tripsByDate[key] ?? 0,
        totalStops: stopsByDate[key] ?? 0,
      );
    }).toList();

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  // ── Day plan sync helpers ──────────────────────────────────────────────────

  Future<List<DayPlan>> getPendingDayPlanSync() async {
    if (kIsWeb) {
      return _webDayPlans.where((plan) => plan.needsSync).toList();
    }
    final db = await database;
    final rows = await db.query('day_plans', where: 'needs_sync = 1');
    return rows.map(DayPlan.fromMap).toList();
  }

  Future<void> markDayPlanSynced({
    required int localId,
    required String remoteId,
  }) async {
    if (kIsWeb) {
      final index = _webDayPlans.indexWhere((plan) => plan.id == localId);
      if (index >= 0) {
        _webDayPlans[index] = _webDayPlans[index].copyWith(
          remoteId: remoteId,
          needsSync: false,
        );
      }
      return;
    }
    final db = await database;
    await db.update(
      'day_plans',
      {'remote_id': remoteId, 'needs_sync': 0},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertDayPlanFromRemote(DayPlan plan) async {
    if (plan.remoteId == null) return;
    if (kIsWeb) {
      final index = _webDayPlans.indexWhere((p) => p.remoteId == plan.remoteId);
      if (index >= 0) {
        _webDayPlans[index] = plan.copyWith(
          id: _webDayPlans[index].id,
          needsSync: false,
        );
        return;
      }
      _webDayPlans.add(
        plan.copyWith(id: _webDayPlanAutoIncrement++, needsSync: false),
      );
      return;
    }
    final db = await database;
    final existing = await db.query(
      'day_plans',
      where: 'remote_id = ?',
      whereArgs: [plan.remoteId],
      limit: 1,
    );
    final row = plan.copyWith(needsSync: false).toMap()..remove('id');
    if (existing.isEmpty) {
      await db.insert('day_plans', row);
    } else {
      await db.update(
        'day_plans',
        row,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<int?> getDayPlanLocalId(String remoteId) async {
    if (kIsWeb) {
      return _webDayPlans.where((p) => p.remoteId == remoteId).firstOrNull?.id;
    }
    final db = await database;
    final rows = await db.query(
      'day_plans',
      columns: ['id'],
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first['id'] as int : null;
  }

  Future<List<DayPlanItem>> getPendingDayPlanItemSync() async {
    if (kIsWeb) {
      return _webDayPlanItems.where((item) => item.needsSync).toList();
    }
    final db = await database;
    final rows = await db.query('day_plan_items', where: 'needs_sync = 1');
    return rows.map(DayPlanItem.fromMap).toList();
  }

  Future<void> markDayPlanItemSynced({
    required int localId,
    required String remoteId,
  }) async {
    if (kIsWeb) {
      final index = _webDayPlanItems.indexWhere((item) => item.id == localId);
      if (index >= 0) {
        _webDayPlanItems[index] = _webDayPlanItems[index].copyWith(
          remoteId: remoteId,
          needsSync: false,
        );
      }
      return;
    }
    final db = await database;
    await db.update(
      'day_plan_items',
      {'remote_id': remoteId, 'needs_sync': 0},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertDayPlanItemFromRemote({
    required DayPlanItem item,
    required int localDayPlanId,
  }) async {
    if (item.remoteId == null) return;
    final resolved = item.copyWith(dayPlanId: localDayPlanId, needsSync: false);
    if (kIsWeb) {
      final index = _webDayPlanItems.indexWhere(
        (i) => i.remoteId == item.remoteId,
      );
      if (index >= 0) {
        _webDayPlanItems[index] = resolved.copyWith(
          id: _webDayPlanItems[index].id,
        );
        return;
      }
      _webDayPlanItems.add(
        resolved.copyWith(id: _webDayPlanItemAutoIncrement++),
      );
      return;
    }
    final db = await database;
    final existing = await db.query(
      'day_plan_items',
      where: 'remote_id = ?',
      whereArgs: [item.remoteId],
      limit: 1,
    );
    final row = resolved.toMap()..remove('id');
    if (existing.isEmpty) {
      await db.insert('day_plan_items', row);
    } else {
      await db.update(
        'day_plan_items',
        row,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }
}

class FirestoreSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _placesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('places');

  Future<SyncSummary> sync(TravelPlaceRepository repository) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SyncSummary(pushed: 0, pulled: 0);

    int pushed = 0;
    int pulled = 0;

    final pending = await repository.getPendingSync();
    for (final place in pending) {
      final data = <String, Object?>{
        'name': place.name,
        'location': place.location,
        'openingTime': place.openingTime,
        'closingTime': place.closingTime,
        'commuteDuration': place.commuteDuration,
        'transportSchedule': place.transportSchedule,
        'visited': place.visited,
        'updatedAt': place.updatedAt,
      };

      DocumentReference ref;
      if (place.remoteId != null) {
        ref = _placesCol(uid).doc(place.remoteId);
        await ref.set(data, SetOptions(merge: true));
      } else {
        ref = await _placesCol(uid).add(data);
      }

      if (place.id != null) {
        await repository.markSynced(
          localId: place.id!,
          remoteId: ref.id,
          updatedAt: place.updatedAt,
        );
      }
      pushed++;
    }

    final snapshot = await _placesCol(uid).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final remote = TravelPlace(
        id: null,
        remoteId: doc.id,
        name: (data['name'] as String?) ?? '',
        location: (data['location'] as String?) ?? '',
        openingTime: (data['openingTime'] as String?) ?? '09:00',
        closingTime: (data['closingTime'] as String?) ?? '18:00',
        commuteDuration: (data['commuteDuration'] as String?) ?? '',
        transportSchedule: (data['transportSchedule'] as String?) ?? '',
        visited: (data['visited'] as bool?) ?? false,
        updatedAt:
            (data['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
        needsSync: false,
      );
      await repository.upsertFromRemote(remote);
      pulled++;
    }

    return SyncSummary(pushed: pushed, pulled: pulled);
  }

  Future<void> deleteRemoteById({
    required String uid,
    required String remoteId,
  }) async {
    await _placesCol(uid).doc(remoteId).delete();
  }

  Future<SyncSummary> syncDayPlans(TravelPlaceRepository repository) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SyncSummary(pushed: 0, pulled: 0);

    final plansCol = _firestore
        .collection('users')
        .doc(uid)
        .collection('day_plans');
    int pushed = 0;
    int pulled = 0;

    // Build place localId → remoteId map for push
    final allPlaces = await repository.getAll();
    final placeLocalToRemote = <int, String>{
      for (final p in allPlaces)
        if (p.id != null && p.remoteId != null) p.id!: p.remoteId!,
    };

    // Push pending day plans
    final pendingPlans = await repository.getPendingDayPlanSync();
    for (final plan in pendingPlans) {
      final data = <String, Object?>{
        'date': plan.date,
        'title': plan.title,
        'notes': plan.notes,
        'createdAt': plan.createdAt,
      };
      final DocumentReference planRef;
      if (plan.remoteId != null) {
        planRef = plansCol.doc(plan.remoteId);
        await planRef.set(data, SetOptions(merge: true));
      } else {
        planRef = await plansCol.add(data);
      }
      if (plan.id != null) {
        await repository.markDayPlanSynced(
          localId: plan.id!,
          remoteId: planRef.id,
        );
      }
      pushed++;
    }

    // Push pending day plan items
    final allPlans = await repository.getDayPlans();
    final localToRemotePlan = <int, String>{
      for (final plan in allPlans)
        if (plan.id != null && plan.remoteId != null) plan.id!: plan.remoteId!,
    };
    final pendingItems = await repository.getPendingDayPlanItemSync();
    for (final item in pendingItems) {
      final planRemoteId = localToRemotePlan[item.dayPlanId];
      if (planRemoteId == null) continue;
      final itemsCol = plansCol.doc(planRemoteId).collection('items');
      final data = <String, Object?>{
        'placeRemoteId': placeLocalToRemote[item.placeId],
        'arrivalTime': item.arrivalTime,
        'leaveTime': item.leaveTime,
        'amountSpent': item.amountSpent,
        'notes': item.notes,
        'sortOrder': item.sortOrder,
      };
      final DocumentReference itemRef;
      if (item.remoteId != null) {
        itemRef = itemsCol.doc(item.remoteId);
        await itemRef.set(data, SetOptions(merge: true));
      } else {
        itemRef = await itemsCol.add(data);
      }
      if (item.id != null) {
        await repository.markDayPlanItemSynced(
          localId: item.id!,
          remoteId: itemRef.id,
        );
      }
      pushed++;
    }

    // Pull day plans from Firestore
    final placeRemoteToLocal = <String, int>{
      for (final p in allPlaces)
        if (p.remoteId != null && p.id != null) p.remoteId!: p.id!,
    };
    final planSnapshots = await plansCol.get();
    for (final planDoc in planSnapshots.docs) {
      final d = planDoc.data();
      final remotePlan = DayPlan(
        remoteId: planDoc.id,
        date: (d['date'] as String?) ?? '',
        title: (d['title'] as String?) ?? '',
        notes: (d['notes'] as String?) ?? '',
        createdAt:
            (d['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
        needsSync: false,
      );
      await repository.upsertDayPlanFromRemote(remotePlan);
      final localPlanId = await repository.getDayPlanLocalId(planDoc.id);
      if (localPlanId == null) continue;

      // Pull items for this plan
      final itemsSnapshot = await plansCol
          .doc(planDoc.id)
          .collection('items')
          .get();
      for (final itemDoc in itemsSnapshot.docs) {
        final i = itemDoc.data();
        final placeRemoteId = i['placeRemoteId'] as String?;
        final localPlaceId = placeRemoteId != null
            ? placeRemoteToLocal[placeRemoteId]
            : null;
        if (localPlaceId == null) continue;
        final remoteItem = DayPlanItem(
          remoteId: itemDoc.id,
          dayPlanId: localPlanId,
          placeId: localPlaceId,
          placeRemoteId: placeRemoteId,
          arrivalTime: (i['arrivalTime'] as String?) ?? '',
          leaveTime: (i['leaveTime'] as String?) ?? '',
          amountSpent: (i['amountSpent'] as num?)?.toDouble() ?? 0,
          notes: (i['notes'] as String?) ?? '',
          sortOrder: (i['sortOrder'] as int?) ?? 0,
          needsSync: false,
        );
        await repository.upsertDayPlanItemFromRemote(
          item: remoteItem,
          localDayPlanId: localPlanId,
        );
        pulled++;
      }
      pulled++;
    }

    return SyncSummary(pushed: pushed, pulled: pulled);
  }

  Future<void> deleteDayPlanRemote({
    required String uid,
    required String remoteId,
  }) async {
    final planRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('day_plans')
        .doc(remoteId);
    final items = await planRef.collection('items').get();
    for (final item in items.docs) {
      await item.reference.delete();
    }
    await planRef.delete();
  }

  Future<void> deleteDayPlanItemRemote({
    required String uid,
    required String planRemoteId,
    required String itemRemoteId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('day_plans')
        .doc(planRemoteId)
        .collection('items')
        .doc(itemRemoteId)
        .delete();
  }
}

class SyncSummary {
  const SyncSummary({required this.pushed, required this.pulled});
  final int pushed;
  final int pulled;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int _placesVersion = 0;
  int _plansVersion = 0;

  void _handlePlacesChanged() {
    setState(() {
      _placesVersion++;
    });
  }

  void _handlePlansChanged() {
    setState(() {
      _plansVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          PlaceCatalogPage(
            version: _placesVersion,
            onChanged: _handlePlacesChanged,
          ),
          DayPlansPage(
            plansVersion: _plansVersion,
            placesVersion: _placesVersion,
            onChanged: _handlePlansChanged,
          ),
          ReportsPage(version: _plansVersion),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            _selectedIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Locais',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Role do dia',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Relatorios',
          ),
        ],
      ),
    );
  }
}

class PlaceCatalogPage extends StatefulWidget {
  const PlaceCatalogPage({
    required this.version,
    required this.onChanged,
    super.key,
  });

  final int version;
  final VoidCallback onChanged;

  @override
  State<PlaceCatalogPage> createState() => _PlaceCatalogPageState();
}

class _PlaceCatalogPageState extends State<PlaceCatalogPage> {
  final TravelPlaceRepository _repository = TravelPlaceRepository.instance;
  final FirestoreSyncService _syncService = FirestoreSyncService();
  List<TravelPlace> _places = const [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPlaces().then((_) => _syncNow(silent: true));
  }

  @override
  void didUpdateWidget(covariant PlaceCatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version) {
      _loadPlaces();
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final data = await _repository.getAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _places = data;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Erro ao carregar locais: $error';
      });
    }
  }

  Future<void> _openPlaceForm([TravelPlace? place]) async {
    final draft = await showModalBottomSheet<TravelPlace>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaceFormSheet(initialValue: place),
    );

    if (draft == null) {
      return;
    }

    if (place == null) {
      await _repository.insert(draft);
    } else {
      await _repository.update(
        draft.copyWith(id: place.id, remoteId: place.remoteId),
      );
    }

    widget.onChanged();
    await _loadPlaces();
    await _syncNow(silent: true);
  }

  Future<void> _deletePlace(TravelPlace place) async {
    if (place.id == null) {
      return;
    }

    final isInUse = await _repository.placeHasDayPlans(place.id!);
    if (isInUse) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esse local ja foi usado em um role. Remova do role antes de excluir.',
          ),
        ),
      );
      return;
    }

    if (place.remoteId != null) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await _syncService.deleteRemoteById(
            uid: uid,
            remoteId: place.remoteId!,
          );
        }
      } catch (_) {
        // Mantem remocao local mesmo quando falha no remoto.
      }
    }

    await _repository.delete(place.id!);
    widget.onChanged();
    await _loadPlaces();
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_isSyncing) {
      return;
    }
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncService.sync(_repository);
      await _loadPlaces();
      if (!mounted || silent) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Locais sincronizados. Enviados: ${result.pushed}, recebidos: ${result.pulled}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted || silent) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro na sincronizacao: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Locais cadastrados'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar locais',
            onPressed: _isSyncing ? null : _syncNow,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _loadPlaces();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : _places.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum local cadastrado ainda. Toque no botao + para montar sua base de lugares.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _places.length,
              itemBuilder: (context, index) {
                final place = _places[index];
                final synced = place.remoteId != null && !place.needsSync;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      place.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Localizacao: ${place.location}'),
                          Text(
                            'Funcionamento: ${place.openingTime} - ${place.closingTime}',
                          ),
                          Text('Deslocamento medio: ${place.commuteDuration}'),
                          Text('Transporte: ${place.transportSchedule}'),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          synced ? Icons.cloud_done : Icons.cloud_upload,
                          size: 18,
                          color: synced ? Colors.blue[600] : Colors.orange[400],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openPlaceForm(place);
                            }
                            if (value == 'delete') {
                              _deletePlace(place);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPlaceForm,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Novo local'),
      ),
    );
  }
}

class DayPlansPage extends StatefulWidget {
  const DayPlansPage({
    required this.plansVersion,
    required this.placesVersion,
    required this.onChanged,
    super.key,
  });

  final int plansVersion;
  final int placesVersion;
  final VoidCallback onChanged;

  @override
  State<DayPlansPage> createState() => _DayPlansPageState();
}

class _DayPlansPageState extends State<DayPlansPage> {
  final TravelPlaceRepository _repository = TravelPlaceRepository.instance;
  final FirestoreSyncService _syncService = FirestoreSyncService();
  List<DayPlanSummary> _summaries = const [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPlans().then((_) => _syncNow(silent: true));
  }

  @override
  void didUpdateWidget(covariant DayPlansPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plansVersion != widget.plansVersion ||
        oldWidget.placesVersion != widget.placesVersion) {
      _loadPlans();
    }
  }

  Future<void> _loadPlans() async {
    try {
      final summaries = await _repository.getDayPlanSummaries();
      if (!mounted) {
        return;
      }
      setState(() {
        _summaries = summaries;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Erro ao carregar roles: $error';
      });
    }
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });
    try {
      await _syncService.syncDayPlans(_repository);
      await _loadPlans();
      if (!mounted || silent) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Roles sincronizados.')));
    } catch (error) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro na sincronizacao: $error')));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _createPlan() async {
    final draft = await showModalBottomSheet<DayPlan>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const DayPlanFormSheet(),
    );

    if (draft == null) {
      return;
    }

    final id = await _repository.insertDayPlan(draft);
    final saved = draft.copyWith(id: id);
    widget.onChanged();
    await _loadPlans();

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayPlanDetailPage(
          initialPlan: saved,
          placesVersion: widget.placesVersion,
        ),
      ),
    );

    widget.onChanged();
    await _loadPlans();
  }

  Future<void> _editPlan(DayPlan plan) async {
    final draft = await showModalBottomSheet<DayPlan>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DayPlanFormSheet(initialValue: plan),
    );

    if (draft == null) {
      return;
    }

    await _repository.updateDayPlan(
      draft.copyWith(
        id: plan.id,
        createdAt: plan.createdAt,
        remoteId: plan.remoteId,
        needsSync: true,
      ),
    );
    widget.onChanged();
    await _loadPlans();
  }

  Future<void> _deletePlan(DayPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir role'),
        content: Text(
          'Deseja excluir o role de ${formatDateLabel(plan.parsedDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || plan.id == null) {
      return;
    }

    await _repository.deleteDayPlan(plan.id!);
    // Delete from Firestore if synced
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && plan.remoteId != null) {
      await _syncService.deleteDayPlanRemote(
        uid: uid,
        remoteId: plan.remoteId!,
      );
    }
    widget.onChanged();
    await _loadPlans();
  }

  Future<void> _openPlan(DayPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayPlanDetailPage(
          initialPlan: plan,
          placesVersion: widget.placesVersion,
        ),
      ),
    );
    widget.onChanged();
    await _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role do dia'),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Sincronizar roles',
              icon: const Icon(Icons.cloud_sync_outlined),
              onPressed: _syncNow,
            ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : _summaries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum role criado. Toque no botao abaixo para definir data, horarios e gastos do dia.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _summaries.length,
              itemBuilder: (context, index) {
                final summary = _summaries[index];
                final plan = summary.plan;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    onTap: () => _openPlan(plan),
                    title: Text(
                      plan.title.isEmpty
                          ? 'Role de ${formatDateLabel(plan.parsedDate)}'
                          : plan.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Data: ${formatDateLabel(plan.parsedDate)}'),
                          Text('Locais escolhidos: ${summary.stopCount}'),
                          Text(
                            'Gasto do dia: ${formatCurrency(summary.totalSpent)}',
                          ),
                          if (plan.notes.isNotEmpty)
                            Text('Observacoes: ${plan.notes}'),
                        ],
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editPlan(plan);
                        }
                        if (value == 'delete') {
                          _deletePlan(plan);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar dados do role'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir role'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlan,
        icon: const Icon(Icons.add_road_outlined),
        label: const Text('Novo role'),
      ),
    );
  }
}

class DayPlanDetailPage extends StatefulWidget {
  const DayPlanDetailPage({
    required this.initialPlan,
    required this.placesVersion,
    super.key,
  });

  final DayPlan initialPlan;
  final int placesVersion;

  @override
  State<DayPlanDetailPage> createState() => _DayPlanDetailPageState();
}

class _DayPlanDetailPageState extends State<DayPlanDetailPage> {
  final TravelPlaceRepository _repository = TravelPlaceRepository.instance;
  final FirestoreSyncService _syncService = FirestoreSyncService();
  late DayPlan _plan;
  List<DayPlanItemDetail> _items = const [];
  List<TravelPlace> _places = const [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      var items = await _repository.getDayPlanItemDetails(_plan.id!);
      var places = await _repository.getAll();
      // Sync if local data is missing (e.g. web in-memory cleared on refresh)
      if (places.isEmpty || (items.isEmpty && _plan.remoteId != null)) {
        await _syncService.sync(_repository);
        await _syncService.syncDayPlans(_repository);
        items = await _repository.getDayPlanItemDetails(_plan.id!);
        places = await _repository.getAll();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _places = places;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Erro ao carregar detalhes do role: $error';
      });
    }
  }

  Future<void> _editPlan() async {
    final draft = await showModalBottomSheet<DayPlan>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DayPlanFormSheet(initialValue: _plan),
    );

    if (draft == null) {
      return;
    }

    final updated = draft.copyWith(
      id: _plan.id,
      createdAt: _plan.createdAt,
      remoteId: _plan.remoteId,
      needsSync: true,
    );
    await _repository.updateDayPlan(updated);
    setState(() {
      _plan = updated;
    });
  }

  Future<void> _openItemForm([DayPlanItemDetail? detail]) async {
    if (_places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre pelo menos um local antes de montar o role do dia.',
          ),
        ),
      );
      return;
    }

    final draft = await showModalBottomSheet<DayPlanItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DayPlanItemFormSheet(
        places: _places,
        dayPlanId: _plan.id!,
        sortOrder: detail?.item.sortOrder ?? _items.length,
        initialValue: detail?.item,
      ),
    );

    if (draft == null) {
      return;
    }

    if (detail == null) {
      await _repository.insertDayPlanItem(draft);
    } else {
      await _repository.updateDayPlanItem(
        draft.copyWith(
          id: detail.item.id,
          remoteId: detail.item.remoteId,
          placeRemoteId: detail.item.placeRemoteId,
          needsSync: true,
        ),
      );
    }

    await _loadData();
  }

  Future<void> _deleteItem(DayPlanItemDetail detail) async {
    if (detail.item.id == null) {
      return;
    }
    await _repository.deleteDayPlanItem(detail.item.id!);
    // Delete from Firestore if synced
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final planRemoteId = _plan.remoteId;
    final itemRemoteId = detail.item.remoteId;
    if (uid != null && planRemoteId != null && itemRemoteId != null) {
      await _syncService.deleteDayPlanItemRemote(
        uid: uid,
        planRemoteId: planRemoteId,
        itemRemoteId: itemRemoteId,
      );
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = _items.fold<double>(
      0,
      (total, detail) => total + detail.item.amountSpent,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _plan.title.isEmpty
              ? 'Role de ${formatDateLabel(_plan.parsedDate)}'
              : _plan.title,
        ),
        actions: [
          IconButton(
            tooltip: 'Editar role',
            onPressed: _editPlan,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planejamento do dia',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text('Data: ${formatDateLabel(_plan.parsedDate)}'),
                          Text('Total gasto: ${formatCurrency(totalSpent)}'),
                          Text('Quantidade de paradas: ${_items.length}'),
                          if (_plan.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Observacoes: ${_plan.notes}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhum local selecionado neste role. Use o botao abaixo para escolher os locais, horarios e gastos.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final detail = _items[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  detail.place.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chegada: ${detail.item.arrivalTime}',
                                      ),
                                      Text(
                                        'Saida prevista: ${detail.item.leaveTime}',
                                      ),
                                      Text(
                                        'Gasto no local: ${formatCurrency(detail.item.amountSpent)}',
                                      ),
                                      Text(
                                        'Endereco: ${detail.place.location}',
                                      ),
                                      if (detail.item.notes.isNotEmpty)
                                        Text(
                                          'Observacoes: ${detail.item.notes}',
                                        ),
                                    ],
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openItemForm(detail);
                                    }
                                    if (value == 'delete') {
                                      _deleteItem(detail);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar parada'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Excluir parada'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openItemForm,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Adicionar local'),
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.version, super.key});

  final int version;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TravelPlaceRepository _repository = TravelPlaceRepository.instance;
  List<ExpenseReportEntry> _entries = const [];
  bool _isLoading = true;
  String? _loadError;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version) {
      _loadReports();
    }
  }

  Future<void> _loadReports() async {
    try {
      final entries = await _repository.getExpenseReportEntries(
        from: _fromDate,
        to: _toDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Erro ao carregar relatorios: $error';
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _fromDate = picked);
    await _loadReports();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _toDate = picked);
    await _loadReports();
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = _entries.fold<double>(
      0,
      (total, entry) => total + entry.totalSpent,
    );
    final totalTrips = _entries.fold<int>(
      0,
      (tripCount, entry) => tripCount + entry.totalTrips,
    );
    final hasFilter = _fromDate != null || _toDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatorios'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                // Date range filter
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFrom,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _fromDate != null
                                ? 'De: ${formatDateLabel(_fromDate!)}'
                                : 'Data inicial',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTo,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _toDate != null
                                ? 'Ate: ${formatDateLabel(_toDate!)}'
                                : 'Data final',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (hasFilter)
                        IconButton(
                          tooltip: 'Limpar filtro',
                          icon: const Icon(Icons.clear),
                          onPressed: _clearFilter,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ReportHighlightCard(
                          label: 'Gasto total',
                          value: formatCurrency(totalSpent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReportHighlightCard(
                          label: 'Roles',
                          value: totalTrips.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ainda nao existem gastos registrados. Crie um role e lance os valores em cada local.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  formatDateLabel(entry.date),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gasto total: ${formatCurrency(entry.totalSpent)}',
                                      ),
                                      Text('Roles no dia: ${entry.totalTrips}'),
                                      Text(
                                        'Locais visitados: ${entry.totalStops}',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ReportHighlightCard extends StatelessWidget {
  const _ReportHighlightCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceFormSheet extends StatefulWidget {
  const PlaceFormSheet({this.initialValue, super.key});

  final TravelPlace? initialValue;

  @override
  State<PlaceFormSheet> createState() => _PlaceFormSheetState();
}

class _PlaceFormSheetState extends State<PlaceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _openingController;
  late final TextEditingController _closingController;
  late final TextEditingController _commuteController;
  late final TextEditingController _transportController;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _nameController = TextEditingController(text: value?.name ?? '');
    _locationController = TextEditingController(text: value?.location ?? '');
    _openingController = TextEditingController(
      text: value?.openingTime ?? '09:00',
    );
    _closingController = TextEditingController(
      text: value?.closingTime ?? '18:00',
    );
    _commuteController = TextEditingController(
      text: value?.commuteDuration ?? '30 min',
    );
    _transportController = TextEditingController(
      text: value?.transportSchedule ?? 'Onibus 08:30 / 10:00',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _openingController.dispose();
    _closingController.dispose();
    _commuteController.dispose();
    _transportController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initial = parseTimeLabel(controller.text) ?? TimeOfDay.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null) {
      return;
    }
    controller.text = formatTimeLabel(selected);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      TravelPlace(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        openingTime: _openingController.text.trim(),
        closingTime: _closingController.text.trim(),
        commuteDuration: _commuteController.text.trim(),
        transportSchedule: _transportController.text.trim(),
        updatedAt: DateTime.now().toIso8601String(),
        needsSync: true,
        visited: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialValue == null ? 'Novo local' : 'Editar local',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do local',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o nome do local'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Localizacao / Endereco',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe a localizacao'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _openingController,
                      readOnly: true,
                      onTap: () => _pickTime(_openingController),
                      decoration: const InputDecoration(
                        labelText: 'Abre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _closingController,
                      readOnly: true,
                      onTap: () => _pickTime(_closingController),
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commuteController,
                decoration: const InputDecoration(
                  labelText: 'Tempo de deslocamento',
                  hintText: 'Ex: 25 min de metro',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o deslocamento'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _transportController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Horario de transporte',
                  hintText: 'Ex: Trem 08:10, 09:00, 09:50',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o horario de transporte'
                    : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar local'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DayPlanFormSheet extends StatefulWidget {
  const DayPlanFormSheet({this.initialValue, super.key});

  final DayPlan? initialValue;

  @override
  State<DayPlanFormSheet> createState() => _DayPlanFormSheetState();
}

class _DayPlanFormSheetState extends State<DayPlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialValue?.title ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialValue?.notes ?? '',
    );
    _selectedDate = widget.initialValue?.parsedDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedDate = selected;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      DayPlan(
        date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ).toIso8601String(),
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt:
            widget.initialValue?.createdAt ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialValue == null
                    ? 'Novo role do dia'
                    : 'Editar role do dia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titulo do role',
                  hintText: 'Ex: Centro com cinema e jantar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Data: ${formatDateLabel(_selectedDate)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observacoes do dia',
                  hintText: 'Ex: sair cedo por causa do transito',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar role'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DayPlanItemFormSheet extends StatefulWidget {
  const DayPlanItemFormSheet({
    required this.places,
    required this.dayPlanId,
    required this.sortOrder,
    this.initialValue,
    super.key,
  });

  final List<TravelPlace> places;
  final int dayPlanId;
  final int sortOrder;
  final DayPlanItem? initialValue;

  @override
  State<DayPlanItemFormSheet> createState() => _DayPlanItemFormSheetState();
}

class _DayPlanItemFormSheetState extends State<DayPlanItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _arrivalController;
  late final TextEditingController _leaveController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  int? _selectedPlaceId;

  @override
  void initState() {
    super.initState();
    _arrivalController = TextEditingController(
      text: widget.initialValue?.arrivalTime ?? '18:00',
    );
    _leaveController = TextEditingController(
      text: widget.initialValue?.leaveTime ?? '20:00',
    );
    _amountController = TextEditingController(
      text: widget.initialValue != null
          ? widget.initialValue!.amountSpent
                .toStringAsFixed(2)
                .replaceAll('.', ',')
          : '0,00',
    );
    _notesController = TextEditingController(
      text: widget.initialValue?.notes ?? '',
    );
    _selectedPlaceId = widget.initialValue?.placeId ?? widget.places.first.id;
  }

  @override
  void dispose() {
    _arrivalController.dispose();
    _leaveController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initial = parseTimeLabel(controller.text) ?? TimeOfDay.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null) {
      return;
    }
    controller.text = formatTimeLabel(selected);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedPlaceId == null) {
      return;
    }

    Navigator.of(context).pop(
      DayPlanItem(
        dayPlanId: widget.dayPlanId,
        placeId: _selectedPlaceId!,
        arrivalTime: _arrivalController.text.trim(),
        leaveTime: _leaveController.text.trim(),
        amountSpent: parseCurrencyInput(_amountController.text),
        notes: _notesController.text.trim(),
        sortOrder: widget.sortOrder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialValue == null
                    ? 'Adicionar local ao role'
                    : 'Editar parada do role',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedPlaceId,
                decoration: const InputDecoration(
                  labelText: 'Local',
                  border: OutlineInputBorder(),
                ),
                items: widget.places
                    .where((place) => place.id != null)
                    .map(
                      (place) => DropdownMenuItem<int>(
                        value: place.id,
                        child: Text(place.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlaceId = value;
                  });
                },
                validator: (value) => value == null ? 'Escolha um local' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _arrivalController,
                      readOnly: true,
                      onTap: () => _pickTime(_arrivalController),
                      decoration: const InputDecoration(
                        labelText: 'Chegada',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _leaveController,
                      readOnly: true,
                      onTap: () => _pickTime(_leaveController),
                      decoration: const InputDecoration(
                        labelText: 'Saida',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quanto gastei no local',
                  hintText: 'Ex: 45,90',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observacoes',
                  hintText: 'Ex: reservar mesa ou comprar ingresso antes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Salvar parada'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'user-not-found' ||
          'invalid-credential' => 'Email ou senha incorretos.',
          'wrong-password' => 'Senha incorreta.',
          'invalid-email' => 'Email invalido.',
          'user-disabled' => 'Conta desativada.',
          'too-many-requests' => 'Muitas tentativas. Tente mais tarde.',
          _ => 'Erro ao entrar: ${e.message}',
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/iconetelalogin.png',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 180,
                          width: double.infinity,
                          alignment: Alignment.center,
                          color: colors.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Roteiro de Viagens',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre com sua conta para continuar',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Informe o email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Minimo 6 caracteres'
                          : null,
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colors.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _signIn,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_isLoading ? 'Entrando...' : 'Entrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
