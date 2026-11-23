import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_slug.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain operations for managing the agent library.
final class AgentService {
  /// Creates an agent service backed by [_repository].
  const new(this._repository);

  final AgentRepository _repository;

  /// Lists all agents in the library.
  Future<Result<List<AgentSummary>>> list() => _repository.list();

  /// Loads the agent with filename stem [id].
  Future<Result<AgentDetail>> getById(String id) {
    final validId = validateAgentLookupId(id);
    if (validId case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    return _repository.getById(id);
  }

  /// Creates a new agent from [request].
  Future<Result<AgentDetail>> create(CreateAgentRequest request) {
    final slug = validateAgentSlug(request.id);
    if (slug case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    if (request.name.trim().isEmpty) {
      return Future.value(
        const FailureResult(ValidationFailure('Agent name must not be empty.')),
      );
    }
    return _repository.create(request);
  }

  /// Updates an existing agent [id] from [request].
  Future<Result<AgentDetail>> update(String id, UpdateAgentRequest request) {
    final slug = validateAgentSlug(id);
    if (slug case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    if (request.name.trim().isEmpty) {
      return Future.value(
        const FailureResult(ValidationFailure('Agent name must not be empty.')),
      );
    }
    if (request.expectedHash.trim().isEmpty) {
      return Future.value(
        const FailureResult(
          ValidationFailure('expectedHash must not be empty.'),
        ),
      );
    }
    return _repository.update(id, request);
  }

  /// Deletes the agent with filename stem [id].
  Future<Result<void>> delete(String id) {
    final validId = validateAgentLookupId(id);
    if (validId case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    return _repository.delete(id);
  }
}
