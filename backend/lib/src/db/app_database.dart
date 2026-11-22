import 'dart:io';

import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

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

/// Registered workspaces: a named entity with one unique root folder
/// (ADR 0022).
@DataClassName('WorkspaceRow')
@TableIndex(
  name: 'idx_workspaces_root_path',
  columns: {#rootPath},
  unique: true,
)
class Workspaces extends Table {
  /// Unique workspace identifier.
  TextColumn get id => text()();

  /// Human-readable workspace name (defaults to the folder name).
  TextColumn get name => text()();

  /// Normalized absolute path of the workspace root folder; unique.
  TextColumn get rootPath => text()();

  /// Whether the root folder was a git repository when registered.
  BoolColumn get isGit => boolean()();

  /// UTC ISO-8601 creation timestamp.
  TextColumn get createdAt => text()();

  /// UTC ISO-8601 last-updated timestamp.
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
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

/// Execution runs of saved workflows.
@DataClassName('RunRow')
@TableIndex(name: 'idx_runs_workspace_id', columns: {#workspaceId})
class Runs extends Table {
  /// Unique run identifier.
  TextColumn get id => text()();

  /// Optional identifier of the source workflow (null if deleted or ad-hoc).
  TextColumn get workflowId => text().nullable()();

  /// Snapshot of the workflow name at run start.
  TextColumn get workflowName => text()();

  /// Frozen JSON snapshot of the `Workflow` definition at run start.
  TextColumn get workflowDefinitionJson => text()();

  /// Path to the workspace folder used by this run.
  TextColumn get workspacePath => text()();

  /// Owning [Workspaces] row. Nullable only because migration 6 to 7 adds the
  /// column and back-fills it; every new run sets it.
  TextColumn get workspaceId => text().nullable().references(
    Workspaces,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Current run status name.
  TextColumn get status => text()();

  /// UTC ISO-8601 start timestamp.
  TextColumn get startedAt => text()();

  /// Optional UTC ISO-8601 completion timestamp.
  TextColumn get finishedAt => text().nullable()();

  /// Optional error message when the run failed or was interrupted.
  TextColumn get errorMessage => text().nullable()();

  /// Workspace isolation mode (`direct` or `worktree`).
  TextColumn get isolationMode =>
      text().withDefault(const Constant('direct'))();

  /// Optional path to the isolated git worktree created for this run.
  TextColumn get worktreePath => text().nullable()();

  /// Optional branch name (`hive/<runId>`) for an isolated git worktree.
  TextColumn get worktreeBranch => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-node execution checkpoints for a [Runs] row.
@DataClassName('CheckpointRow')
@TableIndex(name: 'idx_checkpoints_run_sequence', columns: {#runId, #sequence})
class Checkpoints extends Table {
  /// Unique checkpoint identifier.
  TextColumn get id => text()();

  /// Owning run identifier.
  TextColumn get runId =>
      text().references(Runs, #id, onDelete: KeyAction.cascade)();

  /// Monotonic 1-based sequence number within [runId].
  IntColumn get sequence => integer()();

  /// Node that just completed (null for an initial checkpoint).
  TextColumn get completedNodeId => text().nullable()();

  /// JSON-encoded list of node IDs pending execution.
  TextColumn get pendingNodeIdsJson => text()();

  /// JSON-encoded map of edge ID to retry attempt count.
  TextColumn get attemptsByEdgeJson => text()();

  /// Global consecutive infrastructure failure count.
  IntColumn get circuitBreakerCount => integer()();

  /// JSON-encoded map of node ID to structured output map.
  TextColumn get nodeOutputsJson => text()();

  /// UTC ISO-8601 creation timestamp.
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {runId, sequence},
  ];
}

/// Append-only lifecycle and execution events for a [Runs] row.
@DataClassName('RunEventRow')
@TableIndex(name: 'idx_run_events_run_sequence', columns: {#runId, #sequence})
class RunEvents extends Table {
  /// Unique event identifier.
  TextColumn get id => text()();

  /// Owning run identifier.
  TextColumn get runId =>
      text().references(Runs, #id, onDelete: KeyAction.cascade)();

  /// Monotonic 1-based sequence number within [runId].
  IntColumn get sequence => integer()();

  /// Dot-notation `RunEventType` wire name.
  TextColumn get type => text()();

  /// Optional node identifier associated with this event.
  TextColumn get nodeId => text().nullable()();

  /// Optional edge identifier associated with this event.
  TextColumn get edgeId => text().nullable()();

  /// JSON-encoded structured event payload.
  TextColumn get payloadJson => text()();

  /// UTC ISO-8601 creation timestamp.
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {runId, sequence},
  ];
}

/// Workspace snapshots captured before nodes or restores for a [Runs] row.
@DataClassName('SnapshotRow')
@TableIndex(name: 'idx_snapshots_run_created_at', columns: {#runId, #createdAt})
class Snapshots extends Table {
  /// Unique snapshot identifier.
  TextColumn get id => text()();

  /// Owning run identifier.
  TextColumn get runId =>
      text().references(Runs, #id, onDelete: KeyAction.cascade)();

  /// Optional node identifier associated with this snapshot.
  TextColumn get nodeId => text().nullable()();

  /// Git commit hash in the run's shadow repository.
  TextColumn get commitHash => text()();

  /// Wire name of snapshot kind (`pre_node` or `safety_pre_restore`).
  TextColumn get kind => text()();

  /// Number of files added in this snapshot.
  IntColumn get addedCount => integer()();

  /// Number of files modified in this snapshot.
  IntColumn get modifiedCount => integer()();

  /// Number of files deleted in this snapshot.
  IntColumn get deletedCount => integer()();

  /// UTC ISO-8601 creation timestamp.
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Persisted runtime settings (key/value pairs).
@DataClassName('SettingRow')
class Settings extends Table {
  /// Setting key (for example `agents_dir`, `default_workspace_dir`,
  /// `harness_override.claude_code`).
  TextColumn get key => text()();

  /// Setting value as text.
  TextColumn get value => text()();

  /// UTC ISO-8601 last-updated timestamp.
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Durable human-in-the-loop pauses for a [Runs] row.
@DataClassName('PauseRow')
@TableIndex(
  name: 'idx_pauses_status_created_at',
  columns: {#status, #createdAt},
)
@TableIndex(name: 'idx_pauses_run_status', columns: {#runId, #status})
class Pauses extends Table {
  /// Unique pause identifier.
  TextColumn get id => text()();

  /// Owning run identifier.
  TextColumn get runId =>
      text().references(Runs, #id, onDelete: KeyAction.cascade)();

  /// Node identifier that requested the pause.
  TextColumn get nodeId => text()();

  /// Pause kind wire name (`humanApproval` or `askHuman`).
  TextColumn get kind => text()();

  /// Pause status wire name (`pending`, `answered`, or `cancelled`).
  TextColumn get status => text()();

  /// Snapshot of the workflow name at pause time.
  TextColumn get workflowName => text()();

  /// Snapshot of the node label at pause time.
  TextColumn get nodeLabel => text()();

  /// Optional title for `humanApproval` pauses.
  TextColumn get title => text().nullable()();

  /// Optional instructions for `humanApproval` pauses.
  TextColumn get instructions => text().nullable()();

  /// Whether free-form feedback is allowed for `humanApproval` pauses.
  BoolColumn get allowFeedback => boolean().withDefault(const Constant(true))();

  /// Question text for `askHuman` pauses.
  TextColumn get question => text().nullable()();

  /// JSON-encoded list of suggested answer options for `askHuman` pauses.
  TextColumn get optionsJson => text()();

  /// Approval decision (`approved` or `rejected`) when answered.
  TextColumn get decision => text().nullable()();

  /// Optional reviewer feedback when answered.
  TextColumn get feedback => text().nullable()();

  /// Free-text answer for `askHuman` when answered.
  TextColumn get answer => text().nullable()();

  /// UTC ISO-8601 creation timestamp.
  TextColumn get createdAt => text()();

  /// Optional UTC ISO-8601 resolution timestamp.
  TextColumn get answeredAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The backend's SQLite database.
///
/// Raise [schemaVersion] and add a step to [migration] for every schema
/// change; never edit a migration that has shipped.
@DriftDatabase(
  tables: [
    AppMetadata,
    Workflows,
    Runs,
    Checkpoints,
    RunEvents,
    Settings,
    Snapshots,
    Pauses,
    Workspaces,
  ],
)
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
  int get schemaVersion => 7;

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
      if (from < 3) {
        await m.createTable(runs);
        await m.createTable(checkpoints);
        await m.createTable(runEvents);
        await m.createIndex(idxCheckpointsRunSequence);
        await m.createIndex(idxRunEventsRunSequence);
      }
      if (from < 4) {
        await m.createTable(settings);
      }
      if (from < 5) {
        if (from >= 3) {
          await m.addColumn(runs, runs.isolationMode);
          await m.addColumn(runs, runs.worktreePath);
          await m.addColumn(runs, runs.worktreeBranch);
        }
        await m.createTable(snapshots);
        await m.createIndex(idxSnapshotsRunCreatedAt);
      }
      if (from < 6) {
        await m.createTable(pauses);
        await m.createIndex(idxPausesStatusCreatedAt);
        await m.createIndex(idxPausesRunStatus);
      }
      if (from < 7) {
        await m.createTable(workspaces);
        await m.createIndex(idxWorkspacesRootPath);
        if (from >= 3) {
          await m.addColumn(runs, runs.workspaceId);
        }
        await m.createIndex(idxRunsWorkspaceId);
        await _attachRunsToWorkspaces();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Migration 6 to 7: creates one workspace per distinct run
  /// `workspace_path` (named after the folder) and attaches those runs to it
  /// (ADR 0022).
  Future<void> _attachRunsToWorkspaces() async {
    final rows = await customSelect(
      'SELECT workspace_path, MIN(started_at) AS first_started '
      'FROM runs GROUP BY workspace_path ORDER BY first_started ASC',
    ).get();
    final workspaceIdByKey = <String, String>{};
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in rows) {
      final path = row.read<String>('workspace_path');
      final key = p.canonicalize(path);
      var id = workspaceIdByKey[key];
      if (id == null) {
        id = randomId();
        workspaceIdByKey[key] = id;
        final rootPath = p.normalize(path);
        final name = p.basename(rootPath);
        await into(workspaces).insert(
          WorkspacesCompanion.insert(
            id: id,
            name: name.isEmpty ? rootPath : name,
            rootPath: rootPath,
            isGit:
                FileSystemEntity.typeSync(p.join(rootPath, '.git')) !=
                FileSystemEntityType.notFound,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await customUpdate(
        'UPDATE runs SET workspace_id = ? WHERE workspace_path = ?',
        variables: [Variable<String>(id), Variable<String>(path)],
        updates: {runs},
      );
    }
  }
}
