import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'harnesses_state.freezed.dart';

/// View state for the Harnesses status page.
@freezed
sealed class HarnessesState with _$HarnessesState {
  /// Creates a [HarnessesState].
  const factory({
    required List<HarnessInfo> harnesses,
    @Default(false) bool isRefreshingAll,
    @Default(<HarnessId>{}) Set<HarnessId> refreshingIds,
    @Default(<HarnessId>{}) Set<HarnessId> installingMcpIds,
  }) = _HarnessesState;
}
