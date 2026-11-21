import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';

final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

const _maxSlugLength = 128;

const _windowsReservedNames = <String>{
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
};

/// Validates that [id] is a cross-platform safe lowercase agent slug.
Result<String> validateAgentSlug(String id) {
  if (id.isEmpty || id.length > _maxSlugLength) {
    return const FailureResult(
      ValidationFailure(
        'Agent id must be between 1 and $_maxSlugLength characters.',
      ),
    );
  }
  if (!_slugPattern.hasMatch(id)) {
    return FailureResult(
      ValidationFailure(
        'Agent id "$id" must match [a-z0-9][a-z0-9_-]* (lowercase letters, '
        'digits, hyphens, or underscores).',
      ),
    );
  }
  if (_windowsReservedNames.contains(id)) {
    return FailureResult(
      ValidationFailure(
        'Agent id "$id" is a reserved operating-system filename.',
      ),
    );
  }
  return Success(id);
}
