import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const PlaceListPage(),
    );
  }
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
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
      needsSync: ((map['needs_sync'] as int?) ?? 1) == 1,
      visited: (map['visited'] as int) == 1,
    );
  }

  Map<String, Object?> toApiMap() {
    return {
      '_id': remoteId,
      'name': name,
      'location': location,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'commuteDuration': commuteDuration,
      'transportSchedule': transportSchedule,
      'visited': visited,
      'updatedAt': updatedAt,
    };
  }

  static TravelPlace fromApiMap(Map<String, dynamic> map) {
    return TravelPlace(
      id: null,
      remoteId: map['_id'] as String?,
      name: (map['name'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      openingTime: (map['openingTime'] as String?) ?? '09:00',
      closingTime: (map['closingTime'] as String?) ?? '18:00',
      commuteDuration: (map['commuteDuration'] as String?) ?? '',
      transportSchedule: (map['transportSchedule'] as String?) ?? '',
      visited: (map['visited'] as bool?) ?? false,
      updatedAt: (map['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
      needsSync: false,
    );
  }
}

class TravelPlaceRepository {
  static final TravelPlaceRepository instance = TravelPlaceRepository._();
  TravelPlaceRepository._();

  sqflite.Database? _database;
  final List<TravelPlace> _webPlaces = <TravelPlace>[];
  int _webAutoIncrement = 1;

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
      version: 2,
      onCreate: (db, version) async {
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
          await db.update('places', {'updated_at': DateTime.now().toIso8601String()});
        }
      },
    );
  }

  Future<List<TravelPlace>> getAll() async {
    if (kIsWeb) {
      final places = List<TravelPlace>.from(_webPlaces);
      places.sort((a, b) {
        final byVisited = (a.visited ? 1 : 0).compareTo(b.visited ? 1 : 0);
        if (byVisited != 0) {
          return byVisited;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return places;
    }

    final db = await database;
    final rows = await db.query('places', orderBy: 'visited ASC, name COLLATE NOCASE');
    return rows.map(TravelPlace.fromMap).toList();
  }

  Future<void> insert(TravelPlace place) async {
    if (kIsWeb) {
      _webPlaces.add(
        place.copyWith(
          id: _webAutoIncrement++,
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
      {
        'remote_id': remoteId,
        'updated_at': updatedAt,
        'needs_sync': 0,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertFromRemote(TravelPlace place) async {
    if (place.remoteId == null) {
      return;
    }

    if (kIsWeb) {
      final byRemote = _webPlaces.indexWhere((item) => item.remoteId == place.remoteId);
      if (byRemote >= 0) {
        _webPlaces[byRemote] = place.copyWith(
          id: _webPlaces[byRemote].id,
          needsSync: false,
        );
        return;
      }
      _webPlaces.add(
        place.copyWith(
          id: _webAutoIncrement++,
          needsSync: false,
        ),
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
}

class MongoSyncService {
  MongoSyncService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = String.fromEnvironment(
    'MONGO_API_URL',
    defaultValue: 'http://localhost:3000',
  );

  Future<SyncSummary> sync(TravelPlaceRepository repository) async {
    int pushed = 0;
    int pulled = 0;

    final pending = await repository.getPendingSync();
    for (final place in pending) {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/places/upsert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(place.toApiMap()),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Falha no push para Mongo: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = body['place'] as Map<String, dynamic>;
      final remoteId = remote['_id'] as String?;
      final updatedAt = (remote['updatedAt'] as String?) ?? DateTime.now().toIso8601String();

      if (place.id != null) {
        await repository.markSynced(
          localId: place.id!,
          remoteId: remoteId,
          updatedAt: updatedAt,
        );
      }
      pushed++;
    }

    final response = await _client.get(Uri.parse('$_baseUrl/api/places'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha no pull do Mongo: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['places'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TravelPlace.fromApiMap)
        .toList();

    for (final place in data) {
      await repository.upsertFromRemote(place);
      pulled++;
    }

    return SyncSummary(pushed: pushed, pulled: pulled);
  }

  Future<void> deleteRemoteById(String remoteId) async {
    final response = await _client.delete(Uri.parse('$_baseUrl/api/places/$remoteId'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao excluir no Mongo: ${response.statusCode}');
    }
  }
}

class SyncSummary {
  const SyncSummary({required this.pushed, required this.pulled});
  final int pushed;
  final int pulled;
}

class PlaceListPage extends StatefulWidget {
  const PlaceListPage({super.key});

  @override
  State<PlaceListPage> createState() => _PlaceListPageState();
}

class _PlaceListPageState extends State<PlaceListPage> {
  final TravelPlaceRepository _repository = TravelPlaceRepository.instance;
  final MongoSyncService _syncService = MongoSyncService();
  List<TravelPlace> _places = const [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
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
        _loadError = 'Erro ao carregar dados: $error';
      });
    }
  }

  Future<void> _openPlaceForm([TravelPlace? place]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlaceFormSheet(
        initialValue: place,
        onSave: (value) async {
          if (place == null) {
            await _repository.insert(value);
          } else {
            await _repository.update(value.copyWith(id: place.id));
          }
        },
      ),
    );

    if (saved == true) {
      await _loadPlaces();
    }
  }

  Future<void> _toggleVisited(TravelPlace place, bool value) async {
    await _repository.update(place.copyWith(visited: value));
    await _loadPlaces();
  }

  Future<void> _deletePlace(TravelPlace place) async {
    if (place.id == null) {
      return;
    }

    if (place.remoteId != null) {
      try {
        await _syncService.deleteRemoteById(place.remoteId!);
      } catch (_) {
        // Mantem remocao local mesmo quando falha no remoto.
      }
    }

    await _repository.delete(place.id!);
    await _loadPlaces();
  }

  Future<void> _syncNow() async {
    if (_isSyncing) {
      return;
    }
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncService.sync(_repository);
      await _loadPlaces();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sincronizado. Enviados: ${result.pushed}, recebidos: ${result.pulled}.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na sincronizacao: $error')),
      );
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
        title: const Text('Roteiro de Viagens'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com Mongo',
            onPressed: _isSyncing ? null : _syncNow,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
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
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                        ),
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
                      'Nenhum local cadastrado ainda. Toque no botão + para adicionar o primeiro destino.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _places.length,
                  itemBuilder: (context, index) {
                    final place = _places[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(
                          place.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: place.visited ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Localizacao: ${place.location}'),
                              Text('Funcionamento: ${place.openingTime} - ${place.closingTime}'),
                              Text('Deslocamento: ${place.commuteDuration}'),
                              Text('Transporte: ${place.transportSchedule}'),
                            ],
                          ),
                        ),
                        leading: Checkbox(
                          value: place.visited,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            _toggleVisited(place, value);
                          },
                        ),
                        trailing: PopupMenuButton<String>(
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
                            PopupMenuItem(value: 'delete', child: Text('Excluir')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPlaceForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlaceFormSheet extends StatefulWidget {
  const PlaceFormSheet({
    required this.onSave,
    this.initialValue,
    super.key,
  });

  final TravelPlace? initialValue;
  final Future<void> Function(TravelPlace place) onSave;

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
  bool _visited = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _nameController = TextEditingController(text: value?.name ?? '');
    _locationController = TextEditingController(text: value?.location ?? '');
    _openingController = TextEditingController(text: value?.openingTime ?? '09:00');
    _closingController = TextEditingController(text: value?.closingTime ?? '18:00');
    _commuteController = TextEditingController(text: value?.commuteDuration ?? '30 min');
    _transportController = TextEditingController(text: value?.transportSchedule ?? 'Onibus 08:30 / 10:00');
    _visited = value?.visited ?? false;
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
    final initial = _parseTime(controller.text) ?? TimeOfDay.now();
    final selected = await showTimePicker(context: context, initialTime: initial);
    if (selected == null) {
      return;
    }
    controller.text = _formatTime(selected);
  }

  TimeOfDay? _parseTime(String raw) {
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    await widget.onSave(
      TravelPlace(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        openingTime: _openingController.text.trim(),
        closingTime: _closingController.text.trim(),
        commuteDuration: _commuteController.text.trim(),
        transportSchedule: _transportController.text.trim(),
        updatedAt: DateTime.now().toIso8601String(),
        needsSync: true,
        visited: _visited,
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
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
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _visited,
                title: const Text('Ja visitei este local'),
                onChanged: (value) {
                  setState(() {
                    _visited = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
