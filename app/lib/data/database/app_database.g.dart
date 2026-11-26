// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MeetingsTable extends Meetings with TableInfo<$MeetingsTable, Meeting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peaksPathMeta = const VerificationMeta(
    'peaksPath',
  );
  @override
  late final GeneratedColumn<String> peaksPath = GeneratedColumn<String>(
    'peaks_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _segmentCountMeta = const VerificationMeta(
    'segmentCount',
  );
  @override
  late final GeneratedColumn<int> segmentCount = GeneratedColumn<int>(
    'segment_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Recorded'),
  );
  static const VerificationMeta _isPartialMeta = const VerificationMeta(
    'isPartial',
  );
  @override
  late final GeneratedColumn<bool> isPartial = GeneratedColumn<bool>(
    'is_partial',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_partial" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isForceModeMeta = const VerificationMeta(
    'isForceMode',
  );
  @override
  late final GeneratedColumn<bool> isForceMode = GeneratedColumn<bool>(
    'is_force_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_force_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _markersJsonMeta = const VerificationMeta(
    'markersJson',
  );
  @override
  late final GeneratedColumn<String> markersJson = GeneratedColumn<String>(
    'markers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    audioPath,
    peaksPath,
    durationMs,
    sizeBytes,
    segmentCount,
    language,
    status,
    isPartial,
    isForceMode,
    isDeleted,
    markersJson,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meeting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('peaks_path')) {
      context.handle(
        _peaksPathMeta,
        peaksPath.isAcceptableOrUnknown(data['peaks_path']!, _peaksPathMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('segment_count')) {
      context.handle(
        _segmentCountMeta,
        segmentCount.isAcceptableOrUnknown(
          data['segment_count']!,
          _segmentCountMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_partial')) {
      context.handle(
        _isPartialMeta,
        isPartial.isAcceptableOrUnknown(data['is_partial']!, _isPartialMeta),
      );
    }
    if (data.containsKey('is_force_mode')) {
      context.handle(
        _isForceModeMeta,
        isForceMode.isAcceptableOrUnknown(
          data['is_force_mode']!,
          _isForceModeMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('markers_json')) {
      context.handle(
        _markersJsonMeta,
        markersJson.isAcceptableOrUnknown(
          data['markers_json']!,
          _markersJsonMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
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
  Meeting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meeting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      peaksPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peaks_path'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      segmentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_count'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isPartial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_partial'],
      )!,
      isForceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_force_mode'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      markersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markers_json'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MeetingsTable createAlias(String alias) {
    return $MeetingsTable(attachedDatabase, alias);
  }
}

class Meeting extends DataClass implements Insertable<Meeting> {
  final String id;
  final String title;
  final String? audioPath;
  final String? peaksPath;
  final int durationMs;
  final int sizeBytes;
  final int segmentCount;
  final String language;
  final String status;
  final bool isPartial;
  final bool isForceMode;
  final bool isDeleted;
  final String markersJson;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Meeting({
    required this.id,
    required this.title,
    this.audioPath,
    this.peaksPath,
    required this.durationMs,
    required this.sizeBytes,
    required this.segmentCount,
    required this.language,
    required this.status,
    required this.isPartial,
    required this.isForceMode,
    required this.isDeleted,
    required this.markersJson,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || peaksPath != null) {
      map['peaks_path'] = Variable<String>(peaksPath);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['segment_count'] = Variable<int>(segmentCount);
    map['language'] = Variable<String>(language);
    map['status'] = Variable<String>(status);
    map['is_partial'] = Variable<bool>(isPartial);
    map['is_force_mode'] = Variable<bool>(isForceMode);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['markers_json'] = Variable<String>(markersJson);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MeetingsCompanion toCompanion(bool nullToAbsent) {
    return MeetingsCompanion(
      id: Value(id),
      title: Value(title),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      peaksPath: peaksPath == null && nullToAbsent
          ? const Value.absent()
          : Value(peaksPath),
      durationMs: Value(durationMs),
      sizeBytes: Value(sizeBytes),
      segmentCount: Value(segmentCount),
      language: Value(language),
      status: Value(status),
      isPartial: Value(isPartial),
      isForceMode: Value(isForceMode),
      isDeleted: Value(isDeleted),
      markersJson: Value(markersJson),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Meeting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meeting(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      peaksPath: serializer.fromJson<String?>(json['peaksPath']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      segmentCount: serializer.fromJson<int>(json['segmentCount']),
      language: serializer.fromJson<String>(json['language']),
      status: serializer.fromJson<String>(json['status']),
      isPartial: serializer.fromJson<bool>(json['isPartial']),
      isForceMode: serializer.fromJson<bool>(json['isForceMode']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      markersJson: serializer.fromJson<String>(json['markersJson']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'audioPath': serializer.toJson<String?>(audioPath),
      'peaksPath': serializer.toJson<String?>(peaksPath),
      'durationMs': serializer.toJson<int>(durationMs),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'segmentCount': serializer.toJson<int>(segmentCount),
      'language': serializer.toJson<String>(language),
      'status': serializer.toJson<String>(status),
      'isPartial': serializer.toJson<bool>(isPartial),
      'isForceMode': serializer.toJson<bool>(isForceMode),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'markersJson': serializer.toJson<String>(markersJson),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Meeting copyWith({
    String? id,
    String? title,
    Value<String?> audioPath = const Value.absent(),
    Value<String?> peaksPath = const Value.absent(),
    int? durationMs,
    int? sizeBytes,
    int? segmentCount,
    String? language,
    String? status,
    bool? isPartial,
    bool? isForceMode,
    bool? isDeleted,
    String? markersJson,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Meeting(
    id: id ?? this.id,
    title: title ?? this.title,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    peaksPath: peaksPath.present ? peaksPath.value : this.peaksPath,
    durationMs: durationMs ?? this.durationMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    segmentCount: segmentCount ?? this.segmentCount,
    language: language ?? this.language,
    status: status ?? this.status,
    isPartial: isPartial ?? this.isPartial,
    isForceMode: isForceMode ?? this.isForceMode,
    isDeleted: isDeleted ?? this.isDeleted,
    markersJson: markersJson ?? this.markersJson,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Meeting copyWithCompanion(MeetingsCompanion data) {
    return Meeting(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      peaksPath: data.peaksPath.present ? data.peaksPath.value : this.peaksPath,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      segmentCount: data.segmentCount.present
          ? data.segmentCount.value
          : this.segmentCount,
      language: data.language.present ? data.language.value : this.language,
      status: data.status.present ? data.status.value : this.status,
      isPartial: data.isPartial.present ? data.isPartial.value : this.isPartial,
      isForceMode: data.isForceMode.present
          ? data.isForceMode.value
          : this.isForceMode,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      markersJson: data.markersJson.present
          ? data.markersJson.value
          : this.markersJson,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meeting(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('audioPath: $audioPath, ')
          ..write('peaksPath: $peaksPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('segmentCount: $segmentCount, ')
          ..write('language: $language, ')
          ..write('status: $status, ')
          ..write('isPartial: $isPartial, ')
          ..write('isForceMode: $isForceMode, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('markersJson: $markersJson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    audioPath,
    peaksPath,
    durationMs,
    sizeBytes,
    segmentCount,
    language,
    status,
    isPartial,
    isForceMode,
    isDeleted,
    markersJson,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meeting &&
          other.id == this.id &&
          other.title == this.title &&
          other.audioPath == this.audioPath &&
          other.peaksPath == this.peaksPath &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.segmentCount == this.segmentCount &&
          other.language == this.language &&
          other.status == this.status &&
          other.isPartial == this.isPartial &&
          other.isForceMode == this.isForceMode &&
          other.isDeleted == this.isDeleted &&
          other.markersJson == this.markersJson &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MeetingsCompanion extends UpdateCompanion<Meeting> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> audioPath;
  final Value<String?> peaksPath;
  final Value<int> durationMs;
  final Value<int> sizeBytes;
  final Value<int> segmentCount;
  final Value<String> language;
  final Value<String> status;
  final Value<bool> isPartial;
  final Value<bool> isForceMode;
  final Value<bool> isDeleted;
  final Value<String> markersJson;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MeetingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.peaksPath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.segmentCount = const Value.absent(),
    this.language = const Value.absent(),
    this.status = const Value.absent(),
    this.isPartial = const Value.absent(),
    this.isForceMode = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.markersJson = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingsCompanion.insert({
    required String id,
    required String title,
    this.audioPath = const Value.absent(),
    this.peaksPath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.segmentCount = const Value.absent(),
    this.language = const Value.absent(),
    this.status = const Value.absent(),
    this.isPartial = const Value.absent(),
    this.isForceMode = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.markersJson = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Meeting> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? audioPath,
    Expression<String>? peaksPath,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<int>? segmentCount,
    Expression<String>? language,
    Expression<String>? status,
    Expression<bool>? isPartial,
    Expression<bool>? isForceMode,
    Expression<bool>? isDeleted,
    Expression<String>? markersJson,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (audioPath != null) 'audio_path': audioPath,
      if (peaksPath != null) 'peaks_path': peaksPath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (segmentCount != null) 'segment_count': segmentCount,
      if (language != null) 'language': language,
      if (status != null) 'status': status,
      if (isPartial != null) 'is_partial': isPartial,
      if (isForceMode != null) 'is_force_mode': isForceMode,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (markersJson != null) 'markers_json': markersJson,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? audioPath,
    Value<String?>? peaksPath,
    Value<int>? durationMs,
    Value<int>? sizeBytes,
    Value<int>? segmentCount,
    Value<String>? language,
    Value<String>? status,
    Value<bool>? isPartial,
    Value<bool>? isForceMode,
    Value<bool>? isDeleted,
    Value<String>? markersJson,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MeetingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      audioPath: audioPath ?? this.audioPath,
      peaksPath: peaksPath ?? this.peaksPath,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      segmentCount: segmentCount ?? this.segmentCount,
      language: language ?? this.language,
      status: status ?? this.status,
      isPartial: isPartial ?? this.isPartial,
      isForceMode: isForceMode ?? this.isForceMode,
      isDeleted: isDeleted ?? this.isDeleted,
      markersJson: markersJson ?? this.markersJson,
      note: note ?? this.note,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (peaksPath.present) {
      map['peaks_path'] = Variable<String>(peaksPath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (segmentCount.present) {
      map['segment_count'] = Variable<int>(segmentCount.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isPartial.present) {
      map['is_partial'] = Variable<bool>(isPartial.value);
    }
    if (isForceMode.present) {
      map['is_force_mode'] = Variable<bool>(isForceMode.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (markersJson.present) {
      map['markers_json'] = Variable<String>(markersJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('audioPath: $audioPath, ')
          ..write('peaksPath: $peaksPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('segmentCount: $segmentCount, ')
          ..write('language: $language, ')
          ..write('status: $status, ')
          ..write('isPartial: $isPartial, ')
          ..write('isForceMode: $isForceMode, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('markersJson: $markersJson, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpeakersTable extends Speakers with TableInfo<$SpeakersTable, Speaker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, meetingId, label, displayName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speakers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Speaker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Speaker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Speaker(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
    );
  }

  @override
  $SpeakersTable createAlias(String alias) {
    return $SpeakersTable(attachedDatabase, alias);
  }
}

class Speaker extends DataClass implements Insertable<Speaker> {
  final String id;
  final String meetingId;
  final String label;
  final String displayName;
  const Speaker({
    required this.id,
    required this.meetingId,
    required this.label,
    required this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['label'] = Variable<String>(label);
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  SpeakersCompanion toCompanion(bool nullToAbsent) {
    return SpeakersCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      label: Value(label),
      displayName: Value(displayName),
    );
  }

  factory Speaker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Speaker(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      label: serializer.fromJson<String>(json['label']),
      displayName: serializer.fromJson<String>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'label': serializer.toJson<String>(label),
      'displayName': serializer.toJson<String>(displayName),
    };
  }

  Speaker copyWith({
    String? id,
    String? meetingId,
    String? label,
    String? displayName,
  }) => Speaker(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    label: label ?? this.label,
    displayName: displayName ?? this.displayName,
  );
  Speaker copyWithCompanion(SpeakersCompanion data) {
    return Speaker(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      label: data.label.present ? data.label.value : this.label,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Speaker(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('label: $label, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, meetingId, label, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Speaker &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.label == this.label &&
          other.displayName == this.displayName);
}

class SpeakersCompanion extends UpdateCompanion<Speaker> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<String> label;
  final Value<String> displayName;
  final Value<int> rowid;
  const SpeakersCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.label = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeakersCompanion.insert({
    required String id,
    required String meetingId,
    required String label,
    required String displayName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       label = Value(label),
       displayName = Value(displayName);
  static Insertable<Speaker> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<String>? label,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (label != null) 'label': label,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeakersCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<String>? label,
    Value<String>? displayName,
    Value<int>? rowid,
  }) {
    return SpeakersCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      label: label ?? this.label,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakersCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('label: $label, ')
          ..write('displayName: $displayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _speakerIdMeta = const VerificationMeta(
    'speakerId',
  );
  @override
  late final GeneratedColumn<String> speakerId = GeneratedColumn<String>(
    'speaker_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES speakers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _startSecMeta = const VerificationMeta(
    'startSec',
  );
  @override
  late final GeneratedColumn<double> startSec = GeneratedColumn<double>(
    'start_sec',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endSecMeta = const VerificationMeta('endSec');
  @override
  late final GeneratedColumn<double> endSec = GeneratedColumn<double>(
    'end_sec',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
    'edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    speakerId,
    startSec,
    endSec,
    textContent,
    edited,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('speaker_id')) {
      context.handle(
        _speakerIdMeta,
        speakerId.isAcceptableOrUnknown(data['speaker_id']!, _speakerIdMeta),
      );
    }
    if (data.containsKey('start_sec')) {
      context.handle(
        _startSecMeta,
        startSec.isAcceptableOrUnknown(data['start_sec']!, _startSecMeta),
      );
    } else if (isInserting) {
      context.missing(_startSecMeta);
    }
    if (data.containsKey('end_sec')) {
      context.handle(
        _endSecMeta,
        endSec.isAcceptableOrUnknown(data['end_sec']!, _endSecMeta),
      );
    } else if (isInserting) {
      context.missing(_endSecMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      speakerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_id'],
      ),
      startSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_sec'],
      )!,
      endSec: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_sec'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      )!,
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }
}

class TranscriptSegment extends DataClass
    implements Insertable<TranscriptSegment> {
  final String id;
  final String meetingId;
  final String? speakerId;
  final double startSec;
  final double endSec;
  final String textContent;
  final bool edited;
  final int sortOrder;
  const TranscriptSegment({
    required this.id,
    required this.meetingId,
    this.speakerId,
    required this.startSec,
    required this.endSec,
    required this.textContent,
    required this.edited,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    if (!nullToAbsent || speakerId != null) {
      map['speaker_id'] = Variable<String>(speakerId);
    }
    map['start_sec'] = Variable<double>(startSec);
    map['end_sec'] = Variable<double>(endSec);
    map['text_content'] = Variable<String>(textContent);
    map['edited'] = Variable<bool>(edited);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      speakerId: speakerId == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerId),
      startSec: Value(startSec),
      endSec: Value(endSec),
      textContent: Value(textContent),
      edited: Value(edited),
      sortOrder: Value(sortOrder),
    );
  }

  factory TranscriptSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegment(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      speakerId: serializer.fromJson<String?>(json['speakerId']),
      startSec: serializer.fromJson<double>(json['startSec']),
      endSec: serializer.fromJson<double>(json['endSec']),
      textContent: serializer.fromJson<String>(json['textContent']),
      edited: serializer.fromJson<bool>(json['edited']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'speakerId': serializer.toJson<String?>(speakerId),
      'startSec': serializer.toJson<double>(startSec),
      'endSec': serializer.toJson<double>(endSec),
      'textContent': serializer.toJson<String>(textContent),
      'edited': serializer.toJson<bool>(edited),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TranscriptSegment copyWith({
    String? id,
    String? meetingId,
    Value<String?> speakerId = const Value.absent(),
    double? startSec,
    double? endSec,
    String? textContent,
    bool? edited,
    int? sortOrder,
  }) => TranscriptSegment(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    speakerId: speakerId.present ? speakerId.value : this.speakerId,
    startSec: startSec ?? this.startSec,
    endSec: endSec ?? this.endSec,
    textContent: textContent ?? this.textContent,
    edited: edited ?? this.edited,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  TranscriptSegment copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegment(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      speakerId: data.speakerId.present ? data.speakerId.value : this.speakerId,
      startSec: data.startSec.present ? data.startSec.value : this.startSec,
      endSec: data.endSec.present ? data.endSec.value : this.endSec,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      edited: data.edited.present ? data.edited.value : this.edited,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegment(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('speakerId: $speakerId, ')
          ..write('startSec: $startSec, ')
          ..write('endSec: $endSec, ')
          ..write('textContent: $textContent, ')
          ..write('edited: $edited, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    speakerId,
    startSec,
    endSec,
    textContent,
    edited,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegment &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.speakerId == this.speakerId &&
          other.startSec == this.startSec &&
          other.endSec == this.endSec &&
          other.textContent == this.textContent &&
          other.edited == this.edited &&
          other.sortOrder == this.sortOrder);
}

class TranscriptSegmentsCompanion extends UpdateCompanion<TranscriptSegment> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<String?> speakerId;
  final Value<double> startSec;
  final Value<double> endSec;
  final Value<String> textContent;
  final Value<bool> edited;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TranscriptSegmentsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.speakerId = const Value.absent(),
    this.startSec = const Value.absent(),
    this.endSec = const Value.absent(),
    this.textContent = const Value.absent(),
    this.edited = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    required String id,
    required String meetingId,
    this.speakerId = const Value.absent(),
    required double startSec,
    required double endSec,
    required String textContent,
    this.edited = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       startSec = Value(startSec),
       endSec = Value(endSec),
       textContent = Value(textContent);
  static Insertable<TranscriptSegment> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<String>? speakerId,
    Expression<double>? startSec,
    Expression<double>? endSec,
    Expression<String>? textContent,
    Expression<bool>? edited,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (speakerId != null) 'speaker_id': speakerId,
      if (startSec != null) 'start_sec': startSec,
      if (endSec != null) 'end_sec': endSec,
      if (textContent != null) 'text_content': textContent,
      if (edited != null) 'edited': edited,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<String?>? speakerId,
    Value<double>? startSec,
    Value<double>? endSec,
    Value<String>? textContent,
    Value<bool>? edited,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return TranscriptSegmentsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      speakerId: speakerId ?? this.speakerId,
      startSec: startSec ?? this.startSec,
      endSec: endSec ?? this.endSec,
      textContent: textContent ?? this.textContent,
      edited: edited ?? this.edited,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (speakerId.present) {
      map['speaker_id'] = Variable<String>(speakerId.value);
    }
    if (startSec.present) {
      map['start_sec'] = Variable<double>(startSec.value);
    }
    if (endSec.present) {
      map['end_sec'] = Variable<double>(endSec.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('speakerId: $speakerId, ')
          ..write('startSec: $startSec, ')
          ..write('endSec: $endSec, ')
          ..write('textContent: $textContent, ')
          ..write('edited: $edited, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SummariesTable extends Summaries
    with TableInfo<$SummariesTable, Summary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyPointsJsonMeta = const VerificationMeta(
    'keyPointsJson',
  );
  @override
  late final GeneratedColumn<String> keyPointsJson = GeneratedColumn<String>(
    'key_points_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _decisionsJsonMeta = const VerificationMeta(
    'decisionsJson',
  );
  @override
  late final GeneratedColumn<String> decisionsJson = GeneratedColumn<String>(
    'decisions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _openQuestionsJsonMeta = const VerificationMeta(
    'openQuestionsJson',
  );
  @override
  late final GeneratedColumn<String> openQuestionsJson =
      GeneratedColumn<String>(
        'open_questions_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    summary,
    keyPointsJson,
    decisionsJson,
    openQuestionsJson,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Summary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('key_points_json')) {
      context.handle(
        _keyPointsJsonMeta,
        keyPointsJson.isAcceptableOrUnknown(
          data['key_points_json']!,
          _keyPointsJsonMeta,
        ),
      );
    }
    if (data.containsKey('decisions_json')) {
      context.handle(
        _decisionsJsonMeta,
        decisionsJson.isAcceptableOrUnknown(
          data['decisions_json']!,
          _decisionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('open_questions_json')) {
      context.handle(
        _openQuestionsJsonMeta,
        openQuestionsJson.isAcceptableOrUnknown(
          data['open_questions_json']!,
          _openQuestionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Summary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Summary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      keyPointsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_points_json'],
      )!,
      decisionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decisions_json'],
      )!,
      openQuestionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}open_questions_json'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
    );
  }

  @override
  $SummariesTable createAlias(String alias) {
    return $SummariesTable(attachedDatabase, alias);
  }
}

class Summary extends DataClass implements Insertable<Summary> {
  final String id;
  final String meetingId;
  final String summary;
  final String keyPointsJson;
  final String decisionsJson;
  final String openQuestionsJson;
  final String rawJson;
  const Summary({
    required this.id,
    required this.meetingId,
    required this.summary,
    required this.keyPointsJson,
    required this.decisionsJson,
    required this.openQuestionsJson,
    required this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['summary'] = Variable<String>(summary);
    map['key_points_json'] = Variable<String>(keyPointsJson);
    map['decisions_json'] = Variable<String>(decisionsJson);
    map['open_questions_json'] = Variable<String>(openQuestionsJson);
    map['raw_json'] = Variable<String>(rawJson);
    return map;
  }

  SummariesCompanion toCompanion(bool nullToAbsent) {
    return SummariesCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      summary: Value(summary),
      keyPointsJson: Value(keyPointsJson),
      decisionsJson: Value(decisionsJson),
      openQuestionsJson: Value(openQuestionsJson),
      rawJson: Value(rawJson),
    );
  }

  factory Summary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Summary(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      summary: serializer.fromJson<String>(json['summary']),
      keyPointsJson: serializer.fromJson<String>(json['keyPointsJson']),
      decisionsJson: serializer.fromJson<String>(json['decisionsJson']),
      openQuestionsJson: serializer.fromJson<String>(json['openQuestionsJson']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'summary': serializer.toJson<String>(summary),
      'keyPointsJson': serializer.toJson<String>(keyPointsJson),
      'decisionsJson': serializer.toJson<String>(decisionsJson),
      'openQuestionsJson': serializer.toJson<String>(openQuestionsJson),
      'rawJson': serializer.toJson<String>(rawJson),
    };
  }

  Summary copyWith({
    String? id,
    String? meetingId,
    String? summary,
    String? keyPointsJson,
    String? decisionsJson,
    String? openQuestionsJson,
    String? rawJson,
  }) => Summary(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    summary: summary ?? this.summary,
    keyPointsJson: keyPointsJson ?? this.keyPointsJson,
    decisionsJson: decisionsJson ?? this.decisionsJson,
    openQuestionsJson: openQuestionsJson ?? this.openQuestionsJson,
    rawJson: rawJson ?? this.rawJson,
  );
  Summary copyWithCompanion(SummariesCompanion data) {
    return Summary(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      summary: data.summary.present ? data.summary.value : this.summary,
      keyPointsJson: data.keyPointsJson.present
          ? data.keyPointsJson.value
          : this.keyPointsJson,
      decisionsJson: data.decisionsJson.present
          ? data.decisionsJson.value
          : this.decisionsJson,
      openQuestionsJson: data.openQuestionsJson.present
          ? data.openQuestionsJson.value
          : this.openQuestionsJson,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Summary(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('summary: $summary, ')
          ..write('keyPointsJson: $keyPointsJson, ')
          ..write('decisionsJson: $decisionsJson, ')
          ..write('openQuestionsJson: $openQuestionsJson, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meetingId,
    summary,
    keyPointsJson,
    decisionsJson,
    openQuestionsJson,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Summary &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.summary == this.summary &&
          other.keyPointsJson == this.keyPointsJson &&
          other.decisionsJson == this.decisionsJson &&
          other.openQuestionsJson == this.openQuestionsJson &&
          other.rawJson == this.rawJson);
}

class SummariesCompanion extends UpdateCompanion<Summary> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<String> summary;
  final Value<String> keyPointsJson;
  final Value<String> decisionsJson;
  final Value<String> openQuestionsJson;
  final Value<String> rawJson;
  final Value<int> rowid;
  const SummariesCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.summary = const Value.absent(),
    this.keyPointsJson = const Value.absent(),
    this.decisionsJson = const Value.absent(),
    this.openQuestionsJson = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SummariesCompanion.insert({
    required String id,
    required String meetingId,
    required String summary,
    this.keyPointsJson = const Value.absent(),
    this.decisionsJson = const Value.absent(),
    this.openQuestionsJson = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       summary = Value(summary);
  static Insertable<Summary> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<String>? summary,
    Expression<String>? keyPointsJson,
    Expression<String>? decisionsJson,
    Expression<String>? openQuestionsJson,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (summary != null) 'summary': summary,
      if (keyPointsJson != null) 'key_points_json': keyPointsJson,
      if (decisionsJson != null) 'decisions_json': decisionsJson,
      if (openQuestionsJson != null) 'open_questions_json': openQuestionsJson,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SummariesCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<String>? summary,
    Value<String>? keyPointsJson,
    Value<String>? decisionsJson,
    Value<String>? openQuestionsJson,
    Value<String>? rawJson,
    Value<int>? rowid,
  }) {
    return SummariesCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      summary: summary ?? this.summary,
      keyPointsJson: keyPointsJson ?? this.keyPointsJson,
      decisionsJson: decisionsJson ?? this.decisionsJson,
      openQuestionsJson: openQuestionsJson ?? this.openQuestionsJson,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (keyPointsJson.present) {
      map['key_points_json'] = Variable<String>(keyPointsJson.value);
    }
    if (decisionsJson.present) {
      map['decisions_json'] = Variable<String>(decisionsJson.value);
    }
    if (openQuestionsJson.present) {
      map['open_questions_json'] = Variable<String>(openQuestionsJson.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SummariesCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('summary: $summary, ')
          ..write('keyPointsJson: $keyPointsJson, ')
          ..write('decisionsJson: $decisionsJson, ')
          ..write('openQuestionsJson: $openQuestionsJson, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActionItemsTable extends ActionItems
    with TableInfo<$ActionItemsTable, ActionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _taskMeta = const VerificationMeta('task');
  @override
  late final GeneratedColumn<String> task = GeneratedColumn<String>(
    'task',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Unassigned'),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meetingId,
    task,
    owner,
    dueDate,
    done,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'action_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('task')) {
      context.handle(
        _taskMeta,
        task.isAcceptableOrUnknown(data['task']!, _taskMeta),
      );
    } else if (isInserting) {
      context.missing(_taskMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActionItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      task: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      ),
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ActionItemsTable createAlias(String alias) {
    return $ActionItemsTable(attachedDatabase, alias);
  }
}

class ActionItem extends DataClass implements Insertable<ActionItem> {
  final String id;
  final String meetingId;
  final String task;
  final String owner;
  final String? dueDate;
  final bool done;
  final int sortOrder;
  const ActionItem({
    required this.id,
    required this.meetingId,
    required this.task,
    required this.owner,
    this.dueDate,
    required this.done,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meeting_id'] = Variable<String>(meetingId);
    map['task'] = Variable<String>(task);
    map['owner'] = Variable<String>(owner);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ActionItemsCompanion toCompanion(bool nullToAbsent) {
    return ActionItemsCompanion(
      id: Value(id),
      meetingId: Value(meetingId),
      task: Value(task),
      owner: Value(owner),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      done: Value(done),
      sortOrder: Value(sortOrder),
    );
  }

  factory ActionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActionItem(
      id: serializer.fromJson<String>(json['id']),
      meetingId: serializer.fromJson<String>(json['meetingId']),
      task: serializer.fromJson<String>(json['task']),
      owner: serializer.fromJson<String>(json['owner']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'meetingId': serializer.toJson<String>(meetingId),
      'task': serializer.toJson<String>(task),
      'owner': serializer.toJson<String>(owner),
      'dueDate': serializer.toJson<String?>(dueDate),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ActionItem copyWith({
    String? id,
    String? meetingId,
    String? task,
    String? owner,
    Value<String?> dueDate = const Value.absent(),
    bool? done,
    int? sortOrder,
  }) => ActionItem(
    id: id ?? this.id,
    meetingId: meetingId ?? this.meetingId,
    task: task ?? this.task,
    owner: owner ?? this.owner,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ActionItem copyWithCompanion(ActionItemsCompanion data) {
    return ActionItem(
      id: data.id.present ? data.id.value : this.id,
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      task: data.task.present ? data.task.value : this.task,
      owner: data.owner.present ? data.owner.value : this.owner,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActionItem(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('task: $task, ')
          ..write('owner: $owner, ')
          ..write('dueDate: $dueDate, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, meetingId, task, owner, dueDate, done, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActionItem &&
          other.id == this.id &&
          other.meetingId == this.meetingId &&
          other.task == this.task &&
          other.owner == this.owner &&
          other.dueDate == this.dueDate &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder);
}

class ActionItemsCompanion extends UpdateCompanion<ActionItem> {
  final Value<String> id;
  final Value<String> meetingId;
  final Value<String> task;
  final Value<String> owner;
  final Value<String?> dueDate;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ActionItemsCompanion({
    this.id = const Value.absent(),
    this.meetingId = const Value.absent(),
    this.task = const Value.absent(),
    this.owner = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActionItemsCompanion.insert({
    required String id,
    required String meetingId,
    required String task,
    this.owner = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       meetingId = Value(meetingId),
       task = Value(task);
  static Insertable<ActionItem> custom({
    Expression<String>? id,
    Expression<String>? meetingId,
    Expression<String>? task,
    Expression<String>? owner,
    Expression<String>? dueDate,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      if (task != null) 'task': task,
      if (owner != null) 'owner': owner,
      if (dueDate != null) 'due_date': dueDate,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActionItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? meetingId,
    Value<String>? task,
    Value<String>? owner,
    Value<String?>? dueDate,
    Value<bool>? done,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ActionItemsCompanion(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      task: task ?? this.task,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (task.present) {
      map['task'] = Variable<String>(task.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActionItemsCompanion(')
          ..write('id: $id, ')
          ..write('meetingId: $meetingId, ')
          ..write('task: $task, ')
          ..write('owner: $owner, ')
          ..write('dueDate: $dueDate, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  const Tag({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(id: Value(id), name: Value(name));
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Tag copyWith({String? id, String? name}) =>
      Tag(id: id ?? this.id, name: name ?? this.name);
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag && other.id == this.id && other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeetingTagsTable extends MeetingTags
    with TableInfo<$MeetingTagsTable, MeetingTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeetingTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _meetingIdMeta = const VerificationMeta(
    'meetingId',
  );
  @override
  late final GeneratedColumn<String> meetingId = GeneratedColumn<String>(
    'meeting_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meetings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [meetingId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meeting_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MeetingTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('meeting_id')) {
      context.handle(
        _meetingIdMeta,
        meetingId.isAcceptableOrUnknown(data['meeting_id']!, _meetingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meetingIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {meetingId, tagId};
  @override
  MeetingTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeetingTag(
      meetingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meeting_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $MeetingTagsTable createAlias(String alias) {
    return $MeetingTagsTable(attachedDatabase, alias);
  }
}

class MeetingTag extends DataClass implements Insertable<MeetingTag> {
  final String meetingId;
  final String tagId;
  const MeetingTag({required this.meetingId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meeting_id'] = Variable<String>(meetingId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  MeetingTagsCompanion toCompanion(bool nullToAbsent) {
    return MeetingTagsCompanion(
      meetingId: Value(meetingId),
      tagId: Value(tagId),
    );
  }

  factory MeetingTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeetingTag(
      meetingId: serializer.fromJson<String>(json['meetingId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'meetingId': serializer.toJson<String>(meetingId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  MeetingTag copyWith({String? meetingId, String? tagId}) => MeetingTag(
    meetingId: meetingId ?? this.meetingId,
    tagId: tagId ?? this.tagId,
  );
  MeetingTag copyWithCompanion(MeetingTagsCompanion data) {
    return MeetingTag(
      meetingId: data.meetingId.present ? data.meetingId.value : this.meetingId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeetingTag(')
          ..write('meetingId: $meetingId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(meetingId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeetingTag &&
          other.meetingId == this.meetingId &&
          other.tagId == this.tagId);
}

class MeetingTagsCompanion extends UpdateCompanion<MeetingTag> {
  final Value<String> meetingId;
  final Value<String> tagId;
  final Value<int> rowid;
  const MeetingTagsCompanion({
    this.meetingId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeetingTagsCompanion.insert({
    required String meetingId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : meetingId = Value(meetingId),
       tagId = Value(tagId);
  static Insertable<MeetingTag> custom({
    Expression<String>? meetingId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (meetingId != null) 'meeting_id': meetingId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeetingTagsCompanion copyWith({
    Value<String>? meetingId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return MeetingTagsCompanion(
      meetingId: meetingId ?? this.meetingId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (meetingId.present) {
      map['meeting_id'] = Variable<String>(meetingId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeetingTagsCompanion(')
          ..write('meetingId: $meetingId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MeetingsTable meetings = $MeetingsTable(this);
  late final $SpeakersTable speakers = $SpeakersTable(this);
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  late final $SummariesTable summaries = $SummariesTable(this);
  late final $ActionItemsTable actionItems = $ActionItemsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $MeetingTagsTable meetingTags = $MeetingTagsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    meetings,
    speakers,
    transcriptSegments,
    summaries,
    actionItems,
    tags,
    meetingTags,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speakers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'speakers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('summaries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('action_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meetings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meeting_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meeting_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MeetingsTableCreateCompanionBuilder = MeetingsCompanion Function({
  required String id,
  required String title,
  Value<String?> audioPath,
  Value<String?> peaksPath,
  Value<int> durationMs,
  Value<int> sizeBytes,
  Value<int> segmentCount,
  Value<String> language,
  Value<String> status,
  Value<bool> isPartial,
  Value<bool> isForceMode,
  Value<bool> isDeleted,
  Value<String> markersJson,
  Value<String?> note,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$MeetingsTableUpdateCompanionBuilder = MeetingsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> audioPath,
  Value<String?> peaksPath,
  Value<int> durationMs,
  Value<int> sizeBytes,
  Value<int> segmentCount,
  Value<String> language,
  Value<String> status,
  Value<bool> isPartial,
  Value<bool> isForceMode,
  Value<bool> isDeleted,
  Value<String> markersJson,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$MeetingsTableReferences
    extends BaseReferences<_$AppDatabase, $MeetingsTable, Meeting> {
  $$MeetingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SpeakersTable, List<Speaker>> _speakersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.speakers,
    aliasName: 'meetings__id__speakers__meeting_id',
  );

  $$SpeakersTableProcessedTableManager get speakersRefs {
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_speakersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranscriptSegmentsTable, List<TranscriptSegment>>
  _transcriptSegmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName: 'meetings__id__transcript_segments__meeting_id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SummariesTable, List<Summary>>
  _summariesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.summaries,
    aliasName: 'meetings__id__summaries__meeting_id',
  );

  $$SummariesTableProcessedTableManager get summariesRefs {
    final manager = $$SummariesTableTableManager(
      $_db,
      $_db.summaries,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_summariesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActionItemsTable, List<ActionItem>>
  _actionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.actionItems,
    aliasName: 'meetings__id__action_items__meeting_id',
  );

  $$ActionItemsTableProcessedTableManager get actionItemsRefs {
    final manager = $$ActionItemsTableTableManager(
      $_db,
      $_db.actionItems,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_actionItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MeetingTagsTable, List<MeetingTag>>
  _meetingTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.meetingTags,
    aliasName: 'meetings__id__meeting_tags__meeting_id',
  );

  $$MeetingTagsTableProcessedTableManager get meetingTagsRefs {
    final manager = $$MeetingTagsTableTableManager(
      $_db,
      $_db.meetingTags,
    ).filter((f) => f.meetingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_meetingTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peaksPath => $composableBuilder(
    column: $table.peaksPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentCount => $composableBuilder(
    column: $table.segmentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPartial => $composableBuilder(
    column: $table.isPartial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isForceMode => $composableBuilder(
    column: $table.isForceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markersJson => $composableBuilder(
    column: $table.markersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> speakersRefs(
    Expression<bool> Function($$SpeakersTableFilterComposer f) f,
  ) {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> summariesRefs(
    Expression<bool> Function($$SummariesTableFilterComposer f) f,
  ) {
    final $$SummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.summaries,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SummariesTableFilterComposer(
            $db: $db,
            $table: $db.summaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> actionItemsRefs(
    Expression<bool> Function($$ActionItemsTableFilterComposer f) f,
  ) {
    final $$ActionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.actionItems,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActionItemsTableFilterComposer(
            $db: $db,
            $table: $db.actionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> meetingTagsRefs(
    Expression<bool> Function($$MeetingTagsTableFilterComposer f) f,
  ) {
    final $$MeetingTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meetingTags,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingTagsTableFilterComposer(
            $db: $db,
            $table: $db.meetingTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peaksPath => $composableBuilder(
    column: $table.peaksPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentCount => $composableBuilder(
    column: $table.segmentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPartial => $composableBuilder(
    column: $table.isPartial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isForceMode => $composableBuilder(
    column: $table.isForceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markersJson => $composableBuilder(
    column: $table.markersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingsTable> {
  $$MeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get peaksPath =>
      $composableBuilder(column: $table.peaksPath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get segmentCount => $composableBuilder(
    column: $table.segmentCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isPartial =>
      $composableBuilder(column: $table.isPartial, builder: (column) => column);

  GeneratedColumn<bool> get isForceMode => $composableBuilder(
    column: $table.isForceMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get markersJson => $composableBuilder(
    column: $table.markersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> speakersRefs<T extends Object>(
    Expression<T> Function($$SpeakersTableAnnotationComposer a) f,
  ) {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.meetingId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> summariesRefs<T extends Object>(
    Expression<T> Function($$SummariesTableAnnotationComposer a) f,
  ) {
    final $$SummariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.summaries,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SummariesTableAnnotationComposer(
            $db: $db,
            $table: $db.summaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> actionItemsRefs<T extends Object>(
    Expression<T> Function($$ActionItemsTableAnnotationComposer a) f,
  ) {
    final $$ActionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.actionItems,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.actionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> meetingTagsRefs<T extends Object>(
    Expression<T> Function($$MeetingTagsTableAnnotationComposer a) f,
  ) {
    final $$MeetingTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meetingTags,
      getReferencedColumn: (t) => t.meetingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetingTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingsTable,
          Meeting,
          $$MeetingsTableFilterComposer,
          $$MeetingsTableOrderingComposer,
          $$MeetingsTableAnnotationComposer,
          $$MeetingsTableCreateCompanionBuilder,
          $$MeetingsTableUpdateCompanionBuilder,
          (Meeting, $$MeetingsTableReferences),
          Meeting,
          PrefetchHooks Function({
            bool speakersRefs,
            bool transcriptSegmentsRefs,
            bool summariesRefs,
            bool actionItemsRefs,
            bool meetingTagsRefs,
          })
        > {
  $$MeetingsTableTableManager(_$AppDatabase db, $MeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> peaksPath = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> segmentCount = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isPartial = const Value.absent(),
                Value<bool> isForceMode = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> markersJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion(
                id: id,
                title: title,
                audioPath: audioPath,
                peaksPath: peaksPath,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                segmentCount: segmentCount,
                language: language,
                status: status,
                isPartial: isPartial,
                isForceMode: isForceMode,
                isDeleted: isDeleted,
                markersJson: markersJson,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> audioPath = const Value.absent(),
                Value<String?> peaksPath = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> segmentCount = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isPartial = const Value.absent(),
                Value<bool> isForceMode = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> markersJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MeetingsCompanion.insert(
                id: id,
                title: title,
                audioPath: audioPath,
                peaksPath: peaksPath,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                segmentCount: segmentCount,
                language: language,
                status: status,
                isPartial: isPartial,
                isForceMode: isForceMode,
                isDeleted: isDeleted,
                markersJson: markersJson,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingsTable, Meeting>(table),
                  $$MeetingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                speakersRefs = false,
                transcriptSegmentsRefs = false,
                summariesRefs = false,
                actionItemsRefs = false,
                meetingTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (speakersRefs) db.speakers,
                    if (transcriptSegmentsRefs) db.transcriptSegments,
                    if (summariesRefs) db.summaries,
                    if (actionItemsRefs) db.actionItems,
                    if (meetingTagsRefs) db.meetingTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (speakersRefs)
                        await $_getPrefetchedDataByColumns<
                          Meeting,
                          $MeetingsTable,
                          Speaker,
                          $SpeakersTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._speakersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (transcriptSegmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          Meeting,
                          $MeetingsTable,
                          TranscriptSegment,
                          $TranscriptSegmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._transcriptSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (summariesRefs)
                        await $_getPrefetchedDataByColumns<
                          Meeting,
                          $MeetingsTable,
                          Summary,
                          $SummariesTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._summariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).summariesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (actionItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          Meeting,
                          $MeetingsTable,
                          ActionItem,
                          $ActionItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._actionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).actionItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                      if (meetingTagsRefs)
                        await $_getPrefetchedDataByColumns<
                          Meeting,
                          $MeetingsTable,
                          MeetingTag,
                          $MeetingTagsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MeetingsTableReferences
                              ._meetingTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MeetingsTableReferences(
                                db,
                                table,
                                p0,
                              ).meetingTagsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meeting_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingsTable,
      Meeting,
      $$MeetingsTableFilterComposer,
      $$MeetingsTableOrderingComposer,
      $$MeetingsTableAnnotationComposer,
      $$MeetingsTableCreateCompanionBuilder,
      $$MeetingsTableUpdateCompanionBuilder,
      (Meeting, $$MeetingsTableReferences),
      Meeting,
      PrefetchHooks Function({
        bool speakersRefs,
        bool transcriptSegmentsRefs,
        bool summariesRefs,
        bool actionItemsRefs,
        bool meetingTagsRefs,
      })
    >;
typedef $$SpeakersTableCreateCompanionBuilder = SpeakersCompanion Function({
  required String id,
  required String meetingId,
  required String label,
  required String displayName,
  Value<int> rowid,
});
typedef $$SpeakersTableUpdateCompanionBuilder = SpeakersCompanion Function({
  Value<String> id,
  Value<String> meetingId,
  Value<String> label,
  Value<String> displayName,
  Value<int> rowid,
});

final class $$SpeakersTableReferences
    extends BaseReferences<_$AppDatabase, $SpeakersTable, Speaker> {
  $$SpeakersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('speakers__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TranscriptSegmentsTable, List<TranscriptSegment>>
  _transcriptSegmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName: 'speakers__id__transcript_segments__speaker_id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.speakerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SpeakersTableFilterComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.speakerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SpeakersTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeakersTable> {
  $$SpeakersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.speakerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SpeakersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeakersTable,
          Speaker,
          $$SpeakersTableFilterComposer,
          $$SpeakersTableOrderingComposer,
          $$SpeakersTableAnnotationComposer,
          $$SpeakersTableCreateCompanionBuilder,
          $$SpeakersTableUpdateCompanionBuilder,
          (Speaker, $$SpeakersTableReferences),
          Speaker,
          PrefetchHooks Function({bool meetingId, bool transcriptSegmentsRefs})
        > {
  $$SpeakersTableTableManager(_$AppDatabase db, $SpeakersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeakersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion(
                id: id,
                meetingId: meetingId,
                label: label,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                required String label,
                required String displayName,
                Value<int> rowid = const Value.absent(),
              }) => SpeakersCompanion.insert(
                id: id,
                meetingId: meetingId,
                label: label,
                displayName: displayName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakersTable, Speaker>(table),
                  $$SpeakersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({meetingId = false, transcriptSegmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transcriptSegmentsRefs) db.transcriptSegments,
                  ],
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
                        if (meetingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.meetingId,
                            referencedTable: $$SpeakersTableReferences
                                ._meetingIdTable(db),
                            referencedColumn: $$SpeakersTableReferences
                                ._meetingIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transcriptSegmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          Speaker,
                          $SpeakersTable,
                          TranscriptSegment,
                          $TranscriptSegmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SpeakersTableReferences
                              ._transcriptSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SpeakersTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'speaker_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SpeakersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeakersTable,
      Speaker,
      $$SpeakersTableFilterComposer,
      $$SpeakersTableOrderingComposer,
      $$SpeakersTableAnnotationComposer,
      $$SpeakersTableCreateCompanionBuilder,
      $$SpeakersTableUpdateCompanionBuilder,
      (Speaker, $$SpeakersTableReferences),
      Speaker,
      PrefetchHooks Function({bool meetingId, bool transcriptSegmentsRefs})
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      required String id,
      required String meetingId,
      Value<String?> speakerId,
      required double startSec,
      required double endSec,
      required String textContent,
      Value<bool> edited,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<String> id,
      Value<String> meetingId,
      Value<String?> speakerId,
      Value<double> startSec,
      Value<double> endSec,
      Value<String> textContent,
      Value<bool> edited,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$TranscriptSegmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment
        > {
  $$TranscriptSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('transcript_segments__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SpeakersTable _speakerIdTable(_$AppDatabase db) =>
      db.speakers.createAlias('transcript_segments__speaker_id__speakers__id');

  $$SpeakersTableProcessedTableManager? get speakerId {
    final $_column = $_itemColumn<String>('speaker_id');
    if ($_column == null) return null;
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_speakerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
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

  ColumnFilters<double> get startSec => $composableBuilder(
    column: $table.startSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endSec => $composableBuilder(
    column: $table.endSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableFilterComposer get speakerId {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
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

  ColumnOrderings<double> get startSec => $composableBuilder(
    column: $table.startSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endSec => $composableBuilder(
    column: $table.endSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableOrderingComposer get speakerId {
    final $$SpeakersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableOrderingComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get startSec =>
      $composableBuilder(column: $table.startSec, builder: (column) => column);

  GeneratedColumn<double> get endSec =>
      $composableBuilder(column: $table.endSec, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SpeakersTableAnnotationComposer get speakerId {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.speakerId,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegment,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (TranscriptSegment, $$TranscriptSegmentsTableReferences),
          TranscriptSegment,
          PrefetchHooks Function({bool meetingId, bool speakerId})
        > {
  $$TranscriptSegmentsTableTableManager(
    _$AppDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String?> speakerId = const Value.absent(),
                Value<double> startSec = const Value.absent(),
                Value<double> endSec = const Value.absent(),
                Value<String> textContent = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                id: id,
                meetingId: meetingId,
                speakerId: speakerId,
                startSec: startSec,
                endSec: endSec,
                textContent: textContent,
                edited: edited,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                Value<String?> speakerId = const Value.absent(),
                required double startSec,
                required double endSec,
                required String textContent,
                Value<bool> edited = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                id: id,
                meetingId: meetingId,
                speakerId: speakerId,
                startSec: startSec,
                endSec: endSec,
                textContent: textContent,
                edited: edited,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranscriptSegmentsTable, TranscriptSegment>(
                    table,
                  ),
                  $$TranscriptSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, speakerId = false}) {
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
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$TranscriptSegmentsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$TranscriptSegmentsTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (speakerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.speakerId,
                        referencedTable: $$TranscriptSegmentsTableReferences
                            ._speakerIdTable(db),
                        referencedColumn: $$TranscriptSegmentsTableReferences
                            ._speakerIdTable(db)
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

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegment,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (TranscriptSegment, $$TranscriptSegmentsTableReferences),
      TranscriptSegment,
      PrefetchHooks Function({bool meetingId, bool speakerId})
    >;
typedef $$SummariesTableCreateCompanionBuilder = SummariesCompanion Function({
  required String id,
  required String meetingId,
  required String summary,
  Value<String> keyPointsJson,
  Value<String> decisionsJson,
  Value<String> openQuestionsJson,
  Value<String> rawJson,
  Value<int> rowid,
});
typedef $$SummariesTableUpdateCompanionBuilder = SummariesCompanion Function({
  Value<String> id,
  Value<String> meetingId,
  Value<String> summary,
  Value<String> keyPointsJson,
  Value<String> decisionsJson,
  Value<String> openQuestionsJson,
  Value<String> rawJson,
  Value<int> rowid,
});

final class $$SummariesTableReferences
    extends BaseReferences<_$AppDatabase, $SummariesTable, Summary> {
  $$SummariesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('summaries__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SummariesTableFilterComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableFilterComposer({
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

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyPointsJson => $composableBuilder(
    column: $table.keyPointsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decisionsJson => $composableBuilder(
    column: $table.decisionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openQuestionsJson => $composableBuilder(
    column: $table.openQuestionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableOrderingComposer({
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

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyPointsJson => $composableBuilder(
    column: $table.keyPointsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decisionsJson => $composableBuilder(
    column: $table.decisionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openQuestionsJson => $composableBuilder(
    column: $table.openQuestionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get keyPointsJson => $composableBuilder(
    column: $table.keyPointsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decisionsJson => $composableBuilder(
    column: $table.decisionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get openQuestionsJson => $composableBuilder(
    column: $table.openQuestionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SummariesTable,
          Summary,
          $$SummariesTableFilterComposer,
          $$SummariesTableOrderingComposer,
          $$SummariesTableAnnotationComposer,
          $$SummariesTableCreateCompanionBuilder,
          $$SummariesTableUpdateCompanionBuilder,
          (Summary, $$SummariesTableReferences),
          Summary,
          PrefetchHooks Function({bool meetingId})
        > {
  $$SummariesTableTableManager(_$AppDatabase db, $SummariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> keyPointsJson = const Value.absent(),
                Value<String> decisionsJson = const Value.absent(),
                Value<String> openQuestionsJson = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SummariesCompanion(
                id: id,
                meetingId: meetingId,
                summary: summary,
                keyPointsJson: keyPointsJson,
                decisionsJson: decisionsJson,
                openQuestionsJson: openQuestionsJson,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                required String summary,
                Value<String> keyPointsJson = const Value.absent(),
                Value<String> decisionsJson = const Value.absent(),
                Value<String> openQuestionsJson = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SummariesCompanion.insert(
                id: id,
                meetingId: meetingId,
                summary: summary,
                keyPointsJson: keyPointsJson,
                decisionsJson: decisionsJson,
                openQuestionsJson: openQuestionsJson,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SummariesTable, Summary>(table),
                  $$SummariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
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
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$SummariesTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$SummariesTableReferences
                            ._meetingIdTable(db)
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

typedef $$SummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SummariesTable,
      Summary,
      $$SummariesTableFilterComposer,
      $$SummariesTableOrderingComposer,
      $$SummariesTableAnnotationComposer,
      $$SummariesTableCreateCompanionBuilder,
      $$SummariesTableUpdateCompanionBuilder,
      (Summary, $$SummariesTableReferences),
      Summary,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$ActionItemsTableCreateCompanionBuilder =
    ActionItemsCompanion Function({
      required String id,
      required String meetingId,
      required String task,
      Value<String> owner,
      Value<String?> dueDate,
      Value<bool> done,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ActionItemsTableUpdateCompanionBuilder =
    ActionItemsCompanion Function({
      Value<String> id,
      Value<String> meetingId,
      Value<String> task,
      Value<String> owner,
      Value<String?> dueDate,
      Value<bool> done,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$ActionItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ActionItemsTable, ActionItem> {
  $$ActionItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('action_items__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ActionItemsTable> {
  $$ActionItemsTableFilterComposer({
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

  ColumnFilters<String> get task => $composableBuilder(
    column: $table.task,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActionItemsTable> {
  $$ActionItemsTableOrderingComposer({
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

  ColumnOrderings<String> get task => $composableBuilder(
    column: $table.task,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActionItemsTable> {
  $$ActionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get task =>
      $composableBuilder(column: $table.task, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActionItemsTable,
          ActionItem,
          $$ActionItemsTableFilterComposer,
          $$ActionItemsTableOrderingComposer,
          $$ActionItemsTableAnnotationComposer,
          $$ActionItemsTableCreateCompanionBuilder,
          $$ActionItemsTableUpdateCompanionBuilder,
          (ActionItem, $$ActionItemsTableReferences),
          ActionItem,
          PrefetchHooks Function({bool meetingId})
        > {
  $$ActionItemsTableTableManager(_$AppDatabase db, $ActionItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> meetingId = const Value.absent(),
                Value<String> task = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActionItemsCompanion(
                id: id,
                meetingId: meetingId,
                task: task,
                owner: owner,
                dueDate: dueDate,
                done: done,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String meetingId,
                required String task,
                Value<String> owner = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActionItemsCompanion.insert(
                id: id,
                meetingId: meetingId,
                task: task,
                owner: owner,
                dueDate: dueDate,
                done: done,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActionItemsTable, ActionItem>(table),
                  $$ActionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false}) {
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
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$ActionItemsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$ActionItemsTableReferences
                            ._meetingIdTable(db)
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

typedef $$ActionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActionItemsTable,
      ActionItem,
      $$ActionItemsTableFilterComposer,
      $$ActionItemsTableOrderingComposer,
      $$ActionItemsTableAnnotationComposer,
      $$ActionItemsTableCreateCompanionBuilder,
      $$ActionItemsTableUpdateCompanionBuilder,
      (ActionItem, $$ActionItemsTableReferences),
      ActionItem,
      PrefetchHooks Function({bool meetingId})
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required String id,
  required String name,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> rowid,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MeetingTagsTable, List<MeetingTag>>
  _meetingTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.meetingTags,
    aliasName: 'tags__id__meeting_tags__tag_id',
  );

  $$MeetingTagsTableProcessedTableManager get meetingTagsRefs {
    final manager = $$MeetingTagsTableTableManager(
      $_db,
      $_db.meetingTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_meetingTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  Expression<bool> meetingTagsRefs(
    Expression<bool> Function($$MeetingTagsTableFilterComposer f) f,
  ) {
    final $$MeetingTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meetingTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingTagsTableFilterComposer(
            $db: $db,
            $table: $db.meetingTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
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

  Expression<T> meetingTagsRefs<T extends Object>(
    Expression<T> Function($$MeetingTagsTableAnnotationComposer a) f,
  ) {
    final $$MeetingTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meetingTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetingTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool meetingTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => TagsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<int> rowid = const Value.absent(),
          }) => TagsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, Tag>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (meetingTagsRefs) db.meetingTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (meetingTagsRefs)
                    await $_getPrefetchedDataByColumns<
                      Tag,
                      $TagsTable,
                      MeetingTag,
                      $MeetingTagsTable
                    >(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._meetingTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).meetingTagsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'tag_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool meetingTagsRefs})
    >;
typedef $$MeetingTagsTableCreateCompanionBuilder =
    MeetingTagsCompanion Function({
      required String meetingId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$MeetingTagsTableUpdateCompanionBuilder =
    MeetingTagsCompanion Function({
      Value<String> meetingId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$MeetingTagsTableReferences
    extends BaseReferences<_$AppDatabase, $MeetingTagsTable, MeetingTag> {
  $$MeetingTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeetingsTable _meetingIdTable(_$AppDatabase db) =>
      db.meetings.createAlias('meeting_tags__meeting_id__meetings__id');

  $$MeetingsTableProcessedTableManager get meetingId {
    final $_column = $_itemColumn<String>('meeting_id')!;

    final manager = $$MeetingsTableTableManager(
      $_db,
      $_db.meetings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_meetingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('meeting_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MeetingTagsTableFilterComposer
    extends Composer<_$AppDatabase, $MeetingTagsTable> {
  $$MeetingTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MeetingsTableFilterComposer get meetingId {
    final $$MeetingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableFilterComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeetingTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeetingTagsTable> {
  $$MeetingTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MeetingsTableOrderingComposer get meetingId {
    final $$MeetingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableOrderingComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeetingTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeetingTagsTable> {
  $$MeetingTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MeetingsTableAnnotationComposer get meetingId {
    final $$MeetingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.meetingId,
      referencedTable: $db.meetings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeetingsTableAnnotationComposer(
            $db: $db,
            $table: $db.meetings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeetingTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeetingTagsTable,
          MeetingTag,
          $$MeetingTagsTableFilterComposer,
          $$MeetingTagsTableOrderingComposer,
          $$MeetingTagsTableAnnotationComposer,
          $$MeetingTagsTableCreateCompanionBuilder,
          $$MeetingTagsTableUpdateCompanionBuilder,
          (MeetingTag, $$MeetingTagsTableReferences),
          MeetingTag,
          PrefetchHooks Function({bool meetingId, bool tagId})
        > {
  $$MeetingTagsTableTableManager(_$AppDatabase db, $MeetingTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeetingTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeetingTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeetingTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> meetingId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeetingTagsCompanion(
                meetingId: meetingId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String meetingId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => MeetingTagsCompanion.insert(
                meetingId: meetingId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeetingTagsTable, MeetingTag>(table),
                  $$MeetingTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({meetingId = false, tagId = false}) {
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
                    if (meetingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.meetingId,
                        referencedTable: $$MeetingTagsTableReferences
                            ._meetingIdTable(db),
                        referencedColumn: $$MeetingTagsTableReferences
                            ._meetingIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$MeetingTagsTableReferences
                            ._tagIdTable(db),
                        referencedColumn: $$MeetingTagsTableReferences
                            ._tagIdTable(db)
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

typedef $$MeetingTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeetingTagsTable,
      MeetingTag,
      $$MeetingTagsTableFilterComposer,
      $$MeetingTagsTableOrderingComposer,
      $$MeetingTagsTableAnnotationComposer,
      $$MeetingTagsTableCreateCompanionBuilder,
      $$MeetingTagsTableUpdateCompanionBuilder,
      (MeetingTag, $$MeetingTagsTableReferences),
      MeetingTag,
      PrefetchHooks Function({bool meetingId, bool tagId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MeetingsTableTableManager get meetings =>
      $$MeetingsTableTableManager(_db, _db.meetings);
  $$SpeakersTableTableManager get speakers =>
      $$SpeakersTableTableManager(_db, _db.speakers);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
  $$SummariesTableTableManager get summaries =>
      $$SummariesTableTableManager(_db, _db.summaries);
  $$ActionItemsTableTableManager get actionItems =>
      $$ActionItemsTableTableManager(_db, _db.actionItems);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$MeetingTagsTableTableManager get meetingTags =>
      $$MeetingTagsTableTableManager(_db, _db.meetingTags);
}
