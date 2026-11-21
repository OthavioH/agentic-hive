import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'app_database.g.dart';

/// Key/value facts about this installation, such as when it was created.
@DataClassName('AppMetadataEntry')
class AppMetadata extends Table {
  /// The fact's name, such as `installed_at`.
  TextColumn get key => text()();

  /// The fact's value, as text.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Saved workflow definitions (graph recipes).
@DataClassName('WorkflowRow')
class Workflows extends Table {
  /// Unique workflow identifier.
  TextColumn get id => text()();

  /// Human-readable workflow name.
  TextColumn get name => text()();

  /// Optional workflow description.
  TextColumn get description => text().nullable()();

  /// Serialized JSON containing `nodes`, `edges`, `entryNodeId`, and
  /// `schemaVersion`.
  TextColumn get definitionJson => text()();

  /// UTC ISO-8601 creation timestamp.
  TextColumn get createdAt => text()();

  /// UTC ISO-8601 last-updated timestamp.
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The backend's SQLite database.
///
/// Raise [schemaVersion] and add a step to [migration] for every schema
/// change; never edit a migration that has shipped.
@DriftDatabase(tables: [AppMetadata, Workflows])
class AppDatabase extends _$AppDatabase {
  /// Wraps an already opened query executor [e]; tests pass an in-memory
  /// one.
  new(super.e);

  /// Opens (and creates, if needed) the database file on a background isolate.
  factory open(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));

  /// Metadata key holding the UTC time the database was created.
  static const installedAtKey = 'installed_at';

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appMetadata).insert(
        AppMetadataCompanion.insert(
          key: installedAtKey,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(workflows);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
