import 'package:test/test.dart';

import '../../../tool/src/hive/spec_input.dart';

void main() {
  test('reads the first number of the Run input section', () {
    const prompt =
        'Agent text 42\n\n## Run input\nSpec #100\n\n'
        '## Execution Context\n- Run ID: 7';
    expect(specNumberFromPrompt(prompt), 100);
  });

  test('reads a Run input section at the end of the prompt', () {
    expect(specNumberFromPrompt('## Run input\n100'), 100);
  });

  test('returns null without a Run input section or a number', () {
    expect(specNumberFromPrompt('## Execution Context\n- Run ID: 7'), isNull);
    expect(specNumberFromPrompt('## Run input\nnone\n## Other\n7'), isNull);
  });
}
