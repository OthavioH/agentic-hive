import 'package:freezed_annotation/freezed_annotation.dart';

/// How a workspace snapshot was triggered.
enum SnapshotKind {
  /// Captured automatically before a node executes.
  @JsonValue('pre_node')
  preNode('pre_node'),

  /// Captured automatically right before restoring an earlier snapshot.
  @JsonValue('safety_pre_restore')
  safetyPreRestore('safety_pre_restore');

  new(this.wireName);

  /// Snake-case wire representation (for example `pre_node`).
  final String wireName;

  /// Parses a [SnapshotKind] from its [wireName], throwing a
  /// [FormatException] when unknown.
  static SnapshotKind fromWireName(String wireName) {
    for (final value in values) {
      if (value.wireName == wireName) return value;
    }
    throw FormatException('Unknown SnapshotKind "$wireName".');
  }
}
