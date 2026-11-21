import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pending_pauses_count_provider.g.dart';

/// Live stream of the number of pending pauses for the navigation rail badge.
@riverpod
Stream<int> pendingPausesCount(Ref ref) {
  return ref.watch(watchPendingPausesCountUseCaseProvider)();
}
