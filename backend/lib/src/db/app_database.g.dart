// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetadataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetadataEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetadataEntry extends DataClass
    implements Insertable<AppMetadataEntry> {
  /// The fact's name, such as `installed_at`.
  final String key;

  /// The fact's value, as text.
  final String value;
  const AppMetadataEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetadataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetadataEntry copyWith({String? key, String? value}) =>
      AppMetadataEntry(key: key ?? this.key, value: value ?? this.value);
  AppMetadataEntry copyWithCompanion(AppMetadataCompanion data) {
    return AppMetadataEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetadataEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetadataEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkflowsTable extends Workflows
    with TableInfo<$WorkflowsTable, WorkflowRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionJsonMeta = const VerificationMeta(
    'definitionJson',
  );
  @override
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
    'definition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    definitionJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflows';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkflowRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('definition_json')) {
      context.handle(
        _definitionJsonMeta,
        definitionJson.isAcceptableOrUnknown(
          data['definition_json']!,
          _definitionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkflowRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkflowRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      definitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WorkflowsTable createAlias(String alias) {
    return $WorkflowsTable(attachedDatabase, alias);
  }
}

class WorkflowRow extends DataClass implements Insertable<WorkflowRow> {
  /// Unique workflow identifier.
  final String id;

  /// Human-readable workflow name.
  final String name;

  /// Optional workflow description.
  final String? description;

  /// Serialized JSON containing `nodes`, `edges`, `entryNodeId`, and
  /// `schemaVersion`.
  final String definitionJson;

  /// UTC ISO-8601 creation timestamp.
  final String createdAt;

  /// UTC ISO-8601 last-updated timestamp.
  final String updatedAt;
  const WorkflowRow({
    required this.id,
    required this.name,
    this.description,
    required this.definitionJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['definition_json'] = Variable<String>(definitionJson);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  WorkflowsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      definitionJson: Value(definitionJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkflowRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkflowRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      definitionJson: serializer.fromJson<String>(json['definitionJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'definitionJson': serializer.toJson<String>(definitionJson),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  WorkflowRow copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? definitionJson,
    String? createdAt,
    String? updatedAt,
  }) => WorkflowRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    definitionJson: definitionJson ?? this.definitionJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkflowRow copyWithCompanion(WorkflowsCompanion data) {
    return WorkflowRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      definitionJson: data.definitionJson.present
          ? data.definitionJson.value
          : this.definitionJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, definitionJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkflowRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.definitionJson == this.definitionJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkflowsCompanion extends UpdateCompanion<WorkflowRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> definitionJson;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const WorkflowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String definitionJson,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       definitionJson = Value(definitionJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WorkflowRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? definitionJson,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? definitionJson,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkflowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      definitionJson: definitionJson ?? this.definitionJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, RunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workflowIdMeta = const VerificationMeta(
    'workflowId',
  );
  @override
  late final GeneratedColumn<String> workflowId = GeneratedColumn<String>(
    'workflow_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workflowNameMeta = const VerificationMeta(
    'workflowName',
  );
  @override
  late final GeneratedColumn<String> workflowName = GeneratedColumn<String>(
    'workflow_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workflowDefinitionJsonMeta =
      const VerificationMeta('workflowDefinitionJson');
  @override
  late final GeneratedColumn<String> workflowDefinitionJson =
      GeneratedColumn<String>(
        'workflow_definition_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _workspacePathMeta = const VerificationMeta(
    'workspacePath',
  );
  @override
  late final GeneratedColumn<String> workspacePath = GeneratedColumn<String>(
    'workspace_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<String> finishedAt = GeneratedColumn<String>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workflowId,
    workflowName,
    workflowDefinitionJson,
    workspacePath,
    status,
    startedAt,
    finishedAt,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workflow_id')) {
      context.handle(
        _workflowIdMeta,
        workflowId.isAcceptableOrUnknown(data['workflow_id']!, _workflowIdMeta),
      );
    }
    if (data.containsKey('workflow_name')) {
      context.handle(
        _workflowNameMeta,
        workflowName.isAcceptableOrUnknown(
          data['workflow_name']!,
          _workflowNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workflowNameMeta);
    }
    if (data.containsKey('workflow_definition_json')) {
      context.handle(
        _workflowDefinitionJsonMeta,
        workflowDefinitionJson.isAcceptableOrUnknown(
          data['workflow_definition_json']!,
          _workflowDefinitionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workflowDefinitionJsonMeta);
    }
    if (data.containsKey('workspace_path')) {
      context.handle(
        _workspacePathMeta,
        workspacePath.isAcceptableOrUnknown(
          data['workspace_path']!,
          _workspacePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workspacePathMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workflowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_id'],
      ),
      workflowName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_name'],
      )!,
      workflowDefinitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_definition_json'],
      )!,
      workspacePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_path'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finished_at'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class RunRow extends DataClass implements Insertable<RunRow> {
  /// Unique run identifier.
  final String id;

  /// Optional identifier of the source workflow (null if deleted or ad-hoc).
  final String? workflowId;

  /// Snapshot of the workflow name at run start.
  final String workflowName;

  /// Frozen JSON snapshot of the `Workflow` definition at run start.
  final String workflowDefinitionJson;

  /// Path to the workspace folder used by this run.
  final String workspacePath;

  /// Current run status name.
  final String status;

  /// UTC ISO-8601 start timestamp.
  final String startedAt;

  /// Optional UTC ISO-8601 completion timestamp.
  final String? finishedAt;

  /// Optional error message when the run failed or was interrupted.
  final String? errorMessage;
  const RunRow({
    required this.id,
    this.workflowId,
    required this.workflowName,
    required this.workflowDefinitionJson,
    required this.workspacePath,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || workflowId != null) {
      map['workflow_id'] = Variable<String>(workflowId);
    }
    map['workflow_name'] = Variable<String>(workflowName);
    map['workflow_definition_json'] = Variable<String>(workflowDefinitionJson);
    map['workspace_path'] = Variable<String>(workspacePath);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<String>(finishedAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      workflowId: workflowId == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowId),
      workflowName: Value(workflowName),
      workflowDefinitionJson: Value(workflowDefinitionJson),
      workspacePath: Value(workspacePath),
      status: Value(status),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory RunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunRow(
      id: serializer.fromJson<String>(json['id']),
      workflowId: serializer.fromJson<String?>(json['workflowId']),
      workflowName: serializer.fromJson<String>(json['workflowName']),
      workflowDefinitionJson: serializer.fromJson<String>(
        json['workflowDefinitionJson'],
      ),
      workspacePath: serializer.fromJson<String>(json['workspacePath']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      finishedAt: serializer.fromJson<String?>(json['finishedAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workflowId': serializer.toJson<String?>(workflowId),
      'workflowName': serializer.toJson<String>(workflowName),
      'workflowDefinitionJson': serializer.toJson<String>(
        workflowDefinitionJson,
      ),
      'workspacePath': serializer.toJson<String>(workspacePath),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<String>(startedAt),
      'finishedAt': serializer.toJson<String?>(finishedAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  RunRow copyWith({
    String? id,
    Value<String?> workflowId = const Value.absent(),
    String? workflowName,
    String? workflowDefinitionJson,
    String? workspacePath,
    String? status,
    String? startedAt,
    Value<String?> finishedAt = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
  }) => RunRow(
    id: id ?? this.id,
    workflowId: workflowId.present ? workflowId.value : this.workflowId,
    workflowName: workflowName ?? this.workflowName,
    workflowDefinitionJson:
        workflowDefinitionJson ?? this.workflowDefinitionJson,
    workspacePath: workspacePath ?? this.workspacePath,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  RunRow copyWithCompanion(RunsCompanion data) {
    return RunRow(
      id: data.id.present ? data.id.value : this.id,
      workflowId: data.workflowId.present
          ? data.workflowId.value
          : this.workflowId,
      workflowName: data.workflowName.present
          ? data.workflowName.value
          : this.workflowName,
      workflowDefinitionJson: data.workflowDefinitionJson.present
          ? data.workflowDefinitionJson.value
          : this.workflowDefinitionJson,
      workspacePath: data.workspacePath.present
          ? data.workspacePath.value
          : this.workspacePath,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunRow(')
          ..write('id: $id, ')
          ..write('workflowId: $workflowId, ')
          ..write('workflowName: $workflowName, ')
          ..write('workflowDefinitionJson: $workflowDefinitionJson, ')
          ..write('workspacePath: $workspacePath, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workflowId,
    workflowName,
    workflowDefinitionJson,
    workspacePath,
    status,
    startedAt,
    finishedAt,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunRow &&
          other.id == this.id &&
          other.workflowId == this.workflowId &&
          other.workflowName == this.workflowName &&
          other.workflowDefinitionJson == this.workflowDefinitionJson &&
          other.workspacePath == this.workspacePath &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.errorMessage == this.errorMessage);
}

class RunsCompanion extends UpdateCompanion<RunRow> {
  final Value<String> id;
  final Value<String?> workflowId;
  final Value<String> workflowName;
  final Value<String> workflowDefinitionJson;
  final Value<String> workspacePath;
  final Value<String> status;
  final Value<String> startedAt;
  final Value<String?> finishedAt;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.workflowId = const Value.absent(),
    this.workflowName = const Value.absent(),
    this.workflowDefinitionJson = const Value.absent(),
    this.workspacePath = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    this.workflowId = const Value.absent(),
    required String workflowName,
    required String workflowDefinitionJson,
    required String workspacePath,
    required String status,
    required String startedAt,
    this.finishedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workflowName = Value(workflowName),
       workflowDefinitionJson = Value(workflowDefinitionJson),
       workspacePath = Value(workspacePath),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<RunRow> custom({
    Expression<String>? id,
    Expression<String>? workflowId,
    Expression<String>? workflowName,
    Expression<String>? workflowDefinitionJson,
    Expression<String>? workspacePath,
    Expression<String>? status,
    Expression<String>? startedAt,
    Expression<String>? finishedAt,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workflowId != null) 'workflow_id': workflowId,
      if (workflowName != null) 'workflow_name': workflowName,
      if (workflowDefinitionJson != null)
        'workflow_definition_json': workflowDefinitionJson,
      if (workspacePath != null) 'workspace_path': workspacePath,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<String?>? workflowId,
    Value<String>? workflowName,
    Value<String>? workflowDefinitionJson,
    Value<String>? workspacePath,
    Value<String>? status,
    Value<String>? startedAt,
    Value<String?>? finishedAt,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      workflowId: workflowId ?? this.workflowId,
      workflowName: workflowName ?? this.workflowName,
      workflowDefinitionJson:
          workflowDefinitionJson ?? this.workflowDefinitionJson,
      workspacePath: workspacePath ?? this.workspacePath,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workflowId.present) {
      map['workflow_id'] = Variable<String>(workflowId.value);
    }
    if (workflowName.present) {
      map['workflow_name'] = Variable<String>(workflowName.value);
    }
    if (workflowDefinitionJson.present) {
      map['workflow_definition_json'] = Variable<String>(
        workflowDefinitionJson.value,
      );
    }
    if (workspacePath.present) {
      map['workspace_path'] = Variable<String>(workspacePath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<String>(finishedAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('workflowId: $workflowId, ')
          ..write('workflowName: $workflowName, ')
          ..write('workflowDefinitionJson: $workflowDefinitionJson, ')
          ..write('workspacePath: $workspacePath, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CheckpointsTable extends Checkpoints
    with TableInfo<$CheckpointsTable, CheckpointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedNodeIdMeta = const VerificationMeta(
    'completedNodeId',
  );
  @override
  late final GeneratedColumn<String> completedNodeId = GeneratedColumn<String>(
    'completed_node_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingNodeIdsJsonMeta =
      const VerificationMeta('pendingNodeIdsJson');
  @override
  late final GeneratedColumn<String> pendingNodeIdsJson =
      GeneratedColumn<String>(
        'pending_node_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attemptsByEdgeJsonMeta =
      const VerificationMeta('attemptsByEdgeJson');
  @override
  late final GeneratedColumn<String> attemptsByEdgeJson =
      GeneratedColumn<String>(
        'attempts_by_edge_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _circuitBreakerCountMeta =
      const VerificationMeta('circuitBreakerCount');
  @override
  late final GeneratedColumn<int> circuitBreakerCount = GeneratedColumn<int>(
    'circuit_breaker_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeOutputsJsonMeta = const VerificationMeta(
    'nodeOutputsJson',
  );
  @override
  late final GeneratedColumn<String> nodeOutputsJson = GeneratedColumn<String>(
    'node_outputs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    sequence,
    completedNodeId,
    pendingNodeIdsJson,
    attemptsByEdgeJson,
    circuitBreakerCount,
    nodeOutputsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckpointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('completed_node_id')) {
      context.handle(
        _completedNodeIdMeta,
        completedNodeId.isAcceptableOrUnknown(
          data['completed_node_id']!,
          _completedNodeIdMeta,
        ),
      );
    }
    if (data.containsKey('pending_node_ids_json')) {
      context.handle(
        _pendingNodeIdsJsonMeta,
        pendingNodeIdsJson.isAcceptableOrUnknown(
          data['pending_node_ids_json']!,
          _pendingNodeIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pendingNodeIdsJsonMeta);
    }
    if (data.containsKey('attempts_by_edge_json')) {
      context.handle(
        _attemptsByEdgeJsonMeta,
        attemptsByEdgeJson.isAcceptableOrUnknown(
          data['attempts_by_edge_json']!,
          _attemptsByEdgeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptsByEdgeJsonMeta);
    }
    if (data.containsKey('circuit_breaker_count')) {
      context.handle(
        _circuitBreakerCountMeta,
        circuitBreakerCount.isAcceptableOrUnknown(
          data['circuit_breaker_count']!,
          _circuitBreakerCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_circuitBreakerCountMeta);
    }
    if (data.containsKey('node_outputs_json')) {
      context.handle(
        _nodeOutputsJsonMeta,
        nodeOutputsJson.isAcceptableOrUnknown(
          data['node_outputs_json']!,
          _nodeOutputsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nodeOutputsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {runId, sequence},
  ];
  @override
  CheckpointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckpointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      completedNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_node_id'],
      ),
      pendingNodeIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_node_ids_json'],
      )!,
      attemptsByEdgeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempts_by_edge_json'],
      )!,
      circuitBreakerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}circuit_breaker_count'],
      )!,
      nodeOutputsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_outputs_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CheckpointsTable createAlias(String alias) {
    return $CheckpointsTable(attachedDatabase, alias);
  }
}

class CheckpointRow extends DataClass implements Insertable<CheckpointRow> {
  /// Unique checkpoint identifier.
  final String id;

  /// Owning run identifier.
  final String runId;

  /// Monotonic 1-based sequence number within [runId].
  final int sequence;

  /// Node that just completed (null for an initial checkpoint).
  final String? completedNodeId;

  /// JSON-encoded list of node IDs pending execution.
  final String pendingNodeIdsJson;

  /// JSON-encoded map of edge ID to retry attempt count.
  final String attemptsByEdgeJson;

  /// Global consecutive infrastructure failure count.
  final int circuitBreakerCount;

  /// JSON-encoded map of node ID to structured output map.
  final String nodeOutputsJson;

  /// UTC ISO-8601 creation timestamp.
  final String createdAt;
  const CheckpointRow({
    required this.id,
    required this.runId,
    required this.sequence,
    this.completedNodeId,
    required this.pendingNodeIdsJson,
    required this.attemptsByEdgeJson,
    required this.circuitBreakerCount,
    required this.nodeOutputsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['sequence'] = Variable<int>(sequence);
    if (!nullToAbsent || completedNodeId != null) {
      map['completed_node_id'] = Variable<String>(completedNodeId);
    }
    map['pending_node_ids_json'] = Variable<String>(pendingNodeIdsJson);
    map['attempts_by_edge_json'] = Variable<String>(attemptsByEdgeJson);
    map['circuit_breaker_count'] = Variable<int>(circuitBreakerCount);
    map['node_outputs_json'] = Variable<String>(nodeOutputsJson);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  CheckpointsCompanion toCompanion(bool nullToAbsent) {
    return CheckpointsCompanion(
      id: Value(id),
      runId: Value(runId),
      sequence: Value(sequence),
      completedNodeId: completedNodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(completedNodeId),
      pendingNodeIdsJson: Value(pendingNodeIdsJson),
      attemptsByEdgeJson: Value(attemptsByEdgeJson),
      circuitBreakerCount: Value(circuitBreakerCount),
      nodeOutputsJson: Value(nodeOutputsJson),
      createdAt: Value(createdAt),
    );
  }

  factory CheckpointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckpointRow(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      completedNodeId: serializer.fromJson<String?>(json['completedNodeId']),
      pendingNodeIdsJson: serializer.fromJson<String>(
        json['pendingNodeIdsJson'],
      ),
      attemptsByEdgeJson: serializer.fromJson<String>(
        json['attemptsByEdgeJson'],
      ),
      circuitBreakerCount: serializer.fromJson<int>(
        json['circuitBreakerCount'],
      ),
      nodeOutputsJson: serializer.fromJson<String>(json['nodeOutputsJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'sequence': serializer.toJson<int>(sequence),
      'completedNodeId': serializer.toJson<String?>(completedNodeId),
      'pendingNodeIdsJson': serializer.toJson<String>(pendingNodeIdsJson),
      'attemptsByEdgeJson': serializer.toJson<String>(attemptsByEdgeJson),
      'circuitBreakerCount': serializer.toJson<int>(circuitBreakerCount),
      'nodeOutputsJson': serializer.toJson<String>(nodeOutputsJson),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  CheckpointRow copyWith({
    String? id,
    String? runId,
    int? sequence,
    Value<String?> completedNodeId = const Value.absent(),
    String? pendingNodeIdsJson,
    String? attemptsByEdgeJson,
    int? circuitBreakerCount,
    String? nodeOutputsJson,
    String? createdAt,
  }) => CheckpointRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    sequence: sequence ?? this.sequence,
    completedNodeId: completedNodeId.present
        ? completedNodeId.value
        : this.completedNodeId,
    pendingNodeIdsJson: pendingNodeIdsJson ?? this.pendingNodeIdsJson,
    attemptsByEdgeJson: attemptsByEdgeJson ?? this.attemptsByEdgeJson,
    circuitBreakerCount: circuitBreakerCount ?? this.circuitBreakerCount,
    nodeOutputsJson: nodeOutputsJson ?? this.nodeOutputsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  CheckpointRow copyWithCompanion(CheckpointsCompanion data) {
    return CheckpointRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      completedNodeId: data.completedNodeId.present
          ? data.completedNodeId.value
          : this.completedNodeId,
      pendingNodeIdsJson: data.pendingNodeIdsJson.present
          ? data.pendingNodeIdsJson.value
          : this.pendingNodeIdsJson,
      attemptsByEdgeJson: data.attemptsByEdgeJson.present
          ? data.attemptsByEdgeJson.value
          : this.attemptsByEdgeJson,
      circuitBreakerCount: data.circuitBreakerCount.present
          ? data.circuitBreakerCount.value
          : this.circuitBreakerCount,
      nodeOutputsJson: data.nodeOutputsJson.present
          ? data.nodeOutputsJson.value
          : this.nodeOutputsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckpointRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sequence: $sequence, ')
          ..write('completedNodeId: $completedNodeId, ')
          ..write('pendingNodeIdsJson: $pendingNodeIdsJson, ')
          ..write('attemptsByEdgeJson: $attemptsByEdgeJson, ')
          ..write('circuitBreakerCount: $circuitBreakerCount, ')
          ..write('nodeOutputsJson: $nodeOutputsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    sequence,
    completedNodeId,
    pendingNodeIdsJson,
    attemptsByEdgeJson,
    circuitBreakerCount,
    nodeOutputsJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckpointRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.sequence == this.sequence &&
          other.completedNodeId == this.completedNodeId &&
          other.pendingNodeIdsJson == this.pendingNodeIdsJson &&
          other.attemptsByEdgeJson == this.attemptsByEdgeJson &&
          other.circuitBreakerCount == this.circuitBreakerCount &&
          other.nodeOutputsJson == this.nodeOutputsJson &&
          other.createdAt == this.createdAt);
}

class CheckpointsCompanion extends UpdateCompanion<CheckpointRow> {
  final Value<String> id;
  final Value<String> runId;
  final Value<int> sequence;
  final Value<String?> completedNodeId;
  final Value<String> pendingNodeIdsJson;
  final Value<String> attemptsByEdgeJson;
  final Value<int> circuitBreakerCount;
  final Value<String> nodeOutputsJson;
  final Value<String> createdAt;
  final Value<int> rowid;
  const CheckpointsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.completedNodeId = const Value.absent(),
    this.pendingNodeIdsJson = const Value.absent(),
    this.attemptsByEdgeJson = const Value.absent(),
    this.circuitBreakerCount = const Value.absent(),
    this.nodeOutputsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckpointsCompanion.insert({
    required String id,
    required String runId,
    required int sequence,
    this.completedNodeId = const Value.absent(),
    required String pendingNodeIdsJson,
    required String attemptsByEdgeJson,
    required int circuitBreakerCount,
    required String nodeOutputsJson,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       sequence = Value(sequence),
       pendingNodeIdsJson = Value(pendingNodeIdsJson),
       attemptsByEdgeJson = Value(attemptsByEdgeJson),
       circuitBreakerCount = Value(circuitBreakerCount),
       nodeOutputsJson = Value(nodeOutputsJson),
       createdAt = Value(createdAt);
  static Insertable<CheckpointRow> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<int>? sequence,
    Expression<String>? completedNodeId,
    Expression<String>? pendingNodeIdsJson,
    Expression<String>? attemptsByEdgeJson,
    Expression<int>? circuitBreakerCount,
    Expression<String>? nodeOutputsJson,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (sequence != null) 'sequence': sequence,
      if (completedNodeId != null) 'completed_node_id': completedNodeId,
      if (pendingNodeIdsJson != null)
        'pending_node_ids_json': pendingNodeIdsJson,
      if (attemptsByEdgeJson != null)
        'attempts_by_edge_json': attemptsByEdgeJson,
      if (circuitBreakerCount != null)
        'circuit_breaker_count': circuitBreakerCount,
      if (nodeOutputsJson != null) 'node_outputs_json': nodeOutputsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckpointsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<int>? sequence,
    Value<String?>? completedNodeId,
    Value<String>? pendingNodeIdsJson,
    Value<String>? attemptsByEdgeJson,
    Value<int>? circuitBreakerCount,
    Value<String>? nodeOutputsJson,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return CheckpointsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      sequence: sequence ?? this.sequence,
      completedNodeId: completedNodeId ?? this.completedNodeId,
      pendingNodeIdsJson: pendingNodeIdsJson ?? this.pendingNodeIdsJson,
      attemptsByEdgeJson: attemptsByEdgeJson ?? this.attemptsByEdgeJson,
      circuitBreakerCount: circuitBreakerCount ?? this.circuitBreakerCount,
      nodeOutputsJson: nodeOutputsJson ?? this.nodeOutputsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (completedNodeId.present) {
      map['completed_node_id'] = Variable<String>(completedNodeId.value);
    }
    if (pendingNodeIdsJson.present) {
      map['pending_node_ids_json'] = Variable<String>(pendingNodeIdsJson.value);
    }
    if (attemptsByEdgeJson.present) {
      map['attempts_by_edge_json'] = Variable<String>(attemptsByEdgeJson.value);
    }
    if (circuitBreakerCount.present) {
      map['circuit_breaker_count'] = Variable<int>(circuitBreakerCount.value);
    }
    if (nodeOutputsJson.present) {
      map['node_outputs_json'] = Variable<String>(nodeOutputsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckpointsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sequence: $sequence, ')
          ..write('completedNodeId: $completedNodeId, ')
          ..write('pendingNodeIdsJson: $pendingNodeIdsJson, ')
          ..write('attemptsByEdgeJson: $attemptsByEdgeJson, ')
          ..write('circuitBreakerCount: $circuitBreakerCount, ')
          ..write('nodeOutputsJson: $nodeOutputsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunEventsTable extends RunEvents
    with TableInfo<$RunEventsTable, RunEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _edgeIdMeta = const VerificationMeta('edgeId');
  @override
  late final GeneratedColumn<String> edgeId = GeneratedColumn<String>(
    'edge_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    sequence,
    type,
    nodeId,
    edgeId,
    payloadJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    }
    if (data.containsKey('edge_id')) {
      context.handle(
        _edgeIdMeta,
        edgeId.isAcceptableOrUnknown(data['edge_id']!, _edgeIdMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {runId, sequence},
  ];
  @override
  RunEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      ),
      edgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edge_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunEventsTable createAlias(String alias) {
    return $RunEventsTable(attachedDatabase, alias);
  }
}

class RunEventRow extends DataClass implements Insertable<RunEventRow> {
  /// Unique event identifier.
  final String id;

  /// Owning run identifier.
  final String runId;

  /// Monotonic 1-based sequence number within [runId].
  final int sequence;

  /// Dot-notation `RunEventType` wire name.
  final String type;

  /// Optional node identifier associated with this event.
  final String? nodeId;

  /// Optional edge identifier associated with this event.
  final String? edgeId;

  /// JSON-encoded structured event payload.
  final String payloadJson;

  /// UTC ISO-8601 creation timestamp.
  final String createdAt;
  const RunEventRow({
    required this.id,
    required this.runId,
    required this.sequence,
    required this.type,
    this.nodeId,
    this.edgeId,
    required this.payloadJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['sequence'] = Variable<int>(sequence);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || nodeId != null) {
      map['node_id'] = Variable<String>(nodeId);
    }
    if (!nullToAbsent || edgeId != null) {
      map['edge_id'] = Variable<String>(edgeId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  RunEventsCompanion toCompanion(bool nullToAbsent) {
    return RunEventsCompanion(
      id: Value(id),
      runId: Value(runId),
      sequence: Value(sequence),
      type: Value(type),
      nodeId: nodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(nodeId),
      edgeId: edgeId == null && nullToAbsent
          ? const Value.absent()
          : Value(edgeId),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
    );
  }

  factory RunEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunEventRow(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      type: serializer.fromJson<String>(json['type']),
      nodeId: serializer.fromJson<String?>(json['nodeId']),
      edgeId: serializer.fromJson<String?>(json['edgeId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'sequence': serializer.toJson<int>(sequence),
      'type': serializer.toJson<String>(type),
      'nodeId': serializer.toJson<String?>(nodeId),
      'edgeId': serializer.toJson<String?>(edgeId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  RunEventRow copyWith({
    String? id,
    String? runId,
    int? sequence,
    String? type,
    Value<String?> nodeId = const Value.absent(),
    Value<String?> edgeId = const Value.absent(),
    String? payloadJson,
    String? createdAt,
  }) => RunEventRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    sequence: sequence ?? this.sequence,
    type: type ?? this.type,
    nodeId: nodeId.present ? nodeId.value : this.nodeId,
    edgeId: edgeId.present ? edgeId.value : this.edgeId,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
  );
  RunEventRow copyWithCompanion(RunEventsCompanion data) {
    return RunEventRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      type: data.type.present ? data.type.value : this.type,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      edgeId: data.edgeId.present ? data.edgeId.value : this.edgeId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunEventRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sequence: $sequence, ')
          ..write('type: $type, ')
          ..write('nodeId: $nodeId, ')
          ..write('edgeId: $edgeId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    sequence,
    type,
    nodeId,
    edgeId,
    payloadJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunEventRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.sequence == this.sequence &&
          other.type == this.type &&
          other.nodeId == this.nodeId &&
          other.edgeId == this.edgeId &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt);
}

class RunEventsCompanion extends UpdateCompanion<RunEventRow> {
  final Value<String> id;
  final Value<String> runId;
  final Value<int> sequence;
  final Value<String> type;
  final Value<String?> nodeId;
  final Value<String?> edgeId;
  final Value<String> payloadJson;
  final Value<String> createdAt;
  final Value<int> rowid;
  const RunEventsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.type = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.edgeId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunEventsCompanion.insert({
    required String id,
    required String runId,
    required int sequence,
    required String type,
    this.nodeId = const Value.absent(),
    this.edgeId = const Value.absent(),
    required String payloadJson,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       sequence = Value(sequence),
       type = Value(type),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<RunEventRow> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<int>? sequence,
    Expression<String>? type,
    Expression<String>? nodeId,
    Expression<String>? edgeId,
    Expression<String>? payloadJson,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (sequence != null) 'sequence': sequence,
      if (type != null) 'type': type,
      if (nodeId != null) 'node_id': nodeId,
      if (edgeId != null) 'edge_id': edgeId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<int>? sequence,
    Value<String>? type,
    Value<String?>? nodeId,
    Value<String?>? edgeId,
    Value<String>? payloadJson,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return RunEventsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      nodeId: nodeId ?? this.nodeId,
      edgeId: edgeId ?? this.edgeId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (edgeId.present) {
      map['edge_id'] = Variable<String>(edgeId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunEventsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sequence: $sequence, ')
          ..write('type: $type, ')
          ..write('nodeId: $nodeId, ')
          ..write('edgeId: $edgeId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final $WorkflowsTable workflows = $WorkflowsTable(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $CheckpointsTable checkpoints = $CheckpointsTable(this);
  late final $RunEventsTable runEvents = $RunEventsTable(this);
  late final Index idxCheckpointsRunSequence = Index(
    'idx_checkpoints_run_sequence',
    'CREATE INDEX idx_checkpoints_run_sequence ON checkpoints (run_id, sequence)',
  );
  late final Index idxRunEventsRunSequence = Index(
    'idx_run_events_run_sequence',
    'CREATE INDEX idx_run_events_run_sequence ON run_events (run_id, sequence)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appMetadata,
    workflows,
    runs,
    checkpoints,
    runEvents,
    idxCheckpointsRunSequence,
    idxRunEventsRunSequence,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('checkpoints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppMetadataTableCreateCompanionBuilder =
    AppMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppMetadataTableUpdateCompanionBuilder =
    AppMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetadataTable,
          AppMetadataEntry,
          $$AppMetadataTableFilterComposer,
          $$AppMetadataTableOrderingComposer,
          $$AppMetadataTableAnnotationComposer,
          $$AppMetadataTableCreateCompanionBuilder,
          $$AppMetadataTableUpdateCompanionBuilder,
          (
            AppMetadataEntry,
            BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataEntry>,
          ),
          AppMetadataEntry,
          PrefetchHooks Function()
        > {
  $$AppMetadataTableTableManager(_$AppDatabase db, $AppMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppMetadataTable, AppMetadataEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppMetadataTable,
                    AppMetadataEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetadataTable,
      AppMetadataEntry,
      $$AppMetadataTableFilterComposer,
      $$AppMetadataTableOrderingComposer,
      $$AppMetadataTableAnnotationComposer,
      $$AppMetadataTableCreateCompanionBuilder,
      $$AppMetadataTableUpdateCompanionBuilder,
      (
        AppMetadataEntry,
        BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataEntry>,
      ),
      AppMetadataEntry,
      PrefetchHooks Function()
    >;
typedef $$WorkflowsTableCreateCompanionBuilder = WorkflowsCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  required String definitionJson,
  required String createdAt,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$WorkflowsTableUpdateCompanionBuilder = WorkflowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<String> definitionJson,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$WorkflowsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkflowsTable> {
  $$WorkflowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkflowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkflowsTable> {
  $$WorkflowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkflowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkflowsTable> {
  $$WorkflowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkflowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkflowsTable,
          WorkflowRow,
          $$WorkflowsTableFilterComposer,
          $$WorkflowsTableOrderingComposer,
          $$WorkflowsTableAnnotationComposer,
          $$WorkflowsTableCreateCompanionBuilder,
          $$WorkflowsTableUpdateCompanionBuilder,
          (
            WorkflowRow,
            BaseReferences<_$AppDatabase, $WorkflowsTable, WorkflowRow>,
          ),
          WorkflowRow,
          PrefetchHooks Function()
        > {
  $$WorkflowsTableTableManager(_$AppDatabase db, $WorkflowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkflowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowsCompanion(
                id: id,
                name: name,
                description: description,
                definitionJson: definitionJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String definitionJson,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkflowsCompanion.insert(
                id: id,
                name: name,
                description: description,
                definitionJson: definitionJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkflowsTable, WorkflowRow>(table),
                  BaseReferences<_$AppDatabase, $WorkflowsTable, WorkflowRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkflowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkflowsTable,
      WorkflowRow,
      $$WorkflowsTableFilterComposer,
      $$WorkflowsTableOrderingComposer,
      $$WorkflowsTableAnnotationComposer,
      $$WorkflowsTableCreateCompanionBuilder,
      $$WorkflowsTableUpdateCompanionBuilder,
      (
        WorkflowRow,
        BaseReferences<_$AppDatabase, $WorkflowsTable, WorkflowRow>,
      ),
      WorkflowRow,
      PrefetchHooks Function()
    >;
typedef $$RunsTableCreateCompanionBuilder = RunsCompanion Function({
  required String id,
  Value<String?> workflowId,
  required String workflowName,
  required String workflowDefinitionJson,
  required String workspacePath,
  required String status,
  required String startedAt,
  Value<String?> finishedAt,
  Value<String?> errorMessage,
  Value<int> rowid,
});
typedef $$RunsTableUpdateCompanionBuilder = RunsCompanion Function({
  Value<String> id,
  Value<String?> workflowId,
  Value<String> workflowName,
  Value<String> workflowDefinitionJson,
  Value<String> workspacePath,
  Value<String> status,
  Value<String> startedAt,
  Value<String?> finishedAt,
  Value<String?> errorMessage,
  Value<int> rowid,
});

final class $$RunsTableReferences
    extends BaseReferences<_$AppDatabase, $RunsTable, RunRow> {
  $$RunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CheckpointsTable, List<CheckpointRow>>
  _checkpointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.checkpoints,
    aliasName: 'runs__id__checkpoints__run_id',
  );

  $$CheckpointsTableProcessedTableManager get checkpointsRefs {
    final manager = $$CheckpointsTableTableManager(
      $_db,
      $_db.checkpoints,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_checkpointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RunEventsTable, List<RunEventRow>>
  _runEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.runEvents,
    aliasName: 'runs__id__run_events__run_id',
  );

  $$RunEventsTableProcessedTableManager get runEventsRefs {
    final manager = $$RunEventsTableTableManager(
      $_db,
      $_db.runEvents,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RunsTableFilterComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowName => $composableBuilder(
    column: $table.workflowName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowDefinitionJson => $composableBuilder(
    column: $table.workflowDefinitionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workspacePath => $composableBuilder(
    column: $table.workspacePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> checkpointsRefs(
    Expression<bool> Function($$CheckpointsTableFilterComposer f) f,
  ) {
    final $$CheckpointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checkpoints,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckpointsTableFilterComposer(
            $db: $db,
            $table: $db.checkpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runEventsRefs(
    Expression<bool> Function($$RunEventsTableFilterComposer f) f,
  ) {
    final $$RunEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runEvents,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunEventsTableFilterComposer(
            $db: $db,
            $table: $db.runEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableOrderingComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowName => $composableBuilder(
    column: $table.workflowName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowDefinitionJson => $composableBuilder(
    column: $table.workflowDefinitionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workspacePath => $composableBuilder(
    column: $table.workspacePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workflowId => $composableBuilder(
    column: $table.workflowId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workflowName => $composableBuilder(
    column: $table.workflowName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workflowDefinitionJson => $composableBuilder(
    column: $table.workflowDefinitionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workspacePath => $composableBuilder(
    column: $table.workspacePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  Expression<T> checkpointsRefs<T extends Object>(
    Expression<T> Function($$CheckpointsTableAnnotationComposer a) f,
  ) {
    final $$CheckpointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checkpoints,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckpointsTableAnnotationComposer(
            $db: $db,
            $table: $db.checkpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runEventsRefs<T extends Object>(
    Expression<T> Function($$RunEventsTableAnnotationComposer a) f,
  ) {
    final $$RunEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runEvents,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.runEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunsTable,
          RunRow,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (RunRow, $$RunsTableReferences),
          RunRow,
          PrefetchHooks Function({bool checkpointsRefs, bool runEventsRefs})
        > {
  $$RunsTableTableManager(_$AppDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> workflowId = const Value.absent(),
                Value<String> workflowName = const Value.absent(),
                Value<String> workflowDefinitionJson = const Value.absent(),
                Value<String> workspacePath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String?> finishedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                workflowId: workflowId,
                workflowName: workflowName,
                workflowDefinitionJson: workflowDefinitionJson,
                workspacePath: workspacePath,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> workflowId = const Value.absent(),
                required String workflowName,
                required String workflowDefinitionJson,
                required String workspacePath,
                required String status,
                required String startedAt,
                Value<String?> finishedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                workflowId: workflowId,
                workflowName: workflowName,
                workflowDefinitionJson: workflowDefinitionJson,
                workspacePath: workspacePath,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunsTable, RunRow>(table),
                  $$RunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({checkpointsRefs = false, runEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (checkpointsRefs) db.checkpoints,
                    if (runEventsRefs) db.runEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (checkpointsRefs)
                        await $_getPrefetchedDataByColumns<
                          RunRow,
                          $RunsTable,
                          CheckpointRow,
                          $CheckpointsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RunsTableReferences
                              ._checkpointsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RunsTableReferences(
                            db,
                            table,
                            p0,
                          ).checkpointsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'run_id',
                          typedResults: items,
                        ),
                      if (runEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          RunRow,
                          $RunsTable,
                          RunEventRow,
                          $RunEventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RunsTableReferences
                              ._runEventsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RunsTableReferences(
                            db,
                            table,
                            p0,
                          ).runEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'run_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunsTable,
      RunRow,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (RunRow, $$RunsTableReferences),
      RunRow,
      PrefetchHooks Function({bool checkpointsRefs, bool runEventsRefs})
    >;
typedef $$CheckpointsTableCreateCompanionBuilder =
    CheckpointsCompanion Function({
      required String id,
      required String runId,
      required int sequence,
      Value<String?> completedNodeId,
      required String pendingNodeIdsJson,
      required String attemptsByEdgeJson,
      required int circuitBreakerCount,
      required String nodeOutputsJson,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$CheckpointsTableUpdateCompanionBuilder =
    CheckpointsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<int> sequence,
      Value<String?> completedNodeId,
      Value<String> pendingNodeIdsJson,
      Value<String> attemptsByEdgeJson,
      Value<int> circuitBreakerCount,
      Value<String> nodeOutputsJson,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$CheckpointsTableReferences
    extends BaseReferences<_$AppDatabase, $CheckpointsTable, CheckpointRow> {
  $$CheckpointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RunsTable _runIdTable(_$AppDatabase db) =>
      db.runs.createAlias('checkpoints__run_id__runs__id');

  $$RunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CheckpointsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckpointsTable> {
  $$CheckpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedNodeId => $composableBuilder(
    column: $table.completedNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingNodeIdsJson => $composableBuilder(
    column: $table.pendingNodeIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attemptsByEdgeJson => $composableBuilder(
    column: $table.attemptsByEdgeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get circuitBreakerCount => $composableBuilder(
    column: $table.circuitBreakerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeOutputsJson => $composableBuilder(
    column: $table.nodeOutputsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RunsTableFilterComposer get runId {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckpointsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckpointsTable> {
  $$CheckpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedNodeId => $composableBuilder(
    column: $table.completedNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingNodeIdsJson => $composableBuilder(
    column: $table.pendingNodeIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attemptsByEdgeJson => $composableBuilder(
    column: $table.attemptsByEdgeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get circuitBreakerCount => $composableBuilder(
    column: $table.circuitBreakerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeOutputsJson => $composableBuilder(
    column: $table.nodeOutputsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RunsTableOrderingComposer get runId {
    final $$RunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableOrderingComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckpointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckpointsTable> {
  $$CheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get completedNodeId => $composableBuilder(
    column: $table.completedNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingNodeIdsJson => $composableBuilder(
    column: $table.pendingNodeIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attemptsByEdgeJson => $composableBuilder(
    column: $table.attemptsByEdgeJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get circuitBreakerCount => $composableBuilder(
    column: $table.circuitBreakerCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nodeOutputsJson => $composableBuilder(
    column: $table.nodeOutputsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RunsTableAnnotationComposer get runId {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckpointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CheckpointsTable,
          CheckpointRow,
          $$CheckpointsTableFilterComposer,
          $$CheckpointsTableOrderingComposer,
          $$CheckpointsTableAnnotationComposer,
          $$CheckpointsTableCreateCompanionBuilder,
          $$CheckpointsTableUpdateCompanionBuilder,
          (CheckpointRow, $$CheckpointsTableReferences),
          CheckpointRow,
          PrefetchHooks Function({bool runId})
        > {
  $$CheckpointsTableTableManager(_$AppDatabase db, $CheckpointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckpointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckpointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckpointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String?> completedNodeId = const Value.absent(),
                Value<String> pendingNodeIdsJson = const Value.absent(),
                Value<String> attemptsByEdgeJson = const Value.absent(),
                Value<int> circuitBreakerCount = const Value.absent(),
                Value<String> nodeOutputsJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckpointsCompanion(
                id: id,
                runId: runId,
                sequence: sequence,
                completedNodeId: completedNodeId,
                pendingNodeIdsJson: pendingNodeIdsJson,
                attemptsByEdgeJson: attemptsByEdgeJson,
                circuitBreakerCount: circuitBreakerCount,
                nodeOutputsJson: nodeOutputsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required int sequence,
                Value<String?> completedNodeId = const Value.absent(),
                required String pendingNodeIdsJson,
                required String attemptsByEdgeJson,
                required int circuitBreakerCount,
                required String nodeOutputsJson,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CheckpointsCompanion.insert(
                id: id,
                runId: runId,
                sequence: sequence,
                completedNodeId: completedNodeId,
                pendingNodeIdsJson: pendingNodeIdsJson,
                attemptsByEdgeJson: attemptsByEdgeJson,
                circuitBreakerCount: circuitBreakerCount,
                nodeOutputsJson: nodeOutputsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CheckpointsTable, CheckpointRow>(table),
                  $$CheckpointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.runId,
                        referencedTable: $$CheckpointsTableReferences
                            ._runIdTable(db),
                        referencedColumn: $$CheckpointsTableReferences
                            ._runIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CheckpointsTable,
      CheckpointRow,
      $$CheckpointsTableFilterComposer,
      $$CheckpointsTableOrderingComposer,
      $$CheckpointsTableAnnotationComposer,
      $$CheckpointsTableCreateCompanionBuilder,
      $$CheckpointsTableUpdateCompanionBuilder,
      (CheckpointRow, $$CheckpointsTableReferences),
      CheckpointRow,
      PrefetchHooks Function({bool runId})
    >;
typedef $$RunEventsTableCreateCompanionBuilder = RunEventsCompanion Function({
  required String id,
  required String runId,
  required int sequence,
  required String type,
  Value<String?> nodeId,
  Value<String?> edgeId,
  required String payloadJson,
  required String createdAt,
  Value<int> rowid,
});
typedef $$RunEventsTableUpdateCompanionBuilder = RunEventsCompanion Function({
  Value<String> id,
  Value<String> runId,
  Value<int> sequence,
  Value<String> type,
  Value<String?> nodeId,
  Value<String?> edgeId,
  Value<String> payloadJson,
  Value<String> createdAt,
  Value<int> rowid,
});

final class $$RunEventsTableReferences
    extends BaseReferences<_$AppDatabase, $RunEventsTable, RunEventRow> {
  $$RunEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RunsTable _runIdTable(_$AppDatabase db) =>
      db.runs.createAlias('run_events__run_id__runs__id');

  $$RunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RunEventsTableFilterComposer
    extends Composer<_$AppDatabase, $RunEventsTable> {
  $$RunEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edgeId => $composableBuilder(
    column: $table.edgeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RunsTableFilterComposer get runId {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunEventsTable> {
  $$RunEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edgeId => $composableBuilder(
    column: $table.edgeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RunsTableOrderingComposer get runId {
    final $$RunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableOrderingComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunEventsTable> {
  $$RunEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get edgeId =>
      $composableBuilder(column: $table.edgeId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RunsTableAnnotationComposer get runId {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunEventsTable,
          RunEventRow,
          $$RunEventsTableFilterComposer,
          $$RunEventsTableOrderingComposer,
          $$RunEventsTableAnnotationComposer,
          $$RunEventsTableCreateCompanionBuilder,
          $$RunEventsTableUpdateCompanionBuilder,
          (RunEventRow, $$RunEventsTableReferences),
          RunEventRow,
          PrefetchHooks Function({bool runId})
        > {
  $$RunEventsTableTableManager(_$AppDatabase db, $RunEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> nodeId = const Value.absent(),
                Value<String?> edgeId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunEventsCompanion(
                id: id,
                runId: runId,
                sequence: sequence,
                type: type,
                nodeId: nodeId,
                edgeId: edgeId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required int sequence,
                required String type,
                Value<String?> nodeId = const Value.absent(),
                Value<String?> edgeId = const Value.absent(),
                required String payloadJson,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunEventsCompanion.insert(
                id: id,
                runId: runId,
                sequence: sequence,
                type: type,
                nodeId: nodeId,
                edgeId: edgeId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunEventsTable, RunEventRow>(table),
                  $$RunEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.runId,
                        referencedTable: $$RunEventsTableReferences._runIdTable(
                          db,
                        ),
                        referencedColumn: $$RunEventsTableReferences
                            ._runIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RunEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunEventsTable,
      RunEventRow,
      $$RunEventsTableFilterComposer,
      $$RunEventsTableOrderingComposer,
      $$RunEventsTableAnnotationComposer,
      $$RunEventsTableCreateCompanionBuilder,
      $$RunEventsTableUpdateCompanionBuilder,
      (RunEventRow, $$RunEventsTableReferences),
      RunEventRow,
      PrefetchHooks Function({bool runId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
  $$WorkflowsTableTableManager get workflows =>
      $$WorkflowsTableTableManager(_db, _db.workflows);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$CheckpointsTableTableManager get checkpoints =>
      $$CheckpointsTableTableManager(_db, _db.checkpoints);
  $$RunEventsTableTableManager get runEvents =>
      $$RunEventsTableTableManager(_db, _db.runEvents);
}
