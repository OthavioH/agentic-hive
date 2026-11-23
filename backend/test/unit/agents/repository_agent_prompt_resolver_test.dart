import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/repository_agent_prompt_resolver.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakeAgentRepository implements AgentRepository {
  final Map<String, Result<AgentDetail>> responses =
      <String, Result<AgentDetail>>{};

  @override
  Future<Result<AgentDetail>> getById(String id) async =>
      responses[id] ?? FailureResult(NotFoundFailure('Agent "$id" not found.'));

  @override
  Future<Result<List<AgentSummary>>> list() => throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> create(CreateAgentRequest request) =>
      throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> update(String id, UpdateAgentRequest request) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String id) => throw UnimplementedError();
}

AgentDetail _detail({
  String id = 'reviewer',
  String prompt = 'Review the diff carefully.',
  List<String> allowedTools = const <String>[],
  List<String> deniedTools = const <String>[],
  String? parseError,
  String? rawContent,
}) => AgentDetail(
  id: id,
  name: 'Reviewer',
  contentHash: 'hash',
  updatedAt: DateTime.utc(2026),
  allowedTools: allowedTools,
  deniedTools: deniedTools,
  prompt: prompt,
  parseError: parseError,
  rawContent: rawContent,
);

void main() {
  late _FakeAgentRepository repository;
  late RepositoryAgentPromptResolver resolver;

  setUp(() {
    repository = _FakeAgentRepository();
    resolver = RepositoryAgentPromptResolver(repository);
  });

  group('RepositoryAgentPromptResolver', () {
    test('returns prompt when agent is found and valid', () async {
      repository.responses['reviewer'] = Success(_detail());

      final result = await resolver.resolvePrompt('reviewer');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 'Review the diff carefully.');
    });

    test('propagates NotFoundFailure when agent is missing', () async {
      final result = await resolver.resolvePrompt('missing-agent');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull!.message, contains('missing-agent'));
    });

    test(
      'returns failure naming agent and parseError when file has parseError',
      () async {
        repository.responses['broken'] = Success(
          _detail(
            id: 'broken',
            prompt: '',
            parseError: 'Missing YAML frontmatter.',
            rawContent: 'raw broken content',
          ),
        );

        final result = await resolver.resolvePrompt('broken');

        expect(result.isFailure, isTrue);
        final message = result.failureOrNull!.message;
        expect(message, contains('broken'));
        expect(message, contains('Missing YAML frontmatter.'));
        expect(message, isNot(contains('raw broken content')));
      },
    );

    test('returns failure when prompt is empty or whitespace-only', () async {
      repository.responses['empty'] = Success(_detail(id: 'empty', prompt: ''));
      repository.responses['blank'] = Success(
        _detail(id: 'blank', prompt: '   \n\t  '),
      );

      final emptyResult = await resolver.resolvePrompt('empty');
      final blankResult = await resolver.resolvePrompt('blank');

      expect(emptyResult.isFailure, isTrue);
      expect(emptyResult.failureOrNull!.message, contains('empty'));
      expect(blankResult.isFailure, isTrue);
      expect(blankResult.failureOrNull!.message, contains('blank'));
    });

    test('does not cache prompts across calls', () async {
      repository.responses['dynamic'] = Success(
        _detail(id: 'dynamic', prompt: 'First prompt.'),
      );
      final first = await resolver.resolvePrompt('dynamic');
      expect(first.valueOrNull, 'First prompt.');

      repository.responses['dynamic'] = Success(
        _detail(id: 'dynamic', prompt: 'Updated prompt.'),
      );
      final second = await resolver.resolvePrompt('dynamic');
      expect(second.valueOrNull, 'Updated prompt.');
    });

    test(
      'resolveAgent returns prompt alongside allowedTools and deniedTools',
      () async {
        repository.responses['sweeper'] = Success(
          _detail(
            id: 'sweeper',
            prompt: 'Sweep the codebase.',
            allowedTools: const <String>['Read', 'Edit'],
            deniedTools: const <String>['Bash(rm *)'],
          ),
        );

        final result = await resolver.resolveAgent('sweeper');

        expect(result.isSuccess, isTrue);
        final resolved = result.valueOrNull!;
        expect(resolved.prompt, 'Sweep the codebase.');
        expect(resolved.allowedTools, const <String>['Read', 'Edit']);
        expect(resolved.deniedTools, const <String>['Bash(rm *)']);
      },
    );
  });
}
