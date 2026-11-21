import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/create_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/delete_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/get_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/list_agents_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/update_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/watch_agent_changes_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'use_case_providers.g.dart';

/// Provides [ListAgentsUseCase].
@riverpod
ListAgentsUseCase listAgentsUseCase(Ref ref) =>
    ListAgentsUseCase(ref.watch(agentRepositoryProvider));

/// Provides [GetAgentUseCase].
@riverpod
GetAgentUseCase getAgentUseCase(Ref ref) =>
    GetAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [CreateAgentUseCase].
@riverpod
CreateAgentUseCase createAgentUseCase(Ref ref) =>
    CreateAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [UpdateAgentUseCase].
@riverpod
UpdateAgentUseCase updateAgentUseCase(Ref ref) =>
    UpdateAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [DeleteAgentUseCase].
@riverpod
DeleteAgentUseCase deleteAgentUseCase(Ref ref) =>
    DeleteAgentUseCase(ref.watch(agentRepositoryProvider));

/// Provides [WatchAgentChangesUseCase].
@riverpod
WatchAgentChangesUseCase watchAgentChangesUseCase(Ref ref) =>
    WatchAgentChangesUseCase(ref.watch(agentRepositoryProvider));
