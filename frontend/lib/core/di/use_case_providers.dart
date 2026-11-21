// Entry point for Riverpod use case providers (ADR 0017).
//
// Feature use case providers are registered here so presentation controllers
// depend on domain use cases without importing data implementations.
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/create_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/delete_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/duplicate_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/get_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/list_workflows.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/update_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/validate_workflow.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'use_case_providers.g.dart';

/// Provides [ListWorkflows].
@riverpod
ListWorkflows listWorkflows(Ref ref) =>
    ListWorkflows(ref.watch(workflowRepositoryProvider));

/// Provides [GetWorkflow].
@riverpod
GetWorkflow getWorkflow(Ref ref) =>
    GetWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [CreateWorkflow].
@riverpod
CreateWorkflow createWorkflow(Ref ref) =>
    CreateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [UpdateWorkflow].
@riverpod
UpdateWorkflow updateWorkflow(Ref ref) =>
    UpdateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [DuplicateWorkflow].
@riverpod
DuplicateWorkflow duplicateWorkflow(Ref ref) =>
    DuplicateWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [DeleteWorkflow].
@riverpod
DeleteWorkflow deleteWorkflow(Ref ref) =>
    DeleteWorkflow(ref.watch(workflowRepositoryProvider));

/// Provides [ValidateWorkflow].
@riverpod
ValidateWorkflow validateWorkflow(Ref ref) =>
    ValidateWorkflow(ref.watch(workflowRepositoryProvider));
