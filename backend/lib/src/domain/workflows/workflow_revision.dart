import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:crypto/crypto.dart';

/// Length of a workflow revision in hex characters.
const workflowRevisionLength = 16;

/// Content hash of [workflow]'s definition used for optimistic concurrency
/// (ADR 0026). Ignores `createdAt`/`updatedAt`; map keys are sorted.
String workflowRevision(Workflow workflow) {
  final json =
      (jsonDecode(jsonEncode(workflow.toJson())) as Map<String, Object?>)
        ..remove('createdAt')
        ..remove('updatedAt');
  final canonical = jsonEncode(_canonical(json));
  return sha256
      .convert(utf8.encode(canonical))
      .toString()
      .substring(0, workflowRevisionLength);
}

Object? _canonical(Object? value) => switch (value) {
  Map<String, Object?>() => {
    for (final key in value.keys.toList()..sort()) key: _canonical(value[key]),
  },
  List<Object?>() => [for (final item in value) _canonical(item)],
  _ => value,
};
