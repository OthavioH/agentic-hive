import 'dart:async';

import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/data/window/window_controls_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'window_providers.g.dart';

/// Provides the [WindowControlsRepository] backed by
/// [windowLifecycleServiceProvider].
@riverpod
WindowControlsRepository windowControlsRepository(Ref ref) {
  final repository = WindowControlsRepositoryImpl(
    ref.watch(windowLifecycleServiceProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}
