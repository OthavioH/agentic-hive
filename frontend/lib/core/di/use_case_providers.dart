// Entry point for Riverpod use case providers (ADR 0017).
//
// Feature use case providers are registered here so presentation controllers
// depend on domain use cases without importing data implementations.

import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/harnesses/get_harnesses_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/refresh_harness_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/refresh_harnesses_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/watch_harness_updates_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'use_case_providers.g.dart';

/// Provides [GetHarnessesUseCase].
@riverpod
GetHarnessesUseCase getHarnessesUseCase(Ref ref) =>
    GetHarnessesUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [RefreshHarnessesUseCase].
@riverpod
RefreshHarnessesUseCase refreshHarnessesUseCase(Ref ref) =>
    RefreshHarnessesUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [RefreshHarnessUseCase].
@riverpod
RefreshHarnessUseCase refreshHarnessUseCase(Ref ref) =>
    RefreshHarnessUseCase(ref.watch(harnessRepositoryProvider));

/// Provides [WatchHarnessUpdatesUseCase].
@riverpod
WatchHarnessUpdatesUseCase watchHarnessUpdatesUseCase(Ref ref) =>
    WatchHarnessUpdatesUseCase(ref.watch(harnessRepositoryProvider));
