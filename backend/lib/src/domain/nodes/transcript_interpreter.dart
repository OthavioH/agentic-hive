import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Interprets raw log entries from a single node attempt into neutral
/// [TranscriptEntry] items.
///
/// One instance is created per attempt, fed raw entries in ascending `offset`
/// order, and may retain state across entries. Output must depend only on the
/// entries fed so far (no clock, no randomness) so full history reads and live
/// streams produce identical transcripts.
///
/// Each call to [interpret] returns the entries this raw entry adds or
/// replaces; an entry with the same `id` as an earlier one replaces it in its
/// original position.
abstract interface class TranscriptInterpreter {
  /// Interprets one raw [entry] and returns the transcript entries it adds or
  /// replaces.
  List<TranscriptEntry> interpret(RunLogEntry entry);
}

/// Builds a deterministic [TranscriptEntry.id] from a raw log [entry] offset
/// and an optional zero-based [index] for multi-entry lines.
String transcriptEntryId(RunLogEntry entry, [int index = 0]) =>
    index == 0 ? '${entry.offset}' : '${entry.offset}.$index';

/// Converts a raw log [entry] into a [TranscriptEntry.plainText] entry.
TranscriptEntry plainTextEntry(RunLogEntry entry) => TranscriptEntry.plainText(
  id: transcriptEntryId(entry),
  firstOffset: entry.offset,
  lastOffset: entry.offset,
  stream: entry.stream,
  text: entry.chunk,
);

/// Default [TranscriptInterpreter] that maps every raw line to plain text.
final class PlainTextTranscriptInterpreter implements TranscriptInterpreter {
  /// Creates a plain-text transcript interpreter.
  const new();

  @override
  List<TranscriptEntry> interpret(RunLogEntry entry) => [plainTextEntry(entry)];
}

/// Base [TranscriptInterpreter] for harnesses that emit one JSON object per
/// `stdout` line.
///
/// `stderr` lines, invalid JSON, non-object JSON values, and events for which
/// [interpretEvent] returns `null` fall back to [plainTextEntry] so nothing is
/// ever dropped silently. Returning an empty list from [interpretEvent]
/// explicitly hides an event.
abstract base class JsonLineTranscriptInterpreter
    implements TranscriptInterpreter {
  /// Creates a JSON-line transcript interpreter.
  new();

  @override
  List<TranscriptEntry> interpret(RunLogEntry entry) {
    if (entry.stream == RunOutputStream.stderr) {
      return [plainTextEntry(entry)];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(entry.chunk);
    } on FormatException {
      return [plainTextEntry(entry)];
    }

    if (decoded is! JsonMap) {
      return [plainTextEntry(entry)];
    }

    return interpretEvent(decoded, entry) ?? [plainTextEntry(entry)];
  }

  /// Interprets a decoded JSON object [event] from [entry].
  ///
  /// Return `null` to fall back to [plainTextEntry], or an empty list to hide
  /// the event.
  List<TranscriptEntry>? interpretEvent(JsonMap event, RunLogEntry entry);
}

/// Folds raw [entries] through [interpreter] into an ordered transcript,
/// replacing earlier entries with the same `id` in their original position.
List<TranscriptEntry> buildTranscript(
  TranscriptInterpreter interpreter,
  Iterable<RunLogEntry> entries,
) {
  final byId = <String, TranscriptEntry>{};
  for (final entry in entries) {
    for (final item in interpreter.interpret(entry)) {
      byId[item.id] = item;
    }
  }
  return byId.values.toList(growable: false);
}
