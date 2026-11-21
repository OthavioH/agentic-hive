import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String workspacePath;
  late ResultContractValidator validator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rc_val_');
    workspacePath = p.join(tempDir.path, 'workspace');
    await Directory(workspacePath).create(recursive: true);
    validator = ResultContractValidator();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ResultContractValidator', () {
    test('accepts valid standard payload with data and relative artifacts', () {
      final result = validator.validate(
        const <String, Object?>{
          'status': 'onSuccess',
          'summary': 'Implemented feature X.',
          'data': <String, Object?>{'filesChanged': 2},
          'artifacts': <String>['lib/main.dart', 'test/main_test.dart'],
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[
          NodeOutput.onSuccess,
          NodeOutput.onFailure,
        ],
      );

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.status, ResultContractStatus.success);
      expect(report.summary, 'Implemented feature X.');
      expect(report.output, const <String, Object?>{'filesChanged': 2});
      expect(report.artifacts, const <String>[
        'lib/main.dart',
        'test/main_test.dart',
      ]);
    });

    test('accepts review outputs approved and changesRequested', () {
      final approved = validator.validate(
        const <String, Object?>{
          'status': 'approved',
          'summary': 'All criteria satisfied.',
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[
          NodeOutput.approved,
          NodeOutput.changesRequested,
        ],
      );
      expect(approved.valueOrNull?.status, ResultContractStatus.approved);

      final changes = validator.validate(
        const <String, Object?>{
          'status': 'changesRequested',
          'summary': 'Missing unit tests.',
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[
          NodeOutput.approved,
          NodeOutput.changesRequested,
        ],
      );
      expect(
        changes.valueOrNull?.status,
        ResultContractStatus.changesRequested,
      );
    });

    test('rejects status outside declared availableOutputs', () {
      final result = validator.validate(
        const <String, Object?>{'status': 'approved', 'summary': 'Looks good.'},
        workspacePath: workspacePath,
        availableOutputs: const <String>[
          NodeOutput.onSuccess,
          NodeOutput.onFailure,
        ],
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects missing or blank summary', () {
      final missing = validator.validate(
        const <String, Object?>{'status': 'onSuccess'},
        workspacePath: workspacePath,
        availableOutputs: const <String>[NodeOutput.onSuccess],
      );
      expect(missing.failureOrNull, isA<ValidationFailure>());

      final blank = validator.validate(
        const <String, Object?>{'status': 'onSuccess', 'summary': '   '},
        workspacePath: workspacePath,
        availableOutputs: const <String>[NodeOutput.onSuccess],
      );
      expect(blank.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects non-map data', () {
      final result = validator.validate(
        const <String, Object?>{
          'status': 'onSuccess',
          'summary': 'Done.',
          'data': 'not-an-object',
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[NodeOutput.onSuccess],
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects artifact path traversal and absolute paths', () {
      final traversal = validator.validate(
        const <String, Object?>{
          'status': 'onSuccess',
          'summary': 'Done.',
          'artifacts': <String>['../secret.txt'],
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[NodeOutput.onSuccess],
      );
      expect(traversal.failureOrNull, isA<ValidationFailure>());

      final absolute = validator.validate(
        <String, Object?>{
          'status': 'onSuccess',
          'summary': 'Done.',
          'artifacts': <String>[p.join(tempDir.path, 'outside.txt')],
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[NodeOutput.onSuccess],
      );
      expect(absolute.failureOrNull, isA<ValidationFailure>());

      final emptyItem = validator.validate(
        const <String, Object?>{
          'status': 'onSuccess',
          'summary': 'Done.',
          'artifacts': <String>['  '],
        },
        workspacePath: workspacePath,
        availableOutputs: const <String>[NodeOutput.onSuccess],
      );
      expect(emptyItem.failureOrNull, isA<ValidationFailure>());
    });

    test(
      'rejects symlink artifact escaping workspace when links are supported',
      () async {
        final outsideDir = Directory(p.join(tempDir.path, 'outside'));
        await outsideDir.create(recursive: true);
        final linkPath = p.join(workspacePath, 'escape_link');
        try {
          await Link(linkPath).create(outsideDir.path);
        } on FileSystemException {
          // Windows without Developer Mode / admin privileges may forbid symlinks.
          return;
        }

        final result = validator.validate(
          const <String, Object?>{
            'status': 'onSuccess',
            'summary': 'Done.',
            'artifacts': <String>['escape_link/secret.txt'],
          },
          workspacePath: workspacePath,
          availableOutputs: const <String>[NodeOutput.onSuccess],
        );

        expect(result.failureOrNull, isA<ValidationFailure>());
      },
    );
  });
}
