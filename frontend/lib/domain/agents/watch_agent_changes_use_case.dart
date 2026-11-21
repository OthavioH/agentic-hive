import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Subscribes to real-time agent filesystem change events.
final class WatchAgentChangesUseCase {
  /// Creates a [WatchAgentChangesUseCase].
  const new(this._repository);

  final AgentRepository _repository;

  /// Returns a stream of [AgentsChangedPayload] events.
  Stream<AgentsChangedPayload> call() => _repository.watchAgentChanges();
}
