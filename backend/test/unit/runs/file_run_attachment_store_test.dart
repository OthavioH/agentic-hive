import 'dart:io';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/runs/file_run_attachment_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_validator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late FileRunAttachmentStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('attachment_store_test_');
    store = FileRunAttachmentStore(runsDir: tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  DecodedRunAttachment decoded(
    String fileName,
    String mimeType,
    String ext,
    List<int> bytes,
  ) => DecodedRunAttachment(
    fileName: fileName,
    mimeType: mimeType,
    extension: ext,
    bytes: Uint8List.fromList(bytes),
  );

  test(
    'write creates numbered files and leaves sibling results untouched',
    () async {
      final resultsDir = Directory(p.join(tempDir.path, 'r1', 'results'));
      await resultsDir.create(recursive: true);
      final resultFile = File(p.join(resultsDir.path, 'result.json'));
      await resultFile.writeAsString('{"ok":true}');

      final files = [
        decoded('a.png', 'image/png', 'png', [1, 2, 3]),
        decoded('b.jpg', 'image/jpeg', 'jpg', [4, 5, 6]),
      ];

      final res = await store.write('r1', files);
      expect(res, isA<Success<void>>());

      final f1 = File(p.join(tempDir.path, 'r1', 'attachments', '1.png'));
      final f2 = File(p.join(tempDir.path, 'r1', 'attachments', '2.jpg'));
      expect(f1.existsSync(), isTrue);
      expect(f2.existsSync(), isTrue);
      expect(await f1.readAsBytes(), [1, 2, 3]);
      expect(await f2.readAsBytes(), [4, 5, 6]);
      expect(await resultFile.readAsString(), '{"ok":true}');
    },
  );

  test('crafted fileName never escapes attachments directory', () async {
    final files = [
      decoded('../../evil.png', 'image/png', 'png', [10, 20]),
      decoded(r'C:\x.png', 'image/png', 'png', [30, 40]),
    ];

    final res = await store.write('r1', files);
    expect(res, isA<Success<void>>());

    expect(
      File(p.join(tempDir.path, 'r1', 'attachments', '1.png')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(tempDir.path, 'r1', 'attachments', '2.png')).existsSync(),
      isTrue,
    );
    expect(File(p.join(tempDir.path, 'evil.png')).existsSync(), isFalse);
  });

  test(
    'deleteRun removes attachments folder and succeeds when missing',
    () async {
      await store.write('r1', [
        decoded('a.png', 'image/png', 'png', [1]),
      ]);
      expect(Directory(store.attachmentsDir('r1')).existsSync(), isTrue);

      expect(await store.deleteRun('r1'), isA<Success<void>>());
      expect(Directory(store.attachmentsDir('r1')).existsSync(), isFalse);

      expect(await store.deleteRun('missing'), isA<Success<void>>());
    },
  );

  test('listRunIds returns only run dirs that have attachments', () async {
    await store.write('r1', [
      decoded('a.png', 'image/png', 'png', [1]),
    ]);
    await Directory(p.join(tempDir.path, 'r2', 'results'))
        .create(recursive: true);

    final ids = await store.listRunIds();
    expect(ids, isA<Success<List<String>>>());
    expect(ids.valueOrNull, ['r1']);

    final missingStore = FileRunAttachmentStore(
      runsDir: p.join(tempDir.path, 'does_not_exist'),
    );
    final missingIds = await missingStore.listRunIds();
    expect(missingIds.valueOrNull, isEmpty);
  });

  test(
    'write failure returns PersistenceFailure and leaves no files',
    () async {
      final r1Dir = Directory(p.join(tempDir.path, 'r1'));
      await r1Dir.create(recursive: true);
      await File(p.join(r1Dir.path, 'attachments')).writeAsString('blocker');

      final res = await store.write('r1', [
        decoded('a.png', 'image/png', 'png', [1]),
      ]);
      expect(res, isA<FailureResult<void>>());
      expect((res as FailureResult).failure, isA<PersistenceFailure>());
      expect(
        File(p.join(r1Dir.path, 'attachments', '1.png')).existsSync(),
        isFalse,
      );
    },
  );

  test('filePath matches the file name written by write', () async {
    final files = [
      decoded('a.png', 'image/png', 'png', [1]),
      decoded('b.jpg', 'image/jpeg', 'jpg', [2]),
    ];
    final res = await store.write('r1', files);
    expect(res, isA<Success<void>>());

    for (var i = 0; i < files.length; i++) {
      final expectedPath = store.filePath('r1', i, files[i].toMetadata());
      expect(File(expectedPath).existsSync(), isTrue);
    }
  });
}
